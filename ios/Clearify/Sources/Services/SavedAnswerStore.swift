import Foundation
import FirebaseAuth

final class SavedAnswerStore {
    private struct SavedAnswerRecord: Codable, Hashable {
        let sessionId: String
        var session: SessionHistoryItem?
        let savedAt: Date
    }

    private let legacySavedAnswersKey = "talktrack.savedAnswers"
    private let scopedSavedAnswersKeyPrefix = "clearify.savedAnswers"
    private let defaults: UserDefaults
    private let uidProvider: () -> String?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        uidProvider: @escaping () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.defaults = defaults
        self.uidProvider = uidProvider
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func savedSessionIDs() -> Set<String> {
        Set(loadRecords().map(\.sessionId))
    }

    func isSavedAnswer(_ sessionId: String) -> Bool {
        savedSessionIDs().contains(sessionId)
    }

    func save(session: SessionHistoryItem) {
        var records = loadRecords()
        if let index = records.firstIndex(where: { $0.sessionId == session.id }) {
            records[index].session = session
        } else {
            records.append(
                SavedAnswerRecord(
                    sessionId: session.id,
                    session: session,
                    savedAt: .now
                )
            )
        }
        persist(records)
    }

    func removeSavedAnswer(sessionId: String) {
        let records = loadRecords().filter { $0.sessionId != sessionId }
        persist(records)
    }

    func toggleSavedAnswer(session: SessionHistoryItem) {
        if isSavedAnswer(session.id) {
            removeSavedAnswer(sessionId: session.id)
        } else {
            save(session: session)
        }
    }

    func loadSavedSessions(from archivedSessions: [SessionHistoryItem], limit: Int = 8) -> [SessionHistoryItem] {
        var records = loadRecords(archivedSessions: archivedSessions)
        guard !records.isEmpty else { return [] }

        let archivedByID = Dictionary(uniqueKeysWithValues: archivedSessions.map { ($0.id, $0) })
        var didUpgradeStoredSnapshots = false

        for index in records.indices {
            guard let archived = archivedByID[records[index].sessionId] else { continue }
            if records[index].session != archived {
                records[index].session = archived
                didUpgradeStoredSnapshots = true
            }
        }

        if didUpgradeStoredSnapshots {
            persist(records)
        }

        return records
            .compactMap(\.session)
            .sorted { lhs, rhs in
                let lhsDate = lhs.completedAt ?? lhs.startedAt
                let rhsDate = rhs.completedAt ?? rhs.startedAt
                return lhsDate > rhsDate
            }
            .prefix(limit)
            .map { $0 }
    }

    private func loadRecords(archivedSessions: [SessionHistoryItem] = []) -> [SavedAnswerRecord] {
        guard let uid = currentUID() else { return [] }
        migrateLegacySavedAnswersIfNeeded(for: uid, archivedSessions: archivedSessions)
        let key = scopedSavedAnswersKey(for: uid)
        guard
            let data = defaults.data(forKey: key),
            let records = try? decoder.decode([SavedAnswerRecord].self, from: data)
        else {
            return []
        }
        return records
    }

    private func persist(_ records: [SavedAnswerRecord]) {
        guard let uid = currentUID() else { return }
        let key = scopedSavedAnswersKey(for: uid)

        if records.isEmpty {
            defaults.removeObject(forKey: key)
            return
        }

        guard let data = try? encoder.encode(records) else { return }
        defaults.set(data, forKey: key)
    }

    private func currentUID() -> String? {
        let trimmed = uidProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func scopedSavedAnswersKey(for uid: String) -> String {
        "\(scopedSavedAnswersKeyPrefix).\(uid)"
    }

    private func migrateLegacySavedAnswersIfNeeded(for uid: String, archivedSessions: [SessionHistoryItem]) {
        let scopedKey = scopedSavedAnswersKey(for: uid)
        guard defaults.object(forKey: scopedKey) == nil else { return }

        let legacyIDs = Array(Set(defaults.stringArray(forKey: legacySavedAnswersKey) ?? []))
        guard !legacyIDs.isEmpty else { return }

        let archivedByID = Dictionary(uniqueKeysWithValues: archivedSessions.map { ($0.id, $0) })
        let migrated = legacyIDs.map { id in
            SavedAnswerRecord(
                sessionId: id,
                session: archivedByID[id],
                savedAt: .now
            )
        }

        guard let data = try? encoder.encode(migrated) else { return }
        defaults.set(data, forKey: scopedKey)
        defaults.removeObject(forKey: legacySavedAnswersKey)
    }
}
