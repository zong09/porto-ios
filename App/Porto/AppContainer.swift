import Foundation
import PortoKit

/// Owns the app-wide singletons and wires their dependencies together once at launch.
/// Order matters: session/prefs/snapshot -> api(session) -> store(api).
@MainActor
@Observable
final class AppContainer {
    let config: AppConfig
    let preferences: PreferencesStore
    let session: KeychainSessionStore
    let snapshot: SharedSnapshotStore
    let api: APIClient
    let store: AppDataStore

    init() {
        let config = AppConfig.fromBundle()
        self.config = config
        self.preferences = PreferencesStore()
        self.session = KeychainSessionStore(config: config)
        self.snapshot = SharedSnapshotStore()
        // 401 clears the session inside APIClient; RootView observes session.isAuthenticated and
        // returns to the auth gate. onUnauthorized is a no-op hook point.
        self.api = APIClient(config: config, session: session, onUnauthorized: {})
        self.store = AppDataStore(api: api, preferences: preferences, snapshotStore: snapshot)
    }
}
