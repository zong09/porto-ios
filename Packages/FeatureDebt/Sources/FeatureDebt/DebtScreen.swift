import SwiftUI
import PortoKit
import PortoDesign
import PortoForms

/// Debt tab: total-assets/liabilities/net-worth strip, liability list with pay/add adjust,
/// delete, and a debt-allocation sankey (each liability -> total liabilities).
public struct DebtScreen: View {
    @Bindable private var store: AppDataStore
    @Bindable private var prefs: PreferencesStore

    @State private var adjusting: Liability?
    @State private var editing: Liability?
    @State private var pendingDelete: Liability?
    @State private var addingNew = false
    @State private var errorMessage: String?

    public init(store: AppDataStore, prefs: PreferencesStore) {
        self._store = Bindable(store)
        self._prefs = Bindable(prefs)
    }

    private var theme: Theme { Theme.palette(ThemeID(rawValue: prefs.themeID) ?? .sunset) }
    private var converter: CurrencyConverter { CurrencyConverter(fx: store.summary?.fx ?? 35.84) }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryStrip
                    if !store.liabilities.isEmpty {
                        sankeyCard
                    }
                    liabilityList
                }
                .padding()
            }
            .navigationTitle(prefs.t("liabilities.title"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addingNew = true } label: {
                        Label(prefs.t("liabilities.addBtn"), systemImage: "plus")
                    }
                }
            }
            .refreshable { await store.refreshAll() }
            .sheet(item: $adjusting) { l in
                LiabilityAdjustSheet(store: store, prefs: prefs, liability: l)
            }
            .sheet(item: $editing) { l in
                LiabilityEditSheet(store: store, prefs: prefs, liability: l)
            }
            .sheet(isPresented: $addingNew) {
                LiabilityEditSheet(store: store, prefs: prefs, liability: nil)
            }
            .confirmationDialog(
                prefs.t("liabilities.confirmDeleteDebt"),
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    if let l = pendingDelete { delete(l) }
                    pendingDelete = nil
                } label: { Text("Delete") }
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

    // MARK: - Summary strip

    private var summaryStrip: some View {
        HStack(spacing: 16) {
            statColumn(title: "Total Assets", thb: store.summary?.totalAssetsThb ?? 0)
            Text("—").foregroundStyle(.white.opacity(0.4))
            statColumn(title: prefs.t("liabilities.totalDebt"), thb: totalLiabilitiesThb)
            Text("=").foregroundStyle(.white.opacity(0.4))
            statColumn(title: "Net Worth", thb: store.summary?.netWorthThb ?? 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func statColumn(title: String, thb: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.6))
            MoneyText(thb: thb, display: prefs.displayCurrency, converter: converter,
                      primaryFont: .title3.weight(.bold), secondaryFont: .caption2,
                      showSecondary: false)
            .foregroundStyle(.white)
        }
    }

    private var totalLiabilitiesThb: Double {
        store.summary?.totalLiabilitiesThb ?? liabilities.reduce(0) { $0 + liabilityThb($1) }
    }

    // MARK: - Sankey

    private var liabilities: [Liability] {
        store.liabilities.filter { liabilityThb($0) > 0 }.sorted { liabilityThb($0) > liabilityThb($1) }
    }

    private func liabilityThb(_ l: Liability) -> Double {
        l.currency == .usd ? l.amount * converter.fx : l.amount
    }

    /// `debtPalette` hex strings mirroring `Theme.debtPalette`, verbatim from `themes.ts`
    /// (`Theme` only exposes resolved `Color`s; `SankeySideNode` needs the raw hex for `SankeyView`).
    private var debtPaletteHex: [String] {
        switch ThemeID(rawValue: prefs.themeID) ?? .sunset {
        case .sunset: return ["#FFAE6E", "#E2542B", "#C73B22", "#FFC79A", "#C76B8E", "#A8341C"]
        case .ocean: return ["#46C2C4", "#3E8FD0", "#0E8C8F", "#97DEDF", "#8A6FC0", "#B5402C"]
        case .berry: return ["#F072A0", "#E07A4E", "#C2316B", "#F7AEC8", "#7E5AA8", "#A82A2A"]
        }
    }
    private var debtTotalHex: String {
        switch ThemeID(rawValue: prefs.themeID) ?? .sunset {
        case .sunset: return "#D8482A"
        case .ocean: return "#D8533C"
        case .berry: return "#D23B3B"
        }
    }

    private var sankeyCard: some View {
        let items = liabilities
        let palette = debtPaletteHex
        let leftTotal = items.reduce(0.0) { $0 + liabilityThb($1) }
        let left = items.enumerated().map { i, l in
            SankeySideNode(label: l.name, sub: MoneyFormat.number(liabilityThb(l), fractionDigits: 0),
                           color: palette[i % palette.count], value: liabilityThb(l))
        }
        let right = [SankeySideNode(label: prefs.t("liabilities.totalDebt"),
                                     sub: MoneyFormat.number(leftTotal, fractionDigits: 0),
                                     color: debtTotalHex, value: leftTotal)]
        let flows = items.indices.map { SankeyFlow(leftIndex: $0, rightIndex: 0, value: liabilityThb(items[$0])) }
        let input = SankeyInput(left: left, right: right, flows: flows, SW: 1000, SH: 420, LX: 150, RX: 1000 - 150 - 13)
        return VStack(alignment: .leading, spacing: 8) {
            Text(prefs.language == .th ? "สัดส่วนหนี้สิน" : "Debt Allocation").font(.headline)
            SankeyView(input).frame(height: 260)
        }
        .card()
    }

    // MARK: - List

    private var liabilityList: some View {
        VStack(alignment: .leading, spacing: 10) {
            if store.liabilities.isEmpty {
                Text(prefs.t("liabilities.noDebt"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(Array(store.liabilities.enumerated()), id: \.element.id) { index, l in
                    liabilityRow(l, index: index)
                }
            }
        }
    }

    private func liabilityRow(_ l: Liability, index: Int) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(theme.debtPalette[index % theme.debtPalette.count])
                .frame(width: 10, height: 10)
            Text(l.name).font(.subheadline.weight(.semibold))
            Spacer()
            Text(MoneyFormat.format(l.amount, l.currency)).font(.subheadline.weight(.semibold))
            Menu {
                Button("Pay") { adjusting = l }
                Button("Edit") { editing = l }
                Button(role: .destructive) { pendingDelete = l } label: { Text("Delete") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .padding(14)
        .card()
    }

    private func delete(_ l: Liability) {
        Task {
            do { try await store.deleteLiability(l.id) }
            catch let e as APIError { errorMessage = e.displayMessage }
            catch { errorMessage = error.localizedDescription }
        }
    }
}

/// Pay / add adjustment sheet — `POST /liabilities/:id/transactions` (pay or add).
private struct LiabilityAdjustSheet: View {
    let store: AppDataStore
    let prefs: PreferencesStore
    let liability: Liability

    @Environment(\.dismiss) private var dismiss
    @State private var type: LiabilityTxType = .pay
    @State private var amount: String = ""
    @State private var date = Date()
    @State private var errorMessage: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Pay").tag(LiabilityTxType.pay)
                        Text("Add").tag(LiabilityTxType.add)
                    }.pickerStyle(.segmented)
                }
                Section("Amount") {
                    TextField("0", text: $amount).decimalKeyboard()
                }
                Section(prefs.t("liabilities.colUpdated")) {
                    DatePicker("", selection: $date, displayedComponents: .date)
                }
                Section {
                    HStack {
                        Text(prefs.t("liabilities.colBalance"))
                        Spacer()
                        Text(MoneyFormat.format(previewBalance, liability.currency))
                            .foregroundStyle(.secondary)
                    }
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(liability.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving || Double(amount) == nil)
                }
            }
        }
    }

    private var previewBalance: Double {
        let amt = Double(amount) ?? 0
        return type == .pay ? liability.amount - amt : liability.amount + amt
    }

    private func save() {
        guard let amt = Double(amount) else { return }
        isSaving = true
        let req = AdjustLiabilityRequest(type: type, amount: amt, date: BangkokDate.string(from: date))
        Task {
            do {
                try await store.adjustLiability(liability.id, req)
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

/// Create/edit a liability's name/amount/currency.
private struct LiabilityEditSheet: View {
    let store: AppDataStore
    let prefs: PreferencesStore
    let liability: Liability?

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var amount: String
    @State private var currency: Currency
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(store: AppDataStore, prefs: PreferencesStore, liability: Liability?) {
        self.store = store
        self.prefs = prefs
        self.liability = liability
        self._name = State(initialValue: liability?.name ?? "")
        self._amount = State(initialValue: liability.map { MoneyFormat.number($0.amount) } ?? "")
        self._currency = State(initialValue: liability?.currency ?? .thb)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(prefs.t("liabilities.colName")) {
                    TextField("", text: $name)
                }
                Section(prefs.t("liabilities.colBalance")) {
                    TextField("0", text: $amount).decimalKeyboard()
                    Picker("Currency", selection: $currency) {
                        Text("THB").tag(Currency.thb)
                        Text("USD").tag(Currency.usd)
                    }.pickerStyle(.segmented)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red).font(.footnote) }
                }
            }
            .navigationTitle(liability == nil ? prefs.t("liabilities.addBtn") : name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }.disabled(isSaving || name.isEmpty || Double(amount) == nil)
                }
            }
        }
    }

    private func save() {
        guard let amt = Double(amount) else { return }
        isSaving = true
        Task {
            do {
                if let liability {
                    let req = UpdateLiabilityRequest(name: name, amount: amt, currency: currency.rawValue)
                    try await store.updateLiability(liability.id, req)
                } else {
                    let req = CreateLiabilityRequest(name: name, amount: amt, currency: currency.rawValue)
                    try await store.createLiability(req)
                }
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

#Preview {
    let prefs = PreferencesStore(defaults: UserDefaults(suiteName: "preview.debt")!)
    let store = AppDataStore(api: PreviewDebtAPIClient(), preferences: prefs)
    return DebtScreen(store: store, prefs: prefs)
}

private struct PreviewDebtAPIClient: APIClientProtocol {
    func send<Response>(_ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type) async throws -> Response where Response: Decodable, Response: Sendable {
        throw APIError.offline
    }
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {
        throw APIError.offline
    }
}
