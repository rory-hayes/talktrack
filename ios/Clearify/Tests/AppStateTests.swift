import XCTest
@testable import Clearify

@MainActor
final class AppStateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "ClearifyTests.AppState.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testHydrateWithoutAuthenticatedUserClearsOnboardingState() async {
        let appState = AppState(defaults: defaults)
        appState.markOnboardingComplete(
            preferredFirstName: "Rory",
            experienceLevel: .twoToFourYears,
            selfReportedFocus: .structure,
            mode: .customer,
            roleTrack: .analyst
        )

        await appState.hydrate(
            authProvider: TestAuthProvider(hasUserSession: false),
            userProfileService: TestUserProfileFetcher(result: .success(nil)),
            entitlementService: TestEntitlementSyncer(),
            telemetry: TestTelemetryRecorder()
        )

        XCTAssertFalse(appState.isOnboardingComplete)
        XCTAssertEqual(appState.preferredFirstName, "")
        XCTAssertEqual(appState.selectedMode, .workplace)
        XCTAssertEqual(appState.selectedRoleTrack, .general)
        XCTAssertFalse(AppState(defaults: defaults).isOnboardingComplete)
    }

    func testHydrateWithProfileRestoresCachedSelections() async {
        let appState = AppState(defaults: defaults)
        let profile = TestFixtures.profile(preferredName: "Rory", completed: true)

        await appState.hydrate(
            authProvider: TestAuthProvider(hasUserSession: true),
            userProfileService: TestUserProfileFetcher(result: .success(profile)),
            entitlementService: TestEntitlementSyncer(),
            telemetry: TestTelemetryRecorder()
        )

        XCTAssertFalse(appState.isBootstrapping)
        XCTAssertTrue(appState.isOnboardingComplete)
        XCTAssertEqual(appState.preferredFirstName, "Rory")
        XCTAssertEqual(appState.selectedMode, .workplace)
        XCTAssertEqual(appState.selectedRoleTrack, .general)
        XCTAssertEqual(appState.experienceLevel, .twoToFourYears)
        XCTAssertEqual(appState.selfReportedFocus, .clarity)
    }

    func testHydrateWithoutRemoteProfilePreservesInProgressOnboardingDraft() async {
        let appState = AppState(defaults: defaults)
        appState.preferredFirstName = "Rory"
        appState.selectedMode = .customer
        appState.selectedRoleTrack = .accountExecutive
        appState.experienceLevel = .fiveToSevenYears
        appState.selfReportedFocus = .structure
        appState.isOnboardingComplete = false

        await appState.hydrate(
            authProvider: TestAuthProvider(hasUserSession: true),
            userProfileService: TestUserProfileFetcher(result: .success(nil)),
            entitlementService: TestEntitlementSyncer(),
            telemetry: TestTelemetryRecorder()
        )

        XCTAssertFalse(appState.isBootstrapping)
        XCTAssertFalse(appState.isOnboardingComplete)
        XCTAssertEqual(appState.preferredFirstName, "Rory")
        XCTAssertEqual(appState.selectedMode, .customer)
        XCTAssertEqual(appState.selectedRoleTrack, .accountExecutive)
        XCTAssertEqual(appState.experienceLevel, .fiveToSevenYears)
        XCTAssertEqual(appState.selfReportedFocus, .structure)
    }

    func testResetForSignOutClearsPersistedState() {
        let appState = AppState(defaults: defaults)
        appState.markOnboardingComplete(
            preferredFirstName: "Rory",
            experienceLevel: .fiveToSevenYears,
            selfReportedFocus: .delivery,
            mode: .interview,
            roleTrack: .productManager
        )

        appState.resetForSignOut(clearCache: true)

        XCTAssertFalse(appState.isOnboardingComplete)
        XCTAssertEqual(appState.preferredFirstName, "")
        XCTAssertEqual(appState.selectedMode, .workplace)
        XCTAssertEqual(appState.selectedRoleTrack, .general)
        XCTAssertFalse(AppState(defaults: defaults).isOnboardingComplete)
    }
}
