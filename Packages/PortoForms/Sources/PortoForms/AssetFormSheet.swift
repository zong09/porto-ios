import SwiftUI
import PortoKit
import PortoDesign

/// Create or edit an asset. Ported from `AssetModal.tsx`.
///
/// Create mode: portfolio/type/currency/direction/symbol are all editable, plus an optional
/// "opening transaction" (quantity/price/fee/date) that is posted as a follow-up transaction
/// after the asset is created. Edit mode only allows changing name + manualPrice (NAV, fund only)
/// — everything else is immutable once created (mirrors the web behavior).
public struct AssetFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let editing: Asset?
    private let defaultPortfolioId: String?
    /// Called after a successful save. Passes the created asset id on create (nil on edit) so the
    /// caller can, e.g., open `TransactionFormSheet` prefilled for the "no opening transaction"
    /// flow — mirrors the web's redirect-to-transaction-modal behavior.
    private let onDone: (_ createdAssetId: String?) -> Void

    public init(
        store: AppDataStore,
        prefs: PreferencesStore,
        editing: Asset? = nil,
        defaultPortfolioId: String? = nil,
        onDone: @escaping (_ createdAssetId: String?) -> Void = { _ in }
    ) {
        self.store = store
        self.prefs = prefs
        self.editing = editing
        self.defaultPortfolioId = defaultPortfolioId
        self.onDone = onDone
    }

    private var isEdit: Bool { editing != nil }

    @State private var portfolioId: String = ""
    @State private var type: AssetType = .crypto
    @State private var symbol: String = ""
    @State private var name: String = ""
    @State private var nav: String = ""
    @State private var currency: Currency = .usd
    @State private var direction: Direction = .long

    @State private var openingQty: String = ""
    @State private var openingPrice: String = ""
    @State private var openingFee: String = ""
    @State private var openingDate: Date = Date()

    @State private var error: String?
    @State private var loading = false
    @State private var didInitialize = false

    public var body: some View {
        NavigationStack {
            Form {
                Section(prefs.t("modals.asset.portLabel")) {
                    Picker(prefs.t("modals.asset.portLabel"), selection: $portfolioId) {
                        ForEach(store.portfolios) { p in
                            Text(p.name).tag(p.id)
                        }
                    }
                    .labelsHidden()
                    .disabled(isEdit)
                }

                Section(prefs.t("modals.asset.typeLabel")) {
                    Picker(prefs.t("modals.asset.typeLabel"), selection: $type) {
                        ForEach(AssetType.allCases, id: \.self) { t in
                            Text(prefs.t("common.assetTypes.\(t.rawValue)")).tag(t)
                        }
                    }
                    .labelsHidden()
                    .disabled(isEdit)
                    .onChange(of: type) { _, newType in handleTypeChange(newType) }

                    Picker(prefs.language == .th ? "สกุลเงินของสินทรัพย์" : "Asset Currency", selection: $currency) {
                        Text("THB").tag(Currency.thb)
                        Text("USD").tag(Currency.usd)
                    }
                    .pickerStyle(.segmented)
                    .disabled(isEdit)

                    if !isEdit && (type == .crypto || type == .th || type == .us) {
                        Picker(prefs.language == .th ? "ทิศทาง" : "Direction", selection: $direction) {
                            Text(prefs.language == .th ? "▲ Long" : "▲ Long").tag(Direction.long)
                            Text(prefs.language == .th ? "▼ Short" : "▼ Short").tag(Direction.short)
                        }
                        .pickerStyle(.segmented)
                    }
                    if isEdit, let editing, (editing.direction ?? .long) == .short {
                        Label(
                            prefs.language == .th ? "SHORT — ไม่สามารถเปลี่ยนทิศทางหลังสร้างแล้ว" : "SHORT — direction cannot be changed after creation",
                            systemImage: "arrow.down.circle.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }

                Section {
                    TextField(prefs.t("modals.asset.symbolLabel"), text: $symbol)
                        .disabled(isEdit)
                        #if os(iOS)
                        .autocapitalization(.allCharacters)
                        #endif
                    TextField(prefs.language == .th ? "ชื่อ (ไม่บังคับ)" : "Name (Optional)", text: $name)
                } header: {
                    Text(prefs.t("modals.asset.symbolLabel"))
                }

                if type == .fund {
                    Section(prefs.language == .th ? "NAV เริ่มต้น" : "Initial NAV") {
                        NumericField(title: "NAV", text: $nav)
                    }
                }

                if !isEdit {
                    Section(direction == .short
                        ? (prefs.language == .th ? "รายการ Short เริ่มต้น (ไม่บังคับ)" : "Opening Short (Optional)")
                        : (prefs.language == .th ? "รายการซื้อเริ่มต้น (ไม่บังคับ)" : "Opening Buy (Optional)")
                    ) {
                        NumericField(
                            title: type == .deposit ? "Initial Balance" : "Quantity",
                            text: $openingQty
                        )
                        DatePicker(prefs.language == .th ? "วันที่" : "Date", selection: $openingDate, displayedComponents: .date)

                        if type != .deposit && !openingQty.trimmingCharacters(in: .whitespaces).isEmpty {
                            NumericField(title: "Price per Unit", text: $openingPrice)
                            NumericField(title: "Fee", text: $openingFee)
                        }

                        if !openingQty.trimmingCharacters(in: .whitespaces).isEmpty {
                            let qty = FormSupport.parseDouble(openingQty) ?? 0
                            let price = type == .deposit ? 1 : (FormSupport.parseDouble(openingPrice) ?? 0)
                            let fee = type == .deposit ? 0 : (FormSupport.parseDouble(openingFee) ?? 0)
                            let total = qty * price + fee
                            HStack {
                                Text(prefs.language == .th ? "มูลค่ารวม" : "Total spent")
                                Spacer()
                                Text(MoneyFormat.format(total, currency)).bold()
                            }
                        }
                    }
                }

                if let error {
                    Section { FormErrorBanner(message: error) }
                }
            }
            .navigationTitle(isEdit ? (prefs.language == .th ? "แก้ไขสินทรัพย์" : "Edit Asset") : prefs.t("modals.asset.createTitle"))
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
        if let editing {
            portfolioId = editing.portfolioId
            type = editing.type
            currency = editing.currency
            direction = editing.direction ?? .long
            symbol = editing.symbol
            name = (editing.name != editing.symbol) ? editing.name : ""
            nav = editing.manualPrice.map { String($0) } ?? ""
        } else {
            portfolioId = defaultPortfolioId ?? store.portfolios.first?.id ?? ""
            type = .crypto
            currency = .usd
            direction = .long
        }
        didInitialize = true
    }

    private func handleTypeChange(_ newType: AssetType) {
        currency = (newType == .th || newType == .fund || newType == .deposit) ? .thb : .usd
        if newType == .fund || newType == .deposit { direction = .long }
        if newType == .deposit {
            openingPrice = "1"
            openingFee = "0"
        } else {
            openingPrice = ""
            openingFee = ""
        }
    }

    private func submit() {
        error = nil

        if isEdit, let editing {
            loading = true
            Task {
                do {
                    let manualPrice: Double? = (editing.type == .fund) ? FormSupport.parseDouble(nav) : nil
                    try await store.updateAsset(editing.id, UpdateAssetRequest(name: name.trimmingCharacters(in: .whitespaces), manualPrice: manualPrice))
                    loading = false
                    onDone(nil)
                    dismiss()
                } catch let apiError as APIError {
                    loading = false
                    error = apiError.displayMessage
                } catch {
                    loading = false
                    self.error = prefs.t("common.error")
                }
            }
            return
        }

        let trimmedSymbol = symbol.trimmingCharacters(in: .whitespaces)
        guard !portfolioId.isEmpty else {
            error = prefs.language.rawValue == "th"
                ? "กรุณาเลือกพอร์ตการลงทุนก่อน — หากยังไม่มีให้สร้างพอร์ตก่อน"
                : "Please select a portfolio first - if you do not have one, please create it first."
            return
        }
        guard !trimmedSymbol.isEmpty else {
            error = prefs.language.rawValue == "th" ? "กรุณากรอก Symbol" : "Please enter symbol"
            return
        }

        let yahooSymbol: String?
        switch type {
        case .th: yahooSymbol = "\(trimmedSymbol).BK"
        case .us: yahooSymbol = trimmedSymbol
        default: yahooSymbol = nil
        }
        let manualPrice: Double? = (type == .fund) ? FormSupport.parseDouble(nav) : nil

        let hasOpening = !openingQty.trimmingCharacters(in: .whitespaces).isEmpty
        let qty = FormSupport.parseDouble(openingQty) ?? .nan
        let price: Double = type == .deposit ? 1 : (FormSupport.parseDouble(openingPrice) ?? .nan)
        let fee: Double = type == .deposit ? 0 : (FormSupport.parseDouble(openingFee) ?? .nan)

        if hasOpening {
            if qty.isNaN || qty <= 0 {
                error = prefs.language.rawValue == "th" ? "กรุณากรอกจำนวนเริ่มต้นให้ถูกต้อง (> 0)" : "Please enter a valid starting quantity (> 0)"
                return
            }
            if type != .deposit && (price.isNaN || price <= 0) {
                error = prefs.language.rawValue == "th" ? "กรุณากรอกราคาเริ่มต้นให้ถูกต้อง (> 0)" : "Please enter a valid starting price (> 0)"
                return
            }
            if type != .deposit && (fee.isNaN || fee < 0) {
                error = prefs.language.rawValue == "th" ? "กรุณากรอกค่าธรรมเนียมให้ถูกต้อง (>= 0)" : "Please enter a valid fee (>= 0)"
                return
            }
        }

        loading = true
        Task {
            do {
                let req = CreateAssetRequest(
                    portfolioId: portfolioId,
                    type: type,
                    symbol: trimmedSymbol.uppercased(),
                    name: name.trimmingCharacters(in: .whitespaces),
                    currency: currency,
                    cgId: nil,
                    yahooSymbol: yahooSymbol,
                    manualPrice: manualPrice,
                    direction: direction
                )
                guard let createdId = try await store.createAssetReturningId(req) else {
                    loading = false
                    error = prefs.t("common.error")
                    return
                }

                if hasOpening {
                    let txReq = CreateTransactionRequest(
                        assetId: createdId,
                        side: type == .deposit ? .deposit : (direction == .short ? .sell : .buy),
                        quantity: qty,
                        price: price,
                        fee: fee,
                        date: BangkokDate.string(from: openingDate)
                    )
                    try await store.createTransaction(txReq)
                }
                loading = false
                onDone(createdId)
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
    AssetFormSheet(store: PreviewFactory.store(), prefs: PreferencesStore())
}
