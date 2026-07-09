import SwiftUI
import PortoKit
import PortoDesign
import struct PortoKit.Transaction

/// Create or edit a transaction. Ported from `TransactionModal.tsx`.
///
/// Side semantics: deposit-type assets use deposit/withdraw; short-position assets flip the
/// buy/sell labels to Sell (Open) / Buy (Cover) and validate quantity against the outstanding
/// short size instead of the held quantity.
public struct TransactionFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let editing: Transaction?
    private let defaultAssetId: String?
    private let onAddAsset: (() -> Void)?
    private let onDone: () -> Void

    public init(
        store: AppDataStore,
        prefs: PreferencesStore,
        editing: Transaction? = nil,
        defaultAssetId: String? = nil,
        onAddAsset: (() -> Void)? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.store = store
        self.prefs = prefs
        self.editing = editing
        self.defaultAssetId = defaultAssetId
        self.onAddAsset = onAddAsset
        self.onDone = onDone
    }

    private var isEdit: Bool { editing != nil }

    @State private var assetId: String = ""
    /// Buy-slot side. Deposit-type assets map this to deposit/withdraw; short assets map it to
    /// sell(open)/buy(cover) at submit time.
    @State private var isBuySlot: Bool = true
    @State private var quantity: String = ""
    @State private var price: String = ""
    @State private var fee: String = ""
    @State private var date: Date = Date()

    @State private var error: String?
    @State private var loading = false
    @State private var didInitialize = false

    private var selectedAsset: Asset? { store.assets.first { $0.id == assetId } }
    private var isDeposit: Bool { selectedAsset?.type == .deposit }
    private var isShort: Bool { (selectedAsset?.direction ?? .long) == .short }
    private var assetCurrency: Currency { selectedAsset?.currency ?? .usd }

    public var body: some View {
        NavigationStack {
            Form {
                Section(prefs.t("transactions.colAsset")) {
                    Picker(prefs.t("transactions.colAsset"), selection: $assetId) {
                        ForEach(store.assets) { a in
                            Text("\(a.symbol) — \(a.portfolio?.name ?? "—")").tag(a.id)
                        }
                    }
                    .labelsHidden()
                    .disabled(isEdit)
                    .onChange(of: assetId) { _, _ in prefillPriceForSelectedAsset() }

                    if !isEdit, let onAddAsset {
                        Button {
                            dismiss()
                            onAddAsset()
                        } label: {
                            Text("+ \(prefs.t("portfolios.addAssetBtn"))")
                                .font(.caption).bold()
                        }
                    }
                }

                Section(prefs.t("transactions.colType")) {
                    Picker(prefs.t("transactions.colType"), selection: $isBuySlot) {
                        Text(buySlotLabel(true)).tag(true)
                        Text(buySlotLabel(false)).tag(false)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section {
                    NumericField(
                        title: isDeposit ? "Amount" : "Quantity",
                        text: $quantity
                    )
                    if !isDeposit {
                        NumericField(title: "Price per Unit", text: $price)
                        NumericField(title: "Fee", text: $fee)
                    }
                    DatePicker(prefs.t("transactions.colDate"), selection: $date, displayedComponents: .date)
                } header: {
                    Text(isDeposit
                        ? (prefs.language == .th ? "จำนวนเงิน (\(assetCurrency == .usd ? "$" : "฿"))" : "Amount (\(assetCurrency == .usd ? "$" : "฿"))")
                        : (prefs.language == .th ? "จำนวน (หน่วย/เหรียญ/หุ้น)" : "Quantity (units/coins/shares)"))
                }

                if let error {
                    Section { FormErrorBanner(message: error) }
                }
            }
            .navigationTitle(isEdit ? (prefs.language == .th ? "แก้ไขรายการธุรกรรม" : "Edit Transaction") : prefs.t("modals.transaction.title"))
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

    private func buySlotLabel(_ buySlot: Bool) -> String {
        let th = prefs.language == .th
        if isDeposit {
            return buySlot ? (th ? "ฝากเงิน" : "Deposit") : (th ? "ถอนเงิน" : "Withdraw")
        } else if isShort {
            return buySlot ? (th ? "ขาย (เปิด)" : "Sell (Open)") : (th ? "ซื้อ (ปิด)" : "Buy (Cover)")
        } else {
            return buySlot ? (th ? "ซื้อ" : "Buy") : (th ? "ขาย" : "Sell")
        }
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        if let editing {
            assetId = editing.assetId
            let asset = store.assets.first { $0.id == editing.assetId }
            let short = (asset?.direction ?? .long) == .short
            // isBuySlot is the "left button" slot: buy for long/deposit, sell(open) for short.
            isBuySlot = short ? (editing.side == TransactionSide.sell) : (editing.side == TransactionSide.buy || editing.side == TransactionSide.deposit)
            quantity = trimmedNumber(editing.quantity)
            price = trimmedNumber(editing.price)
            fee = trimmedNumber(editing.fee)
            date = BangkokDate.date(from: String(editing.date.prefix(10))) ?? Date()
        } else {
            assetId = defaultAssetId ?? store.assets.first?.id ?? ""
            isBuySlot = !isShort
            quantity = ""
            fee = ""
            date = Date()
            prefillPriceForSelectedAsset()
        }
        didInitialize = true
    }

    private func trimmedNumber(_ value: Double) -> String {
        value == 0 ? "0" : String(value)
    }

    private func prefillPriceForSelectedAsset() {
        guard !isEdit, let asset = selectedAsset else { return }
        if asset.type == .deposit {
            price = "1"
            fee = "0"
        } else {
            price = asset.currentPrice.map { String($0) } ?? ""
            fee = ""
        }
    }

    private func submit() {
        error = nil
        let th = prefs.language == .th

        guard !assetId.isEmpty else {
            error = th ? "กรุณาเลือกสินทรัพย์ก่อน — ถ้ายังไม่มีให้กด \"+ เพิ่มสินทรัพย์ใหม่\"" : "Please select an asset first - if none exist, click \"+ Add New Asset\""
            return
        }

        let qInput = FormSupport.parseDouble(quantity) ?? .nan
        let pInput: Double = isDeposit ? 1 : (FormSupport.parseDouble(price) ?? .nan)
        let fInput: Double = isDeposit ? 0 : (FormSupport.parseDouble(fee) ?? 0)

        guard !qInput.isNaN, qInput > 0 else {
            error = th ? "กรุณากรอกจำนวนให้ถูกต้อง (> 0)" : "Please enter a valid quantity (> 0)"
            return
        }
        if !isDeposit {
            guard !pInput.isNaN, pInput > 0 else {
                error = th ? "กรุณากรอกราคาให้ถูกต้อง (> 0)" : "Please enter a valid price (> 0)"
                return
            }
            guard !fInput.isNaN, fInput >= 0 else {
                error = th ? "กรุณากรอกค่าธรรมเนียมให้ถูกต้อง (>= 0)" : "Please enter a valid fee (>= 0)"
                return
            }
        }

        let side: TransactionSide
        if isDeposit {
            side = isBuySlot ? .deposit : .withdraw
        } else if isShort {
            side = isBuySlot ? .sell : .buy
        } else {
            side = isBuySlot ? .buy : .sell
        }

        // Cap the reducing side (sell for long, buy/cover for short) at the outstanding position.
        if let selectedAsset {
            let currentQty = selectedAsset.position?.quantity ?? 0
            let oldQty = (editing?.assetId == assetId) ? (editing?.quantity ?? 0) : 0
            let isReducingSide = isShort ? (side == .buy) : (side == .sell)
            if isReducingSide, qInput > (currentQty + oldQty) + 1e-9 {
                let cap = currentQty + oldQty
                let formattedCap = String(format: "%.8f", cap)
                if isShort {
                    error = th
                        ? "ไม่สามารถ cover เกินจำนวนที่ short อยู่ได้ (ปัจจุบัน short อยู่ \(formattedCap) หน่วย)"
                        : "Cannot cover more than you are short (currently short \(formattedCap) units)"
                } else {
                    error = th
                        ? "ไม่สามารถขายเกินจำนวนที่ถืออยู่ได้ (ปัจจุบันถืออยู่ \(formattedCap) หน่วย)"
                        : "Cannot sell more than you hold (currently holding \(formattedCap) units)"
                }
                return
            }
        }

        loading = true
        Task {
            do {
                let req = CreateTransactionRequest(
                    assetId: assetId,
                    side: side,
                    quantity: qInput,
                    price: pInput,
                    fee: fInput,
                    date: BangkokDate.string(from: date)
                )
                if let editing {
                    try await store.updateTransaction(editing.id, req)
                } else {
                    try await store.createTransaction(req)
                }
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
    TransactionFormSheet(store: PreviewFactory.store(), prefs: PreferencesStore())
}
