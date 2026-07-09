import Foundation

/// Persists the JWT + current user across launches and (for the widget) across the app-group
/// Keychain. Any 401 → `clear()` then the app returns to the login gate.
public protocol SessionStoring: AnyObject, Sendable {
    var token: String? { get }
    var currentUser: AuthUser? { get }
    var isAuthenticated: Bool { get }

    func save(token: String, user: AuthUser)
    func clear()
}
