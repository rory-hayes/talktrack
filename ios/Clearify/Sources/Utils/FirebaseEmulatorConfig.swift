import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
enum FirebaseEmulatorConfig {
    private static var hasConfigured = false

    static func configureIfNeeded() {
        guard BackendConfig.isLocalBackend, !hasConfigured else {
            return
        }

        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)

        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.host = "127.0.0.1:8080"
        settings.isSSLEnabled = false
        firestore.settings = settings

        Storage.storage().useEmulator(withHost: "127.0.0.1", port: 9199)
        hasConfigured = true
    }
}
