import SwiftUI

/// Parse a `#RRGGBB` (or `RRGGBB` / `#RGB` / `#RRGGBBAA`) hex string into sRGB
/// components. Verbatim-friendly companion to the web themes (which use 6-digit hex).
@inline(__always)
func hexComponents(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    // Expand 3-digit shorthand (#abc -> #aabbcc)
    if s.count == 3 {
        s = s.map { "\($0)\($0)" }.joined()
    }
    var value: UInt64 = 0
    Scanner(string: s).scanHexInt64(&value)
    let r, g, b, a: Double
    switch s.count {
    case 8: // RRGGBBAA
        r = Double((value & 0xFF00_0000) >> 24) / 255
        g = Double((value & 0x00FF_0000) >> 16) / 255
        b = Double((value & 0x0000_FF00) >> 8) / 255
        a = Double(value & 0x0000_00FF) / 255
    default: // RRGGBB (and any fallthrough)
        r = Double((value & 0xFF0000) >> 16) / 255
        g = Double((value & 0x00FF00) >> 8) / 255
        b = Double(value & 0x0000FF) / 255
        a = 1
    }
    return (r, g, b, a)
}

public extension Color {
    /// Build a Color from a web-style hex string, e.g. `Color(hex: "#EC6530")`.
    init(hex: String) {
        let c = hexComponents(hex)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }
}
