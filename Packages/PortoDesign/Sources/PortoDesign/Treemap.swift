import SwiftUI

/// A squarified treemap. Provide `(value, color, label)` items and an optional
/// `minFrac` floor so tiny slices stay legible (via `redistributeAreas`).
public struct Treemap<Item>: View {
    public struct Cell: Identifiable {
        public let id = UUID()
        public let value: Double
        public let color: Color
        public let label: String
        public let secondary: String?
        public let item: Item
        public init(value: Double, color: Color, label: String,
                    secondary: String? = nil, item: Item) {
            self.value = value; self.color = color; self.label = label
            self.secondary = secondary; self.item = item
        }
    }

    private let cells: [Cell]
    private let minFrac: Double
    private let onTap: ((Item) -> Void)?

    public init(cells: [Cell], minFrac: Double = 0.03, onTap: ((Item) -> Void)? = nil) {
        self.cells = cells
        self.minFrac = minFrac
        self.onTap = onTap
    }

    public var body: some View {
        GeometryReader { geo in
            let area = Double(geo.size.width * geo.size.height)
            let areas = redistributeAreas(cells.map { max(0, $0.value) },
                                          totalArea: area, minFrac: minFrac)
            let items = zip(areas, cells).map { (area: $0.0, data: $0.1) }
            let laid = squarify(items, rect: CGRect(origin: .zero, size: geo.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(laid.enumerated()), id: \.offset) { _, entry in
                    cellView(entry.data, rect: entry.rect)
                }
            }
        }
    }

    @ViewBuilder
    private func cellView(_ cell: Cell, rect: CGRect) -> some View {
        let w = max(0, rect.size.width - 2)
        let h = max(0, rect.size.height - 2)
        RoundedRectangle(cornerRadius: 6)
            .fill(cell.color)
            .frame(width: w, height: h)
            .overlay(alignment: .topLeading) {
                if w > 44 && h > 28 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(cell.label).font(.caption2).fontWeight(.semibold)
                            .lineLimit(1).minimumScaleFactor(0.7)
                        if let s = cell.secondary {
                            Text(s).font(.system(size: 9))
                                .lineLimit(1).minimumScaleFactor(0.7).opacity(0.85)
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(6)
                }
            }
            .offset(x: rect.origin.x + 1, y: rect.origin.y + 1)
            .onTapGesture { onTap?(cell.item) }
    }
}
