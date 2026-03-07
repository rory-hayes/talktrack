import Foundation
import FirebaseAuth
import GoogleSignIn

@MainActor
enum UITestBootstrap {
    private static let resetArgument = "UITEST_RESET_STATE"

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
}
