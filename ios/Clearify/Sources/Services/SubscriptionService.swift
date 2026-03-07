import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isLoading = false

    private let productIDs = [
        "com.tuesday.clearify.pro.monthly",
        "com.tuesday.clearify.pro.yearly",
        "com.clearify.pro.monthly",
        "com.clearify.pro.yearly"
    ]

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let loaded = try await Product.products(for: productIDs)
            products = Dictionary(grouping: loaded, by: \.id)
                .compactMap { $0.value.first }
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async throws -> Transaction? {
        let result = try await product.purchase()
        switch result {
        case let .success(.verified(transaction)):
            return transaction
        case .success(.unverified):
            throw PurchaseError.verificationFailed
        case .pending:
            throw PurchaseError.pending
        case .userCancelled:
            return nil
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }
}

enum PurchaseError: LocalizedError {
    case verificationFailed
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            return "Purchase verification failed."
        case .pending:
            return "Purchase is pending approval."
        case .unknown:
            return "Purchase failed due to an unknown error."
        }
    }
}
