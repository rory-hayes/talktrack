import FirebaseAuth
import FirebaseStorage
import Foundation

final class StorageUploadService {
    private let storage = Storage.storage()

    func uploadRecording(fileURL: URL, sessionId: String, repIndex: Int) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw APIError.unauthenticated
        }

        let path = "tmp/\(uid)/\(sessionId)/rep-\(repIndex).m4a"
        let ref = storage.reference(withPath: path)

        _ = try await ref.putFileAsync(from: fileURL, metadata: nil)
        return path
    }
}
