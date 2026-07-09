# File ownership (no two agents share a folder)

FROZEN after Wave 0: `project.yml`, `Makefile`, all `Package.swift`, `App/Config/*.xcconfig`,
`*.entitlements`, and everything under `Packages/PortoKit/Sources/PortoKit/Contract/`.
Only the Wave 0 / Wave 3 integration agent may edit these.

| Area | Owner wave | Path |
|---|---|---|
| Scaffold / config / Contract | Wave 0 | project.yml, Makefile, Package.swift×9, App/Config, entitlements, PortoKit/Contract |
| PortoKit sources | 1A | Packages/PortoKit/Sources/PortoKit/{API,Session,Store,Formatting,Shared,Localization} |
| PortoDesign | 1B | Packages/PortoDesign/Sources |
| FeatureAuth + FeatureSettings | 2A | Packages/FeatureAuth, Packages/FeatureSettings |
| FeatureOverview | 2B | Packages/FeatureOverview |
| FeaturePortfolios | 2C | Packages/FeaturePortfolios |
| PortoForms bodies | 2D | Packages/PortoForms/Sources |
| FeatureTransactions + FeatureDebt + Widget | 2E | Packages/FeatureTransactions, Packages/FeatureDebt, App/PortoWidget |
| Integration | 3 | App/Porto (RootView/MainTabView), cross-package fixes |

Rule: features never depend on each other. Cross-tab actions route via PortoForms sheets or
MainTabView callbacks. Widget depends on PortoKit + PortoDesign only.
