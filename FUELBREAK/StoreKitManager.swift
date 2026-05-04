import Foundation
import StoreKit

// MARK: - Product ID Constants
enum SensaroProduct: String, CaseIterable {
    case monthly = "net.sensaro.sub.monthly"
    case yearly  = "net.sensaro.sub.yearly"
    case payg50  = "net.sensaro.payg.50calls"

    var displayName: String {
        switch self {
        case .monthly: return "Monthly"
        case .yearly:  return "Yearly"
        case .payg50:  return "Pay-As-You-Go"
        }
    }

    var credits: Int {
        switch self {
        case .monthly: return 100
        case .yearly:  return 1500
        case .payg50:  return 50
        }
    }

    var isSubscription: Bool { self == .monthly || self == .yearly }

    /// Hardcoded fallback price shown when StoreKit returns nothing
    var fallbackPrice: String {
        switch self {
        case .monthly: return "$7.99"
        case .yearly:  return "$97.99"
        case .payg50:  return "$9.99"
        }
    }
}

// MARK: - Purchase State
enum PurchaseState: Equatable {
    case idle
    case purchasing
    case success(productID: String, creditsAdded: Int)
    case failed(String)
    case cancelled
}

// MARK: - StoreKitManager
@MainActor
final class StoreKitManager: ObservableObject {

    @Published var products: [Product] = []
    @Published var purchaseState: PurchaseState = .idle
    @Published var activeSubscription: Product? = nil
    @Published var isLoadingProducts = false

    // ── Set this to true to skip StoreKit and show UI with fallback prices ──
    // Flip to false once StoreKit config is confirmed working.
    private let debugBypassStoreKit = false

    private let lambdaBase = "https://y25m8puewi.execute-api.us-west-1.amazonaws.com/prod"
    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactions()
        Task { await loadProducts() }
    }

    deinit { transactionListenerTask?.cancel() }

    // MARK: - Load Products
    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        if debugBypassStoreKit {
            // In bypass mode products stays empty but formattedPrice uses fallbackPrice.
            // The UI will render with hardcoded prices so you can confirm layout works.
            print("⚠️ [StoreKit] DEBUG BYPASS MODE — not calling StoreKit")
            print("   Flip debugBypassStoreKit = false once .storekit config is working")
            return
        }

        let ids = SensaroProduct.allCases.map(\.rawValue)
        print("🛒 [StoreKit] Requesting: \(ids)")

        do {
            let fetched = try await Product.products(for: ids)
            print("🛒 [StoreKit] Got \(fetched.count) product(s)")
            for p in fetched { print("   ✅ \(p.id) → \(p.displayPrice)") }
            if fetched.isEmpty {
                print("⚠️ [StoreKit] 0 products — StoreKit config not linked correctly")
            }
            self.products = fetched.sorted {
                let order = SensaroProduct.allCases.map(\.rawValue)
                return (order.firstIndex(of: $0.id) ?? 99) < (order.firstIndex(of: $1.id) ?? 99)
            }
        } catch {
            print("❌ [StoreKit] Load failed: \(error)")
            purchaseState = .failed("StoreKit error: \(error.localizedDescription)")
        }

        await checkActiveSubscription()
    }

    // MARK: - Purchase
    func purchase(_ sensaroProduct: SensaroProduct, idToken: String) async {
        if debugBypassStoreKit {
            // Simulate a successful purchase in debug mode
            purchaseState = .purchasing
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s fake delay
            purchaseState = .success(
                productID: sensaroProduct.rawValue,
                creditsAdded: sensaroProduct.credits
            )
            return
        }

        guard let product = products.first(where: { $0.id == sensaroProduct.rawValue }) else {
            let ids = products.map(\.id).joined(separator: "\n")
            //purchaseState = .failed("Product not found: \(sensaroProduct.rawValue)\n\nLoaded \(products.count) products:\n\(ids.isEmpty ? "none" : ids)")
            return
        }
        await purchaseProduct(product, idToken: idToken)
    }

    private func purchaseProduct(_ product: Product, idToken: String) async {
        purchaseState = .purchasing
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await verifyWithLambda(transaction: transaction, idToken: idToken)
                await transaction.finish()
            case .userCancelled:
                purchaseState = .cancelled
            case .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .failed("Unknown result.")
            }
        } catch {
            purchaseState = .failed(error.localizedDescription)
        }
    }

    // MARK: - Restore
    func restorePurchases(idToken: String) async {
        purchaseState = .purchasing
        do {
            try await AppStore.sync()
            await checkActiveSubscription()
            purchaseState = .idle
        } catch {
            purchaseState = .failed("Restore failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Active Subscription
    func checkActiveSubscription() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               let product = products.first(where: { $0.id == transaction.productID }),
               product.type == .autoRenewable {
                activeSubscription = product
                return
            }
        }
        activeSubscription = nil
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.checkActiveSubscription()
                }
            }
        }
    }

    // MARK: - Lambda Verification
    private func verifyWithLambda(transaction: Transaction, idToken: String) async {
        guard let url = URL(string: "\(lambdaBase)/apple-iap-verify") else { return }
        let payload: [String: Any] = [
            "transactionId": transaction.id,
            "productId": transaction.productID,
            "originalTransactionId": transaction.originalID
        ]
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, httpResponse) = try await URLSession.shared.data(for: request)
            guard let http = httpResponse as? HTTPURLResponse, http.statusCode == 200 else {
                purchaseState = .failed("Lambda verification failed. Contact support with transaction ID: \(transaction.id)")
                return
            }
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let creditsAdded = json?["creditsAdded"] as? Int ?? 0
            purchaseState = .success(
                productID: transaction.productID,
                creditsAdded: creditsAdded > 0 ? creditsAdded : (SensaroProduct(rawValue: transaction.productID)?.credits ?? 0)
            )
            await checkActiveSubscription()
        } catch {
            purchaseState = .failed("Network error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error): throw error
        case .verified(let safe): return safe
        }
    }

    func product(for sensaroProduct: SensaroProduct) -> Product? {
        products.first { $0.id == sensaroProduct.rawValue }
    }

    /// Returns StoreKit price if loaded, fallback hardcoded price if in debug mode or not loaded
    func formattedPrice(for sensaroProduct: SensaroProduct) -> String {
        if let product = product(for: sensaroProduct) { return product.displayPrice }
        return sensaroProduct.fallbackPrice  // shows price even when StoreKit not configured
    }
}
