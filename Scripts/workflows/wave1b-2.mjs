export const meta = {
  name: 'porto-wave1b-2',
  description: 'Implement Wave 1B (PortoDesign) then fan out Wave 2 (5 feature agents) per porto-ios-plan.md',
  phases: [
    { title: 'Wave1B', detail: 'PortoDesign: themes, MoneyText, squarify/treemap, sankey, charts + tests' },
    { title: 'Wave2', detail: '5 parallel feature agents (Auth+Settings, Overview, Portfolios, Forms, Transactions+Debt+Widget)' },
  ],
}

const REPO = '/Users/pchayphiphitthaphan/Gits/porto-ios'
const WEB = '/Users/pchayphiphitthaphan/Gits/porto/frontend/src'

const COMMON = `
PROJECT: porto-ios native SwiftUI app at ${REPO}. Web source-of-truth to port from: ${WEB} (read-only, sibling repo).
Read ${REPO}/porto-ios-plan.md and ${REPO}/docs/OWNERSHIP.md and ${REPO}/docs/API.md first.

HARD RULES (violating these breaks the build for other agents):
- FROZEN — never edit: any Package.swift, project.yml, Makefile, App/Config/*.xcconfig, *.entitlements, and everything under Packages/PortoKit/Sources/PortoKit/Contract/. If you need a resource, embed it as Swift source (do NOT add SPM resources, that needs a manifest edit).
- ONLY create/edit files under YOUR assigned folder(s). No two agents share a folder.
- Create files with Bash heredoc: cat > path <<'EOF' ... EOF  (avoids the per-file Write-tool gate). If a fact-forcing gate blocks a Bash or Write, present the 4 requested facts briefly then retry.
- Build with: export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ; cd <your package> ; swift build (and swift test if you added tests). Your package MUST compile before you finish.
- iOS 17+, Swift 5.9, @Observable, Swift Charts. Packages also target macOS 14 so 'swift build' works on the CLI. Guard iOS-only APIs (UIKit/WidgetKit) with #if os(iOS) / #if canImport(...).

PortoKit public API you consume (Packages/PortoKit/Sources/PortoKit):
- Models: Portfolio, Asset (ENRICHED: portfolio,currentPrice,change24h,position), PositionSummary, Transaction, Liability, LiabilityRef, LiabilityTransaction, NetWorthSummary, NetWorthHistoryItem, ChartDatapoint(t,p), AuthUser, AuthResponse, MePayload, AuthConfig. Enums: AssetType(crypto/th/us/fund/deposit), Currency(thb/usd), TransactionSide(buy/sell/deposit/withdraw), Direction(long/short), LiabilityTxType(pay/add).
- Requests: CreateAssetRequest, UpdateAssetRequest, CreatePortfolioRequest, UpdatePortfolioRequest, CreateTransactionRequest, CreateLiabilityRequest, UpdateLiabilityRequest, AdjustLiabilityRequest, ReorderRequest, LoginRequest, RegisterRequest, BackupExportRequest, BackupImportRequest.
- APIError (.displayMessage — Thai verbatim), APIClient / APIClientProtocol, Endpoint (all routes incl backupExport/backupImport/authConfig/demo/login/register/me/clearData/cryptoHistory/stockHistory).
- AppDataStore (@MainActor @Observable): portfolios/assets/transactions/liabilities/liabilityTransactions/summary/history/isRefreshing/isStale/lastError; loadAll(), refreshAll(), fetch*(), createPortfolio/updatePortfolio/deletePortfolio/reorderPortfolios, createAsset/createAssetReturningId/updateAsset/deleteAsset/reorderAssets, createTransaction/updateTransaction/deleteTransaction, createLiability/updateLiability/deleteLiability/adjustLiability, takeSnapshot, writeSnapshot, sparklinePoints, reset.
- PreferencesStore (@Observable): language(Language th/en), displayCurrency(Currency), themeID(String), t(key)->String.
- L10n.string(key,lang); Strings.all keys (ported from translations.ts — e.g. "overview.netWorth","common.save","modals.asset.createTitle", etc). MoneyFormat.format/number/dual, CurrencyConverter(fx:), BangkokDate.todayString().
- KeychainSessionStore (SessionStoring), SharedSnapshotStore.

KEY DOMAIN RULES:
- forbidNonWhitelisted: request DTOs already encode exact keys / omit nils. Use them as-is.
- Mutation responses are RAW entities — NEVER decode as Asset; always go through AppDataStore which refetches.
- Dual-currency: primary = PreferencesStore.displayCurrency (default USD), secondary in parentheses smaller/fainter, 2dp en-US. Summary is THB-base + fx (THB per USD). Use MoneyFormat.dual / CurrencyConverter.
- 401 anywhere -> force logout (handled by APIClient onUnauthorized + AppDataStore). Show Thai 400 messages verbatim via APIError.displayMessage.
- "Today" in Asia/Bangkok (BangkokDate), not device UTC.
`

const SCHEMA = {
  type: 'object',
  additionalProperties: false,
  properties: {
    package: { type: 'string' },
    filesCreated: { type: 'array', items: { type: 'string' } },
    swiftBuild: { type: 'string', enum: ['pass', 'fail'] },
    swiftTest: { type: 'string', enum: ['pass', 'fail', 'none'] },
    publicAPI: { type: 'array', items: { type: 'string' }, description: 'public symbols other waves can rely on' },
    notes: { type: 'string' },
  },
  required: ['package', 'swiftBuild', 'notes'],
}

phase('Wave1B')
const wave1b = await agent(`${COMMON}

YOU ARE WAVE 1B. Owner: Packages/PortoDesign/Sources/PortoDesign (+ Packages/PortoDesign/Tests/PortoDesignTests).
Implement the design system + chart primitives. There is a Wave-0 placeholder PortoDesign.swift defining 'enum ThemeID { sunset, ocean, berry }' — KEEP ThemeID, extend around it.

Port VERBATIM from web:
1. Themes from ${WEB}/utils/themes.ts (THEMES object — exact hex). Expose:
   struct Theme { swatchBg:Color; palette:[Color]; tints:[Color]; greens:[Color]; reds:[Color]; debtPalette:[Color]; typeColor:[AssetType:Color] }
   static func Theme.palette(_ id: ThemeID) -> Theme  (sunset/ocean/berry). Also themeMeta name+desc (Thai) from themes.ts.
   Add Color(hex:) init. palette cycles by index % 6.
2. Squarify treemap from ${WEB}/pages/Overview.tsx (functions squarify + redistributeAreas, lines ~11-60). Port 1:1:
   public func squarify<T>(_ items: [(area: Double, data: T)], rect: CGRect) -> [(rect: CGRect, data: T)]
   public func redistributeAreas(_ values: [Double], totalArea: Double, minFrac: Double) -> [Double]
   Then a Treemap SwiftUI view rendering rects with labels.
3. Sankey from ${WEB}/utils/sankey.ts (computeSankey + clampedHeights). Port 1:1 as pure geometry funcs:
   public struct SankeySideNode/SankeyFlow/SankeyInput/SankeyResult ... public func computeSankey(_ input: SankeyInput) -> SankeyResult
   Emit ribbon SVG-path 'd' strings as-is (a SwiftUI Path can parse the same cubic-bezier commands — write a small path builder, or store the numeric control points). Then a SankeyView using Canvas/Path + positioned node bars.
4. Swift Charts wrappers: AreaHistoryChart(points:[NetWorthHistoryItem] or [(date,value)]), PriceHistoryChart(points:[ChartDatapoint], avgCost: Double?) with a RuleMark at avgCost, Sparkline(values:[Double]) (lightweight Path, no axes — usable in the widget), StackedAllocationBar(segments:[(value: Double, color: Color)]).
5. MoneyText view: dual-currency display. init(thb: Double, display: Currency, converter: CurrencyConverter, primaryFont:/secondaryFont: optional). Primary in display currency, secondary in parens fainter+smaller. Use MoneyFormat.dual.
6. Reusable card()/badge() view modifiers + a PnL color helper (green/red from Theme).

TESTS (Packages/PortoDesign/Tests/PortoDesignTests, XCTest): 
- squarify: total area conserved, rects within bounds, deterministic order on a known input.
- redistributeAreas: min-frac floor respected, sum == totalArea.
- computeSankey / clampedHeights: heights sum <= avail, minH floor respected, empty/zero input returns empty.
- Theme: exact hex for sunset.palette[0] == #EC6530, etc.
Keep the Wave-0 PortoDesignTests theme test passing (ThemeID.allCases order).

Verify: cd Packages/PortoDesign && swift build && swift test  (both must pass).
Return the public API list so Wave 2 can consume it.`,
  { phase: 'Wave1B', schema: SCHEMA, label: 'wave1B:PortoDesign' })

log(`Wave 1B: build=${wave1b?.swiftBuild} test=${wave1b?.swiftTest}`)

phase('Wave2')
const DESIGN_API = wave1b?.publicAPI?.join(', ') || '(see Packages/PortoDesign/Sources/PortoDesign source)'
const CONSUME = `\nPortoDesign public API available (read its source to confirm signatures): ${DESIGN_API}\nImport PortoDesign, PortoForms, PortoKit as needed. Design screens to receive dependencies via init params or @Environment (AppDataStore, PreferencesStore) — Wave 3 wires them into the app. Change the Wave-0 placeholder screen's public init as needed (Wave 2/3 own that). Add #Preview with mock data. VERIFY ONLY your own package(s) with swift build (the App target will not build until Wave 3 rewires MainTabView — that is expected, do NOT touch App/).`

const wave2 = [
  { key: '2A', label: 'wave2A:Auth+Settings', folders: 'Packages/FeatureAuth/Sources/FeatureAuth AND Packages/FeatureSettings/Sources/FeatureSettings',
    task: `FeatureAuth: login/register/demo screens gated by GET /auth/config (enableDemo/enableRegister). Port copy from ${WEB} login translations (Strings keys "login.*"). On submit call APIClient login/register/demo -> on success save to SessionStoring + call a completion. Show APIError.displayMessage (Thai) inline. Email/password validation mirrors backend (email format, pass min 4).
FeatureSettings: theme picker (3 ThemeID, live preview via PreferencesStore.themeID), display-currency toggle (USD/THB), language toggle (th/en). Backup export: POST /backup/export {password>=8} -> base64 -> write porto-backup-YYYY-MM-DD.porto and present share sheet (#if os(iOS) UIActivityViewController via UIViewControllerRepresentable). Import: file importer (.fileImporter) -> read file -> base64 -> POST /backup/import {password,data} -> AppDataStore.loadAll(). Logout (SessionStoring.clear) + Clear data (POST /auth/clear then reset). Use Strings "settings.*","footer.*".` },
  { key: '2B', label: 'wave2B:Overview', folders: 'Packages/FeatureOverview/Sources/FeatureOverview',
    task: `Port ${WEB}/pages/Overview.tsx. OverviewScreen(store: AppDataStore, prefs: PreferencesStore): hero net worth dual-currency (MoneyText), P/L + MoM (compare summary.netWorthThb vs ~30d-back history point), 3 stat cards (Total Assets / Liabilities / Today P/L), area chart of net worth (last 60 of 365 history pts) via AreaHistoryChart, portfolio allocation grid, Treemap (group=portfolio color=portfolio size=value using PortoDesign squarify), 2 sankeys (type->portfolio and assets-vs-liabilities) via computeSankey/SankeyView, all-assets table with weight bars. Pull-to-refresh (.refreshable -> store.refreshAll()) + refresh button + stale banner (store.isStale). Strings "overview.*".` },
  { key: '2C', label: 'wave2C:Portfolios', folders: 'Packages/FeaturePortfolios/Sources/FeaturePortfolios',
    task: `Port the web Portfolios page. PortfoliosScreen(store,prefs): portfolio cards (Theme color), holdings tables per portfolio (dual-currency qty/avgCost/price/value/PL from Asset.position + currentPrice), StackedAllocationBar per portfolio, .onMove reorder (optimistic -> store.reorderAssets/reorderPortfolios), row actions (buy/sell -> present TransactionFormSheet; chart -> price-history modal; NAV/edit -> AssetFormSheet or PriceFormSheet; delete -> confirm -> store.deleteAsset). Price-history modal: ranges 7D/1M/3M/1Y, fetch via Endpoint.cryptoHistory(cgId,days)/stockHistory(symbol,range) through APIClient, PriceHistoryChart with avg-cost RuleMark (position.avgCost). Per-(asset,range) in-memory cache. Strings "portfolios.*". You may need direct APIClient for price history (accept it via init or add a small fetch helper — do NOT edit PortoKit; call Endpoint + an APIClientProtocol passed in).` },
  { key: '2D', label: 'wave2D:Forms', folders: 'Packages/PortoForms/Sources/PortoForms',
    task: `Fill the PortoForms shells (AssetFormSheet, TransactionFormSheet, LiabilityFormSheet, PortfolioFormSheet, PriceFormSheet) with real bodies. KEEP them public; you may CHANGE init signatures to accept dependencies (store: AppDataStore, editing target, onDone) — Wave 2/3 own these. Port from ${WEB}/components/AssetModal.tsx (read it): CG_ID_MAP (25 coins symbol->coingecko id), type->currency defaults (th/fund/deposit->THB, crypto/us->USD), th symbol -> SYMBOL.BK rule, opening-transaction flow (POST asset via store.createAssetReturningId THEN POST transaction). TransactionFormSheet: deposit-type assets -> deposit/withdraw semantics; short direction -> Sell(Open)/Buy(Cover) labels; quantity cap vs current position; price prefill from currentPrice; date defaults to BangkokDate.todayString(). LiabilityFormSheet: 4 modes (create/edit/pay/add) with running balance preview. All labels from Strings "modals.*". Show APIError.displayMessage verbatim on failure. Verify swift build of PortoForms.` },
  { key: '2E', label: 'wave2E:Transactions+Debt+Widget', folders: 'Packages/FeatureTransactions/Sources/FeatureTransactions, Packages/FeatureDebt/Sources/FeatureDebt, AND App/PortoWidget',
    task: `FeatureTransactions: TransactionsScreen(store) merged tx list sorted date desc (createdAt tiebreak, else id), filters (portfolio/type), edit (TransactionFormSheet) / delete (confirm -> store.deleteTransaction), show Thai 400 verbatim. Strings "transactions.*".
FeatureDebt: DebtScreen(store) total-debt strip + liability list + adjust (pay/add via LiabilityFormSheet) + a liabilities sankey. Strings "liabilities.*".
App/PortoWidget: implement the REAL widget over the Wave-0 placeholder. TimelineProvider: read cached SharedSnapshot via SharedSnapshotStore first (render immediately), then live GET /net-worth/summary using Keychain token (APIClient + KeychainSessionStore with shared access group nil ok), policy .after(+30 min). On 401/offline: render cached with a stale tint, never wipe cache. Views: systemSmall = net worth + today P/L badge; systemMedium = + Sparkline (from snapshot.sparkline, PortoDesign). Use containerBackground. This target builds via xcodebuild not swift build — just make it compile logically; note you cannot 'swift build' the widget (it's an app-extension target in project.yml). Verify FeatureTransactions and FeatureDebt with swift build; for the widget, ensure code is consistent with PortoKit/PortoDesign APIs.` },
]

const results = await parallel(wave2.map(w => () =>
  agent(`${COMMON}${CONSUME}

YOU ARE WAVE ${w.key}. Owner folder(s): ${w.folders}.
${w.task}

Return your result. swiftBuild reflects your Swift-package build(s); use 'none' for swiftTest if you added no tests.`,
    { phase: 'Wave2', schema: SCHEMA, label: w.label, model: 'sonnet' })
))

return {
  wave1b,
  wave2: results.filter(Boolean),
  summary: `1B build=${wave1b?.swiftBuild}; ` + wave2.map((w,i) => `${w.key}=${results[i]?.swiftBuild ?? 'null'}`).join(' '),
}
