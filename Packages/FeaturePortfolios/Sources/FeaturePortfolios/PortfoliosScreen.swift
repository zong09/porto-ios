import SwiftUI
import PortoKit
import PortoDesign
import PortoForms

/// Ports the web `Portfolios.tsx` page: one card per portfolio (color dot, dual-currency value +
/// return badge, stacked allocation bar, holdings), reorder for both portfolios and per-portfolio
/// assets, and the row actions (buy/sell, chart, NAV/edit, delete).
public struct PortfoliosScreen: View {
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let api: APIClientProtocol

    public init(store: AppDataStore, prefs: PreferencesStore, api: APIClientProtocol) {
        self.store = store
        self.prefs = prefs
        self.api = api
    }

    // Sheets / dialogs
    @State private var showCreatePortfolio = false
    @State private var editingPortfolio: Portfolio?
    @State private var showAddAsset = false
    @State private var addAssetDefaultPortfolioId: String?
    @State private var editingAsset: Asset?
    @State private var txAsset: Asset?
    @State private var priceAsset: Asset?
    @State private var chartAsset: Asset?
    @State private var reorderingPortfolios = false
    @State private var reorderingAssetsIn: Portfolio?
    @State private var deleteAssetTarget: Asset?
    @State private var deletePortfolioTarget: Portfolio?
    @State private var blockedDeletePortfolio: Portfolio?
    @State private var errorMessage: String?
    @State private var priceHistoryCache: [String: [ChartDatapoint]] = [:]

    private var language: Language { prefs.language }
    private var theme: Theme { Theme.palette(ThemeID(rawValue: prefs.themeID) ?? .sunset) }
    private var fx: Double { store.summary?.fx ?? 35.84 }
    private var converter: CurrencyConverter { CurrencyConverter(fx: fx) }

    private var sortedPortfolios: [Portfolio] {
        store.portfolios.sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
    }

    public var body: some View {
        withDialogs
    }

    private var listContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                header
                if store.portfolios.isEmpty {
                    Text(prefs.t("portfolios.noPorts"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                } else {
                    ForEach(sortedPortfolios) { portfolio in
                        card(for: portfolio)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(prefs.t("portfolios.title"))
        .task { await refreshIfNeeded() }
    }

    private var withForms: some View {
        listContent
            .sheet(isPresented: $showCreatePortfolio) {
                PortfolioFormSheet(store: store, prefs: prefs) { showCreatePortfolio = false }
            }
            .sheet(item: $editingPortfolio) { portfolio in
                PortfolioFormSheet(store: store, prefs: prefs, editing: portfolio) { editingPortfolio = nil }
            }
            .sheet(isPresented: $showAddAsset) {
                AssetFormSheet(store: store, prefs: prefs, defaultPortfolioId: addAssetDefaultPortfolioId) { _ in showAddAsset = false }
            }
            .sheet(item: $editingAsset) { asset in
                AssetFormSheet(store: store, prefs: prefs, editing: asset) { _ in editingAsset = nil }
            }
            .sheet(item: $txAsset) { asset in
                TransactionFormSheet(store: store, prefs: prefs, defaultAssetId: asset.id, onDone: { txAsset = nil })
            }
            .sheet(item: $priceAsset) { asset in
                PriceFormSheet(store: store, prefs: prefs, asset: asset) { priceAsset = nil }
            }
            .sheet(item: $chartAsset) { asset in
                PriceHistoryModal(asset: asset, theme: theme, language: language, api: api,
                                   cache: $priceHistoryCache)
            }
            .sheet(isPresented: $reorderingPortfolios) {
                ReorderPortfoliosSheet(store: store, theme: theme, language: language)
            }
            .sheet(item: $reorderingAssetsIn) { portfolio in
                ReorderAssetsSheet(store: store, portfolio: portfolio, theme: theme, language: language)
            }
    }

    private var deleteAssetTitle: String {
        deleteAssetTarget.map {
            language == .th
                ? "ลบสินทรัพย์ \"\($0.symbol)\" และธุรกรรมทั้งหมด?"
                : "Delete asset \"\($0.symbol)\" and all its transactions?"
        } ?? ""
    }

    private var withDialogs: some View {
        withForms
            .confirmationDialog(
                deleteAssetTitle,
                isPresented: Binding(get: { deleteAssetTarget != nil }, set: { if !$0 { deleteAssetTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button(language == .th ? "ลบ" : "Delete", role: .destructive) {
                    if let a = deleteAssetTarget { Task { await deleteAsset(a) } }
                    deleteAssetTarget = nil
                }
                Button(language == .th ? "ยกเลิก" : "Cancel", role: .cancel) { deleteAssetTarget = nil }
            }
            .confirmationDialog(
                prefs.t("portfolios.confirmDelete"),
                isPresented: Binding(get: { deletePortfolioTarget != nil }, set: { if !$0 { deletePortfolioTarget = nil } }),
                titleVisibility: .visible
            ) {
                Button(language == .th ? "ลบ" : "Delete", role: .destructive) {
                    if let p = deletePortfolioTarget { Task { await deletePortfolio(p) } }
                    deletePortfolioTarget = nil
                }
                Button(language == .th ? "ยกเลิก" : "Cancel", role: .cancel) { deletePortfolioTarget = nil }
            }
            .alert(
                language == .th ? "ไม่สามารถลบพอร์ตได้" : "Cannot delete portfolio",
                isPresented: Binding(get: { blockedDeletePortfolio != nil }, set: { if !$0 { blockedDeletePortfolio = nil } })
            ) {
                Button("OK") { blockedDeletePortfolio = nil }
            } message: {
                Text(language == .th
                     ? "ไม่สามารถลบพอร์ตได้เนื่องจากยังมีสินทรัพย์เหลืออยู่ภายในพอร์ต กรุณาลบสินทรัพย์ทั้งหมดก่อน"
                     : "Cannot delete portfolio because it still contains assets. Please delete all assets first.")
            }
            .alert(prefs.t("common.error"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
    }

    private var header: some View {
        HStack {
            Text(prefs.t("portfolios.title")).font(.title2.bold())
            Spacer()
            if store.portfolios.count > 1 {
                Button {
                    reorderingPortfolios = true
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            Button(prefs.t("portfolios.addAssetBtn")) {
                addAssetDefaultPortfolioId = nil
                showAddAsset = true
            }
            .buttonStyle(.bordered)
            Button(prefs.t("portfolios.createBtn")) { showCreatePortfolio = true }
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func card(for portfolio: Portfolio) -> some View {
        let section: PortfolioSection = PortfolioMath.section(for: portfolio, assets: store.assets, fx: fx)
        PortfolioCardView(
            section: section,
            theme: theme,
            language: language,
            displayCurrency: prefs.displayCurrency,
            converter: converter,
            onAddAsset: {
                addAssetDefaultPortfolioId = portfolio.id
                showAddAsset = true
            },
            onEditPortfolio: { editingPortfolio = portfolio },
            onDeletePortfolio: { requestDeletePortfolio(portfolio) },
            onReorderAssets: { reorderingAssetsIn = portfolio },
            onBuySell: { txAsset = $0 },
            onChart: { chartAsset = $0 },
            onNav: { priceAsset = $0 },
            onEditAsset: { editingAsset = $0 },
            onDeleteAsset: { deleteAssetTarget = $0 }
        )
    }

    private func refreshIfNeeded() async {
        if store.portfolios.isEmpty { try? await store.fetchPortfolios() }
        if store.assets.isEmpty { try? await store.fetchAssets() }
    }

    private func requestDeletePortfolio(_ portfolio: Portfolio) {
        let hasAssets = store.assets.contains { $0.portfolioId == portfolio.id }
        if hasAssets {
            blockedDeletePortfolio = portfolio
        } else {
            deletePortfolioTarget = portfolio
        }
    }

    private func deletePortfolio(_ portfolio: Portfolio) async {
        do { try await store.deletePortfolio(portfolio.id) }
        catch { errorMessage = (error as? APIError)?.displayMessage ?? prefs.t("common.error") }
    }

    private func deleteAsset(_ asset: Asset) async {
        do { try await store.deleteAsset(asset.id) }
        catch { errorMessage = (error as? APIError)?.displayMessage ?? prefs.t("common.error") }
    }
}
