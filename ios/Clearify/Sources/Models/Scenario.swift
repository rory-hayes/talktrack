import Foundation

enum ScenarioMode: String, Codable, CaseIterable, Identifiable {
    case interview
    case workplace
    case customer

    var id: String { rawValue }

    var title: String {
        switch self {
        case .interview: return "Interview"
        case .workplace: return "Workplace"
        case .customer: return "Customer"
        }
    }
}

struct Scenario: Codable, Identifiable, Hashable {
    let id: String
    let mode: ScenarioMode
    let promptText: String
    let tags: [String]
    let difficulty: String
    let active: Bool

    var recommendedDurationLabel: String {
        switch difficulty {
        case "easy":
            return "30-45 sec"
        case "medium":
            return "45-60 sec"
        default:
            return "60-90 sec"
        }
    }

    var defaultStructureHint: String {
        let prompt = promptText.lowercased()
        if mode == .interview {
            return "Use STAR: situation, task, action, result."
        }
        if prompt.contains("standup") || prompt.contains("status") || prompt.contains("update") {
            return "Use progress, next step, blocker."
        }
        if prompt.contains("delay") || prompt.contains("stakeholder") || prompt.contains("customer") {
            return "Lead with the headline, explain the cause, end with next steps."
        }
        return "Lead with the point, support it with evidence, end with the result."
    }

    var coachingWhy: String {
        let prompt = promptText.lowercased()
        if prompt.contains("standup") || prompt.contains("status") || prompt.contains("update") {
            return "This prompt trains concise updates so you sound clear in fast-moving work conversations."
        }
        if mode == .interview {
            return "This prompt helps you answer professional questions without rambling or losing structure."
        }
        if prompt.contains("customer") || prompt.contains("client") || mode == .customer {
            return "This prompt builds confidence explaining decisions and next steps to external stakeholders."
        }
        return "This prompt builds the habit of getting to the point quickly in real workplace conversations."
    }
}
