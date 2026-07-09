# Web-parity checklist (run in Wave 3)

- [ ] Auth: login / register / demo gated by `/auth/config`; 401 anywhere -> force logout.
- [ ] Overview: hero dual-currency, P/L + MoM (~30d-back history point), 3 stat cards,
      area chart (last 60 of 365d), portfolio grid, treemap, 2 sankeys, all-assets weight bars.
- [ ] Portfolios: holdings dual-currency, stacked allocation bar, reorder (optimistic -> PATCH),
      row actions (buy/sell/chart/NAV/edit/delete), price-history modal 7D/1M/3M/1Y + avg-cost RuleMark.
- [ ] Forms: AssetFormSheet (CG_ID_MAP, type->currency defaults, .BK rule, opening txn),
      TransactionFormSheet (side semantics, qty caps), Liability 4 modes, Portfolio/Price.
- [ ] Transactions: merged list date desc, edit/delete, Thai 400 shown verbatim.
- [ ] Debt: strip + list + sankey.
- [ ] Settings: theme/currency/language, backup export/import, logout, clear data.
- [ ] Widget: systemSmall + systemMedium correct; airplane mode shows cached snapshot.
- [ ] Numbers match web UI side-by-side; every mutation fires its invalidation row.
- [ ] "Today" computed in Asia/Bangkok, not device UTC.
