import Foundation

struct ScoreBreakdown: Codable, Hashable {
    let structure: Int
    let clarity: Int
    let conciseness: Int
    let delivery: Int
}

struct SpeechMetrics: Codable, Hashable {
    let wpm: Int
    let fillerCount: Int
    let fillerRate: Double
    let pauseCount: Int
}

enum PacingBand: String, Codable, Hashable {
    case slow
    case steady
    case fast

    var title: String {
        switch self {
        case .slow: return "Slow"
        case .steady: return "Steady"
        case .fast: return "Fast"
        }
    }

    var guidance: String {
        switch self {
        case .slow:
            return "You are leaving too much space between ideas. Tighten the answer and move with more intent."
        case .steady:
            return "Your pace is in the useful range. Keep it and focus on cleaner structure."
        case .fast:
            return "You are rushing. Short pauses will make you sound more confident and easier to follow."
        }
    }
}

struct FeedbackCard: Codable, Hashable {
    let strength: String
    let primaryImprovement: String
    let suggestedStructure: String
    let rewrittenExample: String
    let retryInstruction: String
    let firstSentenceFeedback: String
    let ramblingFeedback: String
    let structureFeedback: String
    let deliveryFeedback: String
    let fillerHotspot: String
    let pacingBand: PacingBand
    let openingOverlong: Bool
    let weakConclusion: Bool
}

struct AnalyzeRepResponse: Codable, Hashable {
    let transcript: String
    let workClarityScore: Int
    let breakdown: ScoreBreakdown
    let speechMetrics: SpeechMetrics
    let strength: String
    let primaryImprovement: String
    let suggestedStructure: String
    let rewrittenExample: String
    let retryInstruction: String
    let firstSentenceFeedback: String
    let ramblingFeedback: String
    let structureFeedback: String
    let deliveryFeedback: String
    let fillerHotspot: String
    let pacingBand: PacingBand
    let openingOverlong: Bool
    let weakConclusion: Bool
    let safetyFlags: [String]

    var feedbackCard: FeedbackCard {
        FeedbackCard(
            strength: strength,
            primaryImprovement: primaryImprovement,
            suggestedStructure: suggestedStructure,
            rewrittenExample: rewrittenExample,
            retryInstruction: retryInstruction,
            firstSentenceFeedback: firstSentenceFeedback,
            ramblingFeedback: ramblingFeedback,
            structureFeedback: structureFeedback,
            deliveryFeedback: deliveryFeedback,
            fillerHotspot: fillerHotspot,
            pacingBand: pacingBand,
            openingOverlong: openingOverlong,
            weakConclusion: weakConclusion
        )
    }
}
