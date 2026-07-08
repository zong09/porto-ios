import WidgetKit
import SwiftUI
import PortoKit
import PortoDesign

/// Home-screen net-worth widget. Cached-first: renders the `SharedSnapshot` written by the app
/// immediately, then attempts a live `GET /net-worth/summary` using the Keychain-stored JWT
/// (shared access group). On 401 / offline / no token, falls back to the cached snapshot with a
/// stale indicator — the cache is never wiped. Policy refreshes every 30 minutes.

// MARK: - Timeline entry

struct NetWorthEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedSnapshot?
    let isStale: Bool
}

// MARK: - Sample data (placeholder / previews only)

private let sampleSnapshot = SharedSnapshot(
    netWorthThb: 1_252_430,
    todayPlThb: 12_840,
    totalAssetsThb: 1_402_430,
    totalLiabilitiesThb: 150_000,
    fx: 35.8,
    sparkline: (0..<30).map { i in 1_180_000 + Double(i) * 2_400 },
    displayCurrency: .usd,
    themeID: "sunset",
    updatedAt: .now
)

// MARK: - Provider

struct NetWorthProvider: TimelineProvider {
    private let snapshotStore = SharedSnapshotStore()

    func placeholder(in context: Context) -> NetWorthEntry {
        NetWorthEntry(date: .now, snapshot: sampleSnapshot, isStale: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (NetWorthEntry) -> Void) {
        let cached = snapshotStore.read()
        if context.isPreview {
            completion(NetWorthEntry(date: .now, snapshot: cached ?? sampleSnapshot, isStale: false))
        } else {
            completion(NetWorthEntry(date: .now, snapshot: cached, isStale: false))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NetWorthEntry>) -> Void) {
        let cached = snapshotStore.read()
        Task {
            let entry = await Self.fetchLiveOrFallback(cached: cached)
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(30 * 60))))
        }
    }

    /// Cached snapshot immediately available; try one live summary fetch to refresh the headline
    /// numbers. The sparkline (30-pt history) is only ever written by the app's `refreshAll`, so a
    /// live-only update keeps the cached sparkline and just refreshes the scalar totals.
    private static func fetchLiveOrFallback(cached: SharedSnapshot?) async -> NetWorthEntry {
        let config = AppConfig.fromBundle()
        let session = KeychainSessionStore(config: config)
        guard session.isAuthenticated else {
            return NetWorthEntry(date: .now, snapshot: cached, isStale: cached != nil)
        }
        let client = APIClient(config: config, session: session)
        do {
            let summary = try await client.get(.netWorthSummary(), as: NetWorthSummary.self)
            let merged = SharedSnapshot(
                netWorthThb: summary.netWorthThb,
                todayPlThb: summary.todayPlThb,
                totalAssetsThb: summary.totalAssetsThb,
                totalLiabilitiesThb: summary.totalLiabilitiesThb,
                fx: summary.fx,
                sparkline: cached?.sparkline ?? [],
                displayCurrency: cached?.displayCurrency ?? .usd,
                themeID: cached?.themeID ?? "sunset",
                updatedAt: .now
            )
            let store = SharedSnapshotStore()
            store.write(merged)
            return NetWorthEntry(date: .now, snapshot: merged, isStale: false)
        } catch {
            // 401, offline, or transport error — never wipe the cache, just flag it stale.
            return NetWorthEntry(date: .now, snapshot: cached, isStale: cached != nil)
        }
    }
}

// MARK: - Views

struct NetWorthWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: NetWorthEntry

    private var theme: Theme {
        Theme.palette(ThemeID(rawValue: entry.snapshot?.themeID ?? "sunset") ?? .sunset)
    }

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                content(snap)
            } else {
                emptyState
            }
        }
        .containerBackground(theme.swatchBg, for: .widget)
    }

    @ViewBuilder
    private func content(_ snap: SharedSnapshot) -> some View {
        let converter = CurrencyConverter(fx: snap.fx)
        let plColor = snap.todayPlThb >= 0 ? (theme.greens.first ?? .green) : (theme.reds.first ?? .red)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Net Worth")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if entry.isStale {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            MoneyText(thb: snap.netWorthThb, display: snap.displayCurrency, converter: converter,
                      primaryFont: .system(size: 21, weight: .bold, design: .rounded),
                      secondaryFont: .caption2, showSecondary: false)

            HStack(spacing: 4) {
                Image(systemName: snap.todayPlThb >= 0 ? "arrow.up.right" : "arrow.down.right")
                Text(plDeltaText(snap, converter: converter))
            }
            .badge(plColor)

            if family == .systemMedium, snap.sparkline.count >= 2 {
                Sparkline(values: snap.sparkline, lineColor: plColor, fillColor: plColor.opacity(0.15))
                    .frame(height: 32)
            }

            Spacer(minLength: 0)

            Text(snap.updatedAt, style: .relative)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Porto")
                .font(.caption.weight(.semibold))
            Text("เปิดแอปเพื่อซิงค์ข้อมูล")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func plDeltaText(_ snap: SharedSnapshot, converter: CurrencyConverter) -> String {
        let amt = converter.fromThb(snap.todayPlThb, to: snap.displayCurrency)
        let sign = amt >= 0 ? "+" : "-"
        return sign + MoneyFormat.format(abs(amt), snap.displayCurrency)
    }
}

// MARK: - Widget

struct NetWorthWidget: Widget {
    let kind = "NetWorthWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NetWorthProvider()) { entry in
            NetWorthWidgetView(entry: entry)
        }
        .configurationDisplayName("มูลค่าสุทธิ")
        .description("แสดงมูลค่าสินทรัพย์สุทธิและกำไร/ขาดทุนวันนี้")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

#Preview(as: .systemSmall) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: sampleSnapshot, isStale: false)
    NetWorthEntry(date: .now, snapshot: sampleSnapshot, isStale: true)
}

#Preview(as: .systemMedium) {
    NetWorthWidget()
} timeline: {
    NetWorthEntry(date: .now, snapshot: sampleSnapshot, isStale: false)
}
