import Foundation

final class LocalPracticeStore {
    private let fileManager = FileManager.default
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let calendar = Calendar.current

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureDirectories()
    }

    func copyRecordingToLibrary(from sourceURL: URL, sessionId: String, repIndex: Int) throws -> String {
        let directory = audioDirectoryURL.appendingPathComponent(sessionId, isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        let fileName = "rep-\(repIndex).m4a"
        let destination = directory.appendingPathComponent(fileName)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: sourceURL, to: destination)
        return "audio/\(sessionId)/\(fileName)"
    }

    func saveCompletedSession(
        sessionId: String,
        context: SessionContext,
        reps: [SpeakingRep],
        completion: CompleteSessionResponse
    ) {
        guard !reps.isEmpty else { return }

        var archive = readArchive()
        archive.removeAll { $0.id == sessionId }
        archive.append(
            SessionHistoryItem(
                id: sessionId,
                mode: context.mode,
                type: context.sessionType,
                scenarioId: context.scenario.id,
                scenarioPrompt: context.scenario.promptText,
                startedAt: reps.first?.createdAt ?? .now,
                completedAt: .now,
                finalScore: completion.sessionScore,
                improvementDelta: completion.improvementDelta,
                reps: reps
            )
        )

        archive.sort { $0.startedAt > $1.startedAt }
        let retained = Array(archive.prefix(20))
        writeArchive(retained)
        pruneAudio(except: Set(retained.map(\.id)))
    }

    func loadRecentSessions(limit: Int = 8) -> [SessionHistoryItem] {
        Array(loadArchivedSessions().prefix(limit))
    }

    func loadArchivedSessions() -> [SessionHistoryItem] {
        readArchive().sorted { $0.startedAt > $1.startedAt }
    }

    func loadProgressSnapshots(limit: Int = 30) -> [ProgressSnapshot] {
        let sessions = readArchive().sorted { $0.startedAt > $1.startedAt }
        guard !sessions.isEmpty else { return [] }

        let grouped = Dictionary(grouping: sessions) { session in
            startOfDay(for: session.startedAt)
        }

        let sortedDays = grouped.keys.sorted(by: >)
        let currentStreak = calculateCurrentStreak(from: sortedDays)

        return sortedDays.prefix(limit).enumerated().map { index, day in
            let daySessions = grouped[day] ?? []
            let finalReps = daySessions.compactMap(\.finalRep)
            let avgScore = daySessions.map { Double($0.finalScore) }.average
            let fillerRate = finalReps.map(\.speechMetrics.fillerRate).average
            let conciseness = finalReps.map { Double($0.breakdown.conciseness) }.average
            let structure = finalReps.map { Double($0.breakdown.structure) }.average

            return ProgressSnapshot(
                date: day,
                avgScore: avgScore,
                fillerRate: fillerRate,
                concisenessAvg: conciseness,
                structureAvg: structure,
                streak: index == 0 ? currentStreak : max(currentStreak - index, 0)
            )
        }
    }

    func fallbackCompletion(for context: SessionContext, sessionId: String, reps: [SpeakingRep]) -> CompleteSessionResponse {
        let sessionScore = reps.last?.score ?? 0
        let improvementDelta = sessionScore - (reps.first?.score ?? sessionScore)

        var existing = readArchive()
        existing.removeAll { $0.id == sessionId }
        let provisional = SessionHistoryItem(
            id: sessionId,
            mode: context.mode,
            type: context.sessionType,
            scenarioId: context.scenario.id,
            scenarioPrompt: context.scenario.promptText,
            startedAt: reps.first?.createdAt ?? .now,
            completedAt: .now,
            finalScore: sessionScore,
            improvementDelta: improvementDelta,
            reps: reps
        )
        existing.append(provisional)
        existing.sort { $0.startedAt > $1.startedAt }

        let snapshots = snapshots(from: existing)
        let first = snapshots.first
        return CompleteSessionResponse(
            sessionScore: sessionScore,
            improvementDelta: improvementDelta,
            streakUpdated: StreakUpdate(current: first?.streak ?? 0, best: first?.streak ?? 0),
            trendSnapshot: TrendSnapshot(
                avgScore7d: Array(snapshots.prefix(7)).map(\.avgScore).average,
                fillerRate7d: Array(snapshots.prefix(7)).map(\.fillerRate).average,
                concisenessAvg7d: Array(snapshots.prefix(7)).map(\.concisenessAvg).average,
                structureAvg7d: Array(snapshots.prefix(7)).map(\.structureAvg).average
            )
        )
    }

    func deleteSession(id: String) {
        let retained = readArchive().filter { $0.id != id }
        writeArchive(retained)
        let directory = audioDirectoryURL.appendingPathComponent(id, isDirectory: true)
        try? fileManager.removeItem(at: directory)
    }

    func absoluteURL(for relativePath: String) -> URL {
        baseDirectoryURL.appendingPathComponent(relativePath)
    }

    private func snapshots(from sessions: [SessionHistoryItem]) -> [ProgressSnapshot] {
        let grouped = Dictionary(grouping: sessions) { session in startOfDay(for: session.startedAt) }
        let sortedDays = grouped.keys.sorted(by: >)
        let streak = calculateCurrentStreak(from: sortedDays)

        return sortedDays.enumerated().map { index, day in
            let daySessions = grouped[day] ?? []
            let finalReps = daySessions.compactMap(\.finalRep)
            return ProgressSnapshot(
                date: day,
                avgScore: daySessions.map { Double($0.finalScore) }.average,
                fillerRate: finalReps.map(\.speechMetrics.fillerRate).average,
                concisenessAvg: finalReps.map { Double($0.breakdown.conciseness) }.average,
                structureAvg: finalReps.map { Double($0.breakdown.structure) }.average,
                streak: index == 0 ? streak : max(streak - index, 0)
            )
        }
    }

    private func calculateCurrentStreak(from sortedDays: [Date]) -> Int {
        guard !sortedDays.isEmpty else { return 0 }

        let today = startOfDay(for: .now)
        let latest = sortedDays[0]
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today

        guard latest == today || latest == yesterday else {
            return 0
        }

        var streak = 0
        var expected = latest
        for day in sortedDays {
            if day == expected {
                streak += 1
                expected = calendar.date(byAdding: .day, value: -1, to: expected) ?? expected
            } else if day < expected {
                break
            }
        }
        return streak
    }

    private func readArchive() -> [SessionHistoryItem] {
        guard
            fileManager.fileExists(atPath: archiveURL.path),
            let data = try? Data(contentsOf: archiveURL)
        else {
            return []
        }

        return (try? decoder.decode([SessionHistoryItem].self, from: data)) ?? []
    }

    private func writeArchive(_ sessions: [SessionHistoryItem]) {
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: archiveURL, options: [.atomic])
    }

    private func ensureDirectories() {
        if !fileManager.fileExists(atPath: baseDirectoryURL.path) {
            try? fileManager.createDirectory(at: baseDirectoryURL, withIntermediateDirectories: true)
        }
        if !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try? fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func pruneAudio(except retainedSessionIDs: Set<String>) {
        guard let contents = try? fileManager.contentsOfDirectory(at: audioDirectoryURL, includingPropertiesForKeys: nil) else {
            return
        }

        for url in contents where !retainedSessionIDs.contains(url.lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private var baseDirectoryURL: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TalkTrack", isDirectory: true)
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private var archiveURL: URL {
        baseDirectoryURL.appendingPathComponent("session-history.json")
    }

    private var audioDirectoryURL: URL {
        baseDirectoryURL.appendingPathComponent("audio", isDirectory: true)
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
