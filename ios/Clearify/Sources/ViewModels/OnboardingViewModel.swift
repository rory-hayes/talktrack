import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    typealias CompleteOnboardingAction = (
        _ preferredName: String,
        _ experienceLevel: ExperienceLevel,
        _ focus: CoachingFocus,
        _ mode: ScenarioMode,
        _ roleTrack: RoleTrack
    ) async throws -> UserProfileRecord

    @Published var preferredName = ""
    @Published var experienceLevel: ExperienceLevel = .zeroToOneYears
    @Published var selectedFocus: CoachingFocus = .clarity
    @Published var selectedMode: ScenarioMode = .workplace
    @Published var selectedRoleTrack: RoleTrack = .general
    @Published var isSubmitting = false
    @Published var errorMessage: String?

    private let completeOnboardingAction: CompleteOnboardingAction

    init(dependencies: Dependencies) {
        self.completeOnboardingAction = { preferredName, experienceLevel, focus, mode, roleTrack in
            try await dependencies.userProfileService.completeOnboarding(
                preferredName: preferredName,
                experienceLevel: experienceLevel,
                focus: focus,
                mode: mode,
                roleTrack: roleTrack
            )
        }
    }

    init(completeOnboardingAction: @escaping CompleteOnboardingAction) {
        self.completeOnboardingAction = completeOnboardingAction
    }

    var trimmedPreferredName: String {
        preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func validateProfileStep() -> Bool {
        OnboardingDebugDiagnostics.shared.record(
            "profile_validation_start nameEmpty=\(trimmedPreferredName.isEmpty)"
        )
        guard !trimmedPreferredName.isEmpty else {
            OnboardingDebugDiagnostics.shared.record("validate_profile_result result=failed reason=missing_preferred_name")
            errorMessage = "Add your first name so we can personalize your coaching plan."
            return false
        }
        OnboardingDebugDiagnostics.shared.record("validate_profile_result result=passed")
        errorMessage = nil
        return true
    }

    func completeOnboarding() async throws -> UserProfileRecord {
        OnboardingDebugDiagnostics.shared.record(
            "profile_submission_start nameEmpty=\(trimmedPreferredName.isEmpty) mode=\(selectedMode.rawValue) role=\(selectedRoleTrack.rawValue)"
        )

        do {
            let profile = try await completeOnboardingAction(
                trimmedPreferredName,
                experienceLevel,
                selectedFocus,
                selectedMode,
                selectedRoleTrack
            )
            OnboardingDebugDiagnostics.shared.record(
                "profile_submission_end success hasCompleted=\(profile.hasCompletedOnboarding)"
            )
            return profile
        } catch {
            OnboardingDebugDiagnostics.shared.record(
                "profile_submission_end failure type=\(String(describing: type(of: error)))"
            )
            throw error
        }
    }
}
