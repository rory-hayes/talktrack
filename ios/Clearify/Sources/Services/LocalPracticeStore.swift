import Foundation
import FirebaseAuth

final class LocalPracticeStore {
    private enum LocalPracticeStoreError: Error {
        case missingAuthenticatedUser
    }

    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let calendar = Calendar.current
    private let uidProvider: () -> String?
    private let rootDirectoryURL: URL

    init(
        fileManager: FileManager = .default,
        rootDirectoryURL: URL? = nil,
        uidProvider: @escaping () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.fileManager = fileManager
        self.uidProvider = uidProvider
        self.rootDirectoryURL = rootDirectoryURL ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("TalkTrack", isDirectory: true)
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        ensureRootDirectory()
    }

    func copyRecordingToLibrary(from sourceURL: URL, sessionId: String, repIndex: Int) throws -> String {
        guard let audioDirectoryURL else { throw LocalPracticeStoreError.missingAuthenticatedUser }
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
        completion: CompleteSessionResponse,
        protectedSessionIDs: Set<String> = []
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
        pruneAudio(except: Set(retained.map(\.id)).union(protectedSessionIDs))
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
        guard let audioDirectoryURL else { return }
        let directory = audioDirectoryURL.appendingPathComponent(id, isDirectory: true)
        try? fileManager.removeItem(at: directory)
    }

    func absoluteURL(for relativePath: String) -> URL {
        currentUserBaseDirectoryURL?.appendingPathComponent(relativePath)
            ?? rootDirectoryURL.appendingPathComponent(relativePath)
    }

    func loadArchivedSession(id: String) -> SessionHistoryItem? {
        readArchive().first(where: { $0.id == id })
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
        migrateLegacyArchiveIfNeeded()
        guard
            let archiveURL,
            fileManager.fileExists(atPath: archiveURL.path),
            let data = try? Data(contentsOf: archiveURL)
        else {
            return []
        }

        return (try? decoder.decode([SessionHistoryItem].self, from: data)) ?? []
    }

    private func writeArchive(_ sessions: [SessionHistoryItem]) {
        guard let archiveURL else { return }
        ensureCurrentUserDirectories()
        guard let data = try? encoder.encode(sessions) else { return }
        try? data.write(to: archiveURL, options: [.atomic])
    }

    private func ensureRootDirectory() {
        if !fileManager.fileExists(atPath: rootDirectoryURL.path) {
            try? fileManager.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func ensureCurrentUserDirectories() {
        guard let currentUserBaseDirectoryURL else { return }
        if !fileManager.fileExists(atPath: currentUserBaseDirectoryURL.path) {
            try? fileManager.createDirectory(at: currentUserBaseDirectoryURL, withIntermediateDirectories: true)
        }
        if let audioDirectoryURL, !fileManager.fileExists(atPath: audioDirectoryURL.path) {
            try? fileManager.createDirectory(at: audioDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func pruneAudio(except retainedSessionIDs: Set<String>) {
        guard
            let audioDirectoryURL,
            let contents = try? fileManager.contentsOfDirectory(at: audioDirectoryURL, includingPropertiesForKeys: nil)
        else {
            return
        }

        for url in contents where !retainedSessionIDs.contains(url.lastPathComponent) {
            try? fileManager.removeItem(at: url)
        }
    }

    private func startOfDay(for date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    private func currentUID() -> String? {
        let trimmed = uidProvider()?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private var currentUserBaseDirectoryURL: URL? {
        guard let uid = currentUID() else { return nil }
        return rootDirectoryURL
            .appendingPathComponent("users", isDirectory: true)
            .appendingPathComponent(uid, isDirectory: true)
    }

    private var archiveURL: URL? {
        currentUserBaseDirectoryURL?.appendingPathComponent("session-history.json")
    }

    private var audioDirectoryURL: URL? {
        currentUserBaseDirectoryURL?.appendingPathComponent("audio", isDirectory: true)
    }

    private var legacyArchiveURL: URL {
        rootDirectoryURL.appendingPathComponent("session-history.json")
    }

    private var legacyAudioDirectoryURL: URL {
        rootDirectoryURL.appendingPathComponent("audio", isDirectory: true)
    }

    private func migrateLegacyArchiveIfNeeded() {
        guard
            let currentUserBaseDirectoryURL,
            let archiveURL,
            !fileManager.fileExists(atPath: archiveURL.path),
            fileManager.fileExists(atPath: legacyArchiveURL.path) || fileManager.fileExists(atPath: legacyAudioDirectoryURL.path)
        else {
            return
        }

        try? fileManager.createDirectory(at: currentUserBaseDirectoryURL, withIntermediateDirectories: true)

        if fileManager.fileExists(atPath: legacyArchiveURL.path) {
            try? fileManager.moveItem(at: legacyArchiveURL, to: archiveURL)
        }

        if
            fileManager.fileExists(atPath: legacyAudioDirectoryURL.path),
            let audioDirectoryURL
        {
            if fileManager.fileExists(atPath: audioDirectoryURL.path) {
                if let contents = try? fileManager.contentsOfDirectory(at: legacyAudioDirectoryURL, includingPropertiesForKeys: nil) {
                    for url in contents {
                        let destination = audioDirectoryURL.appendingPathComponent(url.lastPathComponent, isDirectory: true)
                        if !fileManager.fileExists(atPath: destination.path) {
                            try? fileManager.moveItem(at: url, to: destination)
                        }
                    }
                }
                try? fileManager.removeItem(at: legacyAudioDirectoryURL)
            } else {
                try? fileManager.moveItem(at: legacyAudioDirectoryURL, to: audioDirectoryURL)
            }
        }
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}
