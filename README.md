# Porto — iOS

SwiftUI app for **Porto**, a personal portfolio / net-worth tracker. Companion to the
`porto` backend (sibling repo). Displays net worth, portfolios, transactions, and debt,
with a home-screen net-worth widget.

## Requirements

- **Xcode** (full install, not just Command Line Tools) — iOS 17 SDK
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — `brew install xcodegen` (the `.xcodeproj` is generated, not committed)
- Swift 5.9 / iOS 17.0 deployment target

## Getting started

```sh
brew install xcodegen        # one-time
make generate                # generate Porto.xcodeproj from project.yml
open Porto.xcodeproj          # then ⌘R in Xcode
```

The app talks to the backend at `http://localhost:3002/api` in **Debug** (run the sibling
`porto` repo locally) and the Railway deployment in **Release**. See `App/Config/*.xcconfig`.

## Common tasks (Makefile)

| Command | What it does |
|---|---|
| `make generate` | Regenerate `Porto.xcodeproj` from `project.yml` |
| `make build` | Build the app for the simulator (signing disabled) |
| `make test` | Run app-target tests on the simulator |
| `make test-packages` | Fast SwiftPM unit tests (PortoKit, PortoDesign) — no simulator |
| `make fixtures` | Capture live backend GET responses as test fixtures |
| `make clean` | Remove generated project, DerivedData, `.build` |

> `make build`/`make test` pass `CODE_SIGNING_ALLOWED=NO`, which **skips entitlement
> processing**. To exercise anything that needs entitlements at runtime (e.g. the App
> Group used by the widget), run a normal signed build from Xcode (⌘R) or `xcodebuild`
> without that flag.

## Project layout

```
App/
  Config/            Dev/Prod/Shared .xcconfig  (FROZEN — do not edit)
  Porto/             App target: entry, RootView, MainTabView, AppContainer, Assets, entitlements
  PortoWidget/       WidgetKit extension: NetWorthWidget
Packages/            Local SwiftPM packages (see below)
project.yml          XcodeGen manifest — the source of truth for the Xcode project
Makefile             Build / test / generate orchestration
```

### Packages

| Package | Role |
|---|---|
| `PortoKit` | Core: models, networking, session/Keychain, data store, formatting, shared snapshot, localization |
| `PortoDesign` | Design system: theme palettes, colors, reusable UI primitives |
| `PortoForms` | Shared form components |
| `FeatureAuth` | Login / auth gate |
| `FeatureOverview` | Net-worth overview / dashboard |
| `FeaturePortfolios` | Portfolios & assets |
| `FeatureTransactions` | Transactions |
| `FeatureDebt` | Liabilities / debt |
| `FeatureSettings` | Settings & preferences |

Dependency direction: `PortoKit` → `PortoDesign` → `PortoForms` → `Feature*` → app target.

## Widget

`NetWorthWidget` (small/medium) renders a **cached-first** net-worth snapshot. The app writes
a `SharedSnapshot` into the App Group `group.co.porto.ios` after each refresh; the widget reads
it and optionally attempts a live refresh. The App Group is declared in `project.yml` under each
target's `entitlements.properties` — see [CLAUDE.md](CLAUDE.md) for why it lives there.
