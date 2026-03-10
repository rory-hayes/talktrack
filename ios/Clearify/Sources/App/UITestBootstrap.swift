import Foundation
import FirebaseAuth
import GoogleSignIn

@MainActor
enum UITestBootstrap {
    private static let resetArgument = "UITEST_RESET_STATE"
    private static let authenticatedDashboardArgument = "UITEST_BOOTSTRAP_AUTHENTICATED"
    private static let bootstrapEmailEnvironmentKey = "UITEST_BOOTSTRAP_EMAIL"
    private static let bootstrapPasswordEnvironmentKey = "UITEST_BOOTSTRAP_PASSWORD"

    private static let defaultBootstrapEmail = "audit.authenticated@example.com"
    private static let defaultBootstrapPassword = "Audit123"

    static func resetPersistentStateIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains(resetArgument) else {
            return
        }

        do {
            try Auth.auth().signOut()
        } catch {
            // Best-effort reset for UI tests.
        }
        GIDSignIn.sharedInstance.signOut()

        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleIdentifier)
        }

        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let archiveDirectories = ["TalkTrack", "Clearify"]
        archiveDirectories.compactMap { appSupport?.appendingPathComponent($0, isDirectory: true) }.forEach { url in
            try? fileManager.removeItem(at: url)
        }
    }

    static var shouldBootstrapAuthenticatedDashboard: Bool {
        ProcessInfo.processInfo.arguments.contains(authenticatedDashboardArgument)
    }

    static func hydrationTaskID(currentUserID: String?) -> String {
        if shouldBootstrapAuthenticatedDashboard {
            return authenticatedDashboardArgument
        }

        return currentUserID ?? "signed_out"
    }

    static func prepareAuthenticatedDashboardStateIfNeeded(dependencies: Dependencies) async {
        guard shouldBootstrapAuthenticatedDashboard else {
            return
        }

        guard BackendConfig.isLocalBackend else {
            return
        }

        let email = ProcessInfo.processInfo.environment[bootstrapEmailEnvironmentKey] ?? defaultBootstrapEmail
        let password = ProcessInfo.processInfo.environment[bootstrapPasswordEnvironmentKey] ?? defaultBootstrapPassword
        let currentUserEmail = dependencies.authService.user?.email?.lowercased()

        if currentUserEmail != email.lowercased() {
            do {
                try dependencies.authService.signOut()
            } catch {
                // Best-effort sign out before recreating the UITest user session.
            }

            do {
                try await dependencies.authService.signInWithEmail(email: email, password: password)
            } catch {
                return
            }
        }

        do {
            _ = try await dependencies.userProfileService.completeOnboarding(
                preferredName: "Audit",
                experienceLevel: .twoToFourYears,
                focus: .clarity,
                mode: .workplace,
                roleTrack: .general
            )
        } catch {
            // Leave the app in its natural state if profile seeding fails.
        }
    }
}
