import Foundation

enum CoachingFocus: String, Codable, CaseIterable, Identifiable {
    case structure
    case clarity
    case conciseness
    case delivery

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var planHeadline: String {
        switch self {
        case .structure:
            return "Build answers with a stronger spine."
        case .clarity:
            return "Make the message land faster."
        case .conciseness:
            return "Trim the answer to the point."
        case .delivery:
            return "Sound calmer and more deliberate."
        }
    }

    var planDetail: String {
        switch self {
        case .structure:
            return "Use one pattern consistently: headline, evidence, result."
        case .clarity:
            return "Lead with the conclusion, then explain only what helps understanding."
        case .conciseness:
            return "Cut setup and repetition. Aim to finish while the listener still wants more."
        case .delivery:
            return "Replace filler words with short pauses and let the ending land cleanly."
        }
    }

    var scenarioKeywords: [String] {
        switch self {
        case .structure:
            return ["project", "decision", "challenge", "process", "summary", "outcome"]
        case .clarity:
            return ["explain", "clarify", "concept", "feature", "solution", "recommendation"]
        case .conciseness:
            return ["quick", "30 seconds", "standup", "status", "update", "summary"]
        case .delivery:
            return ["push back", "criticism", "disagrees", "manager", "stakeholder", "customer"]
        }
    }

    static func weakest(from reps: [SpeakingRep], snapshots: [ProgressSnapshot]) -> CoachingFocus {
        guard !reps.isEmpty else {
            let latest = snapshots.first
            let candidates: [(CoachingFocus, Double)] = [
                (.structure, latest?.structureAvg ?? 0),
                (.clarity, (latest?.avgScore ?? 0) / 4),
                (.conciseness, latest?.concisenessAvg ?? 0),
                (.delivery, 25 - (latest?.fillerRate ?? 0))
            ]
            return candidates.min { $0.1 < $1.1 }?.0 ?? .clarity
        }

        let averages: [(CoachingFocus, Double)] = [
            (.structure, reps.map { Double($0.breakdown.structure) }.average),
            (.clarity, reps.map { Double($0.breakdown.clarity) }.average),
            (.conciseness, reps.map { Double($0.breakdown.conciseness) }.average),
            (.delivery, reps.map { Double($0.breakdown.delivery) }.average)
        ]
        return averages.min { $0.1 < $1.1 }?.0 ?? .clarity
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
