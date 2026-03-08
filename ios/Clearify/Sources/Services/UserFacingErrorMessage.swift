import Foundation
import FirebaseAuth

enum UserFacingErrorMessage {
    static func onboardingAuth(_ error: Error) -> String {
        if error is AuthServiceError {
            return "We couldn't continue with Google right now. Try email instead."
        }

        switch authErrorCode(for: error) {
        case .invalidEmail:
            return "Enter a valid email address."
        case .wrongPassword, .userNotFound, .invalidCredential, .emailAlreadyInUse, .credentialAlreadyInUse:
            return "We couldn't sign you in with those details. Check them and try again."
        case .networkError, .tooManyRequests:
            return "We couldn't reach the account service right now. Try again in a moment."
        default:
            return "We couldn't set up your account right now. Try again in a moment."
        }
    }

    static func onboardingSetup(_ error: Error) -> String {
        if case APIError.unauthenticated = error {
            return "Sign in again to finish setting up your coaching plan."
        }
        return "We couldn't finish setting up your coaching plan right now. Try again in a moment."
    }

    static func profileSettings(_ error: Error) -> String {
        if let localized = error as? LocalizedError, error is ProfileSettingsSubmissionError {
            return localized.errorDescription ?? "We couldn't save your profile changes right now. Try again."
        }
        if case APIError.unauthenticated = error {
            return "Sign in again before saving your profile changes."
        }
        return "We couldn't save your profile changes right now. Try again in a moment."
    }

    static func accountLink(_ error: Error) -> String {
        if error is AuthServiceError {
            return "We couldn't connect your Apple account right now. Try email instead."
        }

        switch authErrorCode(for: error) {
        case .invalidEmail:
            return "Enter a valid email address."
        case .weakPassword:
            return "Use a password with at least 6 characters."
        case .emailAlreadyInUse, .credentialAlreadyInUse:
            return "That account is already linked. Sign in with it instead."
        case .wrongPassword, .userNotFound, .invalidCredential:
            return "We couldn't connect that account with the details provided."
        case .networkError, .tooManyRequests:
            return "We couldn't reach the account service right now. Try again in a moment."
        default:
            return "We couldn't connect this account right now. Try again in a moment."
        }
    }

    static func scenarioLibrary(_ error: Error) -> String {
        if case APIError.unauthenticated = error {
            return "Sign in again to load your scenario library."
        }
        return "We couldn't load the scenario library right now. Try again in a moment."
    }

    private static func authErrorCode(for error: Error) -> AuthErrorCode.Code? {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain else { return nil }
        return AuthErrorCode.Code(rawValue: nsError.code)
    }
}
