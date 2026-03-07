import FirebaseAuth
import FirebaseFirestore
import Foundation
import StoreKit

final class EntitlementService {
    private let db = Firestore.firestore()
    private let apiClient = APIClient.shared
    private let isoFormatter = ISO8601DateFormatter()

    func currentPlanTier() async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw APIError.unauthenticated
        }

        let doc = try await db.collection("entitlements").document(uid).getDocument()
        guard let data = doc.data() else {
            return "free"
        }

        if (data["status"] as? String) == "active", (data["tier"] as? String) == "pro" {
            return "pro"
        }

        return "free"
    }

    @discardableResult
    func syncPurchase(transaction: StoreKit.Transaction) async throws -> SyncEntitlementResponse {
        let request = SyncEntitlementRequest(
            uid: try requireUID(),
            status: "active",
            tier: "pro",
            productId: transaction.productID,
            transactionId: String(transaction.id),
            originalTransactionId: String(transaction.originalID),
            purchasedAt: isoFormatter.string(from: transaction.purchaseDate),
            expiresAt: transaction.expirationDate.map { isoFormatter.string(from: $0) }
        )
        return try await sync(request: request)
    }

    @discardableResult
    func syncCurrentEntitlements() async throws -> String {
        var latestActive: StoreKit.Transaction?

        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard case let .verified(transaction) = entitlement else { continue }
            if transaction.revocationDate != nil {
                continue
            }
            if let expires = transaction.expirationDate, expires < .now {
                continue
            }
            latestActive = transaction
            break
        }

        if let latestActive {
            let response = try await syncPurchase(transaction: latestActive)
            return response.tier
        }

        let response = try await sync(
            request: SyncEntitlementRequest(
                uid: try requireUID(),
                status: "inactive",
                tier: "free",
                productId: nil,
                transactionId: nil,
                originalTransactionId: nil,
                purchasedAt: nil,
                expiresAt: nil
            )
        )
        return response.tier
    }

    private func sync(request: SyncEntitlementRequest) async throws -> SyncEntitlementResponse {
        let token = try await Auth.auth().requireIDToken()
        return try await apiClient.post(path: "syncEntitlement", body: request, authToken: token)
    }

    private func requireUID() throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw APIError.unauthenticated
        }
        return uid
    }
}
