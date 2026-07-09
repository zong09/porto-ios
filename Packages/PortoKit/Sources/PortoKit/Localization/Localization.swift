import Foundation

public enum Language: String, Codable, Sendable, CaseIterable {
    case th, en
    public static let `default`: Language = .th
}

/// Looks up localized strings ported from the web `translations.ts`. Missing keys return the key
/// itself (surfaces gaps loudly rather than silently).
public enum L10n {
    public static func string(_ key: String, _ lang: Language) -> String {
        guard let s = Strings.all[key] else { return key }
        return lang == .th ? s.th : s.en
    }
}

/// Observable app-wide preferences (language + display currency + theme). Persisted to
/// UserDefaults; feature code reads these for dual-currency display and localization.
@Observable
public final class PreferencesStore: @unchecked Sendable {
    public var language: Language {
        didSet { defaults.set(language.rawValue, forKey: Keys.language) }
    }
    /// Primary display currency toggle (web default = USD).
    public var displayCurrency: Currency {
        didSet { defaults.set(displayCurrency.rawValue, forKey: Keys.displayCurrency) }
    }
    public var themeID: String {
        didSet { defaults.set(themeID, forKey: Keys.themeID) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let language = "porto.language"
        static let displayCurrency = "porto.displayCurrency"
        static let themeID = "porto.themeID"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.language = (defaults.string(forKey: Keys.language).flatMap(Language.init)) ?? .default
        self.displayCurrency = (defaults.string(forKey: Keys.displayCurrency).flatMap(Currency.init)) ?? .usd
        self.themeID = defaults.string(forKey: Keys.themeID) ?? "sunset"
    }

    public func t(_ key: String) -> String { L10n.string(key, language) }
}
