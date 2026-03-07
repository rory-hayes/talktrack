import Foundation

final class FavoriteScenarioStore {
    // Preserve the existing key so current starred prompts survive this cleanup.
    private let legacyFavoritesKey = "talktrack.favoriteScenarios"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func starredScenarioIDs() -> Set<String> {
        Set(defaults.stringArray(forKey: legacyFavoritesKey) ?? [])
    }

    func isStarredScenario(_ id: String) -> Bool {
        starredScenarioIDs().contains(id)
    }

    func toggleStarredScenario(_ id: String) {
        var ids = starredScenarioIDs()
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        defaults.set(Array(ids).sorted(), forKey: legacyFavoritesKey)
    }
}
