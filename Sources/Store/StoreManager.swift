import Foundation
import StoreKit

@MainActor
final class StoreManager: ObservableObject {
    @AppLog(category: "StoreManager")
    private var logger

    enum ProductID: String, CaseIterable {
        case yearly = "cn.wflixu.Monet.yearly"
        case lifetime = "cn.wflixu.Monet.lifetime"
    }

    @Published var products: [Product] = []
    @Published var isPurchased = false
    @Published var purchasedProductID: ProductID?
    @Published var isPurchasing = false
    @Published var purchaseError: String?

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Product Loading

    func loadProducts() async {
        do {
            let ids = ProductID.allCases.map(\.rawValue)
            logger.info("Requesting products for IDs: \(ids.joined(separator: ", "))")
            let fetched = try await Product.products(for: ids)
            products = fetched.sorted { $0.price < $1.price }
            logger.info("Loaded \(self.products.count) product(s)")
            for p in products {
                logger.info("  Product: id=\(p.id), name=\(p.displayName), price=\(p.displayPrice)")
            }
        } catch {
            logger.error("Failed to load products: \(error.localizedDescription)")
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async {
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    logger.info("Purchase successful: \(transaction.productID)")
                    isPurchased = true
                    if let productID = ProductID(rawValue: transaction.productID) {
                        purchasedProductID = productID
                        UsageTracker.purchasedProductID = productID.rawValue
                    }
                    UsageTracker.hasPurchased = true
                    await transaction.finish()
                case .unverified(let transaction, let error):
                    logger.warning("Purchase unverified: \(transaction.productID), error: \(error.localizedDescription)")
                    purchaseError = String(localized: "Purchase verification failed") + ": \(error.localizedDescription)"
                }
            case .userCancelled:
                logger.info("User cancelled purchase")
            case .pending:
                logger.info("Purchase pending")
                purchaseError = String(localized: "Purchase Pending")
            @unknown default:
                break
            }
        } catch {
            logger.error("Purchase failed: \(error.localizedDescription)")
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Entitlement Verification

    func verifyEntitlement() async {
        // Fallback: restore from UserDefaults in case StoreKit verification is unavailable
        if UsageTracker.hasPurchased {
            isPurchased = true
            if let productIDString = UsageTracker.purchasedProductID,
               let productID = ProductID(rawValue: productIDString) {
                purchasedProductID = productID
            }
            logger.info("Purchased state restored from local flag")
        }

        var entitlementCount = 0
        for await result in Transaction.currentEntitlements {
            entitlementCount += 1
            switch result {
            case .verified(let transaction):
                logger.info("Entitlement found: \(transaction.productID), expires: \(String(describing: transaction.expirationDate))")
                if let productID = ProductID(rawValue: transaction.productID) {
                    isPurchased = true
                    purchasedProductID = productID
                    UsageTracker.hasPurchased = true
                    UsageTracker.purchasedProductID = productID.rawValue
                    logger.info("Entitlement verified: \(transaction.productID)")
                }
            case .unverified(let transaction, let error):
                logger.warning("Unverified entitlement: \(transaction.productID), error: \(error.localizedDescription)")
            }
        }
        logger.info("verifyEntitlement complete, found \(entitlementCount) entitlement(s), isPurchased=\(self.isPurchased)")
    }

    func listenForTransactions() {
        transactionListenerTask = Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await MainActor.run {
                        self.isPurchased = true
                        if let productID = ProductID(rawValue: transaction.productID) {
                            self.purchasedProductID = productID
                            UsageTracker.purchasedProductID = productID.rawValue
                        }
                        UsageTracker.hasPurchased = true
                    }
                    await transaction.finish()
                }
            }
        }
    }

    func stopListening() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
    }

    // MARK: - Helpers

    func product(for type: ProductID) -> Product? {
        products.first { $0.id == type.rawValue }
    }

#if DEBUG
    func debugMarkAsPurchased() {
        isPurchased = true
        purchasedProductID = .lifetime
        UsageTracker.hasPurchased = true
        UsageTracker.purchasedProductID = ProductID.lifetime.rawValue
    }
#endif
}
