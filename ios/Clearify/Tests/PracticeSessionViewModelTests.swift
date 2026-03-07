import XCTest
@testable import Clearify

@MainActor
final class PracticeSessionViewModelTests: XCTestCase {
    func testUnauthenticatedSessionStartResolutionShowsSignInMessage() {
        let resolution = PracticeSessionViewModel.unauthenticatedSessionStartResolution()

        XCTAssertNil(resolution.sessionId)
        XCTAssertFalse(resolution.paywallRequired)
        XCTAssertEqual(resolution.errorMessage, "Sign in to your account before starting a practice session.")
        XCTAssertEqual(resolution.loopPhase, .unavailable)
    }

    func testDisallowedSessionStartTriggersPaywall() {
        let resolution = PracticeSessionViewModel.sessionStartResolution(
            for: StartSessionResponse(
                allowed: false,
                reason: "free_full_session_limit_reached",
                sessionId: nil,
                remainingFullSessionsThisWeek: 0,
                streakState: .init(current: 2, best: 4, lastPracticeDate: "2026-03-07")
            )
        )

        XCTAssertTrue(resolution.paywallRequired)
        XCTAssertEqual(resolution.paywallReason, "free_full_session_limit_reached")
        XCTAssertEqual(resolution.loopPhase, .unavailable)
    }

    func testAllowedSessionStartMovesToReadyToRecord() {
        let resolution = PracticeSessionViewModel.sessionStartResolution(
            for: StartSessionResponse(
                allowed: true,
                reason: nil,
                sessionId: "session-123",
                remainingFullSessionsThisWeek: 2,
                streakState: .init(current: 1, best: 1, lastPracticeDate: "2026-03-07")
            )
        )

        XCTAssertEqual(resolution.sessionId, "session-123")
        XCTAssertFalse(resolution.paywallRequired)
        XCTAssertNil(resolution.errorMessage)
        XCTAssertEqual(resolution.loopPhase, .readyToRecord)
    }

    func testFailedSessionStartUsesLocalBackendSpecificMessage() {
        let localResolution = PracticeSessionViewModel.failedSessionStartResolution(isLocalBackend: true)
        let remoteResolution = PracticeSessionViewModel.failedSessionStartResolution(isLocalBackend: false)

        XCTAssertEqual(localResolution.errorMessage, "Local practice services are not running. Start the Firebase emulators and try again.")
        XCTAssertEqual(remoteResolution.errorMessage, "We couldn't prepare this practice session. Try again in a moment.")
        XCTAssertEqual(localResolution.loopPhase, .unavailable)
        XCTAssertEqual(remoteResolution.loopPhase, .unavailable)
    }
}
