import FirebaseAnalytics
import FirebaseCrashlytics
import FirebaseAuth
import Foundation

final class TelemetryService {
    static let shared = TelemetryService()

    private init() {}

    func identifyCurrentUser(_ user: User?) {
        Analytics.setUserID(user?.uid)
        Crashlytics.crashlytics().setUserID(user?.uid ?? "anonymous")
    }

    func setUserProperty(_ value: String?, forName name: String) {
        Analytics.setUserProperty(value, forName: name)
    }

    func logEvent(_ name: String, parameters: [String: Any] = [:]) {
        Analytics.logEvent(name, parameters: sanitized(parameters))
    }

    func breadcrumb(_ message: String, metadata: [String: Any] = [:]) {
        let suffix = metadata.isEmpty ? "" : " \(sanitized(metadata))"
        Crashlytics.crashlytics().log("\(message)\(suffix)")
    }

    func record(error: Error, context: String, metadata: [String: Any] = [:]) {
        breadcrumb("error.\(context)", metadata: metadata)
        Crashlytics.crashlytics().record(error: error)
    }

    func logAppOpen() {
        logEvent("app_open")
    }

    func logOnboardingStarted() {
        logEvent("onboarding_started")
    }

    func logFirstRepStarted(mode: ScenarioMode) {
        logEvent("first_rep_started", parameters: ["mode": mode.rawValue])
    }

    func logFirstRepCompleted(mode: ScenarioMode, score: Int) {
        logEvent("first_rep_completed", parameters: ["mode": mode.rawValue, "score": score])
    }

    func logSessionCompleted(mode: ScenarioMode, sessionType: SessionType, score: Int, improvementDelta: Int) {
        logEvent(
            "session_completed",
            parameters: [
                "mode": mode.rawValue,
                "session_type": sessionType.rawValue,
                "score": score,
                "improvement_delta": improvementDelta
            ]
        )
    }

    func logPaywallViewed(reason: String?) {
        logEvent("paywall_viewed", parameters: ["reason": reason ?? "unknown"])
    }

    func logPurchaseCompleted(productId: String) {
        logEvent("purchase_completed", parameters: ["product_id": productId])
    }

    func logRequestStart(path: String, metadata: [String: Any] = [:]) {
        breadcrumb("request.start.\(path)", metadata: metadata)
    }

    func logRequestSuccess(path: String, metadata: [String: Any] = [:]) {
        breadcrumb("request.success.\(path)", metadata: metadata)
    }

    func logRequestFailure(path: String, error: Error, metadata: [String: Any] = [:]) {
        record(error: error, context: "request.\(path)", metadata: metadata)
    }

    private func sanitized(_ input: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in input {
            let cleanedKey = key
                .lowercased()
                .replacingOccurrences(of: "[^a-z0-9_]", with: "_", options: .regularExpression)
                .prefix(40)
            result[String(cleanedKey)] = value
        }
        return result
    }
}
