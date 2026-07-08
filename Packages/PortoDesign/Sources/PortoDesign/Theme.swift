import SwiftUI
import PortoKit

/// A resolved color palette for one theme. Ported verbatim from the web
/// `frontend/src/utils/themes.ts` THEMES object (exact hex).
public struct Theme: Sendable {
    /// Neutral swatch/background tone.
    public let swatchBg: Color
    /// Portfolio / series colors (cycle by index % 6).
    public let palette: [Color]
    /// Portfolio card background tints.
    public let tints: [Color]
    /// P&L greens (gains).
    public let greens: [Color]
    /// P&L reds (losses).
    public let reds: [Color]
    /// Liability donut / sankey palette.
    public let debtPalette: [Color]
    /// Per asset-type accent color.
    public let typeColor: [AssetType: Color]

    public init(swatchBg: Color, palette: [Color], tints: [Color], greens: [Color],
                reds: [Color], debtPalette: [Color], typeColor: [AssetType: Color]) {
        self.swatchBg = swatchBg
        self.palette = palette
        self.tints = tints
        self.greens = greens
        self.reds = reds
        self.debtPalette = debtPalette
        self.typeColor = typeColor
    }

    /// A palette color for a series/portfolio index (cycles by index % 6).
    public func paletteColor(_ index: Int) -> Color {
        guard !palette.isEmpty else { return .gray }
        let i = ((index % palette.count) + palette.count) % palette.count
        return palette[i]
    }

    /// Resolve the palette for a theme id.
    public static func palette(_ id: ThemeID) -> Theme {
        switch id {
        case .sunset: return sunset
        case .ocean: return ocean
        case .berry: return berry
        }
    }

    // MARK: - Verbatim palettes (hex exact from themes.ts)

    public static let sunset = Theme(
        swatchBg: Color(hex: "#FAF5EC"),
        palette: ["#EC6530", "#FFAE6E", "#3AA9AC", "#E6A23C", "#C76B8E", "#5FBEC0"].map(Color.init(hex:)),
        tints: ["#FDE7DC", "#FFEEDD", "#DFF1F1", "#FBEBD3", "#F8E1E9", "#E4F6F6"].map(Color.init(hex:)),
        greens: ["#1E9396", "#3AA9AC", "#5FBEC0", "#8FDDDF", "#C4ECEC"].map(Color.init(hex:)),
        reds: ["#D8482A", "#F5A98F", "#F8CFC2"].map(Color.init(hex:)),
        debtPalette: ["#FFAE6E", "#E2542B", "#C73B22", "#FFC79A", "#C76B8E", "#A8341C"].map(Color.init(hex:)),
        typeColor: [
            .crypto: Color(hex: "#E6A23C"), .us: Color(hex: "#3AA9AC"), .th: Color(hex: "#FFAE6E"),
            .fund: Color(hex: "#C76B8E"), .deposit: Color(hex: "#C9B7A8"),
        ]
    )

    public static let ocean = Theme(
        swatchBg: Color(hex: "#F1F6F7"),
        palette: ["#0E8C8F", "#46C2C4", "#2E9E6B", "#3E8FD0", "#8A6FC0", "#D08A3C"].map(Color.init(hex:)),
        tints: ["#DCEFF0", "#E0F2F2", "#DFF1E8", "#E1EDF8", "#ECE6F6", "#FAEEDD"].map(Color.init(hex:)),
        greens: ["#2E9E6B", "#46B383", "#6FD3A2", "#A7E6C7", "#D2F2E2"].map(Color.init(hex:)),
        reds: ["#D8533C", "#EFA191", "#F6CCC1"].map(Color.init(hex:)),
        debtPalette: ["#46C2C4", "#3E8FD0", "#0E8C8F", "#97DEDF", "#8A6FC0", "#B5402C"].map(Color.init(hex:)),
        typeColor: [
            .crypto: Color(hex: "#D08A3C"), .us: Color(hex: "#3E8FD0"), .th: Color(hex: "#46C2C4"),
            .fund: Color(hex: "#8A6FC0"), .deposit: Color(hex: "#A9B8BA"),
        ]
    )

    public static let berry = Theme(
        swatchBg: Color(hex: "#FAF4F7"),
        palette: ["#C2316B", "#F072A0", "#7E5AA8", "#E0A23C", "#3FA6A0", "#E07A4E"].map(Color.init(hex:)),
        tints: ["#FBE3EC", "#FCE6F0", "#EEE6F4", "#FBEFD9", "#DFF1EF", "#FBEADF"].map(Color.init(hex:)),
        greens: ["#2E9E6B", "#46B383", "#7BD0A6", "#A9E4C6", "#D5F1E2"].map(Color.init(hex:)),
        reds: ["#D23B3B", "#E89393", "#F3C3C3"].map(Color.init(hex:)),
        debtPalette: ["#F072A0", "#E07A4E", "#C2316B", "#F7AEC8", "#7E5AA8", "#A82A2A"].map(Color.init(hex:)),
        typeColor: [
            .crypto: Color(hex: "#E0A23C"), .us: Color(hex: "#3FA6A0"), .th: Color(hex: "#F072A0"),
            .fund: Color(hex: "#7E5AA8"), .deposit: Color(hex: "#BCAAB4"),
        ]
    )
}

/// Display metadata (Thai) for each theme, verbatim from themes.ts `themeMeta`.
public struct ThemeMeta: Sendable, Hashable {
    public let name: String
    public let desc: String
    public init(name: String, desc: String) { self.name = name; self.desc = desc }
}

public extension Theme {
    /// Ordered theme ids (matches web `themeOrder`).
    static let order: [ThemeID] = [.sunset, .ocean, .berry]

    /// Name + Thai description for a theme id (web `themeMeta`).
    static func meta(_ id: ThemeID) -> ThemeMeta {
        switch id {
        case .sunset: return ThemeMeta(name: "Sunset", desc: "อบอุ่น · ส้ม–พีช–เทอร์ควอยซ์")
        case .ocean: return ThemeMeta(name: "Ocean", desc: "เย็นสบาย · ฟ้า–เขียวน้ำทะเล")
        case .berry: return ThemeMeta(name: "Berry", desc: "สดใส · ม่วงแดง–ชมพู")
        }
    }
}
