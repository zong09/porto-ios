import SwiftUI
import PortoKit
import PortoDesign
import PortoForms

/// Transactions tab: merged transaction list (date desc, `createdAt` tiebreak else `id`),
/// portfolio/asset-type filters, edit + delete. Thai 400s from the backend are shown verbatim.
public struct TransactionsScreen: View {
    @Bindable private var store: AppDataStore
    @Bindable private var prefs: PreferencesStore

    @State private var portfolioFilter: String? = nil
    @State private var typeFilter: AssetType? = nil
    @State private var editingTransaction: TxModel?
    @State private var pendingDelete: TxModel?
    @State private var errorMessage: String?

    public init(store: AppDataStore, prefs: PreferencesStore) {
        self._store = Bindable(store)
        self._prefs = Bindable(prefs)
    }

    private var theme: Theme { Theme.palette(ThemeID(rawValue: prefs.themeID) ?? .sunset) }
    private var converter: CurrencyConverter { CurrencyConverter(fx: store.summary?.fx ?? 35.84) }

    /// Merged + sorted (date desc, then createdAt desc, then id desc as a stable final tiebreak).
    private var sortedTransactions: [TxModel] {
        store.transactions
            .filter { tx in
                guard let portfolioFilter else { return true }
                return tx.asset?.portfolioId == portfolioFilter
            }
            .filter { tx in
                guard let typeFilter else { return true }
                return tx.asset?.type == typeFilter
            }
            .sorted { a, b in
                if a.date != b.date { return a.date > b.date }
                if let ca = a.createdAt, let cb = b.createdAt, ca != cb { return ca > cb }
                return a.id > b.id
            }
    }

    public var body: some View {
        NavigationStack {
            List {
                filterSection
                if sortedTransactions.isEmpty {
                    Text(prefs.t("transactions.noTx"))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(sortedTransactions) { tx in
                        row(tx)
                            .contentShape(Rectangle())
                            .onTapGesture { editingTransaction = tx }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = tx } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button { editingTransaction = tx } label: {
                                    Label("Edit", systemImage: "pencil")
                                }.tint(theme.palette.first ?? .accentColor)
                            }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(prefs.t("transactions.title"))
            .refreshable { await store.refreshAll() }
            .sheet(item: $editingTransaction) { tx in
                TransactionEditSheet(store: store, prefs: prefs, transaction: tx)
            }
            .confirmationDialog(
                prefs.t("transactions.confirmDeleteTx"),
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let tx = pendingDelete { delete(tx) }
                    pendingDelete = nil
                } label: {
                    Text("Delete")
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            }
            .alert(
                "",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                actions: { Button("OK", role: .cancel) { errorMessage = nil } },
                message: { Text(errorMessage ?? "") }
            )
        }
    }

    // MARK: - Filters

    @ViewBuilder
    private var filterSection: some View {
        Section {
            Picker(prefs.t("transactions.colPort"), selection: $portfolioFilter) {
                Text(prefs.t("transactions.filterAllPorts")).tag(String?.none)
                ForEach(store.portfolios) { p in
                    Text(p.name).tag(String?.some(p.id))
                }
            }
            Picker(prefs.t("transactions.colType"), selection: $typeFilter) {
                Text(prefs.t("transactions.filterAllTypes")).tag(AssetType?.none)
                ForEach(AssetType.allCases, id: \.self) { t in
                    Text(t.rawValue.uppercased()).tag(AssetType?.some(t))
                }
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func row(_ tx: TxModel) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(tx.asset?.symbol ?? tx.assetId)
                    .font(.subheadline.weight(.semibold))
                sideBadge(tx.side)
                Spacer()
                MoneyText(thb: netAmountThb(tx), display: prefs.displayCurrency,
                          converter: converter, primaryFont: .subheadline.weight(.semibold),
                          secondaryFont: .caption2, showSecondary: false)
            }
            HStack {
                Text(tx.asset?.portfolio?.name ?? "—")
                Text("·")
                Text(tx.date)
                Spacer()
                Text(prefs.t("transactions.colQty") + " " + MoneyFormat.number(tx.quantity, fractionDigits: 4))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func sideBadge(_ side: TransactionSide) -> some View {
        switch side {
        case .buy, .deposit:
            Text(prefs.t("transactions.txBuy")).badge(theme.greens.first ?? .green)
        case .sell, .withdraw:
            Text(prefs.t("transactions.txSell")).badge(theme.reds.first ?? .red)
        }
    }

    private func netAmountThb(_ tx: TxModel) -> Double {
        let native = tx.quantity * tx.price - tx.fee
        guard let currency = tx.asset?.currency, currency == .usd else { return native }
        return native * converter.fx
    }

    private func delete(_ tx: TxModel) {
        Task {
            do { try await store.deleteTransaction(tx.id) }
            catch let e as APIError { errorMessage = e.displayMessage }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

/// Lightweight edit form for an existing transaction (side/quantity/price/fee/date), submitted via
/// `PUT /transactions/:id`. `PortoForms.TransactionFormSheet` is still a Wave 2D placeholder, so
/// this stays self-contained rather than depending on an unfinished cross-package signature.
private struct TransactionEditSheet: View {
    let store: AppDataStore
    let prefs: PreferencesStore
    let transaction: TxModel

    @Environment(\.dismiss) private var dismiss
    @State private var side: TransactionSide
    @State private var quantity: String
    @State private var price: String
    @State private var fee: String
    @State private var date: Date
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(store: AppDataStore, prefs: PreferencesStore, transaction: TxModel) {
        self.store = store
        self.prefs = prefs
        self.transaction = transaction
        self._side = State(initialValue: transaction.side)
        self._quantity = State(initialValue: MoneyFormat.number(transaction.quantity, fractionDigits: 8))
        self._price = State(initialValue: MoneyFormat.number(transaction.price, fractionDigits: 8))
        self._fee = State(initialValue: MoneyFormat.number(transaction.fee, fractionDigits: 2))
        self._date = State(initialValue: BangkokDate.date(from: transaction.date) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Side", selection: $side) {
                        Text(prefs.t("transactions.txBuy")).tag(TransactionSide.buy)
                        Text(prefs.t("transactions.txSell")).tag(TransactionSide.sell)
                    }.pickerStyle(.segmented)
                }
                Section(prefs.t("transactions.colQty")) {
                    TextField("0", text: $quantity).decimalKeyboard()
                }
                Section(prefs.t("transactions.colPrice")) {
                    TextField("0", text: $price).decimalKeyboard()
                }
                Section("Fee") {
                    TextField("0", text: $fee).decimalKeyboard()
                }
                Section(prefs.t("transactions.colDate")) {
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(transaction.asset?.symbol ?? transaction.assetId)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving)
                }
            }
        }
    }

    private func save() {
        guard let qty = Double(quantity), let p = Double(price) else {
            errorMessage = "จำนวนหรือราคาไม่ถูกต้อง"
            return
        }
        let feeVal = Double(fee) ?? 0
        isSaving = true
        let req = CreateTransactionRequest(
            assetId: transaction.assetId, side: side, quantity: qty, price: p,
            fee: feeVal, date: BangkokDate.string(from: date)
        )
        Task {
            do {
                try await store.updateTransaction(transaction.id, req)
                isSaving = false
                dismiss()
            } catch let e as APIError {
                isSaving = false
                errorMessage = e.displayMessage
            } catch {
                isSaving = false
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "preview.transactions")!)
    let store = AppDataStore(api: PreviewAPIClient(), preferences: prefs)
    return TransactionsScreen(store: store, prefs: prefs)
}

private extension View {
    /// Numeric keyboard on iOS; no-op on macOS (the package also targets macOS 14 for CLI builds).
    @ViewBuilder
    func decimalKeyboard() -> some View {
        #if os(iOS)
        self.keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

/// No-op API client for previews only.
private struct PreviewAPIClient: APIClientProtocol {
    func get<T>(_ endpoint: Endpoint, as type: T.Type) async throws -> T where T: Decodable, T: Sendable {
        throw APIError.offline
    }
    func send<Response>(_ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type) async throws -> Response where Response: Decodable, Response: Sendable {
        throw APIError.offline
    }
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {
        throw APIError.offline
    }
}
