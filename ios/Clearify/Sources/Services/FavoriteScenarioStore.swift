import Foundation
import FirebaseAuth

final class FavoriteScenarioStore {
    private let legacyFavoritesKey = "talktrack.favoriteScenarios"
    private let scopedFavoritesKeyPrefix = "clearify.favoriteScenarios"
    private let defaults: UserDefaults
    private let uidProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        uidProvider: @escaping () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.defaults = defaults
        self.uidProvider = uidProvider
    }

    func starredScenarioIDs() -> Set<String> {
        guard let uid = currentUID() else { return [] }
        migrateLegacyFavoritesIfNeeded(for: uid)
        return Set(defaults.stringArray(forKey: scopedFavoritesKey(for: uid)) ?? [])
    }

    func isStarredScenario(_ id: String) -> Bool {
        starredScenarioIDs().contains(id)
    }

    func toggleStarredScenario(_ id: String) {
        guard let uid = currentUID() else { return }
        var ids = starredScenarioIDs()
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        defaults.set(Array(ids).sorted(), forKey: scopedFavoritesKey(for: uid))
    }

    private func currentUID() -> String? {
        let trimmed = uidProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func scopedFavoritesKey(for uid: String) -> String {
        "\(scopedFavoritesKeyPrefix).\(uid)"
    }

    private func migrateLegacyFavoritesIfNeeded(for uid: String) {
        let scopedKey = scopedFavoritesKey(for: uid)
        guard defaults.object(forKey: scopedKey) == nil else { return }

        let legacyIDs = defaults.stringArray(forKey: legacyFavoritesKey) ?? []
        guard !legacyIDs.isEmpty else { return }

        defaults.set(Array(Set(legacyIDs)).sorted(), forKey: scopedKey)
        defaults.removeObject(forKey: legacyFavoritesKey)
    }
}
