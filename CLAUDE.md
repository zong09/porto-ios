# CLAUDE.md

Guidance for working in the Porto iOS repo. Read `README.md` first for the project overview.

## The Xcode project is generated — never edit it

`Porto.xcodeproj` is produced by **XcodeGen** from `project.yml` and is **gitignored**. Never
edit the `.xcodeproj` directly; edit `project.yml` and run `make generate` (or `xcodegen
generate`). Anything you change in the generated project is lost on the next regenerate.

## Files that are generated / frozen — edit the source, not the artifact

| Artifact | Source of truth | Notes |
|---|---|---|
| `Porto.xcodeproj` | `project.yml` | Regenerate with `make generate` |
| `App/*/*.entitlements` | `project.yml` → target `entitlements.properties` | **XcodeGen overwrites these files on every `generate`.** Editing the `.entitlements` XML directly does NOT stick. |
| `App/*/Info.generated.plist` | `project.yml` → target `info.properties` | Generated |
| `App/Config/*.xcconfig` | — | **FROZEN.** Do not edit (banner in `Shared.xcconfig`). Change build settings via `project.yml` `settings` instead. |

### Example: adding an entitlement/capability

Add it under the target in `project.yml`, then regenerate:

```yaml
    entitlements:
      path: App/Porto/Porto.entitlements
      properties:
        com.apple.security.application-groups:
          - group.co.porto.ios
```

## Build & verify

```sh
make generate        # after any project.yml change
make build           # simulator build (signing OFF — skips entitlements)
make test-packages   # fast SwiftPM unit tests, no simulator
make test            # app-target tests on simulator
```

Destination defaults to `iPhone 17` simulator (override with `DESTINATION=...`).

**Signing caveat:** `make build`/`make test` set `CODE_SIGNING_ALLOWED=NO`, which skips
entitlement processing. To verify runtime behavior that depends on entitlements (App Group,
Keychain sharing), build from Xcode (⌘R) or run `xcodebuild` without that flag — the simulator
then honors the `*-Simulated.xcent` it generates.

## App ↔ widget shared state

- The app and `PortoWidgetExtension` share data via App Group **`group.co.porto.ios`**
  (`AppConfig.appGroupIdentifier`). Both targets must declare it in `project.yml`.
- `SharedSnapshotStore` reads/writes `shared-snapshot.json` in the App Group container. If the
  entitlement is missing, `containerURL(...)` returns `nil` and reads/writes silently no-op —
  the widget then shows its empty state.
- The app writes the snapshot in `AppDataStore.writeSnapshot()` (called after refresh). The
  widget renders cached-first, then optionally does a live fetch.
- `AppConfig.fromBundle()` currently sets `keychainAccessGroup: nil`, so the widget cannot read
  the app's JWT for its own live fetch — it relies on the app-written cache. Sharing the Keychain
  would require a `keychain-access-groups` entitlement + a real signing team.

## Architecture notes

- Entry: `PortoApp` → `AppContainer` (wires singletons: config, preferences, session, snapshot,
  api, store) → `RootView` (auth gate) → `MainTabView`.
- Layering: `PortoKit` (core) → `PortoDesign` → `PortoForms` → `Feature*` → app target. Keep
  dependencies pointing one way; features depend on kit/design, not on each other.
- Backend URL comes from `API_BASE_URL` in the xcconfig, surfaced via `Info.plist` (`APIBaseURL`)
  and read in `AppConfig.fromBundle()`. Debug → `localhost:3002`, Release → Railway.
- Localization: Thai is the primary UI language; user-facing strings are often Thai.

## App icon

`App/Porto/Assets.xcassets/AppIcon.appiconset`. Icons must be **opaque, no alpha channel**
(Apple rejects alpha in the marketing icon). The catalog is wired via
`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon` in `project.yml`.
