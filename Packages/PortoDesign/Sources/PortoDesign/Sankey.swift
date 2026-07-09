import CoreGraphics
import Foundation

// Bipartite Sankey geometry — ported 1:1 from the web `frontend/src/utils/sankey.ts`.
// Ribbons are emitted as SVG-path `d` strings in viewBox units (0..SW, 0..SH).
// Node bars/labels are emitted as percentage box styles.

public struct SankeySideNode: Sendable, Hashable {
    public let label: String
    public let sub: String?
    public let color: String
    public let value: Double
    public init(label: String, sub: String? = nil, color: String, value: Double) {
        self.label = label; self.sub = sub; self.color = color; self.value = value
    }
}

public struct SankeyFlow: Sendable, Hashable {
    public let leftIndex: Int
    public let rightIndex: Int
    public let value: Double
    public init(leftIndex: Int, rightIndex: Int, value: Double) {
        self.leftIndex = leftIndex; self.rightIndex = rightIndex; self.value = value
    }
}

public struct SankeyInput: Sendable {
    public var left: [SankeySideNode]
    public var right: [SankeySideNode]
    public var flows: [SankeyFlow]
    public var SW: Double
    public var SH: Double
    public var LX: Double
    public var RX: Double
    public var NODEW: Double?
    public var GAP: Double?
    /// Minimum node height in viewBox units so tiny values stay legible.
    public var MINH: Double?
    public init(left: [SankeySideNode], right: [SankeySideNode], flows: [SankeyFlow],
                SW: Double, SH: Double, LX: Double, RX: Double,
                NODEW: Double? = nil, GAP: Double? = nil, MINH: Double? = nil) {
        self.left = left; self.right = right; self.flows = flows
        self.SW = SW; self.SH = SH; self.LX = LX; self.RX = RX
        self.NODEW = NODEW; self.GAP = GAP; self.MINH = MINH
    }
}

/// Box styles as percentage strings (e.g. `"12.5%"`), matching the web output.
public struct SankeyBox: Sendable, Hashable {
    public let left: String
    public let top: String
    public let width: String
    public let height: String
}

public struct SankeyRibbon: Sendable, Hashable {
    public let d: String
    public let fill: String
}

public struct SankeyNodeGeo: Sendable, Hashable {
    public let label: String
    public let sub: String?
    public let color: String
    public let bar: SankeyBox
    public let labelBox: SankeyBox
}

public struct SankeyResult: Sendable, Hashable {
    public let ribbons: [SankeyRibbon]
    public let left: [SankeyNodeGeo]
    public let right: [SankeyNodeGeo]
}

/// Distributes `avail` height across values proportionally, but no positive
/// value renders below `minH` — clamped nodes take minH and the rest rescale
/// into the remaining space. Zero/negative values get zero height.
/// Ported 1:1 from `clampedHeights` in sankey.ts.
public func clampedHeights(_ values: [Double], avail: Double, minH: Double) -> [Double] {
    let positive = values.filter { $0 > 0 }.count
    if positive == 0 { return values.map { _ in 0 } }
    let effMin = Swift.min(minH, avail / Double(positive))
    var clamped = values.map { _ in false }
    while true {
        let freeVal = values.indices.reduce(0.0) { acc, i in
            (values[i] > 0 && !clamped[i]) ? acc + values[i] : acc
        }
        let freeAvail = avail - Double(clamped.filter { $0 }.count) * effMin
        let scale = freeVal > 0 ? freeAvail / freeVal : 0
        var changed = false
        for i in values.indices where values[i] > 0 && !clamped[i] && values[i] * scale < effMin {
            clamped[i] = true
            changed = true
        }
        if !changed {
            return values.indices.map { i in
                if values[i] <= 0 { return 0 }
                return clamped[i] ? effMin : values[i] * scale
            }
        }
    }
}

/// Compute bipartite Sankey geometry. Ported 1:1 from `computeSankey` in sankey.ts.
public func computeSankey(_ input: SankeyInput) -> SankeyResult {
    let left = input.left, right = input.right, flows = input.flows
    let SW = input.SW, SH = input.SH
    let NODEW = input.NODEW ?? 13
    let GAP = input.GAP ?? 14
    let MINH = input.MINH ?? 30
    let LX = input.LX, RX = input.RX

    let total = left.reduce(0.0) { $0 + $1.value }
    var ribbons: [SankeyRibbon] = []
    var leftGeo: [SankeyNodeGeo] = []
    var rightGeo: [SankeyNodeGeo] = []

    if total <= 0 || left.isEmpty || right.isEmpty {
        return SankeyResult(ribbons: ribbons, left: leftGeo, right: rightGeo)
    }

    let PADDING_Y = 20.0
    let availSH = SH - PADDING_Y * 2
    let lH = clampedHeights(left.map { $0.value }, avail: availSH - GAP * Double(left.count - 1), minH: MINH)
    let rH = clampedHeights(right.map { $0.value }, avail: availSH - GAP * Double(right.count - 1), minH: MINH)

    func px(_ v: Double) -> String { "\((v / SW) * 100)%" }
    func py(_ v: Double) -> String { "\((v / SH) * 100)%" }

    // left node geometry (vertically centered block)
    let lTotalH = lH.reduce(0.0, +)
    var ly = (SH - (lTotalH + GAP * Double(left.count - 1))) / 2
    var lTop: [Double] = []
    var lCursor: [Double] = []
    for i in left.indices {
        lTop.append(ly)
        lCursor.append(ly)
        ly += lH[i] + GAP
    }

    // right node geometry
    let rTotalH = rH.reduce(0.0, +)
    var ry = (SH - (rTotalH + GAP * Double(right.count - 1))) / 2
    var rTop: [Double] = []
    var rCursor: [Double] = []
    for i in right.indices {
        rTop.append(ry)
        rCursor.append(ry)
        ry += rH[i] + GAP
    }

    // Ribbon end thicknesses distributed within each node independently.
    let RIBBON_MINH = 1.5
    var orderedFlows: [(li: Int, ri: Int, value: Double)] = []
    for li in left.indices {
        for ri in right.indices {
            guard let flow = flows.first(where: { $0.leftIndex == li && $0.rightIndex == ri }),
                  flow.value > 0 else { continue }
            orderedFlows.append((li, ri, flow.value))
        }
    }
    func endHeights(_ side: WritableKeyPath<(li: Int, ri: Int, value: Double), Int>, _ index: Int, _ nodeH: Double)
        -> [String: Double] {
        let segs = orderedFlows.filter { $0[keyPath: side] == index }
        let heights = clampedHeights(segs.map { $0.value }, avail: nodeH, minH: RIBBON_MINH)
        var map: [String: Double] = [:]
        for (i, f) in segs.enumerated() { map["\(f.li)-\(f.ri)"] = heights[i] }
        return map
    }
    let lEnd = left.indices.map { endHeights(\.li, $0, lH[$0]) }
    let rEnd = right.indices.map { endHeights(\.ri, $0, rH[$0]) }

    for f in orderedFlows {
        let key = "\(f.li)-\(f.ri)"
        let sh = lEnd[f.li][key] ?? 0
        let th = rEnd[f.ri][key] ?? 0
        let s0 = lCursor[f.li]
        let s1 = s0 + sh
        let t0 = rCursor[f.ri]
        let t1 = t0 + th
        lCursor[f.li] = s1
        rCursor[f.ri] = t1
        let x0 = LX + NODEW
        let x1 = RX
        let xc = (x0 + x1) / 2
        let d = "M\(x0),\(s0) C\(xc),\(s0) \(xc),\(t0) \(x1),\(t0)"
            + " L\(x1),\(t1) C\(xc),\(t1) \(xc),\(s1) \(x0),\(s1) Z"
        ribbons.append(SankeyRibbon(d: d, fill: left[f.li].color))
    }

    for i in left.indices {
        let n = left[i]
        leftGeo.append(SankeyNodeGeo(
            label: n.label, sub: n.sub, color: n.color,
            bar: SankeyBox(left: px(LX), top: py(lTop[i]), width: px(NODEW), height: py(lH[i])),
            labelBox: SankeyBox(left: "0", top: py(lTop[i]), width: px(LX - 8), height: py(lH[i]))
        ))
    }
    for i in right.indices {
        let n = right[i]
        rightGeo.append(SankeyNodeGeo(
            label: n.label, sub: n.sub, color: n.color,
            bar: SankeyBox(left: px(RX), top: py(rTop[i]), width: px(NODEW), height: py(rH[i])),
            labelBox: SankeyBox(left: px(RX + NODEW + 8), top: py(rTop[i]),
                                width: px(SW - RX - NODEW - 8), height: py(rH[i]))
        ))
    }

    return SankeyResult(ribbons: ribbons, left: leftGeo, right: rightGeo)
}
