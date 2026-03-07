import Foundation

final class SavedAnswerStore {
    // Preserve the existing key so current saved answers survive this cleanup.
    private let legacySavedAnswersKey = "talktrack.savedAnswers"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func savedSessionIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: legacySavedAnswersKey) ?? [])
    }

    func isSavedAnswer(_ sessionId: String) -> Bool {
        savedSessionIDs().contains(sessionId)
    }

    func toggleSavedAnswer(sessionId: String) {
        var ids = savedSessionIDs()
        if ids.contains(sessionId) {
            ids.remove(sessionId)
        } else {
            ids.insert(sessionId)
        }
        defaults.set(Array(ids).sorted(), forKey: legacySavedAnswersKey)
    }

    func loadSavedSessions(from archivedSessions: [SessionHistoryItem], limit: Int = 8) -> [SessionHistoryItem] {
        let ids = savedSessionIDs()
        guard !ids.isEmpty else { return [] }

        return archivedSessions
            .filter { ids.contains($0.id) }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(limit)
            .map { $0 }
    }
}
