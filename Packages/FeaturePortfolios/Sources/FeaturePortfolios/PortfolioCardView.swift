import SwiftUI
import PortoKit
import PortoDesign

/// One portfolio's card: header (color dot, name, dual-currency value + return badge, actions),
/// stacked allocation bar + legend (>=2 active holdings), and the holdings list.
struct PortfolioCardView: View {
    let section: PortfolioSection
    let theme: Theme
    let language: Language
    let displayCurrency: Currency
    let converter: CurrencyConverter
    let onAddAsset: () -> Void
    let onEditPortfolio: () -> Void
    let onDeletePortfolio: () -> Void
    let onReorderAssets: () -> Void
    let onBuySell: (Asset) -> Void
    let onChart: (Asset) -> Void
    let onNav: (Asset) -> Void
    let onEditAsset: (Asset) -> Void
    let onDeleteAsset: (Asset) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            if section.hasAllocation {
                allocation
            }
            Divider()
            if !section.hasHoldings {
                Text(L10n.string("portfolios.noAssetsInPort", language))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 10) {
                    ForEach(section.holdings) { holding in
                        AssetRowView(holding: holding, theme: theme, language: language, converter: converter,
                                     onBuySell: { onBuySell(holding.asset) },
                                     onChart: { onChart(holding.asset) },
                                     onNav: { onNav(holding.asset) },
                                     onEdit: { onEditAsset(holding.asset) },
                                     onDelete: { onDeleteAsset(holding.asset) })
                        if holding.id != section.holdings.last?.id { Divider() }
                    }
                }
            }
        }
        .card()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(theme.paletteColor(section.portfolio.color)).frame(width: 12, height: 12)
                Text(section.portfolio.name).font(.headline)
                if section.holdings.count > 1 {
                    Button(action: onReorderAssets) {
                        Image(systemName: "arrow.up.arrow.down.circle").font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Menu {
                    Button(action: onEditPortfolio) { Label(language == .th ? "แก้ไข" : "Rename", systemImage: "pencil") }
                    Button(role: .destructive, action: onDeletePortfolio) {
                        Label(language == .th ? "ลบพอร์ต" : "Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            HStack(spacing: 10) {
                let parts = MoneyFormat.dual(thb: section.valueThb, display: displayCurrency, converter: converter)
                (Text(parts.primary).font(.title3.bold()) + Text("  " + parts.secondary).font(.caption).foregroundStyle(.secondary))
                if section.valueThb > 0 {
                    Text("\(section.returnPct >= 0 ? "+" : "")\(String(format: "%.1f", section.returnPct))%")
                        .font(.caption.bold())
                        .badge(PnL.color(section.returnPct, theme: theme))
                }
                Spacer()
                Button(action: onAddAsset) {
                    Label(language == .th ? "สินทรัพย์" : "Asset", systemImage: "plus")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var allocation: some View {
        VStack(alignment: .leading, spacing: 8) {
            StackedAllocationBar(segments: section.activeHoldings.enumerated().map { idx, h in
                (value: max(0, h.valueThb), color: theme.paletteColor(idx))
            })
            .frame(height: 8)
            FlowLegend(items: section.activeHoldings.enumerated().map { idx, h in
                (symbol: h.asset.symbol,
                 pct: section.valueThb > 0 ? (h.valueThb / section.valueThb) * 100 : 0,
                 color: theme.paletteColor(idx))
            })
        }
    }
}

/// Simple wrapping legend row (symbol + percent chip) for the allocation bar.
private struct FlowLegend: View {
    let items: [(symbol: String, pct: Double, color: Color)]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(item.color).frame(width: 8, height: 8)
                    Text(item.symbol).font(.caption2.bold())
                    Text("\(Int(item.pct.rounded()))%").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}
