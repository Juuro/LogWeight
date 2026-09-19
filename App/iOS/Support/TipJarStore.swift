import Observation
import StoreKit
import LogWeightCore

/// Loads tip-jar products and drives purchases via StoreKit 2.
///
/// Tips are consumables: a successful purchase has nothing to unlock or
/// restore, so there is no entitlement to track beyond `purchaseState` for
/// the confirmation UI. No server round-trip, no receipt validation needed.
@Observable
@MainActor
final class TipJarStore {

    enum PurchaseState: Equatable {
        case idle
        case purchasing(TipJarProduct)
        case thankYou(TipJarProduct)
        case failed
    }

    private(set) var products: [Product] = []
    private(set) var purchaseState: PurchaseState = .idle
    /// Stays `true` for a week after the last tip, so the thank-you note
    /// survives leaving and re-entering the screen.
    private(set) var showsThankYou = TipThankYouPolicy.shouldShowThankYou()
    @ObservationIgnored
    private nonisolated(unsafe) var transactionListener: Task<Void, Never>?

    init() {
        transactionListener = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    func loadProducts() async {
        do {
            let identifiers = TipJarProduct.allCases.map(\.rawValue)
            products = try await Product.products(for: identifiers)
                .sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    func purchase(_ product: Product) async {
        guard let tip = TipJarProduct(rawValue: product.id) else { return }
        purchaseState = .purchasing(tip)
        do {
            switch try await product.purchase() {
            case .success(.verified(let transaction)):
                await transaction.finish()
                recordTip(transaction)
                purchaseState = .thankYou(tip)
            case .success(.unverified):
                purchaseState = .failed
            case .userCancelled, .pending:
                purchaseState = .idle
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else { return }
        await transaction.finish()
        if let tip = TipJarProduct(rawValue: transaction.productID) {
            recordTip(transaction)
            purchaseState = .thankYou(tip)
        }
    }

    private func recordTip(_ transaction: Transaction) {
        TipThankYouPolicy.recordTip(at: transaction.purchaseDate)
        showsThankYou = TipThankYouPolicy.shouldShowThankYou()
    }
}
