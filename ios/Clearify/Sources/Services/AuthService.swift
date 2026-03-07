import Foundation
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

enum AuthServiceError: LocalizedError {
    case googleSignInUnavailable
    case missingGoogleToken
    case missingPresentationContext

    var errorDescription: String? {
        switch self {
        case .googleSignInUnavailable:
            return "Google Sign-In isn't configured correctly for this app."
        case .missingGoogleToken:
            return "Google Sign-In did not return a valid token."
        case .missingPresentationContext:
            return "Clearify couldn't open the Google sign-in sheet."
        }
    }
}

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var user: User?

    private var listenerHandle: AuthStateDidChangeListenerHandle?

    init() {
        user = Auth.auth().currentUser
        TelemetryService.shared.identifyCurrentUser(user)
        TelemetryService.shared.setUserProperty(user == nil ? "signed_out" : "signed_in", forName: "auth_state")

        listenerHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            self?.user = user
            TelemetryService.shared.identifyCurrentUser(user)
            TelemetryService.shared.setUserProperty(user == nil ? "signed_out" : "signed_in", forName: "auth_state")
        }
    }

    deinit {
        if let listenerHandle {
            Auth.auth().removeStateDidChangeListener(listenerHandle)
        }
    }

    func signInWithEmail(email: String, password: String) async throws {
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idToken,
            rawNonce: nonce
        )
        _ = try await Auth.auth().signIn(with: credential)
    }

    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthServiceError.googleSignInUnavailable
        }

        let configuration = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = configuration

        guard let rootViewController = UIApplication.shared.topMostViewController() else {
            throw AuthServiceError.missingPresentationContext
        }

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthServiceError.missingGoogleToken
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )

        _ = try await Auth.auth().signIn(with: credential)
    }

    func linkAnonymousWithEmail(email: String, password: String) async throws {
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        if let user = Auth.auth().currentUser, user.isAnonymous {
            _ = try await user.link(with: credential)
        } else {
            try await signInWithEmail(email: email, password: password)
        }
    }

    func linkAnonymousWithApple(idToken: String, nonce: String) async throws {
        let credential = OAuthProvider.credential(
            withProviderID: "apple.com",
            idToken: idToken,
            rawNonce: nonce
        )

        if let user = Auth.auth().currentUser, user.isAnonymous {
            _ = try await user.link(with: credential)
        } else {
            _ = try await Auth.auth().signIn(with: credential)
        }
    }

    func ensureUserSession() async {
        if Auth.auth().currentUser != nil {
            user = Auth.auth().currentUser
            return
        }
        user = nil
    }

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }
}

private extension UIApplication {
    func topMostViewController(
        base: UIViewController? = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return topMostViewController(base: navigationController.visibleViewController)
        }
        if let tabBarController = base as? UITabBarController {
            return topMostViewController(base: tabBarController.selectedViewController)
        }
        if let presentedViewController = base?.presentedViewController {
            return topMostViewController(base: presentedViewController)
        }
        return base
    }
}
