import Foundation

struct SpeakingRep: Identifiable, Codable, Hashable {
    let id: String
    let sessionId: String
    let repIndex: Int
    let transcript: String
    let durationSec: Double
    let breakdown: ScoreBreakdown
    let score: Int
    let speechMetrics: SpeechMetrics
    let feedback: FeedbackCard
    let localAudioPath: String?
    let createdAt: Date

    var shortTranscript: String {
        transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    init(
        id: String,
        sessionId: String,
        repIndex: Int,
        transcript: String,
        durationSec: Double,
        breakdown: ScoreBreakdown,
        score: Int,
        speechMetrics: SpeechMetrics,
        feedback: FeedbackCard,
        localAudioPath: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.sessionId = sessionId
        self.repIndex = repIndex
        self.transcript = transcript
        self.durationSec = durationSec
        self.breakdown = breakdown
        self.score = score
        self.speechMetrics = speechMetrics
        self.feedback = feedback
        self.localAudioPath = localAudioPath
        self.createdAt = createdAt
    }
}
