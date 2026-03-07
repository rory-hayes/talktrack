import Foundation

struct ProgressSnapshot: Codable, Hashable {
    let date: Date
    let avgScore: Double
    let fillerRate: Double
    let concisenessAvg: Double
    let structureAvg: Double
    let streak: Int
}

struct TrendSnapshot: Codable, Hashable {
    let avgScore7d: Double
    let fillerRate7d: Double
    let concisenessAvg7d: Double
    let structureAvg7d: Double
}
