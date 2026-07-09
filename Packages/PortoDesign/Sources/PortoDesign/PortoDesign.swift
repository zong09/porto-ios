import SwiftUI
import PortoKit

/// Wave 0 placeholder. Wave 1B fills PortoDesign with:
/// Theme (Sunset/Ocean/Berry from web themes.ts), MoneyText, cards/badges, and the chart
/// primitives (Squarify/Treemap, Sankey, AreaHistoryChart, PriceHistoryChart, Sparkline,
/// StackedAllocationBar). Kept intentionally small so Wave 0 stays green.

/// Theme identifiers shared across app, settings, and widget (stable raw values).
public enum ThemeID: String, Codable, Sendable, CaseIterable {
    case sunset, ocean, berry
    public static let `default`: ThemeID = .sunset
}
