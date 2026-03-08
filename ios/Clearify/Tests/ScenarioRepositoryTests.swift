import XCTest
@testable import Clearify

@MainActor
final class ScenarioRepositoryTests: XCTestCase {
    func testPersonalizedRecommendationUsesRemoteScenarioSourceBeforeBundledFallback() async {
        let bundled = [
            TestFixtures.scenario(id: "bundled-1", promptText: "Bundled prompt")
        ]
        let remote = [
            TestFixtures.scenario(id: "remote-1", promptText: "Remote prompt")
        ]
        let repository = ScenarioRepository(
            bundledScenarios: bundled,
            remoteScenarioLoader: { _ in remote }
        )

        let recommendation = await repository.personalizedRecommendation(
            for: .workplace,
            weakestFocus: .clarity,
            roleTrack: .general,
            experienceLevel: .zeroToOneYears,
            on: Date(timeIntervalSince1970: 1_700_000_000)
        )

        XCTAssertEqual(recommendation?.id, "remote-1")
    }

    func testNextScenarioUsesResolvedRemoteScenariosForFollowUpRecommendations() async {
        let current = TestFixtures.scenario(id: "remote-current", promptText: "Explain the current blocker")
        let followUp = TestFixtures.scenario(id: "remote-follow-up", promptText: "Explain the next step for the blocker")
        let repository = ScenarioRepository(
            bundledScenarios: [TestFixtures.scenario(id: "bundled-1", promptText: "Bundled prompt")],
            remoteScenarioLoader: { _ in [current, followUp] }
        )

        let nextScenario = await repository.nextScenario(
            after: current,
            weakestFocus: .clarity,
            roleTrack: .softwareEngineer,
            experienceLevel: .zeroToOneYears
        )

        XCTAssertEqual(nextScenario?.id, "remote-follow-up")
    }

    func testBundledScenariosRemainFallbackWhenRemoteListIsEmpty() async throws {
        let bundled = [
            TestFixtures.scenario(id: "bundled-1", promptText: "Bundled prompt")
        ]
        let repository = ScenarioRepository(
            bundledScenarios: bundled,
            remoteScenarioLoader: { _ in [] }
        )

        let scenarios = try await repository.prioritizedScenarios(
            for: .workplace,
            weakestFocus: .clarity,
            roleTrack: .general,
            experienceLevel: .zeroToOneYears
        )

        XCTAssertEqual(scenarios.map(\.id), ["bundled-1"])
    }
}
