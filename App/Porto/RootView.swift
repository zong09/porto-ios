import SwiftUI
import PortoKit
import PortoDesign
import FeatureAuth

/// Session gate: unauthenticated -> AuthScreen; authenticated -> MainTabView.
/// A 401 anywhere clears the session (APIClient), which flips this back to the auth gate and
/// resets the data store.
struct RootView: View {
    @Bindable var container: AppContainer

    private var accent: Color {
        Theme.palette(ThemeID(rawValue: container.preferences.themeID) ?? .sunset).palette.first ?? .accentColor
    }

    var body: some View {
        Group {
            if container.session.isAuthenticated {
                MainTabView(container: container)
            } else {
                AuthScreen(
                    api: container.api,
                    session: container.session,
                    preferences: container.preferences,
                    onAuthenticated: { Task { await container.store.loadAll() } }
                )
            }
        }
        .tint(accent)
        .task {
            if container.session.isAuthenticated { await container.store.loadAll() }
        }
        .onChange(of: container.session.isAuthenticated) { _, isAuth in
            if !isAuth { container.store.reset() }
        }
    }
}
