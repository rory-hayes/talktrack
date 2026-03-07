import Foundation

@MainActor
final class ProgressViewModel: ObservableObject {
    struct Runtime {
        let fetchLatestProgress: (_ limit: Int) async throws -> [ProgressSnapshot]
        let fetchRecentSessions: (_ limit: Int) async throws -> [SessionHistoryItem]
        let loadLocalProgressSnapshots: (_ limit: Int) -> [ProgressSnapshot]
        let loadLocalRecentSessions: (_ limit: Int) -> [SessionHistoryItem]
        let loadSavedSessions: (_ limit: Int) -> [SessionHistoryItem]
        let personalizedRecommendation: (_ mode: ScenarioMode, _ weakestFocus: CoachingFocus, _ roleTrack: RoleTrack, _ experienceLevel: ExperienceLevel) -> Scenario?
        let recordTelemetry: (_ error: Error, _ context: String) -> Void
    }

    @Published var snapshots: [ProgressSnapshot] = []
    @Published var recentSessions: [SessionHistoryItem] = []
    @Published var savedSessions: [SessionHistoryItem] = []
    @Published var recommendedScenario: Scenario?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let runtime: Runtime
    private var profileFocus: CoachingFocus = .clarity
    private var selectedMode: ScenarioMode = .workplace
    private var selectedRoleTrack: RoleTrack = .general
    private var experienceLevel: ExperienceLevel = .zeroToOneYears

    init(dependencies: Dependencies) {
        self.runtime = Runtime(
            fetchLatestProgress: { limit in
                try await dependencies.progressService.fetchLatestProgress(limit: limit)
            },
            fetchRecentSessions: { limit in
                try await dependencies.progressService.fetchRecentSessions(limit: limit)
            },
            loadLocalProgressSnapshots: { limit in
                dependencies.localPracticeStore.loadProgressSnapshots(limit: limit)
            },
            loadLocalRecentSessions: { limit in
                dependencies.localPracticeStore.loadRecentSessions(limit: limit)
            },
            loadSavedSessions: { limit in
                dependencies.savedAnswerStore.loadSavedSessions(
                    from: dependencies.localPracticeStore.loadArchivedSessions(),
                    limit: limit
                )
            },
            personalizedRecommendation: { mode, weakestFocus, roleTrack, experienceLevel in
                dependencies.scenarioRepository.personalizedRecommendation(
                    for: mode,
                    weakestFocus: weakestFocus,
                    roleTrack: roleTrack,
                    experienceLevel: experienceLevel
                )
            },
            recordTelemetry: { error, context in
                dependencies.telemetry.record(error: error, context: context)
            }
        )
    }

    init(runtime: Runtime) {
        self.runtime = runtime
    }

    func load(
        selectedMode: ScenarioMode,
        selectedRoleTrack: RoleTrack,
        experienceLevel: ExperienceLevel,
        defaultFocus: CoachingFocus
    ) async {
        isLoading = true
        errorMessage = nil
        self.selectedMode = selectedMode
        self.selectedRoleTrack = selectedRoleTrack
        self.experienceLevel = experienceLevel
        self.profileFocus = defaultFocus
        defer { isLoading = false }

        do {
            async let progressTask = runtime.fetchLatestProgress(30)
            async let sessionsTask = runtime.fetchRecentSessions(8)
            snapshots = try await progressTask
            recentSessions = try await sessionsTask
            savedSessions = runtime.loadSavedSessions(6)
            refreshRecommendedScenario()
        } catch {
            runtime.recordTelemetry(error, "progress_load")
            snapshots = runtime.loadLocalProgressSnapshots(30)
            recentSessions = runtime.loadLocalRecentSessions(8)
            savedSessions = runtime.loadSavedSessions(6)
            refreshRecommendedScenario()
            errorMessage = "We couldn't refresh every progress detail. Showing what is available on this device."
        }
    }

    var weakestFocus: CoachingFocus {
        CoachingFocus.weakest(from: recentSessions.flatMap(\.reps), snapshots: snapshots)
    }

    var effectiveFocus: CoachingFocus {
        hasPracticeData ? weakestFocus : profileFocus
    }

    var streak: Int {
        snapshots.first?.streak ?? 0
    }

    var hasPracticeData: Bool {
        !snapshots.isEmpty || !recentSessions.isEmpty
    }

    var weeklyAverage: Int {
        guard !snapshots.isEmpty else { return 0 }
        let window = snapshots.prefix(7)
        let average = window.map(\.avgScore).reduce(0, +) / Double(window.count)
        return Int(average.rounded())
    }

    var weeklyScoreHeadline: String {
        guard let trendDelta else {
            return hasPracticeData ? "Building your first trend" : "No trend yet"
        }

        if trendDelta >= 5 {
            return "Up \(trendDelta) points this week"
        }
        if trendDelta <= -5 {
            return "Down \(-trendDelta) points this week"
        }
        return "Holding steady this week"
    }

    var weeklySummaryDetail: String {
        guard hasPracticeData else {
            return "Your weekly score, streak, and score trend will appear here after your first completed session."
        }

        guard let trendDelta else {
            return "Keep going. A few more sessions will make the trend easier to trust."
        }

        let latest = Int((snapshots.first?.avgScore ?? Double(weeklyAverage)).rounded())
        if trendDelta >= 5 {
            return "Your recent average is \(latest). The score trend is moving in the right direction."
        }
        if trendDelta <= -5 {
            return "Your recent average is \(latest). Revisit your weakest focus on the next prompt to recover faster."
        }
        return "Your recent average is \(latest). Another clean session should break the plateau."
    }

    var topRecurringIssue: String {
        switch effectiveFocus {
        case .structure:
            return "Your answers lose shape when the middle gets crowded."
        case .clarity:
            return "The main point arrives too late."
        case .conciseness:
            return "You add extra detail after the useful answer is already there."
        case .delivery:
            return "Fillers and pace are making the answer feel less confident."
        }
    }

    var recentWin: String {
        guard hasPracticeData else {
            return "Finish one session and this section will call out the clearest improvement you made."
        }
        guard let best = recentSessions.max(by: { $0.improvementDelta < $1.improvementDelta }) else {
            return "Complete a session to unlock your first coaching win."
        }
        if best.improvementDelta > 0 {
            return "\(best.mode.title) improved by \(best.improvementDelta) points on “\(best.scenarioPrompt)”."
        }
        return best.strongestMoment
    }

    var weeklySummary: String {
        guard hasPracticeData else {
            return "Complete your first session to start a real weekly summary."
        }

        let fullSessions = recentSessions.filter { $0.type == .full }.count
        let quickDrills = recentSessions.filter { $0.type == .quick }.count
        return "You completed \(fullSessions) full sessions and \(quickDrills) quick drills across your latest practice streak."
    }

    var focusCardTitle: String {
        hasPracticeData ? "Current coaching focus" : "Start here first"
    }

    var focusHeadline: String {
        hasPracticeData ? effectiveFocus.planHeadline : "Start by improving \(effectiveFocus.title.lowercased())."
    }

    var focusDetail: String {
        hasPracticeData
            ? effectiveFocus.planDetail
            : "You chose \(effectiveFocus.title.lowercased()) during setup. A few sessions will confirm whether it stays the main priority."
    }

    var recurringIssueLabel: String {
        hasPracticeData ? "Recurring issue" : "What to look for first"
    }

    var recentWinLabel: String {
        hasPracticeData ? "Recent win" : "What unlocks next"
    }

    var recommendedPracticeTitle: String {
        recommendedScenario?.promptText ?? "Your next prompt will appear here"
    }

    var recommendedPracticeDetail: String {
        if let recommendedScenario {
            return recommendedScenario.coachingWhy
        }

        return "Complete a session or refresh your setup so Clearify can point you to the next useful prompt."
    }

    var recommendedPracticeCTA: String {
        hasPracticeData ? "Practice next prompt" : "Start first practice"
    }

    var canRecommendPractice: Bool {
        recommendedScenario != nil
    }

    var historySectionTitle: String {
        hasPracticeData ? "Recent sessions" : "Recent sessions will appear here"
    }

    var progressErrorTitle: String {
        "Using available progress data"
    }

    func sessionSummary(for session: SessionHistoryItem) -> String {
        if session.improvementDelta > 0 {
            return "Moved up \(session.improvementDelta) points in this session."
        }
        if session.improvementDelta == 0 {
            return "Held the score steady while refining the answer."
        }
        return "This session slipped by \(-session.improvementDelta) points, which makes the next focus clearer."
    }

    func sessionMeta(for session: SessionHistoryItem) -> String {
        let dateText = relativeDateString(for: session.completedAt ?? session.startedAt)
        let deltaText = session.improvementDelta >= 0 ? "+\(session.improvementDelta)" : "\(session.improvementDelta)"
        return "\(dateText) • \(session.mode.title) • \(session.type.rawValue.capitalized) • \(deltaText)"
    }

    private var trendDelta: Int? {
        let window = Array(snapshots.prefix(7))
        guard window.count >= 2 else { return nil }
        let latest = window.first?.avgScore ?? 0
        let earliest = window.last?.avgScore ?? 0
        return Int((latest - earliest).rounded())
    }

    private func refreshRecommendedScenario() {
        recommendedScenario = runtime.personalizedRecommendation(
            selectedMode,
            effectiveFocus,
            selectedRoleTrack,
            experienceLevel
        )
    }

    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: .now).capitalized
    }
}
