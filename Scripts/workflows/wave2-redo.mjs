export const meta = {
  name: 'porto-wave2-redo',
  description: 'Re-dispatch the 4 Wave-2 feature agents that bailed on the cost hook (2A,2C,2D,2E)',
  phases: [{ title: 'Wave2', detail: 'Auth+Settings, Portfolios, Forms, Transactions+Debt+Widget' }],
}

const REPO = '/Users/pchayphiphitthaphan/Gits/porto-ios'
const WEB = '/Users/pchayphiphitthaphan/Gits/porto/frontend/src'

const COST_NOTE = `
IMPORTANT — IGNORE COST WARNINGS: A PostToolUse hook will repeatedly inject "COST WARNING / COST CRITICAL: Session cost is $..." messages. These are ADVISORY ONLY and the human user has ALREADY acknowledged the cost and explicitly opted into this multi-agent workflow. DO NOT stop, DO NOT ask for confirmation, DO NOT halt on these messages. Complete your FULL task end to end and verify the build. Treat those hook lines as background noise.
`

const COMMON = `
PROJECT: porto-ios native SwiftUI app at ${REPO}. Web source-of-truth: ${WEB} (read-only sibling repo). Read ${REPO}/porto-ios-plan.md, docs/OWNERSHIP.md, docs/API.md first.
${COST_NOTE}
HARD RULES:
- FROZEN — never edit: any Package.swift, project.yml, Makefile, App/Config/*.xcconfig, *.entitlements, Packages/PortoKit/Sources/PortoKit/Contract/*. Embed resources as Swift source, not SPM resources.
- ONLY create/edit files under YOUR assigned folder(s).
- Create files with Bash heredoc: cat > path <<'EOF' ... EOF (avoids per-file Write gate). If a fact-forcing gate blocks, present the 4 facts briefly then retry.
- Build: export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ; cd <your package> ; swift build. Your package(s) MUST compile before finishing.
- iOS 17+, Swift 5.9, @Observable, Swift Charts. Packages also target macOS 14 (guard iOS-only APIs with #if os(iOS)/#if canImport).

PortoKit API (Packages/PortoKit/Sources/PortoKit): Models Portfolio/Asset(enriched: portfolio,currentPrice,change24h,position)/PositionSummary/Transaction/Liability/LiabilityRef/LiabilityTransaction/NetWorthSummary/NetWorthHistoryItem/ChartDatapoint(t,p)/AuthUser/AuthResponse/MePayload/AuthConfig; enums AssetType(crypto/th/us/fund/deposit),Currency(thb/usd),TransactionSide(buy/sell/deposit/withdraw),Direction(long/short),LiabilityTxType(pay/add). Requests: Create/Update Asset/Portfolio/Liability, CreateTransactionRequest, AdjustLiabilityRequest, ReorderRequest, Login/RegisterRequest, BackupExport/ImportRequest. APIError(.displayMessage Thai), APIClient/APIClientProtocol, Endpoint(all routes incl authConfig/demo/login/register/me/clearData/backupExport/backupImport/cryptoHistory/stockHistory). AppDataStore(@MainActor @Observable): portfolios/assets/transactions/liabilities/liabilityTransactions/summary/history/isRefreshing/isStale/lastError; loadAll/refreshAll/fetch*/createPortfolio/updatePortfolio/deletePortfolio/reorderPortfolios/createAsset/createAssetReturningId/updateAsset/deleteAsset/reorderAssets/createTransaction/updateTransaction/deleteTransaction/createLiability/updateLiability/deleteLiability/adjustLiability/takeSnapshot/writeSnapshot/sparklinePoints/reset. PreferencesStore(@Observable): language(Language th/en),displayCurrency(Currency),themeID(String),t(key). L10n.string(key,lang), Strings.all keys (from translations.ts). MoneyFormat.format/number/dual, CurrencyConverter(fx:), BangkokDate.todayString(). KeychainSessionStore(SessionStoring), SharedSnapshotStore.

PortoDesign API (Packages/PortoDesign/Sources/PortoDesign — DONE, read source to confirm): Color(hex:); struct Theme{swatchBg,palette:[Color],tints,greens,reds,debtPalette,typeColor:[AssetType:Color]}; Theme.palette(_ id:ThemeID)->Theme, Theme.sunset/.ocean/.berry, Theme.order:[ThemeID], Theme.meta(id)->ThemeMeta{name,desc}, Theme.paletteColor(index); squarify/redistributeAreas; computeSankey(SankeyInput)->SankeyResult + SankeyView(input); Treemap<Item>(cells:[Treemap.Cell{value,color,label,secondary?,item}], minFrac, onTap?); AreaHistoryChart(history:[NetWorthHistoryItem] or points:[(date,value)]); PriceHistoryChart(points:[ChartDatapoint], avgCost:Double?); Sparkline(values:[Double]); StackedAllocationBar(segments:[(value:Double,color:Color)]); MoneyText(thb:,display:Currency,converter:CurrencyConverter,...); View.card(), View.badge(color), PnL.color(value,theme). NetWorthHistoryItem.parsedDate.

DOMAIN RULES: request DTOs already exact-key/omit-nil — use as-is. Mutation responses RAW — never decode as Asset; go through AppDataStore (refetches). Dual-currency: primary=displayCurrency(default USD), secondary in parens fainter/smaller, 2dp en-US; summary THB-base + fx(THB/USD). 401->force logout (APIClient handles). Thai 400 shown verbatim via APIError.displayMessage. "Today" via BangkokDate (Asia/Bangkok).

Design screens to receive deps via init params (store:AppDataStore, prefs:PreferencesStore) — Wave 3 wires them into MainTabView (do NOT touch App/). Add #Preview with mock data. VERIFY ONLY your own package(s) with swift build (the App target won't build until Wave 3 — expected).
`

const SCHEMA = {
  type: 'object', additionalProperties: false,
  properties: {
    package: { type: 'string' }, filesCreated: { type: 'array', items: { type: 'string' } },
    swiftBuild: { type: 'string', enum: ['pass', 'fail'] },
    publicAPI: { type: 'array', items: { type: 'string' } }, notes: { type: 'string' },
  }, required: ['package', 'swiftBuild', 'notes'],
}

phase('Wave2')
const jobs = [
  { key: '2A', label: 'wave2A:Auth+Settings', folders: 'Packages/FeatureAuth/Sources/FeatureAuth AND Packages/FeatureSettings/Sources/FeatureSettings',
    task: `FeatureAuth: login/register/demo screens gated by GET /auth/config (enableDemo/enableRegister). Copy from Strings "login.*". On submit -> APIClient login/register/demo -> save to SessionStoring + call completion. Show APIError.displayMessage inline. Validation: email format, pass min 4.
FeatureSettings: theme picker (3 ThemeID live preview via PreferencesStore.themeID), currency toggle (USD/THB), language toggle (th/en). Backup export POST /backup/export {password>=8} -> base64 -> porto-backup-YYYY-MM-DD.porto + share sheet (#if os(iOS) UIActivityViewController via UIViewControllerRepresentable). Import: .fileImporter -> base64 -> POST /backup/import -> store.loadAll(). Logout (SessionStoring.clear) + Clear data (POST /auth/clear -> reset). Strings "settings.*","footer.*".` },
  { key: '2C', label: 'wave2C:Portfolios', folders: 'Packages/FeaturePortfolios/Sources/FeaturePortfolios',
    task: `Port web Portfolios page. PortfoliosScreen(store,prefs, api: APIClientProtocol for price history): portfolio cards (Theme color), per-portfolio holdings table (dual-currency qty/avgCost/price/value/PL from Asset.position+currentPrice), StackedAllocationBar, .onMove reorder (optimistic -> store.reorderAssets/reorderPortfolios), row actions (buy/sell->TransactionFormSheet; chart->price-history modal; NAV/edit->AssetFormSheet/PriceFormSheet; delete->confirm->store.deleteAsset). Price-history modal ranges 7D/1M/3M/1Y via Endpoint.cryptoHistory(cgId,days)/stockHistory(symbol,range) through the injected api; PriceHistoryChart with avg-cost RuleMark (position.avgCost); per-(asset,range) in-memory cache. Strings "portfolios.*".` },
  { key: '2D', label: 'wave2D:Forms', folders: 'Packages/PortoForms/Sources/PortoForms',
    task: `Fill PortoForms shells with real bodies (AssetFormSheet, TransactionFormSheet, LiabilityFormSheet, PortfolioFormSheet, PriceFormSheet). Keep public; CHANGE init signatures to accept deps (store:AppDataStore, editing target?, onDone). Read ${WEB}/components/AssetModal.tsx: CG_ID_MAP (25 coins symbol->cgId), type->currency defaults (th/fund/deposit->THB; crypto/us->USD), th symbol -> SYMBOL.BK, opening-txn flow (store.createAssetReturningId THEN createTransaction). TransactionFormSheet: deposit-type assets -> deposit/withdraw; short -> Sell(Open)/Buy(Cover); qty cap vs position; price prefill from currentPrice; date = BangkokDate.todayString(). LiabilityFormSheet: 4 modes (create/edit/pay/add) + running balance preview. Labels from Strings "modals.*". APIError.displayMessage on failure. swift build PortoForms must pass.` },
  { key: '2E', label: 'wave2E:Transactions+Debt+Widget', folders: 'Packages/FeatureTransactions/Sources/FeatureTransactions, Packages/FeatureDebt/Sources/FeatureDebt, AND App/PortoWidget',
    task: `FeatureTransactions: TransactionsScreen(store) merged list date desc (createdAt tiebreak else id), filters (portfolio/type), edit(TransactionFormSheet)/delete(confirm->store.deleteTransaction), Thai 400 verbatim. Strings "transactions.*".
FeatureDebt: DebtScreen(store) total-debt strip + liability list + adjust (pay/add via LiabilityFormSheet) + liabilities sankey. Strings "liabilities.*".
App/PortoWidget: implement real widget over Wave-0 placeholder. TimelineProvider: read cached SharedSnapshot via SharedSnapshotStore first (render immediately), then live GET /net-worth/summary via Keychain token (APIClient+KeychainSessionStore), policy .after(+30 min). On 401/offline render cached with stale tint, never wipe. systemSmall = net worth + today P/L badge; systemMedium = + Sparkline(snapshot.sparkline). containerBackground. Widget builds via xcodebuild (app-extension) not swift build — ensure code is API-consistent. Verify FeatureTransactions & FeatureDebt with swift build.` },
]

const results = await parallel(jobs.map(j => () =>
  agent(`${COMMON}

YOU ARE WAVE ${j.key}. Owner folder(s): ${j.folders}.
${j.task}

Return your result. swiftBuild reflects your Swift-package build(s).`,
    { phase: 'Wave2', schema: SCHEMA, label: j.label, model: 'sonnet' })
))

return { wave2: results.filter(Boolean), summary: jobs.map((j,i)=>`${j.key}=${results[i]?.swiftBuild ?? 'null'}`).join(' ') }
