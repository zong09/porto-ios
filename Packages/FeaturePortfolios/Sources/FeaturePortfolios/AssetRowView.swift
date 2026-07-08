import SwiftUI
import PortoKit
import PortoDesign

/// One holding row: symbol (+ SHORT badge)/name/type, qty · avg cost · price, dual-currency
/// value + P/L (native currency as primary — matches `formatMoneyPrimary(val, h.currency)` on the
/// web), and the row actions (buy/sell, chart/NAV, edit, delete).
struct AssetRowView: View {
    let holding: Holding
    let theme: Theme
    let language: Language
    let converter: CurrencyConverter
    let onBuySell: () -> Void
    let onChart: () -> Void
    let onNav: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var asset: Asset { holding.asset }
    private var isDeposit: Bool { asset.type == .deposit }
    private var isUp: Bool { holding.plThb >= 0 }
    private var typeColor: Color { theme.typeColor[asset.type] ?? (theme.typeColor[.deposit] ?? .gray) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topLine
            if !isDeposit {
                metricsLine
            }
            HStack(alignment: .top) {
                valueColumn
                Spacer()
                actions
            }
        }
        .padding(.vertical, 4)
    }

    private var topLine: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(asset.symbol).font(.subheadline.bold())
                    if holding.isShort {
                        Text("SHORT").font(.caption2.bold()).badge(.red)
                    }
                }
                if !asset.name.isEmpty, asset.name != asset.symbol {
                    Text(asset.name).font(.caption2).foregroundStyle(.secondary)
                }
            }
            Text(L10n.string("common.assetTypes.\(asset.type.rawValue)", language))
                .font(.caption2.bold())
                .badge(typeColor)
            Spacer()
        }
    }

    private var metricsLine: some View {
        HStack(spacing: 14) {
            metric(title: prefs("portfolios.tableQty"),
                   value: PortfolioMoney.quantity(holding.quantity, type: asset.type, ccy: asset.currency))
            let avg = PortfolioMoney.dualNative(holding.avgCost, ccy: asset.currency, converter: converter)
            metric(title: prefs("portfolios.tableAvgCost"), value: avg.primary, secondary: avg.secondary)
            let price = PortfolioMoney.dualNative(holding.currentPrice, ccy: asset.currency, converter: converter)
            metric(title: prefs("portfolios.tablePrice"), value: price.primary, secondary: price.secondary)
        }
    }

    private func metric(title: String, value: String, secondary: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
            if let secondary { Text(secondary).font(.caption2).foregroundStyle(.secondary) }
        }
    }

    private var valueColumn: some View {
        let value = PortfolioMoney.dualThbBase(holding.valueThb, primary: asset.currency, converter: converter)
        let pl = PortfolioMoney.dualThbBase(holding.plThb, primary: asset.currency, converter: converter)
        return VStack(alignment: .leading, spacing: 1) {
            Text(value.primary).font(.subheadline.bold())
            Text(value.secondary).font(.caption2).foregroundStyle(.secondary)
            if !isDeposit {
                Text("\(isUp ? "+" : "")\(pl.primary)")
                    .font(.caption.bold())
                    .foregroundStyle(isUp ? (theme.greens.first ?? .green) : (theme.reds.first ?? .red))
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button(action: onBuySell) {
                Text(holding.isShort
                     ? (language == .th ? "ขาย/ปิด" : "Sell/Cover")
                     : (language == .th ? "ซื้อ/ขาย" : "Buy/Sell"))
                    .font(.caption2.bold())
            }
            .buttonStyle(.borderedProminent)

            if asset.type != .fund, asset.type != .deposit {
                Button(action: onChart) {
                    Text(language == .th ? "กราฟ" : "Chart").font(.caption2.bold())
                }
                .buttonStyle(.bordered)
            }
            if asset.type == .fund {
                Button(action: onNav) {
                    Text("NAV").font(.caption2.bold())
                }
                .buttonStyle(.bordered)
            }
            Button(action: onEdit) { Image(systemName: "pencil") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Button(action: onDelete) { Image(systemName: "xmark") }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
    }

    private func prefs(_ key: String) -> String { L10n.string(key, language) }
}
