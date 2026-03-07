import XCTest
@testable import Clearify

@MainActor
final class ProgressViewModelTests: XCTestCase {
    func testLoadUsesRemoteDataWhenAvailable() async {
        let remoteSnapshots = [TestFixtures.snapshot(avgScore: 81, streak: 5)]
        let remoteSessions = [TestFixtures.session(improvementDelta: 7)]
        let savedSessions = [TestFixtures.session(id: "saved-1", improvementDelta: 3)]
        let recommendedScenario = TestFixtures.scenario(promptText: "Explain a blocker to your manager")

        let viewModel = ProgressViewModel(
            runtime: .init(
                fetchLatestProgress: { _ in remoteSnapshots },
                fetchRecentSessions: { _ in remoteSessions },
                loadLocalProgressSnapshots: { _ in [] },
                loadLocalRecentSessions: { _ in [] },
                loadSavedSessions: { _ in savedSessions },
                personalizedRecommendation: { _, _, _, _ in recommendedScenario },
                recordTelemetry: { _, _ in }
            )
        )

        await viewModel.load(
            selectedMode: .workplace,
            selectedRoleTrack: .general,
            experienceLevel: .zeroToOneYears,
            defaultFocus: .clarity
        )

        XCTAssertEqual(viewModel.snapshots, remoteSnapshots)
        XCTAssertEqual(viewModel.recentSessions, remoteSessions)
        XCTAssertEqual(viewModel.savedSessions, savedSessions)
        XCTAssertEqual(viewModel.recommendedScenario, recommendedScenario)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testLoadFallsBackToLocalDataWhenRemoteFetchFails() async {
        let localSnapshots = [TestFixtures.snapshot(avgScore: 72, streak: 2)]
        let localSessions = [TestFixtures.session(improvementDelta: 1)]
        let savedSessions = [TestFixtures.session(id: "saved-1", improvementDelta: 2)]
        let recommendedScenario = TestFixtures.scenario(promptText: "Summarize a meeting outcome")
        var recordedContexts: [String] = []

        let viewModel = ProgressViewModel(
            runtime: .init(
                fetchLatestProgress: { _ in throw TestError() },
                fetchRecentSessions: { _ in throw TestError() },
                loadLocalProgressSnapshots: { _ in localSnapshots },
                loadLocalRecentSessions: { _ in localSessions },
                loadSavedSessions: { _ in savedSessions },
                personalizedRecommendation: { _, _, _, _ in recommendedScenario },
                recordTelemetry: { _, context in recordedContexts.append(context) }
            )
        )

        await viewModel.load(
            selectedMode: .workplace,
            selectedRoleTrack: .general,
            experienceLevel: .zeroToOneYears,
            defaultFocus: .clarity
        )

        XCTAssertEqual(viewModel.snapshots, localSnapshots)
        XCTAssertEqual(viewModel.recentSessions, localSessions)
        XCTAssertEqual(viewModel.savedSessions, savedSessions)
        XCTAssertEqual(viewModel.recommendedScenario, recommendedScenario)
        XCTAssertEqual(viewModel.errorMessage, "We couldn't refresh every progress detail. Showing what is available on this device.")
        XCTAssertEqual(recordedContexts, ["progress_load"])
    }
}
