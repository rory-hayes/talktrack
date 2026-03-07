import Foundation
@testable import Clearify

@MainActor
final class TestAuthProvider: AppStateAuthSessionProviding {
    var hasUserSession: Bool

    init(hasUserSession: Bool) {
        self.hasUserSession = hasUserSession
    }
}

@MainActor
final class TestUserProfileFetcher: AppStateUserProfileFetching {
    var result: Result<UserProfileRecord?, Error>

    init(result: Result<UserProfileRecord?, Error>) {
        self.result = result
    }

    func fetchCurrentProfile() async throws -> UserProfileRecord? {
        try result.get()
    }
}

@MainActor
final class TestEntitlementSyncer: AppStateEntitlementSyncing {
    var result: Result<String, Error> = .success("free")

    func syncCurrentEntitlements() async throws -> String {
        try result.get()
    }
}

@MainActor
final class TestTelemetryRecorder: AppStateTelemetryRecording {
    private(set) var recordedContexts: [String] = []

    func record(error: Error, context: String, metadata: [String : Any]) {
        recordedContexts.append(context)
    }
}

struct TestFixtures {
    static func profile(
        uid: String = "user-123",
        preferredName: String = "Rory",
        completed: Bool = true
    ) -> UserProfileRecord {
        UserProfileRecord(
            uid: uid,
            email: "rory@example.com",
            displayName: "Rory Doyle",
            preferredName: preferredName,
            locale: "en",
            planTier: "free",
            onboardingGoalMode: .workplace,
            selectedRoleTrack: .general,
            experienceLevel: .twoToFourYears,
            selfReportedFocus: .clarity,
            onboardingCompletedAt: completed ? Date(timeIntervalSince1970: 1_700_000_000) : nil,
            streakCurrent: 3,
            streakBest: 5,
            lastPracticeDate: "2026-03-07"
        )
    }

    static func scenario(
        id: String = "scenario-1",
        mode: ScenarioMode = .workplace,
        promptText: String = "Give a quick project update"
    ) -> Scenario {
        Scenario(
            id: id,
            mode: mode,
            promptText: promptText,
            tags: ["update"],
            difficulty: "easy",
            active: true
        )
    }

    static func rep(score: Int = 70, structure: Int = 18, clarity: Int = 18, conciseness: Int = 17, delivery: Int = 17) -> SpeakingRep {
        SpeakingRep(
            id: UUID().uuidString,
            sessionId: "session-1",
            repIndex: 1,
            transcript: "A focused answer",
            durationSec: 45,
            breakdown: ScoreBreakdown(
                structure: structure,
                clarity: clarity,
                conciseness: conciseness,
                delivery: delivery
            ),
            score: score,
            speechMetrics: SpeechMetrics(
                wpm: 130,
                fillerCount: 2,
                fillerRate: 1.5,
                pauseCount: 4
            ),
            feedback: FeedbackCard(
                strength: "Clear opening",
                primaryImprovement: "Shorten the middle",
                suggestedStructure: "Progress -> Blocker -> Next step",
                rewrittenExample: "Yesterday I closed the bug. Today I am testing the fix.",
                retryInstruction: "Try again in 30-45 seconds.",
                firstSentenceFeedback: "Lead with the main point.",
                ramblingFeedback: "Trim the setup.",
                structureFeedback: "Keep the order fixed.",
                deliveryFeedback: "Slow down slightly.",
                fillerHotspot: "Two fillers in the setup.",
                pacingBand: .steady,
                openingOverlong: false,
                weakConclusion: false
            )
        )
    }

    static func session(
        id: String = "session-1",
        mode: ScenarioMode = .workplace,
        type: SessionType = .full,
        prompt: String = "Give a quick project update",
        improvementDelta: Int = 6,
        reps: [SpeakingRep] = [rep(score: 68), rep(score: 74, structure: 20, clarity: 19, conciseness: 18, delivery: 17)]
    ) -> SessionHistoryItem {
        SessionHistoryItem(
            id: id,
            mode: mode,
            type: type,
            scenarioId: "scenario-1",
            scenarioPrompt: prompt,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            completedAt: Date(timeIntervalSince1970: 1_700_000_300),
            finalScore: reps.last?.score ?? 74,
            improvementDelta: improvementDelta,
            reps: reps
        )
    }

    static func snapshot(avgScore: Double = 78, streak: Int = 4) -> ProgressSnapshot {
        ProgressSnapshot(
            date: Date(timeIntervalSince1970: 1_700_000_000),
            avgScore: avgScore,
            fillerRate: 1.8,
            concisenessAvg: 18,
            structureAvg: 19,
            streak: streak
        )
    }
}

struct TestError: Error {}
