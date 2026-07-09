import SwiftUI
import PortoKit
import PortoDesign

/// Manual price (NAV) update for an asset. Ported from `PriceModal.tsx`.
public struct PriceFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let asset: Asset
    private let onDone: () -> Void

    public init(
        store: AppDataStore,
        prefs: PreferencesStore,
        asset: Asset,
        onDone: @escaping () -> Void = {}
    ) {
        self.store = store
        self.prefs = prefs
        self.asset = asset
        self.onDone = onDone
    }

    @State private var price: String = ""
    @State private var error: String?
    @State private var loading = false
    @State private var didInitialize = false

    private var th: Bool { prefs.language == .th }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(asset.symbol) — \(asset.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NumericField(
                        title: th ? "NAV ปัจจุบัน (฿/หน่วย)" : "Current NAV (฿/Unit)",
                        text: $price
                    )
                } header: {
                    Text(th ? "NAV ปัจจุบัน (฿/หน่วย)" : "Current NAV (฿/Unit)")
                }
                if let error {
                    Section { FormErrorBanner(message: error) }
                }
            }
            .navigationTitle(prefs.t("modals.price.title"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(prefs.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(loading ? prefs.t("common.loading") : prefs.t("common.save")) { submit() }
                        .disabled(loading)
                }
            }
            .onAppear { initializeIfNeeded() }
        }
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        price = asset.manualPrice.map { String($0) } ?? ""
        didInitialize = true
    }

    private func submit() {
        error = nil
        guard let parsedPrice = FormSupport.parseDouble(price), parsedPrice > 0 else {
            error = th ? "กรุณากรอกราคา NAV ให้ถูกต้อง (> 0)" : "Please enter a valid NAV price (> 0)"
            return
        }
        loading = true
        Task {
            do {
                try await store.updateAsset(asset.id, UpdateAssetRequest(manualPrice: parsedPrice))
                loading = false
                onDone()
                dismiss()
            } catch let apiError as APIError {
                loading = false
                error = apiError.displayMessage
            } catch {
                loading = false
                self.error = prefs.t("common.error")
            }
        }
    }
}

#Preview {
    PriceFormSheet(
        store: PreviewFactory.store(),
        prefs: PreferencesStore(),
        asset: Asset(
            id: "1", portfolioId: "p1", type: .fund, symbol: "K-CHANGE-A(A)", name: "K-Change Fund",
            currency: .thb, direction: .long, cgId: nil, yahooSymbol: nil, manualPrice: 12.34,
            sortOrder: 0, portfolio: nil, currentPrice: 12.34, change24h: nil, position: nil
        )
    )
}
