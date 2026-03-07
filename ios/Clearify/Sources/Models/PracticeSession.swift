import Foundation

struct PracticeSession: Identifiable, Codable, Hashable {
    let id: String
    let uid: String
    let mode: ScenarioMode
    let scenarioId: String
    let type: SessionType
    let expectedRepCount: Int
    let startedAt: Date
    var completedAt: Date?
    var repCount: Int
    var finalScore: Int?
}

enum SessionType: String, Codable {
    case full
    case quick
}
