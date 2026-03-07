import Foundation
import FirebaseFirestore
import FirebaseFirestoreSwift

final class ScenarioRepository {
    private let db = Firestore.firestore()
    private var bundledScenarios: [Scenario] = []

    private let starterScenarioIDs: [ScenarioMode: [String]] = [
        .interview: ["interview_001", "interview_002", "interview_005", "interview_014"],
        .workplace: ["workplace_001", "workplace_006", "workplace_020", "workplace_046"],
        .customer: ["customer_001", "customer_002", "customer_009", "customer_014"]
    ]

    init() {
        bundledScenarios = loadBundledScenarios()
    }

    func scenarios(for mode: ScenarioMode) async throws -> [Scenario] {
        let remote = try await fetchRemoteScenarios(for: mode)
        if !remote.isEmpty {
            return remote
        }
        return bundledScenarios.filter { $0.mode == mode && $0.active }
    }

    func prioritizedScenarios(
        for mode: ScenarioMode,
        weakestFocus: CoachingFocus?,
        roleTrack: RoleTrack,
        experienceLevel: ExperienceLevel? = nil
    ) async throws -> [Scenario] {
        let list = try await scenarios(for: mode)
        let starterIDs = starterScenarioIDs[mode] ?? []

        return list.sorted { lhs, rhs in
            let lhsScore = rankingScore(for: lhs, mode: mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel, starterIDs: starterIDs)
            let rhsScore = rankingScore(for: rhs, mode: mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel, starterIDs: starterIDs)
            if lhsScore == rhsScore {
                return lhs.promptText < rhs.promptText
            }
            return lhsScore > rhsScore
        }
    }

    func personalizedRecommendation(
        for mode: ScenarioMode,
        weakestFocus: CoachingFocus?,
        roleTrack: RoleTrack,
        experienceLevel: ExperienceLevel? = nil,
        on date: Date = .now
    ) -> Scenario? {
        let list = prioritizedBundledScenarios(for: mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel)
        guard !list.isEmpty else { return nil }

        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % min(list.count, 12)
        return list[index]
    }

    func nextScenario(
        after scenario: Scenario,
        weakestFocus: CoachingFocus?,
        roleTrack: RoleTrack,
        experienceLevel: ExperienceLevel? = nil
    ) -> Scenario? {
        prioritizedBundledScenarios(for: scenario.mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel)
            .first(where: { $0.id != scenario.id })
    }

    private func prioritizedBundledScenarios(
        for mode: ScenarioMode,
        weakestFocus: CoachingFocus?,
        roleTrack: RoleTrack,
        experienceLevel: ExperienceLevel?
    ) -> [Scenario] {
        let starterIDs = starterScenarioIDs[mode] ?? []
        return bundledScenarios
            .filter { $0.mode == mode && $0.active }
            .sorted {
                rankingScore(for: $0, mode: mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel, starterIDs: starterIDs) >
                    rankingScore(for: $1, mode: mode, weakestFocus: weakestFocus, roleTrack: roleTrack, experienceLevel: experienceLevel, starterIDs: starterIDs)
            }
    }

    private func rankingScore(
        for scenario: Scenario,
        mode: ScenarioMode,
        weakestFocus: CoachingFocus?,
        roleTrack: RoleTrack,
        experienceLevel: ExperienceLevel?,
        starterIDs: [String]
    ) -> Int {
        let loweredPrompt = scenario.promptText.lowercased()
        var score = 0

        if starterIDs.contains(scenario.id) {
            score += 50
        }
        if scenario.difficulty == "easy" {
            score += 24
        } else if scenario.difficulty == "medium" {
            score += 12
        }
        if let weakestFocus {
            if scenario.tags.contains(weakestFocus.rawValue) {
                score += 20
            }
            if weakestFocus.scenarioKeywords.contains(where: { loweredPrompt.contains($0) }) {
                score += 14
            }
        }

        if roleKeywords(for: roleTrack).contains(where: { loweredPrompt.contains($0) }) {
            score += 12
        }

        if let experienceLevel {
            score += experienceScore(for: scenario.difficulty, experienceLevel: experienceLevel)
        }

        if mode == .workplace, loweredPrompt.contains("quick") || loweredPrompt.contains("summary") {
            score += 6
        }

        return score
    }

    private func experienceScore(for difficulty: String, experienceLevel: ExperienceLevel) -> Int {
        switch experienceLevel {
        case .switchingOrStudent, .zeroToOneYears:
            switch difficulty {
            case "easy": return 18
            case "medium": return 8
            default: return -4
            }
        case .twoToFourYears:
            switch difficulty {
            case "medium": return 10
            case "easy": return 6
            default: return 2
            }
        case .fiveToSevenYears:
            switch difficulty {
            case "hard": return 16
            case "medium": return 8
            default: return -4
            }
        }
    }

    private func roleKeywords(for roleTrack: RoleTrack) -> [String] {
        switch roleTrack {
        case .general:
            return []
        case .softwareEngineer:
            return ["bug", "feature", "blocker", "technical", "project"]
        case .productManager:
            return ["stakeholder", "priorities", "decision", "tradeoff", "leadership"]
        case .accountExecutive:
            return ["customer", "pricing", "objection", "recommendation", "benefits"]
        case .analyst:
            return ["analysis", "results", "report", "metrics", "investigation"]
        case .customerSuccess:
            return ["client", "customer", "support", "issue", "next steps"]
        }
    }

    private func fetchRemoteScenarios(for mode: ScenarioMode) async throws -> [Scenario] {
        do {
            let snapshot = try await db.collection("scenarios")
                .whereField("mode", isEqualTo: mode.rawValue)
                .whereField("active", isEqualTo: true)
                .getDocuments()

            if !snapshot.documents.isEmpty {
                return snapshot.documents.compactMap { doc in
                    try? doc.data(as: Scenario.self)
                }
            }
        } catch {
            return []
        }

        return []
    }

    private func loadBundledScenarios() -> [Scenario] {
        guard
            let url = Bundle.main.url(forResource: "scenarios", withExtension: "json"),
            let data = try? Data(contentsOf: url)
        else {
            return []
        }

        let decoder = JSONDecoder()
        do {
            return try decoder.decode([Scenario].self, from: data)
        } catch {
            return []
        }
    }
}
