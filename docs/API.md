# Porto API contract (snapshot for porto-ios)

Base: `http://localhost:3002/api` (dev). JWT Bearer, 7d expiry, **no refresh** — 401 anywhere -> force logout.
`ValidationPipe forbidNonWhitelisted`: request bodies must carry exact keys only; omit nil fields.
Numerics: MOSTLY JSON numbers (Double), BUT /transactions serializes quantity/price/fee as STRINGS (Postgres numeric, transformer not applied on that path) — Contract decodes numerics flexibly (string-or-number) via KeyedDecodingContainer.decodeFlexibleDouble. Verified against live backend. Dates = `"YYYY-MM-DD"`. Errors: `{statusCode, message: string|string[], error}` (Thai — surface verbatim).

## Enums
- AssetType: `crypto | th | us | fund | deposit`
- Currency: `THB | USD`
- Transaction side (request): `buy | sell | deposit | withdraw` (stored `buy | sell`)
- Direction: `long | short`
- Liability tx type: `pay | add`
- Portfolio color: Int `0..5`

## Endpoints
| Method | Path | Body | Response |
|---|---|---|---|
| POST | /auth/register | RegisterRequest {email,name,pass} | {token, user{id,name,email,isDemo}} |
| POST | /auth/login | LoginRequest {email,pass} | {token, user{...}} |
| POST | /auth/demo | — | {token, user{...}} (24h) |
| GET  | /auth/config | — | {enableDemo, enableRegister} |
| GET  | /auth/me | — | {userId, email, name, isDemo} |
| POST | /auth/clear | — | {success} |
| GET  | /portfolios | — | Portfolio[] |
| POST | /portfolios | CreatePortfolioRequest | raw entity |
| PATCH| /portfolios/:id | UpdatePortfolioRequest | raw entity |
| PATCH| /portfolios/reorder | {orderedIds} | {success} |
| DELETE| /portfolios/:id | — | {success} |
| GET  | /assets | — | Asset[] (ENRICHED: portfolio, currentPrice, change24h, position) |
| POST | /assets | CreateAssetRequest | RAW entity — do not decode as Asset; refetch |
| PATCH| /assets/:id | UpdateAssetRequest {name?,manualPrice?} | RAW entity |
| PATCH| /assets/reorder | {orderedIds} | {success} |
| DELETE| /assets/:id | — | {success} |
| GET  | /transactions | — | Transaction[] (asset nested) |
| POST | /transactions | CreateTransactionRequest | raw |
| PUT  | /transactions/:id | CreateTransactionRequest | raw |
| DELETE| /transactions/:id | — | {success} |
| GET  | /liabilities | — | Liability[] |
| GET  | /liabilities/transactions | — | LiabilityTransaction[] |
| POST | /liabilities | CreateLiabilityRequest | raw |
| PATCH| /liabilities/:id | UpdateLiabilityRequest | raw |
| POST | /liabilities/:id/transactions | AdjustLiabilityRequest {type,amount,date} | raw |
| DELETE| /liabilities/:id | — | {success} |
| GET  | /net-worth/summary | — | NetWorthSummary {totalAssetsThb,totalLiabilitiesThb,netWorthThb,todayPlThb,totalCostThb,fx} |
| GET  | /net-worth/history?days= | — | NetWorthHistoryItem[] |
| POST | /net-worth/snapshot | — | history row |
| GET  | /prices/crypto/:cgId/history?days= | — | {prices:[[t,p],...]} |
| GET  | /prices/stock/:symbol/history?range= | — | ChartDatapoint[] {t,p} |
| POST | /backup/export | {password} (min 8) | {data: base64} |
| POST | /backup/import | {password, data(base64)} | {success} |

Source of truth: `../porto/frontend/src/hooks/useApi.ts` + backend controllers/entities.
