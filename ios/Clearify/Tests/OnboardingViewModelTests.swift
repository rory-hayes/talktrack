import XCTest
@testable import Clearify

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testValidateProfileStepRequiresName() {
        let viewModel = OnboardingViewModel { _, _, _, _, _ in
            TestFixtures.profile()
        }

        viewModel.preferredName = "   "

        XCTAssertFalse(viewModel.validateProfileStep())
        XCTAssertEqual(viewModel.errorMessage, "Add your first name so we can personalize your coaching plan.")
    }

    func testCompleteOnboardingTrimsPreferredNameBeforeDelegating() async throws {
        var capturedName = ""
        let viewModel = OnboardingViewModel { preferredName, _, _, _, _ in
            capturedName = preferredName
            return TestFixtures.profile(preferredName: preferredName)
        }
        viewModel.preferredName = "  Rory  "
        viewModel.experienceLevel = .twoToFourYears
        viewModel.selectedFocus = .structure
        viewModel.selectedMode = .customer
        viewModel.selectedRoleTrack = .accountExecutive

        let profile = try await viewModel.completeOnboarding()

        XCTAssertEqual(capturedName, "Rory")
        XCTAssertEqual(profile.preferredName, "Rory")
    }
}
