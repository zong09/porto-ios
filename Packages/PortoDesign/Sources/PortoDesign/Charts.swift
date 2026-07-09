import SwiftUI
import PortoKit
#if canImport(Charts)
import Charts
#endif

// MARK: - Date parsing helpers

private let ymdFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "Asia/Bangkok")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

public extension NetWorthHistoryItem {
    /// Parsed `date` ("YYYY-MM-DD") in Asia/Bangkok, or `.distantPast` if unparseable.
    var parsedDate: Date { ymdFormatter.date(from: date) ?? .distantPast }
}

// MARK: - Area net-worth history chart

/// Area chart of net worth over time. Accepts `(date, value)` points; a
/// convenience initializer maps `[NetWorthHistoryItem]` (net worth in THB).
public struct AreaHistoryChart: View {
    private let points: [(date: Date, value: Double)]
    private let lineColor: Color
    private let fillColor: Color

    public init(points: [(date: Date, value: Double)],
                lineColor: Color = .accentColor,
                fillColor: Color? = nil) {
        self.points = points
        self.lineColor = lineColor
        self.fillColor = fillColor ?? lineColor.opacity(0.18)
    }

    public init(history: [NetWorthHistoryItem],
                lineColor: Color = .accentColor,
                fillColor: Color? = nil) {
        self.init(points: history.map { ($0.parsedDate, $0.netWorthThb) },
                  lineColor: lineColor, fillColor: fillColor)
    }

    public var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                AreaMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(fillColor)
                    .interpolationMethod(.monotone)
                LineMark(x: .value("Date", p.date), y: .value("Value", p.value))
                    .foregroundStyle(lineColor)
                    .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        #else
        Sparkline(values: points.map(\.value), lineColor: lineColor, fillColor: fillColor)
        #endif
    }
}

// MARK: - Price history chart with avg-cost rule

/// Line chart of price history (`ChartDatapoint` with epoch-ms `t`). Draws a
/// dashed `RuleMark` at `avgCost` when provided.
public struct PriceHistoryChart: View {
    private let points: [ChartDatapoint]
    private let avgCost: Double?
    private let lineColor: Color
    private let ruleColor: Color

    public init(points: [ChartDatapoint], avgCost: Double? = nil,
                lineColor: Color = .accentColor, ruleColor: Color = .secondary) {
        self.points = points
        self.avgCost = avgCost
        self.lineColor = lineColor
        self.ruleColor = ruleColor
    }

    private func date(_ t: Double) -> Date { Date(timeIntervalSince1970: t / 1000) }

    public var body: some View {
        #if canImport(Charts)
        Chart {
            ForEach(Array(points.enumerated()), id: \.offset) { _, p in
                LineMark(x: .value("Date", date(p.t)), y: .value("Price", p.p))
                    .foregroundStyle(lineColor)
                    .interpolationMethod(.monotone)
            }
            if let avg = avgCost, avg > 0 {
                RuleMark(y: .value("Avg cost", avg))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(ruleColor)
                    .annotation(position: .top, alignment: .leading) {
                        Text(MoneyFormat.number(avg))
                            .font(.system(size: 9)).foregroundStyle(ruleColor)
                    }
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        #else
        Sparkline(values: points.map(\.p), lineColor: lineColor)
        #endif
    }
}

// MARK: - Sparkline (Charts-free; widget-safe)

/// Lightweight sparkline built from a plain `Path` — no axes, no Charts
/// dependency, so it is safe to use inside the widget extension.
public struct Sparkline: View {
    private let values: [Double]
    private let lineColor: Color
    private let fillColor: Color?
    private let lineWidth: CGFloat

    public init(values: [Double], lineColor: Color = .accentColor,
                fillColor: Color? = nil, lineWidth: CGFloat = 1.5) {
        self.values = values
        self.lineColor = lineColor
        self.fillColor = fillColor
        self.lineWidth = lineWidth
    }

    public var body: some View {
        GeometryReader { geo in
            let pts = normalizedPoints(in: geo.size)
            if pts.count >= 2 {
                if let fill = fillColor {
                    areaPath(pts, size: geo.size).fill(fill)
                }
                linePath(pts)
                    .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth,
                                                          lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func normalizedPoints(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = maxV - minV
        let stepX = size.width / CGFloat(values.count - 1)
        return values.enumerated().map { i, v in
            let x = CGFloat(i) * stepX
            let ny = range > 0 ? CGFloat((v - minV) / range) : 0.5
            let y = size.height - ny * size.height
            return CGPoint(x: x, y: y)
        }
    }

    private func linePath(_ pts: [CGPoint]) -> Path {
        var p = Path()
        p.move(to: pts[0])
        for pt in pts.dropFirst() { p.addLine(to: pt) }
        return p
    }

    private func areaPath(_ pts: [CGPoint], size: CGSize) -> Path {
        var p = linePath(pts)
        p.addLine(to: CGPoint(x: pts.last!.x, y: size.height))
        p.addLine(to: CGPoint(x: pts.first!.x, y: size.height))
        p.closeSubpath()
        return p
    }
}

// MARK: - Stacked allocation bar

/// A single horizontal bar split into proportional colored segments.
public struct StackedAllocationBar: View {
    public struct Segment: Identifiable {
        public let id = UUID()
        public let value: Double
        public let color: Color
        public init(value: Double, color: Color) { self.value = value; self.color = color }
    }

    private let segments: [Segment]
    private let height: CGFloat
    private let cornerRadius: CGFloat

    public init(segments: [(value: Double, color: Color)],
                height: CGFloat = 10, cornerRadius: CGFloat = 5) {
        self.segments = segments.map { Segment(value: $0.value, color: $0.color) }
        self.height = height
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        let total = max(segments.reduce(0) { $0 + max(0, $1.value) }, 0.0000001)
        GeometryReader { geo in
            HStack(spacing: 0) {
                ForEach(segments) { seg in
                    Rectangle()
                        .fill(seg.color)
                        .frame(width: geo.size.width * CGFloat(max(0, seg.value) / total))
                }
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
