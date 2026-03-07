import Foundation

enum BackendConfig {
    static var baseURL: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "CLEARIFY_API_BASE_URL") as? String,
            let url = URL(string: raw),
            !raw.isEmpty
        else {
            fatalError("CLEARIFY_API_BASE_URL is not configured")
        }
        return url
    }

    static var isLocalBackend: Bool {
        let host = baseURL.host?.lowercased() ?? ""
        return host == "127.0.0.1" || host == "localhost"
    }
}
