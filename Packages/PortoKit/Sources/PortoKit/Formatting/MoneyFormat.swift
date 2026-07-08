import Foundation

/// Money formatting matching the web: 2 decimal places, en-US grouping, currency symbol prefix.
public enum MoneyFormat {
    public static func symbol(_ currency: Currency) -> String {
        switch currency { case .thb: return "฿"; case .usd: return "$" }
    }

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.usesGroupingSeparator = true
        return f
    }()

    /// e.g. `฿1,234.50` / `$1,234.50`.
    public static func format(_ amount: Double, _ currency: Currency) -> String {
        let n = formatter.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
        return symbol(currency) + n
    }

    /// Number only (no symbol), 2dp en-US.
    public static func number(_ amount: Double, fractionDigits: Int = 2) -> String {
        let f = formatter
        f.minimumFractionDigits = fractionDigits
        f.maximumFractionDigits = fractionDigits
        defer { f.minimumFractionDigits = 2; f.maximumFractionDigits = 2 }
        return f.string(from: NSNumber(value: amount)) ?? String(format: "%.\(fractionDigits)f", amount)
    }

    /// Dual currency: primary in `display`, secondary (the other) in parentheses.
    /// `thb` is the THB-base amount; conversion uses `converter`.
    public static func dual(thb: Double, display: Currency, converter: CurrencyConverter)
        -> (primary: String, secondary: String) {
        let other: Currency = display == .usd ? .thb : .usd
        let primaryAmount = converter.fromThb(thb, to: display)
        let secondaryAmount = converter.fromThb(thb, to: other)
        return (format(primaryAmount, display), "(" + format(secondaryAmount, other) + ")")
    }
}
