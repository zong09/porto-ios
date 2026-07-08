import Foundation
import PortoKit

/// Row-level formatting helpers ported from `Portfolios.tsx`. Unlike the global dual-currency rule
/// (primary = display-currency toggle), rows here show the ASSET's native currency as primary and
/// the other as secondary — matching `formatMoneyPrimary/Secondary(val, h.currency)` on the web.
enum PortfolioMoney {
    /// `thb` is THB-base (already signed). `primaryCcy` picks which currency is shown first.
    static func dualThbBase(_ thb: Double, primary primaryCcy: Currency, converter: CurrencyConverter)
        -> (primary: String, secondary: String) {
        MoneyFormat.dual(thb: thb, display: primaryCcy, converter: converter)
    }

    /// For a NATIVE amount (e.g. avgCost/currentPrice already in the asset's own currency):
    /// converts to THB-base first, then shows `ccy` as primary.
    static func dualNative(_ amount: Double, ccy: Currency, converter: CurrencyConverter)
        -> (primary: String, secondary: String) {
        let thb = converter.convert(amount, from: ccy, to: .thb)
        return MoneyFormat.dual(thb: thb, display: ccy, converter: converter)
    }

    private static let qtyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 8
        f.usesGroupingSeparator = true
        return f
    }()

    /// Deposit assets show as money (2dp + symbol); everything else shows a bare quantity
    /// (0-8 fraction digits, matching the web's `toLocaleString` call).
    static func quantity(_ qty: Double, type: AssetType, ccy: Currency) -> String {
        if type == .deposit {
            return MoneyFormat.format(qty, ccy)
        }
        return qtyFormatter.string(from: NSNumber(value: qty)) ?? String(qty)
    }
}
