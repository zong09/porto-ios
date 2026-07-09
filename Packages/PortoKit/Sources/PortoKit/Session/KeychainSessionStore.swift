import Foundation

/// Concrete `SessionStoring` backed by the Keychain (token) + UserDefaults (user profile, non-secret).
/// Token lives in the shared access group so the widget can authenticate.
@Observable
public final class KeychainSessionStore: SessionStoring, @unchecked Sendable {
    public private(set) var token: String?
    public private(set) var currentUser: AuthUser?

    public var isAuthenticated: Bool { token != nil }

    private let keychain: Keychain
    private let defaults: UserDefaults
    private let tokenKey = AppConfig.tokenKeychainKey
    private let userKey = "porto.user.v1"

    public init(config: AppConfig, defaults: UserDefaults = .standard) {
        self.keychain = Keychain(service: "co.porto.ios", accessGroup: config.keychainAccessGroup)
        self.defaults = defaults
        if let data = keychain.get(tokenKey), let t = String(data: data, encoding: .utf8) {
            self.token = t
        }
        if let data = defaults.data(forKey: userKey) {
            self.currentUser = try? JSONDecoder().decode(AuthUser.self, from: data)
        }
    }

    public func save(token: String, user: AuthUser) {
        self.token = token
        self.currentUser = user
        keychain.set(Data(token.utf8), account: tokenKey)
        if let data = try? JSONEncoder().encode(user) {
            defaults.set(data, forKey: userKey)
        }
    }

    public func clear() {
        token = nil
        currentUser = nil
        keychain.delete(tokenKey)
        defaults.removeObject(forKey: userKey)
    }
}
