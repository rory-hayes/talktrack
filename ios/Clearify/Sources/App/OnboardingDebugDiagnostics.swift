import Combine
import Foundation

@MainActor
final class OnboardingDebugDiagnostics: ObservableObject {
    static let shared = OnboardingDebugDiagnostics()
    static let stateAccessibilityIdentifier = "debug.onboarding.state"
    static let eventsAccessibilityIdentifier = "debug.onboarding.events"
    nonisolated private static let debugEnabled = {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("UITEST_RESET_STATE") || arguments.contains("UITEST_DEBUG_ONBOARDING")
    }()

    @Published private(set) var currentStep = "unknown"
    @Published private(set) var authenticatedProgressStep = "unknown"
    @Published private(set) var isSubmitting = false
    @Published private(set) var isAuthenticating = false
    @Published private(set) var lastEvent = "idle"
    @Published private(set) var recentEvents: [String] = []

    let isEnabled: Bool

    private var eventCount = 0
    private let maxRetainedEvents = 40

    private init(processInfo: ProcessInfo = .processInfo) {
        isEnabled = Self.debugEnabled
    }

    nonisolated static func recordFromAnyActor(_ event: String) {
        guard debugEnabled else { return }
        Task { @MainActor in
            shared.record(event)
        }
    }

    var stateSummary: String {
        "step=\(currentStep) authStep=\(authenticatedProgressStep) submitting=\(isSubmitting) authenticating=\(isAuthenticating) last=\(lastEvent)"
    }

    var eventsSummary: String {
        recentEvents.isEmpty ? "no-events" : recentEvents.joined(separator: "\n")
    }

    func updateState(
        step: String? = nil,
        authenticatedProgressStep: String? = nil,
        isSubmitting: Bool? = nil,
        isAuthenticating: Bool? = nil
    ) {
        guard isEnabled else { return }

        if let step {
            currentStep = step
        }
        if let authenticatedProgressStep {
            self.authenticatedProgressStep = authenticatedProgressStep
        }
        if let isSubmitting {
            self.isSubmitting = isSubmitting
        }
        if let isAuthenticating {
            self.isAuthenticating = isAuthenticating
        }
    }

    func record(_ event: String) {
        guard isEnabled else { return }

        eventCount += 1
        let uptimeMS = Int((ProcessInfo.processInfo.systemUptime * 1_000).rounded())
        let formattedEvent = "[\(eventCount) @\(uptimeMS)ms] \(event)"
        lastEvent = formattedEvent
        recentEvents.append(formattedEvent)
        if recentEvents.count > maxRetainedEvents {
            recentEvents.removeFirst(recentEvents.count - maxRetainedEvents)
        }
        print("ONBOARDING_DEBUG \(formattedEvent)")
    }
}
