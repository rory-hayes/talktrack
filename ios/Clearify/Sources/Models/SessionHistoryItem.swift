import Foundation

struct SessionHistoryItem: Identifiable, Codable, Hashable {
    let id: String
    let mode: ScenarioMode
    let type: SessionType
    let scenarioId: String
    let scenarioPrompt: String
    let startedAt: Date
    let completedAt: Date?
    let finalScore: Int
    let improvementDelta: Int
    let reps: [SpeakingRep]

    var firstRep: SpeakingRep? {
        reps.first
    }

    var finalRep: SpeakingRep? {
        reps.last
    }

    var topImprovement: String {
        finalRep?.feedback.primaryImprovement ?? "Keep tightening the main point."
    }

    var strongestMoment: String {
        finalRep?.feedback.strength ?? "You are building a stronger communication habit."
    }
}
