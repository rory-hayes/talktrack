import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var subscriptionService: SubscriptionService
    @State private var purchaseMessage: String?

    let dependencies: Dependencies
    let reason: String?

    init(dependencies: Dependencies, reason: String?) {
        self.dependencies = dependencies
        self.reason = reason
        _subscriptionService = ObservedObject(wrappedValue: dependencies.subscriptionService)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Upgrade to Pro")
                    .font(.largeTitle.bold())

                Text("Practice without free plan limits. Start full sessions and quick drills whenever you need them.")
                    .foregroundStyle(.secondary)

                if let reasonMessage {
                    Text(reasonMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if subscriptionService.isLoading {
                    ProgressView("Loading plans...")
                } else {
                    ForEach(subscriptionService.products, id: \.id) { product in
                        Button {
                            Task {
                                await purchase(product)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.displayName)
                                        .font(.headline)
                                    Text(product.description)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(product.displayPrice)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                Button("Restore Purchases") {
                    Task {
                        await restorePurchases()
                    }
                }
                .buttonStyle(.bordered)

                if let purchaseMessage {
                    Text(purchaseMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button("Not now") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .padding(20)
            .navigationTitle("Pro")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                dependencies.telemetry.logPaywallViewed(reason: reason)
                await subscriptionService.loadProducts()
            }
        }
    }

    private func purchase(_ product: Product) async {
        do {
            guard let transaction = try await subscriptionService.purchase(product) else {
                return
            }
            _ = try await dependencies.entitlementService.syncPurchase(transaction: transaction)
            await transaction.finish()
            dependencies.telemetry.logPurchaseCompleted(productId: transaction.productID)
            purchaseMessage = "Purchase synced. Pro is now active on this account."
        } catch {
            dependencies.telemetry.record(error: error, context: "purchase_flow")
            purchaseMessage = userFacingPurchaseMessage(for: error, flow: .purchase)
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionService.restorePurchases()
            let tier = try await dependencies.entitlementService.syncCurrentEntitlements()
            purchaseMessage = tier == "pro" ? "Purchases restored." : "No active subscription found."
        } catch {
            dependencies.telemetry.record(error: error, context: "restore_purchases")
            purchaseMessage = userFacingPurchaseMessage(for: error, flow: .restore)
        }
    }

    private var reasonMessage: String? {
        guard let reason else { return nil }

        switch reason {
        case "free_full_session_limit_reached":
            return "You've used this week's free full sessions. Upgrade to keep practicing today."
        case "free_quick_drill_limit_reached":
            return "You've already used today's free quick drill. Upgrade to keep practicing today."
        default:
            return "Your current plan limit has been reached. Upgrade to keep practicing."
        }
    }

    private func userFacingPurchaseMessage(for error: Error, flow: PurchaseFlow) -> String {
        if let purchaseError = error as? PurchaseError {
            switch purchaseError {
            case .verificationFailed:
                return "Apple could not verify this purchase. Please try again."
            case .pending:
                return "Your purchase is pending approval. Pro will unlock once Apple confirms it."
            case .unknown:
                break
            }
        }

        if let apiError = error as? APIError {
            switch apiError {
            case .unauthenticated:
                return "Sign in again before managing your subscription."
            case .invalidResponse, .serverError:
                break
            }
        }

        switch flow {
        case .purchase:
            return "We couldn't turn on Pro right now. Please try again."
        case .restore:
            return "We couldn't restore your purchases right now. Please try again."
        }
    }
}

private enum PurchaseFlow {
    case purchase
    case restore
}
