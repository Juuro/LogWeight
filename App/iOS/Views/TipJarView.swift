import SwiftUI
import StoreKit
import LogWeightCore

/// "Support LogWeight" screen: lists consumable tip tiers.
///
/// No paywall, no nagging — reachable only from Settings, or from the
/// one-time `TipPromptSheet` shown after `TipPromptCoordinator.promptThreshold`
/// successful entries.
struct TipJarView: View {
    @State private var store = TipJarStore()

    var body: some View {
        List {
            Section {
                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        HStack {
                            Label(product.displayName, systemImage: symbol(for: product))
                            Spacer()
                            Text(product.displayPrice)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isPurchasing)
                    .accessibilityIdentifier("tipjar.product.\(product.id)")
                }

                Text("LogWeight is free, with no ads and no tracking. If it's useful to you, a tip helps keep it that way.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if case .thankYou = store.purchaseState {
                Section {
                    Label("Thank you for supporting LogWeight!", systemImage: "heart.fill")
                        .foregroundStyle(.pink)
                        .accessibilityIdentifier("tipjar.thankyou")
                }
            }

            if case .failed = store.purchaseState {
                Section {
                    Text("The purchase didn't go through. Please try again.")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Support LogWeight")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.loadProducts()
        }
    }

    private var isPurchasing: Bool {
        if case .purchasing = store.purchaseState { return true }
        return false
    }

    private func symbol(for product: Product) -> String {
        TipJarProduct(rawValue: product.id)?.sfSymbol ?? "heart"
    }
}

#if DEBUG
#Preview {
    NavigationStack { TipJarView() }
}
#endif
