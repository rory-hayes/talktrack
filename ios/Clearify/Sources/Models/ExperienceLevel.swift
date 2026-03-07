import Foundation

enum ExperienceLevel: String, Codable, CaseIterable, Identifiable {
    case switchingOrStudent
    case zeroToOneYears
    case twoToFourYears
    case fiveToSevenYears

    var id: String { rawValue }

    var title: String {
        switch self {
        case .switchingOrStudent:
            return "Switching / Starting"
        case .zeroToOneYears:
            return "0-1 years"
        case .twoToFourYears:
            return "2-4 years"
        case .fiveToSevenYears:
            return "5-7 years"
        }
    }

    var subtitle: String {
        switch self {
        case .switchingOrStudent:
            return "Career switchers, grads, and first-job prep"
        case .zeroToOneYears:
            return "Early workplace reps and clearer updates"
        case .twoToFourYears:
            return "Ownership, stakeholder questions, and sharper explanations"
        case .fiveToSevenYears:
            return "Leadership presence, tradeoffs, and harder conversations"
        }
    }

    var coachingSummary: String {
        switch self {
        case .switchingOrStudent:
            return "We will bias toward foundational prompts and high-confidence structures."
        case .zeroToOneYears:
            return "We will keep prompts practical and focused on everyday workplace moments."
        case .twoToFourYears:
            return "We will lean into prioritization, explaining work, and sharper recommendations."
        case .fiveToSevenYears:
            return "We will emphasize leadership clarity, concise tradeoffs, and calmer delivery."
        }
    }
}
