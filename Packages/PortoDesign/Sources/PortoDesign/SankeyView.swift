import SwiftUI

/// Renders a bipartite Sankey from a `SankeyInput` using `computeSankey`.
/// Ribbons are drawn as filled cubic-bezier paths; node bars + labels are
/// positioned from the percentage geometry.
public struct SankeyView: View {
    private let input: SankeyInput
    private let result: SankeyResult

    public init(_ input: SankeyInput) {
        self.input = input
        self.result = computeSankey(input)
    }

    public var body: some View {
        GeometryReader { geo in
            let sx = geo.size.width / CGFloat(input.SW)
            let sy = geo.size.height / CGFloat(input.SH)
            ZStack(alignment: .topLeading) {
                // Ribbons
                ForEach(Array(result.ribbons.enumerated()), id: \.offset) { _, r in
                    SVGPath.path(r.d, scaleX: sx, scaleY: sy)
                        .fill(Color(hex: r.fill).opacity(0.55))
                }
                // Node bars + labels
                nodes(result.left, size: geo.size, labelTrailing: false)
                nodes(result.right, size: geo.size, labelTrailing: true)
            }
        }
    }

    @ViewBuilder
    private func nodes(_ geos: [SankeyNodeGeo], size: CGSize, labelTrailing: Bool) -> some View {
        ForEach(Array(geos.enumerated()), id: \.offset) { _, n in
            let bx = SVGPath.percent(n.bar.left) * size.width
            let by = SVGPath.percent(n.bar.top) * size.height
            let bw = SVGPath.percent(n.bar.width) * size.width
            let bh = SVGPath.percent(n.bar.height) * size.height
            let lx = SVGPath.percent(n.labelBox.left) * size.width
            let ly = SVGPath.percent(n.labelBox.top) * size.height
            let lw = SVGPath.percent(n.labelBox.width) * size.width
            let lh = SVGPath.percent(n.labelBox.height) * size.height

            RoundedRectangle(cornerRadius: 2)
                .fill(Color(hex: n.color))
                .frame(width: bw, height: bh)
                .offset(x: bx, y: by)

            VStack(alignment: labelTrailing ? .leading : .trailing, spacing: 1) {
                Text(n.label)
                    .font(.caption2).fontWeight(.semibold)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let sub = n.sub {
                    Text(sub).font(.system(size: 9)).foregroundStyle(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            .frame(width: max(0, lw), height: max(0, lh),
                   alignment: labelTrailing ? .leading : .trailing)
            .offset(x: lx, y: ly)
        }
    }
}
