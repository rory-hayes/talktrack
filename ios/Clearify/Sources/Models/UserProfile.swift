import Foundation

struct UserProfileRecord: Hashable, Codable {
    let uid: String
    let email: String?
    let displayName: String?
    let preferredName: String
    let locale: String
    let planTier: String
    let onboardingGoalMode: ScenarioMode
    let selectedRoleTrack: RoleTrack
    let experienceLevel: ExperienceLevel
    let selfReportedFocus: CoachingFocus
    let onboardingCompletedAt: Date?
    let streakCurrent: Int
    let streakBest: Int
    let lastPracticeDate: String?

    var hasCompletedOnboarding: Bool {
        onboardingCompletedAt != nil
    }

    var hasMeaningfulProfile: Bool {
        !preferredName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
