import Foundation

@MainActor
final class PracticeSessionViewModel: ObservableObject {
    enum LoopPhase: Equatable {
        case preparingSession
        case readyToRecord
        case recording
        case uploading
        case analyzing
        case readyForRetry
        case completingSession
        case completed
        case unavailable
    }

    enum CompletionAction {
        case relatedScenario
        case quickDrill
    }

    struct SessionStartResolution: Equatable {
        let sessionId: String?
        let paywallRequired: Bool
        let paywallReason: String?
        let errorMessage: String?
        let loopPhase: LoopPhase
    }

    @Published var sessionId: String?
    @Published var currentRepIndex = 1
    @Published var maxReps = 3
    @Published var isBusy = false
    @Published var isRecording = false
    @Published var elapsed: TimeInterval = 0
    @Published var latestFeedback: AnalyzeRepResponse?
    @Published var reps: [SpeakingRep] = []
    @Published var completion: CompleteSessionResponse?
    @Published var paywallRequired = false
    @Published var paywallReason: String?
    @Published var isBestAnswerSaved = false
    @Published var errorMessage: String?
    @Published var loopPhase: LoopPhase = .preparingSession

    private let dependencies: Dependencies
    private let context: SessionContext
    private let minimumDuration: TimeInterval = 30
    private let maximumDuration: TimeInterval = 90
    private var currentRecordingURL: URL?
    private var currentLocalAudioPath: String?
    private var hasLoggedFirstRepStarted = false
    private var hasLoggedFirstRepCompleted = false

    init(dependencies: Dependencies, context: SessionContext) {
        self.dependencies = dependencies
        self.context = context
        self.maxReps = context.sessionType == .full ? 3 : 1
    }

    func start() async {
        guard sessionId == nil else { return }
        isBusy = true
        loopPhase = .preparingSession
        errorMessage = nil
        defer { isBusy = false }

        await dependencies.authService.ensureUserSession()
        guard dependencies.authService.user != nil else {
            applySessionStartResolution(Self.unauthenticatedSessionStartResolution())
            return
        }

        do {
            let result = try await dependencies.sessionService.startSession(
                mode: context.mode,
                scenarioId: context.scenario.id,
                scenarioPrompt: context.scenario.promptText,
                sessionType: context.sessionType
            )

            let resolution = Self.sessionStartResolution(for: result)
            applySessionStartResolution(resolution)
            if resolution.sessionId != nil {
                refreshSavedState()
            }
        } catch {
            dependencies.telemetry.record(error: error, context: "start_session", metadata: ["mode": context.mode.rawValue])
            applySessionStartResolution(Self.failedSessionStartResolution(isLocalBackend: BackendConfig.isLocalBackend))
        }
    }

    func toggleRecording() async {
        if isRecording {
            await stopAndAnalyze()
        } else {
            await startRecording()
        }
    }

    private func startRecording() async {
        do {
            errorMessage = nil
            let granted = await dependencies.recorder.requestPermission()
            guard granted else {
                errorMessage = "Microphone access is required to practice."
                loopPhase = .readyToRecord
                return
            }

            let fileURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("talktrack-\(UUID().uuidString).m4a")

            try dependencies.recorder.startRecording(to: fileURL)
            currentRecordingURL = fileURL
            currentLocalAudioPath = nil
            isRecording = true
            elapsed = 0
            loopPhase = .recording
            if currentRepIndex == 1, !hasLoggedFirstRepStarted {
                hasLoggedFirstRepStarted = true
                dependencies.telemetry.logFirstRepStarted(mode: context.mode)
            }

            Task {
                while self.isRecording {
                    self.elapsed = self.dependencies.recorder.elapsed
                    if self.elapsed >= self.maximumDuration {
                        await self.stopAndAnalyze()
                        break
                    }
                    try? await Task.sleep(for: .milliseconds(200))
                }
            }
        } catch {
            errorMessage = "We couldn't start recording. Close this session and try again."
            loopPhase = .readyToRecord
        }
    }

    private func stopAndAnalyze() async {
        guard let sessionId else { return }
        guard let fileURL = currentRecordingURL else { return }

        isBusy = true
        defer {
            isBusy = false
            isRecording = false
            currentRecordingURL = nil
            currentLocalAudioPath = nil
        }

        do {
            let duration = try dependencies.recorder.stopRecording()
            if duration < minimumDuration {
                errorMessage = "Aim for at least 30 seconds so the coaching has enough signal."
                loopPhase = .readyToRecord
                try? FileManager.default.removeItem(at: fileURL)
                return
            }

            currentLocalAudioPath = try dependencies.localPracticeStore.copyRecordingToLibrary(
                from: fileURL,
                sessionId: sessionId,
                repIndex: currentRepIndex
            )

            loopPhase = .uploading
            let storagePath = try await dependencies.uploader.uploadRecording(
                fileURL: fileURL,
                sessionId: sessionId,
                repIndex: currentRepIndex
            )
            try? FileManager.default.removeItem(at: fileURL)

            loopPhase = .analyzing
            let analysis = try await dependencies.sessionService.analyzeRep(
                sessionId: sessionId,
                repIndex: currentRepIndex,
                mode: context.mode,
                prompt: context.scenario.promptText,
                audioStoragePath: storagePath,
                durationSec: duration
            )

            latestFeedback = analysis
            reps.append(
                SpeakingRep(
                    id: "\(sessionId)-\(currentRepIndex)",
                    sessionId: sessionId,
                    repIndex: currentRepIndex,
                    transcript: analysis.transcript,
                    durationSec: duration,
                    breakdown: analysis.breakdown,
                    score: analysis.workClarityScore,
                    speechMetrics: analysis.speechMetrics,
                    feedback: analysis.feedbackCard,
                    localAudioPath: currentLocalAudioPath
                )
            )

            if currentRepIndex == 1, !hasLoggedFirstRepCompleted {
                hasLoggedFirstRepCompleted = true
                dependencies.telemetry.logFirstRepCompleted(mode: context.mode, score: analysis.workClarityScore)
            }

            if currentRepIndex >= maxReps {
                loopPhase = .completingSession
                do {
                    completion = try await dependencies.sessionService.completeSession(sessionId: sessionId)
                } catch {
                    completion = dependencies.localPracticeStore.fallbackCompletion(
                        for: context,
                        sessionId: sessionId,
                        reps: reps
                    )
                    errorMessage = "Saved locally. We could not sync this session right now."
                }

                if let completion {
                    dependencies.localPracticeStore.saveCompletedSession(
                        sessionId: sessionId,
                        context: context,
                        reps: reps,
                        completion: completion,
                        protectedSessionIDs: dependencies.savedAnswerStore.savedSessionIDs()
                    )
                    refreshSavedState()
                    dependencies.telemetry.logSessionCompleted(
                        mode: context.mode,
                        sessionType: context.sessionType,
                        score: completion.sessionScore,
                        improvementDelta: completion.improvementDelta
                    )
                }
                loopPhase = .completed
            } else {
                currentRepIndex += 1
                loopPhase = .readyForRetry
            }
        } catch {
            dependencies.telemetry.record(error: error, context: "practice_session", metadata: ["mode": context.mode.rawValue])
            if BackendConfig.isLocalBackend {
                errorMessage = "Local practice services are unavailable right now. Check the Firebase emulators and retry."
            } else {
                errorMessage = "We couldn't analyze that answer. Record it again and we'll retry."
            }
            loopPhase = .readyToRecord
        }
    }

    var beforeAfterPair: (before: SpeakingRep, after: SpeakingRep)? {
        guard let before = reps.first, let after = reps.last, reps.count > 1 else { return nil }
        return (before, after)
    }

    var improvementHeadline: String {
        guard let pair = beforeAfterPair else {
            return latestFeedback?.strength ?? "Keep the next answer tighter."
        }

        let delta = pair.after.score - pair.before.score
        if delta >= 8 {
            return "Clearer and tighter. The retry fixed the biggest issue."
        }
        if delta >= 3 {
            return "You improved. One more cleaner opening would raise the score again."
        }
        return "The content is there, but the answer still needs a sharper structure."
    }

    var completionTitle: String {
        context.sessionType == .full ? "Session complete" : "Quick drill complete"
    }

    var completionChangeTitle: String {
        guard let completion else { return "What changed" }
        return completion.improvementDelta > 0 ? "What improved" : "What to carry into the next rep"
    }

    var completionChangeSummary: String {
        guard let completion else {
            return "You finished the loop and have a clear coaching target for the next answer."
        }

        if let pair = beforeAfterPair {
            let delta = completion.improvementDelta
            if delta >= 8 {
                return "You lifted this answer from \(pair.before.score) to \(pair.after.score). The retry solved the biggest issue."
            }
            if delta >= 3 {
                return "You moved this answer up by \(delta) points, from \(pair.before.score) to \(pair.after.score)."
            }
            if delta > 0 {
                return "You improved this answer slightly, from \(pair.before.score) to \(pair.after.score), and clarified what to fix next."
            }
            if delta == 0 {
                return "The score held at \(pair.after.score), but the last rep made the next coaching target clearer."
            }
            return "The score slipped from \(pair.before.score) to \(pair.after.score), so the next rep should stay tighter and more deliberate."
        }

        return "You finished one scored answer. Use the coaching while it is still fresh."
    }

    var completionChangeDetail: String {
        if let strongestGain = strongestGainFocus {
            switch strongestGain {
            case .structure:
                return "Structure improved most. The answer has a clearer backbone now."
            case .clarity:
                return "Clarity improved most. The main point lands faster than the first try."
            case .conciseness:
                return "Conciseness improved most. The retry trimmed extra setup and repetition."
            case .delivery:
                return "Delivery improved most. The answer sounds steadier and more controlled."
            }
        }

        return weakestFocus.planDetail
    }

    var weakestFocus: CoachingFocus {
        CoachingFocus.weakest(from: reps, snapshots: [])
    }

    var recommendedCompletionAction: CompletionAction {
        switch weakestFocus {
        case .structure, .clarity:
            return .relatedScenario
        case .conciseness, .delivery:
            return .quickDrill
        }
    }

    func completionActionTitle(_ action: CompletionAction) -> String {
        switch action {
        case .relatedScenario:
            return "Practice a related prompt"
        case .quickDrill:
            return context.sessionType == .quick ? "Run this prompt once more" : "Lock it in with one fast rep"
        }
    }

    func completionActionDetail(_ action: CompletionAction) -> String {
        switch action {
        case .relatedScenario:
            switch weakestFocus {
            case .structure:
                return "Take the same answer shape into a fresh scenario while the pattern is still warm."
            case .clarity:
                return "Use a new prompt to keep the opening direct and easy to follow."
            case .conciseness:
                return "Move to a nearby prompt if you want to keep cutting setup in different situations."
            case .delivery:
                return "A related prompt helps you carry the calmer delivery into another real situation."
            }
        case .quickDrill:
            switch weakestFocus {
            case .structure:
                return "One short repeat helps you make the structure automatic before you switch prompts."
            case .clarity:
                return "A fast repeat on the same prompt helps the stronger opening stick."
            case .conciseness:
                return "One short rep on the same prompt is the fastest way to trim extra detail."
            case .delivery:
                return "One more quick rep helps settle pace, pauses, and filler carryover."
            }
        }
    }

    func saveBestAnswer() {
        guard let session = currentSessionHistoryItem else { return }
        dependencies.savedAnswerStore.toggleSavedAnswer(session: session)
        isBestAnswerSaved = dependencies.savedAnswerStore.isSavedAnswer(session.id)
    }

    func refreshSavedState() {
        guard let sessionId else { return }
        isBestAnswerSaved = dependencies.savedAnswerStore.isSavedAnswer(sessionId)
    }

    func nextScenario(roleTrack: RoleTrack, experienceLevel: ExperienceLevel? = nil) async -> Scenario? {
        await dependencies.scenarioRepository.nextScenario(
            after: context.scenario,
            weakestFocus: weakestFocus,
            roleTrack: roleTrack,
            experienceLevel: experienceLevel
        )
    }

    static func unauthenticatedSessionStartResolution() -> SessionStartResolution {
        SessionStartResolution(
            sessionId: nil,
            paywallRequired: false,
            paywallReason: nil,
            errorMessage: "Sign in to your account before starting a practice session.",
            loopPhase: .unavailable
        )
    }

    static func sessionStartResolution(for result: StartSessionResponse) -> SessionStartResolution {
        if !result.allowed {
            return SessionStartResolution(
                sessionId: nil,
                paywallRequired: true,
                paywallReason: result.reason,
                errorMessage: nil,
                loopPhase: .unavailable
            )
        }

        return SessionStartResolution(
            sessionId: result.sessionId,
            paywallRequired: false,
            paywallReason: nil,
            errorMessage: nil,
            loopPhase: .readyToRecord
        )
    }

    static func failedSessionStartResolution(isLocalBackend: Bool) -> SessionStartResolution {
        SessionStartResolution(
            sessionId: nil,
            paywallRequired: false,
            paywallReason: nil,
            errorMessage: isLocalBackend
                ? "Local practice services are not running. Start the Firebase emulators and try again."
                : "We couldn't prepare this practice session. Try again in a moment.",
            loopPhase: .unavailable
        )
    }

    private func applySessionStartResolution(_ resolution: SessionStartResolution) {
        sessionId = resolution.sessionId
        paywallRequired = resolution.paywallRequired
        paywallReason = resolution.paywallReason
        errorMessage = resolution.errorMessage
        loopPhase = resolution.loopPhase
    }

    var stageTitle: String {
        switch loopPhase {
        case .preparingSession:
            return "Preparing your session"
        case .readyToRecord:
            return currentRepIndex == 1 ? "Record your first answer" : "Take the next retry"
        case .recording:
            return "Speak like it is the real conversation"
        case .uploading:
            return "Uploading your answer"
        case .analyzing:
            return "Reviewing your answer"
        case .readyForRetry:
            return maxReps == 1 ? "Your coaching is ready" : "Use the coaching and try again"
        case .completingSession:
            return "Saving your session"
        case .completed:
            return "Session complete"
        case .unavailable:
            return "Practice is not ready"
        }
    }

    var stageMessage: String {
        switch loopPhase {
        case .preparingSession:
            return "Setting up the prompt, limits, and scoring for this practice run."
        case .readyToRecord:
            if currentRepIndex == 1 {
                return "Aim for one clear answer in \(targetDurationLabel). Get to the point early, then support it."
            }
            return "Use the coaching below, then record the same answer again in \(targetDurationLabel)."
        case .recording:
            return "Focus on one clear opening, one structure, and one firm finish. Stop when the answer lands."
        case .uploading:
            return "Hold for a second while we send the audio for transcription."
        case .analyzing:
            return "We’re scoring structure, clarity, conciseness, and delivery so the retry is specific."
        case .readyForRetry:
            return latestFeedback?.retryInstruction ?? "Read the coaching, then take another shot while it is fresh."
        case .completingSession:
            return "Wrapping the scores, streak, and session summary into your progress."
        case .completed:
            return "You finished this loop. Review the change, then choose what to do next."
        case .unavailable:
            return errorMessage ?? "This session could not be prepared right now."
        }
    }

    var statusDetail: String {
        if let feedback = latestFeedback, !isRecording {
            return "Score \(feedback.workClarityScore)"
        }
        if isRecording {
            return "Min \(Int(minimumDuration))s"
        }
        return "Target \(targetDurationLabel)"
    }

    var controlCaption: String {
        if isBusy {
            return "Working..."
        }
        if isRecording {
            return "Tap to stop and review"
        }
        if shouldShowRetryAction {
            return "Ready for the next take"
        }
        return currentRepIndex == 1 ? "Tap to start your answer" : "Tap when you're ready to retry"
    }

    var busyMessage: String {
        switch loopPhase {
        case .preparingSession:
            return "Preparing your session..."
        case .uploading:
            return "Uploading your answer..."
        case .analyzing:
            return "Analyzing your answer..."
        case .completingSession:
            return "Finalizing your session..."
        default:
            return "Processing your answer..."
        }
    }

    var shouldShowRetryAction: Bool {
        loopPhase == .readyForRetry && completion == nil && currentRepIndex <= maxReps
    }

    var retryButtonTitle: String {
        if currentRepIndex >= maxReps {
            return "Record final rep"
        }
        return "Start rep \(currentRepIndex) of \(maxReps)"
    }

    func startRetry() async {
        guard shouldShowRetryAction, !isBusy, !isRecording else { return }
        await startRecording()
    }

    private var targetDurationLabel: String {
        context.scenario.recommendedDurationLabel
    }

    private var currentSessionHistoryItem: SessionHistoryItem? {
        guard let sessionId, let completion else { return nil }
        return SessionHistoryItem(
            id: sessionId,
            mode: context.mode,
            type: context.sessionType,
            scenarioId: context.scenario.id,
            scenarioPrompt: context.scenario.promptText,
            startedAt: reps.first?.createdAt ?? .now,
            completedAt: .now,
            finalScore: completion.sessionScore,
            improvementDelta: completion.improvementDelta,
            reps: reps
        )
    }

    private var strongestGainFocus: CoachingFocus? {
        guard let pair = beforeAfterPair else { return nil }

        let deltas: [(CoachingFocus, Int)] = [
            (.structure, pair.after.breakdown.structure - pair.before.breakdown.structure),
            (.clarity, pair.after.breakdown.clarity - pair.before.breakdown.clarity),
            (.conciseness, pair.after.breakdown.conciseness - pair.before.breakdown.conciseness),
            (.delivery, pair.after.breakdown.delivery - pair.before.breakdown.delivery)
        ]

        guard let best = deltas.max(by: { $0.1 < $1.1 }), best.1 > 0 else {
            return nil
        }

        return best.0
    }
}
