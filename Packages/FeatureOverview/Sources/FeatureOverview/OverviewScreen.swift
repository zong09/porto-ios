import SwiftUI
import PortoKit
import PortoDesign
import PortoForms

/// Ported from `porto/frontend/src/pages/Overview.tsx`.
/// Hero net worth, P/L + MoM badges, 3 stat cards, net-worth area chart,
/// portfolio allocation grid, treemap, 2 sankeys, all-assets table.
public struct OverviewScreen: View {
    private let store: AppDataStore
    private let prefs: PreferencesStore

    public init(store: AppDataStore, prefs: PreferencesStore) {
        self.store = store
        self.prefs = prefs
    }

    private var theme: Theme { Theme.palette(ThemeID(rawValue: prefs.themeID) ?? .default) }
    private var fx: Double { store.summary?.fx ?? 35.84 }
    private var converter: CurrencyConverter { CurrencyConverter(fx: fx) }
    private var display: Currency { prefs.displayCurrency }
    private func t(_ key: String) -> String { prefs.t(key) }

    private var hasAssets: Bool { store.assets.contains { ($0.position?.quantity ?? 0) > 0 } }

    // MARK: - Derived stats

    private var totalAssets: Double { store.summary?.totalAssetsThb ?? 0 }
    private var totalLiabilities: Double { store.summary?.totalLiabilitiesThb ?? 0 }
    private var netWorth: Double { store.summary?.netWorthThb ?? 0 }
    private var todayPl: Double { store.summary?.todayPlThb ?? 0 }
    private var totalCost: Double { store.summary?.totalCostThb ?? 0 }
    private var totalPl: Double { totalAssets - totalCost }
    private var totalPlPct: Double { totalCost > 0 ? (totalPl / totalCost) * 100 : 0 }

    private struct MoM { var label: String; var up: Bool; var pct: Double }
    private var mom: MoM {
        let historyData = store.history
        guard historyData.count >= 2 else { return MoM(label: "—", up: true, pct: 0) }
        let cutoff = BangkokDate.todayString(now: Date(timeIntervalSinceNow: -28 * 86400))
        var oldPoint = historyData[0]
        for p in historyData where p.date <= cutoff { oldPoint = p }
        guard oldPoint.netWorthThb > 0 else { return MoM(label: "—", up: true, pct: 0) }
        let pct = ((netWorth - oldPoint.netWorthThb) / oldPoint.netWorthThb) * 100
        let arrow = pct >= 0 ? "\u{25B2} +" : "\u{25BC} -"
        return MoM(label: "\(arrow)\(String(format: "%.1f", abs(pct)))% \(t("overview.monthAbbr"))", up: pct >= 0, pct: pct)
    }

    private var chartPoints: [NetWorthHistoryItem] { Array(store.history.suffix(60)) }

    private struct PortfolioSummary: Identifiable {
        let id: String
        let name: String
        let color: Int
        let valueThb: Double
        let returnPct: Double
        let pctOfTotal: Double
        let desc: String
    }

    private var portfolioSummaries: [PortfolioSummary] {
        let typeLabels: [AssetType: String] = [
            .crypto: t("common.assetTypes.crypto"), .th: t("common.assetTypes.th"),
            .us: t("common.assetTypes.us"), .fund: t("common.assetTypes.fund"),
            .deposit: t("common.assetTypes.deposit"),
        ]
        let items = store.portfolios.map { p -> PortfolioSummary in
            let pAssets = store.assets.filter { $0.portfolioId == p.id }
            var valueThb = 0.0, costThb = 0.0, plThb = 0.0
            var types: [String] = []
            for a in pAssets {
                guard let pos = a.position, pos.quantity > 0 else { continue }
                let multiplier = a.currency == .usd ? fx : 1
                let isShort = (a.direction ?? .long) == .short
                let assetVal = pos.quantity * (a.currentPrice ?? 0) * multiplier
                valueThb += isShort ? -assetVal : assetVal
                let assetCost = pos.quantity * pos.avgCost * multiplier
                costThb += assetCost
                plThb += isShort ? (pos.avgCost - (a.currentPrice ?? 0)) * pos.quantity * multiplier : (assetVal - assetCost)
                if let label = typeLabels[a.type], !types.contains(label) { types.append(label) }
            }
            let returnPct = costThb > 0 ? (plThb / costThb) * 100 : 0
            let pctOfTotal = totalAssets > 0 ? (valueThb / totalAssets) * 100 : 0
            let desc = "\(types.joined(separator: " · ")) · \(pAssets.count) \(t("overview.itemsCount"))"
            return PortfolioSummary(id: p.id, name: p.name, color: p.color, valueThb: valueThb,
                                     returnPct: returnPct, pctOfTotal: pctOfTotal, desc: desc)
        }
        return items.sorted { $0.valueThb > $1.valueThb }
    }

    private struct TreemapItem { let asset: Asset; let valueThb: Double; let portfolioColor: Int }

    private var treemapCells: [Treemap<TreemapItem>.Cell] {
        store.assets.compactMap { a -> Treemap<TreemapItem>.Cell? in
            guard let pos = a.position, pos.quantity > 0 else { return nil }
            let multiplier = a.currency == .usd ? fx : 1
            let val = abs(pos.quantity * (a.currentPrice ?? 0) * multiplier)
            guard val > 0 else { return nil }
            let color = theme.paletteColor(a.portfolio?.color ?? 0)
            return Treemap<TreemapItem>.Cell(value: val, color: color, label: a.symbol,
                                              secondary: MoneyFormat.dual(thb: val, display: display, converter: converter).primary,
                                              item: TreemapItem(asset: a, valueThb: val, portfolioColor: a.portfolio?.color ?? 0))
        }.sorted { $0.value > $1.value }
    }

    /// Sankey: portfolio (left) -> asset type (right). Ported from `Overview.tsx` `typeSankey`.
    private var typeSankey: SankeyInput? {
        let groups = portfolioValueByType()
        guard !groups.isEmpty else { return nil }
        var typeAgg: [AssetType: Double] = [:]
        for g in groups { for (ty, v) in g.byType { typeAgg[ty, default: 0] += v } }
        let typeItems = typeAgg.sorted { $0.value > $1.value }
        guard !typeItems.isEmpty else { return nil }
        let total = groups.reduce(0) { $0 + $1.total }
        let left = groups.map { g in
            SankeySideNode(label: g.name, sub: plainMoney(g.total), color: hex(theme.paletteColor(g.color)), value: g.total)
        }
        let right = typeItems.map { (ty, v) -> SankeySideNode in
            let pct = total > 0 ? String(format: "%.1f", (v / total) * 100) : "0"
            return SankeySideNode(label: assetTypeLabel(ty), sub: "\(plainMoney(v)) · \(pct)%",
                                   color: hex(theme.typeColor[ty] ?? .gray), value: v)
        }
        var flows: [SankeyFlow] = []
        for (li, g) in groups.enumerated() {
            for (ri, (ty, _)) in typeItems.enumerated() {
                if let v = g.byType[ty], v > 0 { flows.append(SankeyFlow(leftIndex: li, rightIndex: ri, value: v)) }
            }
        }
        return SankeyInput(left: left, right: right, flows: flows, SW: 1000, SH: 460, LX: 132, RX: 1000 - 132 - 13)
    }

    /// Liability sankey: each debt (left) -> total debt (right).
    private var liabSankey: SankeyInput? {
        let items = store.liabilities
            .map { (l: $0, amt: $0.currency == .usd ? $0.amount * fx : $0.amount) }
            .filter { $0.amt > 0 }
            .sorted { $0.amt > $1.amt }
        guard !items.isEmpty else { return nil }
        let leftTotal = items.reduce(0) { $0 + $1.amt }
        let left = items.enumerated().map { i, x -> SankeySideNode in
            let pct = String(format: "%.1f", (x.amt / leftTotal) * 100)
            return SankeySideNode(label: x.l.name, sub: "\(plainMoney(x.amt)) · \(pct)%",
                                   color: hex(theme.debtPalette[i % theme.debtPalette.count]), value: x.amt)
        }
        let right = [SankeySideNode(label: prefs.language == .th ? "หนี้สินรวม" : "Total Debt",
                                     sub: plainMoney(leftTotal), color: hex(theme.reds.first ?? .red), value: leftTotal)]
        let flows = left.indices.map { SankeyFlow(leftIndex: $0, rightIndex: 0, value: left[$0].value) }
        return SankeyInput(left: left, right: right, flows: flows, SW: 1000, SH: 420, LX: 150, RX: 1000 - 150 - 13)
    }

    private struct TypeGroup { let name: String; let color: Int; let total: Double; let byType: [AssetType: Double] }
    private func portfolioValueByType() -> [TypeGroup] {
        store.portfolios.compactMap { p -> TypeGroup? in
            var byType: [AssetType: Double] = [:]
            for a in store.assets where a.portfolioId == p.id {
                guard let pos = a.position, pos.quantity > 0 else { continue }
                let multiplier = a.currency == .usd ? fx : 1
                let val = abs(pos.quantity * (a.currentPrice ?? 0) * multiplier)
                byType[a.type, default: 0] += val
            }
            let total = byType.values.reduce(0, +)
            guard total > 0 else { return nil }
            return TypeGroup(name: p.name, color: p.color, total: total, byType: byType)
        }.sorted { $0.total > $1.total }
    }

    private func assetTypeLabel(_ ty: AssetType) -> String {
        switch ty {
        case .crypto: return t("common.assetTypes.crypto")
        case .th: return t("common.assetTypes.th")
        case .us: return t("common.assetTypes.us")
        case .fund: return t("common.assetTypes.fund")
        case .deposit: return t("common.assetTypes.deposit")
        }
    }

    private func plainMoney(_ thb: Double) -> String {
        MoneyFormat.format(display == .thb ? thb : thb / fx, display)
    }

    private func hex(_ color: Color) -> String {
        #if canImport(UIKit)
        let c = UIColor(color)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        #else
        return "#888888"
        #endif
    }

    // MARK: - All assets table

    private struct AssetRow: Identifiable {
        let id: String
        let symbol: String
        let name: String
        let portfolioName: String
        let portfolioColor: Color
        let currentPrice: Double
        let currency: Currency
        let valueThb: Double
        let change24h: Double
        let returnPct: Double
        let weightPct: Double
    }

    private var allAssetsTable: [AssetRow] {
        store.assets.compactMap { a -> AssetRow? in
            guard let pos = a.position, pos.quantity > 0 else { return nil }
            let multiplier = a.currency == .usd ? fx : 1
            let isShort = (a.direction ?? .long) == .short
            let assetVal = pos.quantity * (a.currentPrice ?? 0) * multiplier
            let valueThb = isShort ? -assetVal : assetVal
            let costThb = pos.quantity * pos.avgCost * multiplier
            let plThb = isShort ? (costThb - assetVal) : (valueThb - costThb)
            let returnPct = costThb > 0 ? (plThb / costThb) * 100 : 0
            let weightPct = totalAssets > 0 ? (abs(valueThb) / totalAssets) * 100 : 0
            let portfolio = a.portfolio ?? store.portfolios.first { $0.id == a.portfolioId }
            return AssetRow(id: a.id, symbol: a.symbol, name: a.name, portfolioName: portfolio?.name ?? "—",
                             portfolioColor: theme.paletteColor(portfolio?.color ?? 0), currentPrice: a.currentPrice ?? 0,
                             currency: a.currency, valueThb: valueThb, change24h: a.change24h ?? 0,
                             returnPct: returnPct, weightPct: weightPct)
        }.sorted { abs($0.valueThb) > abs($1.valueThb) }
    }

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if store.isStale { staleBanner }
                hero
                statCards
                if chartPoints.count >= 2 { areaChartCard }
                if hasAssets {
                    portfolioGrid
                    treemapCard
                    if let ts = typeSankey {
                        sankeyCard(title: t("overview.assetOverview"), input: ts, height: 300)
                    }
                    if let ls = liabSankey {
                        sankeyCard(title: t("overview.debtRatio"), input: ls, height: 260)
                    }
                    assetsTable
                } else {
                    emptyState
                }
            }
            .padding(16)
        }
        .refreshable { await store.refreshAll() }
        .overlay(alignment: .topTrailing) {
            Button { Task { await store.refreshAll() } } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isRefreshing ? 360 : 0))
                    .animation(store.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default,
                               value: store.isRefreshing)
            }
            .padding()
        }
    }

    private var staleBanner: some View {
        Label(t("common.loading"), systemImage: "exclamationmark.triangle.fill")
            .font(.caption.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(.orange)
    }

    private var hero: some View {
        VStack(spacing: 6) {
            Text(t("overview.netWorth")).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
            MoneyText(thb: netWorth, display: display, converter: converter,
                      primaryFont: .system(size: 40, weight: .bold), secondaryFont: .callout)
            HStack(spacing: 8) {
                if totalCost > 0 {
                    Text("\(totalPl >= 0 ? "+" : "")\(MoneyFormat.format(display == .thb ? totalPl : totalPl / fx, display)) (\(totalPlPct >= 0 ? "+" : "")\(String(format: "%.1f", totalPlPct))%)")
                        .badge(PnL.color(totalPl, theme: theme))
                }
                Text(mom.label).badge(PnL.color(mom.up ? 1 : -1, theme: theme))
            }
            .font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var statCards: some View {
        HStack(spacing: 12) {
            statCard(t("overview.totalAssets"), MoneyFormat.format(display == .thb ? totalAssets : totalAssets / fx, display), .primary)
            statCard(t("overview.liabilities"), MoneyFormat.format(display == .thb ? totalLiabilities : totalLiabilities / fx, display), theme.reds.first ?? .red)
            statCard(t("overview.todayPl"), MoneyFormat.format(display == .thb ? todayPl : todayPl / fx, display), PnL.color(todayPl, theme: theme))
        }
    }

    private func statCard(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(value).font(.headline).foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var areaChartCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(t("overview.netWorthGrowth")).font(.subheadline.weight(.bold))
                Spacer()
                Text("\(mom.up ? "\u{25B2}" : "\u{25BC}") \(String(format: "%.1f", abs(mom.pct)))%")
                    .font(.caption.weight(.bold)).foregroundStyle(PnL.color(mom.up ? 1 : -1, theme: theme))
            }
            let pts = chartPoints.map { (date: $0.parsedDate, value: display == .thb ? $0.netWorthThb : $0.netWorthThb / ($0.fxRate ?? fx)) }
            AreaHistoryChart(points: pts, lineColor: theme.paletteColor(0))
                .frame(height: 170)
        }
        .card()
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "questionmark.circle").font(.system(size: 32)).foregroundStyle(.secondary)
            Text(t("overview.emptyTitle")).font(.headline)
            Text(t("overview.emptyDesc")).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
        .card()
    }

    private var portfolioGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
            ForEach(portfolioSummaries) { p in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(p.name).font(.subheadline.weight(.bold))
                        Spacer()
                        Text("\(p.returnPct >= 0 ? "+" : "")\(String(format: "%.1f", p.returnPct))%")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(PnL.color(p.returnPct, theme: theme))
                    }
                    Text(MoneyFormat.format(display == .thb ? p.valueThb : p.valueThb / fx, display))
                        .font(.title3.weight(.bold))
                    Text(p.desc).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    StackedAllocationBar(segments: [(value: max(2, p.pctOfTotal), color: theme.paletteColor(p.color))], height: 6)
                    Text("\(String(format: "%.1f", p.pctOfTotal))% \(t("overview.pctOfTotalAssets"))")
                        .font(.system(size: 10, weight: .bold)).foregroundStyle(.secondary)
                }
                .padding(12)
                .background(theme.tints[p.color % theme.tints.count], in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var treemapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t("overview.assetOverview")).font(.subheadline.weight(.bold))
            Text(t("overview.treemapLegend")).font(.caption2).foregroundStyle(.secondary)
            Treemap(cells: treemapCells)
                .frame(height: 380)
        }
        .card()
    }

    private func sankeyCard(title: String, input: SankeyInput, height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.weight(.bold))
            SankeyView(input)
                .frame(height: height)
        }
        .card()
    }

    private var assetsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(t("overview.allAssets")).font(.subheadline.weight(.bold))
                Spacer()
                Text("\(allAssetsTable.count) \(t("overview.itemsCount"))").font(.caption2).foregroundStyle(.secondary)
            }
            ForEach(allAssetsTable) { row in
                VStack(spacing: 4) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(row.symbol).font(.caption.weight(.bold))
                            HStack(spacing: 4) {
                                Circle().fill(row.portfolioColor).frame(width: 6, height: 6)
                                Text(row.portfolioName).font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(MoneyFormat.format(display == .thb ? row.valueThb : row.valueThb / fx, display))
                                .font(.caption.weight(.bold))
                            Text(row.returnPct == 0 ? "—" : "\(row.returnPct >= 0 ? "+" : "")\(String(format: "%.1f", row.returnPct))%")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(row.returnPct == 0 ? .secondary : PnL.color(row.returnPct, theme: theme))
                        }
                    }
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(row.portfolioColor)
                                    .frame(width: geo.size.width * CGFloat(min(100, row.weightPct)) / 100)
                            }
                    }
                    .frame(height: 5)
                }
                .padding(.vertical, 6)
                Divider()
            }
        }
        .card()
    }
}

#Preview {
    let api = PreviewAPIClient()
    let prefs = PreferencesStore(defaults: .init(suiteName: "preview-overview")!)
    let store = AppDataStore(api: api, preferences: prefs)
    return OverviewScreen(store: store, prefs: prefs)
        .task { await store.loadAll() }
}

/// Minimal in-memory API client for previews.
private final class PreviewAPIClient: APIClientProtocol, @unchecked Sendable {
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {}

    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type
    ) async throws -> Response {
        let portfolios = [Portfolio(id: "p1", name: "Crypto Vault", color: 0, sortOrder: 0),
                           Portfolio(id: "p2", name: "US Stocks", color: 1, sortOrder: 1)]
        let assets = [
            Asset(id: "a1", portfolioId: "p1", type: .crypto, symbol: "BTC", name: "Bitcoin", currency: .usd,
                  portfolio: portfolios[0], currentPrice: 65000, change24h: 2.3,
                  position: PositionSummary(quantity: 0.5, avgCost: 40000, totalCost: 20000, realizedPnl: 0, direction: .long)),
            Asset(id: "a2", portfolioId: "p2", type: .us, symbol: "AAPL", name: "Apple Inc.", currency: .usd,
                  portfolio: portfolios[1], currentPrice: 190, change24h: -1.1,
                  position: PositionSummary(quantity: 20, avgCost: 150, totalCost: 3000, realizedPnl: 0, direction: .long)),
        ]
        let summary = NetWorthSummary(totalAssetsThb: 1_500_000, totalLiabilitiesThb: 200_000,
                                       netWorthThb: 1_300_000, todayPlThb: 15_000, totalCostThb: 1_100_000, fx: 35.8)
        let history = (0..<60).map { i in
            NetWorthHistoryItem(id: "h\(i)", date: BangkokDate.string(from: Date(timeIntervalSinceNow: Double(i - 60) * 86400)),
                                 totalAssetsThb: 1_400_000 + Double(i) * 2000, totalLiabilitiesThb: 200_000,
                                 netWorthThb: 1_200_000 + Double(i) * 2000, fxRate: 35.8)
        }
        let liabilities = [Liability(id: "l1", name: "Car Loan", amount: 200_000, currency: .thb)]
        if Response.self == [Portfolio].self { return portfolios as! Response }
        if Response.self == [Asset].self { return assets as! Response }
        if Response.self == NetWorthSummary.self { return summary as! Response }
        if Response.self == [NetWorthHistoryItem].self { return history as! Response }
        if Response.self == [Liability].self { return liabilities as! Response }
        if let data = "[]".data(using: .utf8), let decoded = try? JSONDecoder().decode(Response.self, from: data) {
            return decoded
        }
        throw APIError.transport("preview: unsupported \(Response.self)")
    }
}
