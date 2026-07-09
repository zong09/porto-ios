import SwiftUI
import PortoKit
import PortoDesign

/// Range selector matching the web `ChartModal` (`'7D' | '1M' | '3M' | '1Y'`).
enum PriceRange: String, CaseIterable, Identifiable {
    case d7 = "7D", m1 = "1M", m3 = "3M", y1 = "1Y"
    var id: String { rawValue }
    /// Days back, used for the crypto history endpoint.
    var days: Int {
        switch self {
        case .d7: return 7
        case .m1: return 30
        case .m3: return 90
        case .y1: return 365
        }
    }
}

/// Decodes the crypto history endpoint's raw shape (`{ prices: [[t, p], ...] }`).
private struct CryptoHistoryResponse: Decodable {
    let prices: [[Double]]
}

/// Price-history modal for one asset: range picker (7D/1M/3M/1Y) + line chart with a dashed
/// avg-cost `RuleMark`. Crypto goes through `/prices/crypto/{cgId}/history?days=`, stocks (th/us)
/// through `/prices/stock/{symbol}/history?range=`. Results are cached per (asset, range) for the
/// lifetime of the screen so switching ranges back and forth doesn't re-fetch.
struct PriceHistoryModal: View {
    let asset: Asset
    let theme: Theme
    let language: Language
    let api: APIClientProtocol
    @Binding var cache: [String: [ChartDatapoint]]

    @Environment(\.dismiss) private var dismiss
    @State private var range: PriceRange = .m3
    @State private var points: [ChartDatapoint] = []
    @State private var isLoading = false
    @State private var errorText: String?

    private var cacheKey: String { "\(asset.id)|\(range.rawValue)" }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Range", selection: $range) {
                    ForEach(PriceRange.allCases) { r in Text(r.rawValue).tag(r) }
                }
                .pickerStyle(.segmented)

                if isLoading && points.isEmpty {
                    ProgressView(language == .th ? "กำลังดึงข้อมูลราคาประวัติ…" : "Fetching price history...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if points.count >= 2 {
                    summaryRow
                    PriceHistoryChart(points: points, avgCost: asset.position?.avgCost,
                                       lineColor: theme.paletteColor(0))
                        .frame(height: 220)
                } else {
                    Text(language == .th ? "ไม่มีข้อมูลราคาประวัติ" : "No price history available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(asset.symbol)
            .navigationBarTitleDisplayModeIfAvailable()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .th ? "ปิด" : "Close") { dismiss() }
                }
            }
        }
        .task(id: range) { await load() }
    }

    private var summaryRow: some View {
        let prices = points.map(\.p)
        let first = prices.first ?? 0
        let last = prices.last ?? 0
        let changePct = first > 0 ? ((last - first) / first) * 100 : 0
        let isUp = changePct >= 0
        return HStack(spacing: 16) {
            Text(MoneyFormat.number(last))
                .font(.title2.bold())
            Text("\(isUp ? "▲ +" : "▼ ")\(String(format: "%.1f", abs(changePct)))%")
                .font(.subheadline.bold())
                .foregroundStyle(isUp ? (theme.greens.first ?? .green) : (theme.reds.first ?? .red))
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("High: \(MoneyFormat.number(prices.max() ?? 0))").font(.caption2)
                Text("Low: \(MoneyFormat.number(prices.min() ?? 0))").font(.caption2)
            }
            .foregroundStyle(.secondary)
        }
    }

    private func load() async {
        if let cached = cache[cacheKey] {
            points = cached
            return
        }
        isLoading = true
        errorText = nil
        defer { isLoading = false }
        do {
            let fetched: [ChartDatapoint]
            if asset.type == .crypto, let cgId = asset.cgId {
                let raw = try await api.get(.cryptoHistory(cgId: cgId, days: range.days), as: CryptoHistoryResponse.self)
                fetched = raw.prices.compactMap { pair in
                    guard pair.count >= 2 else { return nil }
                    return ChartDatapoint(t: pair[0], p: pair[1])
                }
            } else {
                let symbol = asset.yahooSymbol ?? asset.symbol
                fetched = try await api.get(.stockHistory(symbol: symbol, range: range.rawValue), as: [ChartDatapoint].self)
            }
            cache[cacheKey] = fetched
            points = fetched
        } catch {
            errorText = (error as? APIError)?.displayMessage
                ?? (language == .th ? "ไม่สามารถดึงข้อมูลประวัติราคาได้ในขณะนี้" : "Unable to fetch price history at this time")
        }
    }
}

private extension View {
    @ViewBuilder
    func navigationBarTitleDisplayModeIfAvailable() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
