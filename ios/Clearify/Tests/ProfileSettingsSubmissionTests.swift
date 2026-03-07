import XCTest
@testable import Clearify

@MainActor
final class ProfileSettingsSubmissionTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ClearifyTests.ProfileSettings.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveRejectsBlankName() async {
        let appState = AppState(defaults: defaults)
        let updater = TestUserProfileUpdater()

        do {
            try await ProfileSettingsSubmission.save(
                preferredName: "   ",
                experienceLevel: .zeroToOneYears,
                focus: .clarity,
                mode: .workplace,
                roleTrack: .general,
                using: updater,
                appState: appState
            )
            XCTFail("Expected save to fail")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Add your first name before saving.")
            XCTAssertFalse(updater.didUpdate)
        }
    }

    func testSaveUpdatesRemoteProfileAndAppState() async throws {
        let appState = AppState(defaults: defaults)
        let updater = TestUserProfileUpdater()

        try await ProfileSettingsSubmission.save(
            preferredName: "  Rory  ",
            experienceLevel: .fiveToSevenYears,
            focus: .delivery,
            mode: .customer,
            roleTrack: .customerSuccess,
            using: updater,
            appState: appState
        )

        XCTAssertTrue(updater.didUpdate)
        XCTAssertEqual(updater.preferredName, "Rory")
        XCTAssertTrue(appState.isOnboardingComplete)
        XCTAssertEqual(appState.preferredFirstName, "Rory")
        XCTAssertEqual(appState.experienceLevel, .fiveToSevenYears)
        XCTAssertEqual(appState.selfReportedFocus, .delivery)
        XCTAssertEqual(appState.selectedMode, .customer)
        XCTAssertEqual(appState.selectedRoleTrack, .customerSuccess)
    }
}

private final class TestUserProfileUpdater: UserProfileUpdating {
    private(set) var didUpdate = false
    private(set) var preferredName = ""

    func updateProfile(
        preferredName: String,
        experienceLevel: ExperienceLevel,
        focus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack
    ) async throws -> UserProfileRecord {
        didUpdate = true
        self.preferredName = preferredName
        return TestFixtures.profile(preferredName: preferredName)
    }
}
