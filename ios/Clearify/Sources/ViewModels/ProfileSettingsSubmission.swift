import Foundation

protocol UserProfileUpdating {
    func updateProfile(
        preferredName: String,
        experienceLevel: ExperienceLevel,
        focus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack
    ) async throws -> UserProfileRecord
}

extension UserProfileService: UserProfileUpdating {}

enum ProfileSettingsSubmissionError: LocalizedError {
    case missingPreferredName

    var errorDescription: String? {
        switch self {
        case .missingPreferredName:
            return "Add your first name before saving."
        }
    }
}

@MainActor
enum ProfileSettingsSubmission {
    static func save(
        preferredName: String,
        experienceLevel: ExperienceLevel,
        focus: CoachingFocus,
        mode: ScenarioMode,
        roleTrack: RoleTrack,
        using userProfileService: UserProfileUpdating,
        appState: AppState
    ) async throws {
        let trimmedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw ProfileSettingsSubmissionError.missingPreferredName
        }

        _ = try await userProfileService.updateProfile(
            preferredName: trimmedName,
            experienceLevel: experienceLevel,
            focus: focus,
            mode: mode,
            roleTrack: roleTrack
        )

        appState.markOnboardingComplete(
            preferredFirstName: trimmedName,
            experienceLevel: experienceLevel,
            selfReportedFocus: focus,
            mode: mode,
            roleTrack: roleTrack
        )
    }
}
