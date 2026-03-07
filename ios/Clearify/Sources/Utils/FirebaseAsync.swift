import Foundation
import FirebaseStorage

extension StorageReference {
    func putFileAsync(from url: URL, metadata: StorageMetadata?) async throws -> StorageMetadata {
        try await withCheckedThrowingContinuation { continuation in
            putFile(from: url, metadata: metadata) { metadata, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let metadata {
                    continuation.resume(returning: metadata)
                } else {
                    continuation.resume(throwing: APIError.invalidResponse)
                }
            }
        }
    }
}
