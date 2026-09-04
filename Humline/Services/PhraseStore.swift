import Combine
import Foundation
import StoreKit

@MainActor
final class PhraseStore: ObservableObject {
    static let phrasePackID = "com.catfordlabs.humline.phrasepack"

    @Published private(set) var hasPhrasePack = false
    @Published private(set) var product: Product?
    @Published var statusMessage: String?

    private var started = false

    func isUnlocked(_ melody: Melody) -> Bool {
        melody.isFree || hasPhrasePack || AppSettings.debugUnlockAll
    }

    func start() async {
        await refreshEntitlements()
        await loadProduct()
        guard !started else { return }
        started = true
        Task {
            for await update in StoreKit.Transaction.updates {
                if let transaction = try? checkVerified(update) {
                    await apply(transaction)
                    await transaction.finish()
                }
            }
        }
    }

    func purchase() async {
        guard let product else {
            statusMessage = "Phrase pack is not available in this build yet."
            return
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await apply(transaction)
                await transaction.finish()
                statusMessage = "Phrase pack unlocked."
                HumlineAnalytics.signal("Store.phrasePack.purchased")
            case .userCancelled:
                break
            case .pending:
                statusMessage = "Purchase pending."
            @unknown default:
                break
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasPhrasePack ? "Purchases restored." : "No phrase pack found to restore."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    var priceText: String {
        product?.displayPrice ?? "£2.99"
    }

    private func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.phrasePackID])
            product = products.first
        } catch {
            statusMessage = nil
        }
    }

    private func refreshEntitlements() async {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(entitlement) {
                await apply(transaction)
            }
        }
    }

    private func apply(_ transaction: StoreKit.Transaction) async {
        if transaction.productID == Self.phrasePackID, transaction.revocationDate == nil {
            hasPhrasePack = true
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
