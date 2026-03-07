import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var selectedMode: ScenarioMode = .workplace
    @Published var recommendedScenario: Scenario?
    @Published var scenarios: [Scenario] = []
    @Published var streak = 0
    @Published var avgScore7d: Double = 0
    @Published var weakestFocus: CoachingFocus = .clarity
    @Published var roleTrack: RoleTrack = .general
    @Published var recentSessions: [SessionHistoryItem] = []
    @Published var preferredName: String = ""
    @Published var experienceLevel: ExperienceLevel = .zeroToOneYears
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dependencies: Dependencies

    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let profile = try? await dependencies.userProfileService.fetchCurrentProfile()
            if scenarios.isEmpty {
                selectedMode = profile?.onboardingGoalMode ?? selectedMode
            }
            roleTrack = profile?.selectedRoleTrack ?? roleTrack
            preferredName = profile?.preferredName ?? preferredName
            experienceLevel = profile?.experienceLevel ?? experienceLevel

            async let progressTask = dependencies.progressService.fetchLatestProgress(limit: 7)
            async let sessionsTask = dependencies.progressService.fetchRecentSessions(limit: 6)
            let progress = try await progressTask
            recentSessions = try await sessionsTask

            streak = progress.first?.streak ?? profile?.streakCurrent ?? 0
            avgScore7d = progress.isEmpty ? 0 : (progress.map(\.avgScore).reduce(0, +) / Double(progress.count))
            if recentSessions.isEmpty && progress.isEmpty {
                weakestFocus = profile?.selfReportedFocus ?? .clarity
            } else {
                weakestFocus = CoachingFocus.weakest(from: recentSessions.flatMap(\.reps), snapshots: progress)
            }

            scenarios = try await dependencies.scenarioRepository.prioritizedScenarios(
                for: selectedMode,
                weakestFocus: weakestFocus,
                roleTrack: roleTrack,
                experienceLevel: experienceLevel
            )
            recommendedScenario = dependencies.scenarioRepository.personalizedRecommendation(
                for: selectedMode,
                weakestFocus: weakestFocus,
                roleTrack: roleTrack,
                experienceLevel: experienceLevel
            ) ?? scenarios.first
        } catch {
            dependencies.telemetry.record(error: error, context: "home_load")
            errorMessage = "We couldn't load your next prompt. Open the prompt library or try again in a moment."
        }
    }
}
