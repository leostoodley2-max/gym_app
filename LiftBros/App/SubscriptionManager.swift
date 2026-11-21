import Foundation
import Observation
import StoreKit

/// LiftBros Pro subscriptions via StoreKit 2.
///
/// Product IDs live in `ProProduct`. For local testing in Xcode, select `LiftBros.storekit` under
/// Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Options ▸ StoreKit Configuration.
///
/// Sideloaded/test builds can't reach the App Store, so `previewPro` lets testers switch Pro on locally.
/// It is only offered when no products load, so App Store builds always go through a real purchase.
@MainActor
@Observable
final class SubscriptionManager {
    private(set) var products: [Product] = []
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var previewPro: Bool
    var lastError: String?

    @ObservationIgnored private var updatesTask: Task<Void, Never>?
    private static let previewKey = "LiftBros.previewPro"

    init() {
        previewPro = UserDefaults.standard.bool(forKey: Self.previewKey)
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
        Task { await load() }
    }

    var isPro: Bool { !purchasedProductIDs.isEmpty || previewPro }

    /// True when the App Store returned our products (TestFlight / App Store / StoreKit config file).
    var storeAvailable: Bool { !products.isEmpty }

    func product(_ id: ProProduct) -> Product? { products.first { $0.id == id.rawValue } }

    func displayPrice(_ id: ProProduct) -> String { product(id)?.displayPrice ?? id.fallbackPrice }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProProduct.allCases.map(\.rawValue))
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        purchasedProductIDs = ids
    }

    /// Returns true when the purchase completed.
    func purchase(_ id: ProProduct) async -> Bool {
        guard let product = product(id) else {
            lastError = "Subscriptions aren't available in this build."
            return false
        }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    lastError = "The purchase couldn't be verified."
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await StoreKit.AppStore.sync()
        } catch {
            lastError = error.localizedDescription
        }
        await refreshEntitlements()
    }

    /// Testing only: turns Pro on locally when the App Store isn't available.
    func setPreviewPro(_ enabled: Bool) {
        previewPro = enabled
        UserDefaults.standard.set(enabled, forKey: Self.previewKey)
    }
}
