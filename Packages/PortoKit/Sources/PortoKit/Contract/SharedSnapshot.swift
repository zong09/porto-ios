import Foundation

/// Written by the app into the App Group container after every summary/history refresh, then read
/// by the WidgetKit extension. Keep this Codable stable — it is a cross-process contract.
public struct SharedSnapshot: Codable, Sendable {
    public let netWorthThb: Double
    public let todayPlThb: Double
    public let totalAssetsThb: Double
    public let totalLiabilitiesThb: Double
    /// THB per 1 USD.
    public let fx: Double
    /// Up to 30 recent net-worth (THB) points, oldest -> newest.
    public let sparkline: [Double]
    public let displayCurrency: Currency
    public let themeID: String
    public let updatedAt: Date

    public init(netWorthThb: Double, todayPlThb: Double, totalAssetsThb: Double,
                totalLiabilitiesThb: Double, fx: Double, sparkline: [Double],
                displayCurrency: Currency, themeID: String, updatedAt: Date) {
        self.netWorthThb = netWorthThb; self.todayPlThb = todayPlThb
        self.totalAssetsThb = totalAssetsThb; self.totalLiabilitiesThb = totalLiabilitiesThb
        self.fx = fx; self.sparkline = sparkline; self.displayCurrency = displayCurrency
        self.themeID = themeID; self.updatedAt = updatedAt
    }
}
