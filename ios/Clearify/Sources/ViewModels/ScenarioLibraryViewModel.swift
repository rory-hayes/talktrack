import Foundation

@MainActor
final class ScenarioLibraryViewModel: ObservableObject {
    @Published var selectedMode: ScenarioMode
    @Published var selectedRoleTrack: RoleTrack
    @Published var showStarredOnly = false
    @Published var scenarios: [Scenario] = []
    @Published var starredScenarioIDs: Set<String> = []
    @Published var weakestFocus: CoachingFocus = .clarity
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let dependencies: Dependencies

    init(dependencies: Dependencies, mode: ScenarioMode, roleTrack: RoleTrack) {
        self.dependencies = dependencies
        self.selectedMode = mode
        self.selectedRoleTrack = roleTrack
        self.starredScenarioIDs = dependencies.favoriteScenarioStore.starredScenarioIDs()
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        errorMessage = nil
        starredScenarioIDs = dependencies.favoriteScenarioStore.starredScenarioIDs()

        do {
            async let progressTask = dependencies.progressService.fetchLatestProgress(limit: 14)
            async let sessionTask = dependencies.progressService.fetchRecentSessions(limit: 10)
            async let profileTask = dependencies.userProfileService.fetchCurrentProfile()
            let progress = try await progressTask
            let sessions = try await sessionTask
            let profile = try await profileTask
            let experienceLevel = profile?.experienceLevel
            weakestFocus = sessions.isEmpty && progress.isEmpty
                ? profile?.selfReportedFocus ?? .clarity
                : CoachingFocus.weakest(from: sessions.flatMap(\.reps), snapshots: progress)

            let prioritized = try await dependencies.scenarioRepository.prioritizedScenarios(
                for: selectedMode,
                weakestFocus: weakestFocus,
                roleTrack: selectedRoleTrack,
                experienceLevel: experienceLevel
            )
            scenarios = showStarredOnly
                ? prioritized.filter { starredScenarioIDs.contains($0.id) }
                : prioritized
        } catch {
            dependencies.telemetry.record(error: error, context: "scenario_library_load")
            scenarios = []
            errorMessage = UserFacingErrorMessage.scenarioLibrary(error)
        }
    }

    func toggleStarredPrompt(_ scenario: Scenario) {
        dependencies.favoriteScenarioStore.toggleStarredScenario(scenario.id)
        starredScenarioIDs = dependencies.favoriteScenarioStore.starredScenarioIDs()
        if showStarredOnly {
            scenarios.removeAll { !starredScenarioIDs.contains($0.id) }
        }
    }

    func isStarredPrompt(_ scenario: Scenario) -> Bool {
        starredScenarioIDs.contains(scenario.id)
    }
}
