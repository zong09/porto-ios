import SwiftUI
import PortoKit
import FeatureOverview
import FeaturePortfolios
import FeatureTransactions
import FeatureDebt
import FeatureSettings

struct MainTabView: View {
    @Bindable var container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            OverviewScreen(store: container.store, prefs: container.preferences)
                .tabItem { Label(container.preferences.t("common.overview"), systemImage: "chart.pie") }
            PortfoliosScreen(store: container.store, prefs: container.preferences, api: container.api)
                .tabItem { Label(container.preferences.t("common.ports"), systemImage: "folder") }
            TransactionsScreen(store: container.store, prefs: container.preferences)
                .tabItem { Label(container.preferences.t("common.tx"), systemImage: "list.bullet.rectangle") }
            DebtScreen(store: container.store, prefs: container.preferences)
                .tabItem { Label(container.preferences.t("common.debt"), systemImage: "creditcard") }
            SettingsScreen(store: container.store, preferences: container.preferences,
                           session: container.session, api: container.api,
                           onLoggedOut: { container.store.reset() })
                .tabItem { Label(container.preferences.t("common.settings"), systemImage: "gearshape") }
        }
        // refreshAll on foreground (also runs post-login via RootView.loadAll).
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && container.session.isAuthenticated {
                Task { await container.store.refreshAll() }
            }
        }
    }
}
