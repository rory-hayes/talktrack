import XCTest
import FirebaseAuth
@testable import Clearify

@MainActor
final class UserFacingErrorMessageTests: XCTestCase {
    func testGenericAPIServerErrorDoesNotLeakRawBackendMessage() {
        let error = APIError.serverError(statusCode: 500, message: "{\"error\":\"uid_mismatch\"}")

        XCTAssertEqual(error.localizedDescription, "Clearify hit a server problem. Please try again.")
    }

    func testOnboardingMapsFirebaseInvalidEmailToProductCopy() {
        let error = NSError(domain: AuthErrorDomain, code: AuthErrorCode.invalidEmail.rawValue)

        XCTAssertEqual(
            UserFacingErrorMessage.onboardingAuth(error),
            "Enter a valid email address."
        )
    }

    func testProfileSettingsKeepsLocalValidationMessage() {
        XCTAssertEqual(
            UserFacingErrorMessage.profileSettings(ProfileSettingsSubmissionError.missingPreferredName),
            "Add your first name before saving."
        )
    }
}
