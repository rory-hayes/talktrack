import Foundation
import FirebaseAuth

final class APIClient {
    static let shared = APIClient()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
    }

    func post<RequestBody: Encodable, ResponseBody: Decodable>(
        path: String,
        body: RequestBody,
        authToken: String
    ) async throws -> ResponseBody {
        TelemetryService.shared.logRequestStart(path: path)
        let url = BackendConfig.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            guard (200..<300).contains(http.statusCode) else {
                let message = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.serverError(statusCode: http.statusCode, message: message)
            }

            TelemetryService.shared.logRequestSuccess(path: path, metadata: ["status_code": http.statusCode])
            return try decoder.decode(ResponseBody.self, from: data)
        } catch {
            TelemetryService.shared.logRequestFailure(path: path, error: error)
            throw error
        }
    }
}

enum APIError: Error, LocalizedError {
    case invalidResponse
    case unauthenticated
    case serverError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Server sent an invalid response."
        case .unauthenticated:
            return "Sign in to continue."
        case let .serverError(statusCode, message):
            return APIError.userFacingServerMessage(statusCode: statusCode, rawMessage: message)
        }
    }

    private static func userFacingServerMessage(statusCode: Int, rawMessage _: String) -> String {
        switch statusCode {
        case 400:
            return "Clearify could not send that request. Try again."
        case 401:
            return "Your session expired. Sign in again and retry."
        case 403:
            return "This action is not available for your account."
        case 404:
            return "Clearify could not find that practice session. Start a new one and try again."
        case 429:
            return "You have reached your current plan limit."
        case 500...599:
            return "Clearify hit a server problem. Please try again."
        default:
            return "Clearify could not complete that request. Please try again."
        }
    }
}

extension Auth {
    func requireIDToken() async throws -> String {
        guard let user = currentUser else {
            throw APIError.unauthenticated
        }
        return try await user.getIDTokenResult().token
    }
}
