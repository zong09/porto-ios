import Foundation

/// Converts between THB and USD using `fx` = THB per 1 USD (from NetWorthSummary).
/// The backend keeps everything THB-based; the UI toggles a display currency.
public struct CurrencyConverter: Sendable {
    /// THB per 1 USD.
    public let fx: Double
    public init(fx: Double) { self.fx = fx }

    public func convert(_ amount: Double, from: Currency, to: Currency) -> Double {
        guard from != to, fx > 0 else { return amount }
        switch (from, to) {
        case (.usd, .thb): return amount * fx
        case (.thb, .usd): return amount / fx
        default: return amount
        }
    }

    /// A THB-base amount expressed in the requested display currency.
    public func fromThb(_ thb: Double, to: Currency) -> Double {
        convert(thb, from: .thb, to: to)
    }
}
