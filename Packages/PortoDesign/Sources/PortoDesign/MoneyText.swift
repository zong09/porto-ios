import SwiftUI
import PortoKit

/// Dual-currency money display: primary amount in the display currency, and the
/// converted amount in parentheses, smaller and fainter. Uses `MoneyFormat.dual`.
public struct MoneyText: View {
    private let thb: Double
    private let display: Currency
    private let converter: CurrencyConverter
    private let primaryFont: Font
    private let secondaryFont: Font
    private let showSecondary: Bool

    public init(thb: Double,
                display: Currency,
                converter: CurrencyConverter,
                primaryFont: Font = .body.weight(.semibold),
                secondaryFont: Font = .caption,
                showSecondary: Bool = true) {
        self.thb = thb
        self.display = display
        self.converter = converter
        self.primaryFont = primaryFont
        self.secondaryFont = secondaryFont
        self.showSecondary = showSecondary
    }

    public var body: some View {
        let parts = MoneyFormat.dual(thb: thb, display: display, converter: converter)
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(parts.primary)
                .font(primaryFont)
            if showSecondary {
                Text(parts.secondary)
                    .font(secondaryFont)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
