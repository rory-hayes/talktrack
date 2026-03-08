import XCTest
@testable import Clearify

@MainActor
final class LocalPersistenceStoresTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var rootDirectoryURL: URL!
    private var currentUID: String?

    override func setUp() {
        super.setUp()
        suiteName = "ClearifyTests.LocalPersistence.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        rootDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClearifyTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: rootDirectoryURL, withIntermediateDirectories: true)
        currentUID = "user-a"
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: rootDirectoryURL)
        defaults = nil
        suiteName = nil
        rootDirectoryURL = nil
        currentUID = nil
        super.tearDown()
    }

    func testFavoriteScenarioStoreScopesFavoritesByUserAndMigratesLegacyDataOnce() {
        defaults.set(["legacy-1", "legacy-2"], forKey: "talktrack.favoriteScenarios")
        let store = FavoriteScenarioStore(defaults: defaults) { [unowned self] in
            currentUID
        }

        XCTAssertEqual(store.starredScenarioIDs(), Set(["legacy-1", "legacy-2"]))
        XCTAssertNil(defaults.object(forKey: "talktrack.favoriteScenarios"))

        currentUID = "user-b"
        XCTAssertEqual(store.starredScenarioIDs(), [])

        store.toggleStarredScenario("scenario-b")
        XCTAssertEqual(store.starredScenarioIDs(), Set(["scenario-b"]))

        currentUID = "user-a"
        XCTAssertEqual(store.starredScenarioIDs(), Set(["legacy-1", "legacy-2"]))
    }

    func testLocalArchiveScopesByUserAndHidesDataWhenSignedOut() throws {
        let store = makeLocalPracticeStore()

        try saveSession(id: "session-a", with: store)
        XCTAssertEqual(store.loadArchivedSessions().map(\.id), ["session-a"])

        currentUID = nil
        XCTAssertEqual(store.loadArchivedSessions(), [])

        currentUID = "user-b"
        XCTAssertEqual(store.loadArchivedSessions(), [])
    }

    func testSavedAnswersRemainAvailableAfterArchivePruningAndKeepAudio() throws {
        let localStore = makeLocalPracticeStore()
        let savedStore = SavedAnswerStore(defaults: defaults) { [unowned self] in
            currentUID
        }

        let firstSession = try saveSession(id: "session-01", with: localStore)
        savedStore.save(session: firstSession)

        for index in 2...21 {
            _ = try saveSession(
                id: String(format: "session-%02d", index),
                with: localStore,
                protectedSessionIDs: savedStore.savedSessionIDs()
            )
        }

        XCTAssertNil(localStore.loadArchivedSession(id: "session-01"))
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: localStore.absoluteURL(for: "audio/session-01/rep-1.m4a").path
            )
        )

        let savedSessions = savedStore.loadSavedSessions(from: localStore.loadArchivedSessions())
        XCTAssertEqual(savedSessions.map(\.id), ["session-01"])
        XCTAssertEqual(savedSessions.first?.scenarioPrompt, firstSession.scenarioPrompt)
        XCTAssertEqual(savedSessions.first?.finalRep?.localAudioPath, "audio/session-01/rep-1.m4a")
    }

    private func makeLocalPracticeStore() -> LocalPracticeStore {
        LocalPracticeStore(
            fileManager: .default,
            rootDirectoryURL: rootDirectoryURL.appendingPathComponent("TalkTrack", isDirectory: true)
        ) { [unowned self] in
            currentUID
        }
    }

    private func saveSession(
        id: String,
        with store: LocalPracticeStore,
        protectedSessionIDs: Set<String> = []
    ) throws -> SessionHistoryItem {
        let sourceURL = rootDirectoryURL.appendingPathComponent("\(id).m4a")
        try Data("audio".utf8).write(to: sourceURL)
        let localAudioPath = try store.copyRecordingToLibrary(from: sourceURL, sessionId: id, repIndex: 1)

        let sequenceNumber = Int(id.split(separator: "-").last ?? "") ?? 0
        let createdAt = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 + sequenceNumber))

        let rep = SpeakingRep(
            id: "\(id)-rep-1",
            sessionId: id,
            repIndex: 1,
            transcript: "A focused answer",
            durationSec: 45,
            breakdown: ScoreBreakdown(structure: 20, clarity: 21, conciseness: 19, delivery: 18),
            score: 78,
            speechMetrics: SpeechMetrics(wpm: 128, fillerCount: 2, fillerRate: 1.5, pauseCount: 4),
            feedback: FeedbackCard(
                strength: "Clear opening",
                primaryImprovement: "Trim the setup",
                suggestedStructure: "Point -> evidence -> next step",
                rewrittenExample: "Here is the update and what happens next.",
                retryInstruction: "Lead with the headline.",
                firstSentenceFeedback: "Start with the main point.",
                ramblingFeedback: "Keep the middle shorter.",
                structureFeedback: "Hold the sequence.",
                deliveryFeedback: "Slow down slightly.",
                fillerHotspot: "Two fillers in the opening.",
                pacingBand: .steady,
                openingOverlong: false,
                weakConclusion: false
            ),
            localAudioPath: localAudioPath,
            createdAt: createdAt
        )

        let context = SessionContext(
            mode: .workplace,
            scenario: TestFixtures.scenario(id: "scenario-\(id)", promptText: "Prompt \(id)"),
            sessionType: .full
        )
        let completion = CompleteSessionResponse(
            sessionScore: rep.score,
            improvementDelta: 5,
            streakUpdated: StreakUpdate(current: 3, best: 4),
            trendSnapshot: TrendSnapshot(avgScore7d: 76, fillerRate7d: 1.6, concisenessAvg7d: 18, structureAvg7d: 19)
        )

        store.saveCompletedSession(
            sessionId: id,
            context: context,
            reps: [rep],
            completion: completion,
            protectedSessionIDs: protectedSessionIDs
        )

        guard let session = store.loadArchivedSession(id: id) else {
            XCTFail("Expected archived session \(id)")
            throw TestError()
        }

        return session
    }
}
