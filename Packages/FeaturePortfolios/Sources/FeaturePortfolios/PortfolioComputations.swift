import Foundation
import PortoKit
import PortoDesign

/// A single asset's computed holding numbers for the Portfolios screen. Ported 1:1 from the web
/// `Portfolios.tsx` per-asset computation (short positions subtract from portfolio value; P&L for
/// shorts profits when price drops).
struct Holding: Identifiable, Hashable {
    let asset: Asset
    var id: String { asset.id }
    let quantity: Double
    let avgCost: Double
    let currentPrice: Double
    /// THB-base, signed (negative for short positions).
    let valueThb: Double
    /// THB-base cost basis (unsigned).
    let costThb: Double
    let plThb: Double
    let returnPct: Double
    let isShort: Bool

    static func == (l: Holding, r: Holding) -> Bool { l.id == r.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// A portfolio plus its computed holdings/aggregates, mirroring `portfolioSections` in the web page.
struct PortfolioSection: Identifiable {
    let portfolio: Portfolio
    var id: String { portfolio.id }
    let holdings: [Holding]
    /// THB-base, signed.
    let valueThb: Double
    let returnPct: Double
    var hasHoldings: Bool { !holdings.isEmpty }
    /// Holdings with quantity > 0, sorted by value desc — feeds the allocation bar.
    let activeHoldings: [Holding]
    var hasAllocation: Bool { activeHoldings.count >= 2 }
}

enum PortfolioMath {
    /// Builds computed holdings for one portfolio's assets. `fx` = THB per 1 USD.
    static func holdings(for portfolioId: String, assets: [Asset], fx: Double) -> [Holding] {
        assets
            .filter { $0.portfolioId == portfolioId }
            .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) }
            .map { asset in
                let multiplier: Double = asset.currency == .usd ? fx : 1
                let quantity = asset.position?.quantity ?? 0
                let currentPrice = asset.currentPrice ?? 0
                let avgCost = asset.position?.avgCost ?? 0
                let isShort = (asset.direction ?? .long) == .short

                let assetValueThb = quantity * currentPrice * multiplier
                let assetCostThb = quantity * avgCost * multiplier
                let valueThb = isShort ? -assetValueThb : assetValueThb
                let plThb = isShort
                    ? (avgCost - currentPrice) * quantity * multiplier
                    : assetValueThb - assetCostThb
                let returnPct = assetCostThb > 0 ? (plThb / assetCostThb) * 100 : 0

                return Holding(asset: asset, quantity: quantity, avgCost: avgCost,
                               currentPrice: currentPrice, valueThb: valueThb, costThb: assetCostThb,
                               plThb: plThb, returnPct: returnPct, isShort: isShort)
            }
    }

    static func section(for portfolio: Portfolio, assets: [Asset], fx: Double) -> PortfolioSection {
        let holdings = holdings(for: portfolio.id, assets: assets, fx: fx)
        let valueThb = holdings.reduce(0) { $0 + $1.valueThb }
        let costThb = holdings.reduce(0) { $0 + $1.costThb }
        let plThb = holdings.reduce(0) { $0 + $1.plThb }
        let returnPct = costThb > 0 ? (plThb / costThb) * 100 : 0
        let active = holdings.filter { $0.quantity > 0 }.sorted { $0.valueThb > $1.valueThb }
        return PortfolioSection(portfolio: portfolio, holdings: holdings, valueThb: valueThb,
                                 returnPct: returnPct, activeHoldings: active)
    }
}
