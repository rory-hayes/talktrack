import Foundation
import SwiftUI

@MainActor
protocol AppStateAuthSessionProviding {
    var hasUserSession: Bool { get }
}

@MainActor
protocol AppStateUserProfileFetching {
    func fetchCurrentProfile() async throws -> UserProfileRecord?
}

@MainActor
protocol AppStateEntitlementSyncing {
    func syncCurrentEntitlements() async throws -> String
}

@MainActor
protocol AppStateTelemetryRecording {
    func record(error: Error, context: String, metadata: [String: Any])
}

extension AuthService: AppStateAuthSessionProviding {
    var hasUserSession: Bool { user != nil }
}

extension UserProfileService: AppStateUserProfileFetching {}
extension EntitlementService: AppStateEntitlementSyncing {}
extension TelemetryService: AppStateTelemetryRecording {}

@MainActor
final class AppState: ObservableObject {
    @Published var isBootstrapping = true
    @Published var selectedMode: ScenarioMode = .workplace
    @Published var selectedRoleTrack: RoleTrack = .general
    @Published var preferredFirstName: String = ""
    @Published var experienceLevel: ExperienceLevel = .zeroToOneYears
    @Published var selfReportedFocus: CoachingFocus = .clarity
    @Published var selectedTab: RootTab = .home
    @Published var isOnboardingComplete = false
    @Published var activeSessionContext: SessionContext?

    private let defaults: UserDefaults
    private let onboardingCompleteKey = "clearify.onboarding.complete"
    private let selectedModeKey = "clearify.onboarding.mode"
    private let selectedRoleKey = "clearify.onboarding.role"
    private let preferredFirstNameKey = "clearify.onboarding.firstName"
    private let experienceLevelKey = "clearify.onboarding.experienceLevel"
    private let selfReportedFocusKey = "clearify.onboarding.selfFocus"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        restoreCachedState()
    }

    func hydrate(dependencies: Dependencies) async {
        await hydrate(
            authProvider: dependencies.authService,
            userProfileService: dependencies.userProfileService,
            entitlementService: dependencies.entitlementService,
            telemetry: dependencies.telemetry
        )
    }

    func hydrate(
        authProvider: AppStateAuthSessionProviding,
        userProfileService: AppStateUserProfileFetching,
        entitlementService: AppStateEntitlementSyncing,
        telemetry: AppStateTelemetryRecording
    ) async {
        OnboardingDebugDiagnostics.shared.record("appstate_hydrate_enter hasSession=\(authProvider.hasUserSession)")
        defer { isBootstrapping = false }

        guard authProvider.hasUserSession else {
            OnboardingDebugDiagnostics.shared.record("appstate_hydrate_reset_for_signed_out_user")
            resetForSignOut(clearCache: true)
            return
        }

        do {
            if let profile = try await userProfileService.fetchCurrentProfile() {
                OnboardingDebugDiagnostics.shared.record(
                    "appstate_hydrate_profile_loaded hasCompleted=\(profile.hasCompletedOnboarding) nameEmpty=\(profile.preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)"
                )
                selectedMode = profile.onboardingGoalMode
                selectedRoleTrack = profile.selectedRoleTrack
                preferredFirstName = profile.preferredName
                experienceLevel = profile.experienceLevel
                selfReportedFocus = profile.selfReportedFocus
                isOnboardingComplete = profile.hasCompletedOnboarding
                cacheState()
            } else {
                OnboardingDebugDiagnostics.shared.record("appstate_hydrate_profile_missing")
                resetForAuthenticatedUserWithoutProfile()
            }
            _ = try? await entitlementService.syncCurrentEntitlements()
        } catch {
            OnboardingDebugDiagnostics.shared.record(
                "appstate_hydrate_failed type=\(String(describing: type(of: error)))"
            )
            telemetry.record(error: error, context: "hydrate_state", metadata: [:])
            resetForAuthenticatedUserWithoutProfile()
        }
    }

    func markOnboardingComplete(
        preferredFirstName: String,
        experienceLevel: ExperienceLevel,
        selfReportedFocus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack
    ) {
        OnboardingDebugDiagnostics.shared.record(
            "appstate_mark_onboarding_complete nameEmpty=\(preferredFirstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) mode=\(mode.rawValue) role=\(roleTrack.rawValue)"
        )
        self.preferredFirstName = preferredFirstName
        self.experienceLevel = experienceLevel
        self.selfReportedFocus = selfReportedFocus
        selectedMode = mode
        selectedRoleTrack = roleTrack
        isOnboardingComplete = true
        cacheState()
    }

    func resetForSignOut(clearCache: Bool = true) {
        OnboardingDebugDiagnostics.shared.record("appstate_reset_for_sign_out clearCache=\(clearCache)")
        selectedMode = .workplace
        selectedRoleTrack = .general
        preferredFirstName = ""
        experienceLevel = .zeroToOneYears
        selfReportedFocus = .clarity
        selectedTab = .home
        isOnboardingComplete = false
        activeSessionContext = nil
        if clearCache {
            defaults.removeObject(forKey: onboardingCompleteKey)
            defaults.removeObject(forKey: selectedModeKey)
            defaults.removeObject(forKey: selectedRoleKey)
            defaults.removeObject(forKey: preferredFirstNameKey)
            defaults.removeObject(forKey: experienceLevelKey)
            defaults.removeObject(forKey: selfReportedFocusKey)
        }
    }

    private func restoreCachedState() {
        if let rawMode = defaults.string(forKey: selectedModeKey), let mode = ScenarioMode(rawValue: rawMode) {
            selectedMode = mode
        }
        if let rawRole = defaults.string(forKey: selectedRoleKey), let role = RoleTrack(rawValue: rawRole) {
            selectedRoleTrack = role
        }
        if let name = defaults.string(forKey: preferredFirstNameKey) {
            preferredFirstName = name
        }
        if let rawExperience = defaults.string(forKey: experienceLevelKey), let level = ExperienceLevel(rawValue: rawExperience) {
            experienceLevel = level
        }
        if let rawFocus = defaults.string(forKey: selfReportedFocusKey), let focus = CoachingFocus(rawValue: rawFocus) {
            selfReportedFocus = focus
        }
        isOnboardingComplete = defaults.bool(forKey: onboardingCompleteKey)
    }

    private func cacheState() {
        OnboardingDebugDiagnostics.shared.record(
            "appstate_cache_write onboardingComplete=\(isOnboardingComplete) mode=\(selectedMode.rawValue) role=\(selectedRoleTrack.rawValue)"
        )
        defaults.set(isOnboardingComplete, forKey: onboardingCompleteKey)
        defaults.set(selectedMode.rawValue, forKey: selectedModeKey)
        defaults.set(selectedRoleTrack.rawValue, forKey: selectedRoleKey)
        defaults.set(preferredFirstName, forKey: preferredFirstNameKey)
        defaults.set(experienceLevel.rawValue, forKey: experienceLevelKey)
        defaults.set(selfReportedFocus.rawValue, forKey: selfReportedFocusKey)
    }

    private func resetForAuthenticatedUserWithoutProfile() {
        OnboardingDebugDiagnostics.shared.record("appstate_reset_authenticated_user_without_profile")
        selectedTab = .home
        isOnboardingComplete = false
        cacheState()
    }
}

enum RootTab: Hashable {
    case home
    case progress
    case profile
}

struct SessionContext: Identifiable, Hashable {
    let id = UUID()
    let mode: ScenarioMode
    let scenario: Scenario
    let sessionType: SessionType
}
