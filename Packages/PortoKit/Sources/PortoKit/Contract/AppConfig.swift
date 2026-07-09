import Foundation

/// Build/runtime configuration. `apiBaseURL` comes from the xcconfig (`API_BASE_URL`) via
/// Info.plist; the app-group + Keychain identifiers are shared with the widget.
public struct AppConfig: Sendable {
    public let apiBaseURL: URL
    public let appGroupID: String
    public let keychainAccessGroup: String?
    public let allowDebugBaseURLOverride: Bool

    public init(apiBaseURL: URL, appGroupID: String, keychainAccessGroup: String?,
                allowDebugBaseURLOverride: Bool) {
        self.apiBaseURL = apiBaseURL; self.appGroupID = appGroupID
        self.keychainAccessGroup = keychainAccessGroup
        self.allowDebugBaseURLOverride = allowDebugBaseURLOverride
    }

    public static let appGroupIdentifier = "group.co.porto.ios"
    public static let sharedSnapshotFilename = "shared-snapshot.json"
    public static let tokenKeychainKey = "porto.jwt.v1"

    /// Reads `API_BASE_URL` from the main bundle's Info.plist. Falls back to the dev URL.
    public static func fromBundle(_ bundle: Bundle = .main) -> AppConfig {
        let urlString = (bundle.object(forInfoDictionaryKey: "APIBaseURL") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let url = urlString.flatMap(URL.init(string:)) ?? URL(string: "http://localhost:3002/api")!
        #if DEBUG
        let allowOverride = true
        #else
        let allowOverride = false
        #endif
        return AppConfig(
            apiBaseURL: url,
            appGroupID: appGroupIdentifier,
            keychainAccessGroup: nil,
            allowDebugBaseURLOverride: allowOverride
        )
    }
}
