# Porto iOS — Native SwiftUI App (multi-agent parallel plan)

## Context

Porto is a personal portfolio tracker (React SPA + NestJS API on Railway). The user wants a mobile app and — after comparing PWA / Capacitor / RN / Flutter / native — chose **native SwiftUI**, iOS-first, for true native UX plus Apple-only surfaces (home-screen widget showing net worth). The backend API is reused unchanged (runs from the `porto` repo); porto-ios is a new client.

**Locked decisions:** v1 = full app (web parity) + net worth WidgetKit widget · new git repo at `/Users/pchayphiphitthaphan/Gits/porto-ios`, **sibling** to `/Users/pchayphiphitthaphan/Gits/porto` (not nested) · iOS 17+ (`@Observable`, Swift Charts) · plan structured for **multiple agents working in parallel**.

## Architecture decisions

- **XcodeGen + local Swift Packages.** `project.yml` → `xcodegen generate`; the `.xcodeproj` is gitignored. All code lives in local SPM packages (sources auto-globbed by folder) so agents adding files never touch a shared manifest — kills the pbxproj-conflict problem. `project.yml`, all `Package.swift`, entitlements, xcconfigs are written in Wave 0 then **frozen** (only Wave 0/3 agent may edit).
- No third-party deps: `@Observable` stores + async/await URLSession. Swift Charts for area/price charts; treemap (squarify) + sankey ported 1:1 from the web's custom implementations.
- Token in **Keychain** (shared access group with widget). Any 401 → force logout (mirrors web Axios interceptor).
- API base URL via xcconfig: Dev `http://localhost:3002/api`, Prod Railway URL.

## Repo layout

Root `/Users/pchayphiphitthaphan/Gits/porto-ios/`; the web repo (source of truth for ports) is reachable at `../porto/`.

```
porto-ios/
├── project.yml, Makefile (generate/build/test/fixtures), .gitignore
├── docs/ (API.md contract snapshot, OWNERSHIP.md, PARITY-CHECKLIST.md)
├── App/
│   ├── Porto/          # thin app target: PortoApp, RootView (session gate), MainTabView (5 tabs), fonts (Anuphan), entitlements
│   ├── PortoWidget/    # WidgetKit extension: NetWorthWidget (small+medium), TimelineProvider
│   └── Config/         # Shared/Dev/Prod.xcconfig (API_BASE_URL)
└── Packages/
    ├── PortoKit/       # models, APIClient, SessionStore, AppDataStore (invalidation graph), MoneyFormat/CurrencyConverter, SharedSnapshotWriter, TH/EN L10n
    │   └── Sources/PortoKit/Contract/   # WAVE 0, FROZEN: Models, APIClientProtocol, Endpoint, APIError, SessionStoring, SharedSnapshot, AppConfig
    ├── PortoDesign/    # Theme (Sunset/Ocean/Berry from web themes.ts), MoneyText dual-currency, cards/badges, Charts: Squarify, Treemap, SankeyLayout/View, AreaHistoryChart, PriceHistoryChart, Sparkline, StackedAllocationBar
    ├── PortoForms/     # AssetFormSheet (CG_ID_MAP, type→currency defaults, .BK rule, opening txn), TransactionFormSheet (side semantics, qty caps), Portfolio/Liability/PriceFormSheet
    ├── FeatureAuth/ FeatureOverview/ FeaturePortfolios/ FeatureTransactions/ FeatureDebt/ FeatureSettings/
```

Dependency graph: PortoKit ← PortoDesign ← PortoForms ← features. Features never depend on each other; cross-tab actions route via PortoForms sheets or MainTabView callbacks. Widget depends on PortoKit + PortoDesign (Sparkline/Theme) only.

## API contract essentials (full map in docs/API.md at scaffold time)

- JWT Bearer, 7d expiry, **no refresh token** — 401 anywhere → force logout.
- `ValidationPipe forbidNonWhitelisted` — DTOs must encode exact keys only, omit nils.
- Numerics arrive as JSON numbers → `Double`; dates `"YYYY-MM-DD"` strings; error body `{statusCode, message: string|string[], error}` with Thai messages — surface verbatim.
- GET /assets returns **enriched** shape (`portfolio`, `currentPrice`, `change24h`, `position`); POST/PATCH return **raw entity** → never decode mutation responses as Asset; refetch instead.
- `/auth/me` returns `userId`; login/register user object uses `id` — separate DTOs.
- Enums: AssetType `crypto|th|us|fund|deposit`, Currency `THB|USD`, side request `buy|sell|deposit|withdraw` (stored `buy|sell`), direction `long|short`, liability tx `pay|add`, portfolio color Int 0..5.
- Summary is THB-base + `fx` (THB per USD); dual-currency display: primary = display-currency toggle (default USD), secondary in parentheses smaller/fainter, 2dp en-US.

## Invalidation graph (AppDataStore must mirror web useApi.ts)

| Mutation | Refetch |
|---|---|
| portfolio create/update/delete | portfolios (+assets — enriched portfolio name/color) |
| portfolio/asset reorder | optimistic → rollback on error → refetch |
| asset create/delete | assets, summary, transactions |
| asset update | assets, summary |
| transaction create/update/delete | transactions, assets, summary |
| liability create/update/delete | liabilities, summary |
| liability pay/add | liabilities, liabilityTransactions, summary |
| snapshot POST | history |
| backup import | reload everything |
| **refreshAll** (pull-to-refresh / foreground / post-login) | assets+summary parallel → POST /net-worth/snapshot → history → write SharedSnapshot + WidgetCenter.reload |

## Widget design

- App Group `group.co.porto.ios` + shared Keychain access group (`kSecAttrAccessibleAfterFirstUnlock`).
- `SharedSnapshot` JSON in group container: netWorthThb, todayPlThb, totals, fx, 30-pt sparkline, displayCurrency, themeID, updatedAt. App writes after every summary/history refetch → `WidgetCenter.reloadTimelines`.
- TimelineProvider: show cached snapshot immediately, then live GET /net-worth/summary with Keychain token; policy `.after(+30 min)`. On 401/offline: render cached with stale tint — never wipe cache.
- systemSmall = net worth + today P/L badge; systemMedium = + sparkline.

## Wave plan (file ownership — no two agents share a folder)

**Wave 0 — Scaffold (1 agent):** `git init` in `/Users/pchayphiphitthaphan/Gits/porto-ios` (fresh repo, not a subfolder of porto); project.yml, Makefile, all 11 Package.swift, xcconfigs, entitlements, `PortoKit/Contract/*` (all models/protocols — load-bearing), PortoForms public **shells** (init signatures + TODO bodies), placeholder screen per feature package with fixed public signatures, placeholder tabs + widget, docs/, Anuphan fonts, `make fixtures` script (demo login via curl → capture all GET responses as test fixtures; hits the backend at `localhost:3002` — network, unaffected by the repo split). Exit gate: `make generate && make build` green, 5 placeholder tabs run. Then freeze.

**Wave 1 — Foundations (2 agents parallel):**
- 1A `PortoKit/Sources/{API,Session,Store,Formatting,Shared,Localization}` + tests: APIClient (Bearer, 401→forceLogout, string|string[] error decode), exact-key DTOs, Keychain, AppDataStore + invalidation graph, converters/formatters, SharedSnapshotWriter, TH/EN strings (port web translations.ts). Fixture-decode + invalidation tests.
- 1B `PortoDesign/Sources` + tests: themes verbatim from `frontend/src/utils/themes.ts`, MoneyText, squarify port from `frontend/src/pages/Overview.tsx`, sankey port from `frontend/src/utils/sankey.ts`, Swift Charts wrappers, previews with sample data. Algorithm unit tests vs fixtures exported from web code.

**Wave 2 — Features (5 agents parallel):**
- 2A FeatureAuth + FeatureSettings: login/register/demo gated by /auth/config; theme/currency/language pickers, backup export (share sheet, `porto-backup-YYYY-MM-DD.porto`) / import (file importer), logout, clear-data.
- 2B FeatureOverview: hero dual-currency, P/L + MoM (~30d-back history point), 3 stat cards, area chart (last 60 pts of 365d), portfolio grid, treemap, 2 sankeys, all-assets table with weight bars, pull-to-refresh + refresh button + stale banner.
- 2C FeaturePortfolios: cards, holdings tables (dual currency), stacked allocation bar, `.onMove` reorder (optimistic → PATCH), row actions (buy/sell/chart/NAV/edit/delete), price-history modal 7D/1M/3M/1Y with avg-cost RuleMark, per-(asset,range) cache.
- 2D PortoForms bodies: AssetFormSheet (th/fund/deposit→THB, crypto/us→USD defaults; CG_ID_MAP 25 coins; th→`SYMBOL.BK`; opening txn = POST asset → POST transaction), TransactionFormSheet (deposit assets→deposit/withdraw, short→Sell(Open)/Buy(Cover), qty cap vs position, price prefill, date today Asia/Bangkok), LiabilityFormSheet 4 modes + balance preview, Portfolio/Price sheets.
- 2E FeatureTransactions + FeatureDebt + `App/PortoWidget/*.swift` bodies: merged txn list date desc (createdAt tiebreak), edit/delete, Thai 400 shown verbatim; debt strip + list + sankey; widget provider/views per design above.

**Wave 3 — Integration (1 agent):** real RootView/MainTabView wiring, store injection, 401 flow E2E, refreshAll on scenePhase, widget verification, localization/accessibility sweep, app icon, run PARITY-CHECKLIST. Cross-package fixes serialized here.

## Key risks

1. forbidNonWhitelisted 400s → per-request DTO structs, encoded-key tests vs docs/API.md.
2. Raw-vs-enriched decode → mutation responses ignored, always refetch.
3. "Today" boundaries → compute in Asia/Bangkok, not device UTC.
4. Physical device dev → debug-only base-URL override (LAN IP); ATS `NSAllowsLocalNetworking` in Dev.
5. Widget token expiry (7d, no refresh) → degrade to cached snapshot, never crash/wipe.
6. Treemap/sankey fidelity → port 1:1 with unit tests on identical inputs from web fixtures.

## Verification

Local backend is started from the sibling `porto` repo (`cd ../porto`: `docker compose up -d` + `cd backend && npm run start:dev`, localhost:3002, .env.dev has ENABLE_DEMO=true); `make`/`swift` commands run from the porto-ios root.
- Wave 0: `make generate && make build`; `swift build` per package.
- Wave 1: `make fixtures` then `swift test` (PortoKit, PortoDesign).
- Wave 2: `swift build` per feature; simulator with demo account; per-screen numbers vs web UI side-by-side; every mutation fires its invalidation row (APIClient debug log); over-sell shows Thai 400; reorder persists.
- Wave 3 E2E: register → create portfolio → add BTC w/ opening txn → Overview totals match web → partial sell → txn edit/delete → liability pay/add → backup roundtrip → theme/currency/language toggles → force 401 → auto-logout → widget small+medium correct, airplane mode shows cached snapshot.

## Reference files (source of truth to port from)

Read-only ports from the sibling `porto` repo — not files in porto-ios. Paths are relative to the porto-ios root.

- `../porto/frontend/src/hooks/useApi.ts` — invalidation graph + response shapes
- `../porto/frontend/src/utils/themes.ts` — theme palettes (verbatim hex)
- `../porto/frontend/src/components/AssetModal.tsx` — CG_ID_MAP, defaults, .BK rule, opening-txn flow
- `../porto/frontend/src/pages/Overview.tsx` — squarify + overview aggregation
- `../porto/frontend/src/utils/sankey.ts` — computeSankey layout
- `../porto/frontend/src/store/translations.ts` — TH/EN strings
