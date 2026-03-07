import Foundation

struct StartSessionRequest: Codable {
    let uid: String
    let mode: ScenarioMode
    let scenarioId: String
    let scenarioPrompt: String
    let sessionType: SessionType
    let timezone: String
}

struct StartSessionResponse: Codable {
    let allowed: Bool
    let reason: String?
    let sessionId: String?
    let remainingFullSessionsThisWeek: Int
    let streakState: StreakState
}

struct StreakState: Codable {
    let current: Int
    let best: Int
    let lastPracticeDate: String?
}

struct AnalyzeRepRequest: Codable {
    let uid: String
    let sessionId: String
    let repIndex: Int
    let mode: ScenarioMode
    let prompt: String
    let audioStoragePath: String
    let durationSec: Double
}

struct CompleteSessionRequest: Codable {
    let uid: String
    let sessionId: String
    let timezone: String
}

struct SyncEntitlementRequest: Codable {
    let uid: String
    let status: String
    let tier: String
    let productId: String?
    let transactionId: String?
    let originalTransactionId: String?
    let purchasedAt: String?
    let expiresAt: String?
}

struct SyncEntitlementResponse: Codable {
    let tier: String
    let status: String
}

struct CompleteSessionResponse: Codable {
    let sessionScore: Int
    let improvementDelta: Int
    let streakUpdated: StreakUpdate
    let trendSnapshot: TrendSnapshot
}

struct StreakUpdate: Codable {
    let current: Int
    let best: Int
}
