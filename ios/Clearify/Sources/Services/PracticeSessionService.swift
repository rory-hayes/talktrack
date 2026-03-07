import FirebaseAuth
import Foundation

final class PracticeSessionService {
    private let apiClient = APIClient.shared

    func startSession(
        mode: ScenarioMode,
        scenarioId: String,
        scenarioPrompt: String,
        sessionType: SessionType
    ) async throws -> StartSessionResponse {
        let uid = try requireUID()
        let token = try await Auth.auth().requireIDToken()

        return try await apiClient.post(
            path: "startSession",
            body: StartSessionRequest(
                uid: uid,
                mode: mode,
                scenarioId: scenarioId,
                scenarioPrompt: scenarioPrompt,
                sessionType: sessionType,
                timezone: TimeZone.current.identifier
            ),
            authToken: token
        )
    }

    func analyzeRep(
        sessionId: String,
        repIndex: Int,
        mode: ScenarioMode,
        prompt: String,
        audioStoragePath: String,
        durationSec: Double
    ) async throws -> AnalyzeRepResponse {
        let uid = try requireUID()
        let token = try await Auth.auth().requireIDToken()

        return try await apiClient.post(
            path: "analyzeRep",
            body: AnalyzeRepRequest(
                uid: uid,
                sessionId: sessionId,
                repIndex: repIndex,
                mode: mode,
                prompt: prompt,
                audioStoragePath: audioStoragePath,
                durationSec: durationSec
            ),
            authToken: token
        )
    }

    func completeSession(sessionId: String) async throws -> CompleteSessionResponse {
        let uid = try requireUID()
        let token = try await Auth.auth().requireIDToken()

        return try await apiClient.post(
            path: "completeSession",
            body: CompleteSessionRequest(
                uid: uid,
                sessionId: sessionId,
                timezone: TimeZone.current.identifier
            ),
            authToken: token
        )
    }

    private func requireUID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw APIError.unauthenticated
        }
        return uid
    }
}
