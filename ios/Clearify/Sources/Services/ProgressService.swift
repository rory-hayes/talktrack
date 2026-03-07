import FirebaseAuth
import FirebaseFirestore
import Foundation

final class ProgressService {
    private let db = Firestore.firestore()
    private let localStore: LocalPracticeStore

    init(localStore: LocalPracticeStore) {
        self.localStore = localStore
    }

    func fetchLatestProgress(limit: Int = 14) async throws -> [ProgressSnapshot] {
        if Auth.auth().currentUser?.isAnonymous != false {
            return localStore.loadProgressSnapshots(limit: limit)
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            return localStore.loadProgressSnapshots(limit: limit)
        }

        do {
            let snapshot = try await db.collection("progress_daily")
                .whereField("uid", isEqualTo: uid)
                .order(by: "date", descending: true)
                .limit(to: limit)
                .getDocuments()

            let remote: [ProgressSnapshot] = snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard
                    let dateStr = data["date"] as? String,
                    let avgScore = number(data["avgScore"]),
                    let fillerRate = number(data["avgFillerRate"]),
                    let concisenessAvg = number(data["concisenessAvg"]),
                    let structureAvg = number(data["structureAvg"])
                else {
                    return nil
                }

                let formatter = ISO8601DateFormatter()
                let date = formatter.date(from: "\(dateStr)T00:00:00Z") ?? .now
                return ProgressSnapshot(
                    date: date,
                    avgScore: avgScore,
                    fillerRate: fillerRate,
                    concisenessAvg: concisenessAvg,
                    structureAvg: structureAvg,
                    streak: int(data["streakCurrent"]) ?? 0
                )
            }

            return remote.isEmpty ? localStore.loadProgressSnapshots(limit: limit) : remote
        } catch {
            return localStore.loadProgressSnapshots(limit: limit)
        }
    }

    func fetchRecentSessions(limit: Int = 8) async throws -> [SessionHistoryItem] {
        if Auth.auth().currentUser?.isAnonymous != false {
            return localStore.loadRecentSessions(limit: limit)
        }

        guard let uid = Auth.auth().currentUser?.uid else {
            return localStore.loadRecentSessions(limit: limit)
        }

        do {
            let sessionsSnapshot = try await db.collection("sessions")
                .whereField("uid", isEqualTo: uid)
                .order(by: "startedAt", descending: true)
                .limit(to: max(limit * 2, 12))
                .getDocuments()

            let documents = sessionsSnapshot.documents.filter { ($0.data()["status"] as? String) == "completed" }
            if documents.isEmpty {
                return localStore.loadRecentSessions(limit: limit)
            }

            var items: [SessionHistoryItem] = []
            for document in documents.prefix(limit) {
                if let item = try await sessionHistoryItem(from: document) {
                    items.append(item)
                }
            }
            return items.isEmpty ? localStore.loadRecentSessions(limit: limit) : items
        } catch {
            return localStore.loadRecentSessions(limit: limit)
        }
    }

    private func sessionHistoryItem(from document: QueryDocumentSnapshot) async throws -> SessionHistoryItem? {
        let data = document.data()
        guard
            let modeRaw = data["mode"] as? String,
            let mode = ScenarioMode(rawValue: modeRaw),
            let typeRaw = data["type"] as? String,
            let type = SessionType(rawValue: typeRaw),
            let scenarioId = data["scenarioId"] as? String
        else {
            return nil
        }

        let repsSnapshot = try await document.reference.collection("reps")
            .order(by: "repIndex", descending: false)
            .getDocuments()

        let reps = repsSnapshot.documents.compactMap { repDocument in
            speakingRep(from: repDocument.data(), sessionId: document.documentID)
        }
        guard !reps.isEmpty else {
            return nil
        }

        return SessionHistoryItem(
            id: document.documentID,
            mode: mode,
            type: type,
            scenarioId: scenarioId,
            scenarioPrompt: data["scenarioPrompt"] as? String ?? reps.first?.feedback.rewrittenExample ?? "Practice session",
            startedAt: timestamp(from: data["startedAt"]) ?? .now,
            completedAt: timestamp(from: data["completedAt"]),
            finalScore: int(data["finalScore"]) ?? reps.last?.score ?? 0,
            improvementDelta: int(data["improvementDelta"]) ?? 0,
            reps: reps
        )
    }

    private func speakingRep(from data: [String: Any], sessionId: String) -> SpeakingRep? {
        guard
            let repId = data["repId"] as? String,
            let repIndex = int(data["repIndex"]),
            let transcript = data["transcript"] as? String,
            let durationSec = number(data["durationSec"]),
            let score = int(data["score"]),
            let breakdown = breakdown(from: data["breakdown"]),
            let speechMetrics = speechMetrics(from: data["speechMetrics"]),
            let feedbackData = data["feedback"] as? [String: Any]
        else {
            return nil
        }

        let feedback = FeedbackCard(
            strength: feedbackData["strength"] as? String ?? "You are getting clearer.",
            primaryImprovement: feedbackData["primaryImprovement"] as? String ?? "Lead with the point sooner.",
            suggestedStructure: feedbackData["suggestedStructure"] as? String ?? "Context -> Action -> Result",
            rewrittenExample: feedbackData["rewrittenExample"] as? String ?? "",
            retryInstruction: feedbackData["retryInstruction"] as? String ?? "Retry in 40-60 seconds.",
            firstSentenceFeedback: feedbackData["firstSentenceFeedback"] as? String ?? "",
            ramblingFeedback: feedbackData["ramblingFeedback"] as? String ?? "",
            structureFeedback: feedbackData["structureFeedback"] as? String ?? "",
            deliveryFeedback: feedbackData["deliveryFeedback"] as? String ?? "",
            fillerHotspot: feedbackData["fillerHotspot"] as? String ?? "No clear filler cluster detected.",
            pacingBand: PacingBand(rawValue: feedbackData["pacingBand"] as? String ?? "") ?? .steady,
            openingOverlong: feedbackData["openingOverlong"] as? Bool ?? false,
            weakConclusion: feedbackData["weakConclusion"] as? Bool ?? false
        )

        return SpeakingRep(
            id: repId,
            sessionId: sessionId,
            repIndex: repIndex,
            transcript: transcript,
            durationSec: durationSec,
            breakdown: breakdown,
            score: score,
            speechMetrics: speechMetrics,
            feedback: feedback,
            localAudioPath: data["localAudioPath"] as? String,
            createdAt: timestamp(from: data["createdAt"]) ?? .now
        )
    }

    private func breakdown(from value: Any?) -> ScoreBreakdown? {
        guard let data = value as? [String: Any] else { return nil }
        return ScoreBreakdown(
            structure: int(data["structure"]) ?? 0,
            clarity: int(data["clarity"]) ?? 0,
            conciseness: int(data["conciseness"]) ?? 0,
            delivery: int(data["delivery"]) ?? 0
        )
    }

    private func speechMetrics(from value: Any?) -> SpeechMetrics? {
        guard let data = value as? [String: Any] else { return nil }
        return SpeechMetrics(
            wpm: int(data["wpm"]) ?? 0,
            fillerCount: int(data["fillerCount"]) ?? 0,
            fillerRate: number(data["fillerRate"]) ?? 0,
            pauseCount: int(data["pauseCount"]) ?? 0
        )
    }

    private func timestamp(from value: Any?) -> Date? {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let v as Double:
            return v
        case let v as Int:
            return Double(v)
        case let v as NSNumber:
            return v.doubleValue
        default:
            return nil
        }
    }

    private func int(_ value: Any?) -> Int? {
        switch value {
        case let v as Int:
            return v
        case let v as NSNumber:
            return v.intValue
        default:
            return nil
        }
    }
}
