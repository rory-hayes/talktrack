import Foundation

enum RoleTrack: String, Codable, CaseIterable, Identifiable {
    case general
    case softwareEngineer
    case productManager
    case accountExecutive
    case analyst
    case customerSuccess

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return "General"
        case .softwareEngineer: return "Software Engineer"
        case .productManager: return "Product Manager"
        case .accountExecutive: return "Account Executive"
        case .analyst: return "Analyst"
        case .customerSuccess: return "Customer Success"
        }
    }

    var subtitle: String {
        switch self {
        case .general: return "Balanced workplace communication"
        case .softwareEngineer: return "Standups, blockers, technical explanations"
        case .productManager: return "Stakeholders, prioritization, tradeoffs"
        case .accountExecutive: return "Objections, value articulation, recommendations"
        case .analyst: return "Explaining findings, metrics, and recommendations"
        case .customerSuccess: return "Clarifying issues, next steps, and trust"
        }
    }
}
