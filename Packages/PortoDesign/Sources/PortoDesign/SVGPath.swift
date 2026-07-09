import SwiftUI

/// Minimal parser for the absolute SVG path commands emitted by `computeSankey`
/// (`M`, `C`, `L`, `Z`). Coordinates are in viewBox units and mapped through
/// `scale` (viewBox -> view space).
enum SVGPath {
    static func path(_ d: String, scaleX: CGFloat, scaleY: CGFloat) -> Path {
        var path = Path()
        // Tokenize: split on commands, keep numbers.
        var numbers: [CGFloat] = []
        var command: Character?
        func pt(_ i: Int) -> CGPoint {
            CGPoint(x: numbers[i] * scaleX, y: numbers[i + 1] * scaleY)
        }
        func flush() {
            guard let c = command else { return }
            switch c {
            case "M": if numbers.count >= 2 { path.move(to: pt(0)) }
            case "L": if numbers.count >= 2 { path.addLine(to: pt(0)) }
            case "C":
                if numbers.count >= 6 {
                    path.addCurve(to: pt(4), control1: pt(0), control2: pt(2))
                }
            case "Z", "z": path.closeSubpath()
            default: break
            }
            numbers.removeAll(keepingCapacity: true)
        }
        var current = ""
        func pushNumber() {
            if !current.isEmpty, let v = Double(current) { numbers.append(CGFloat(v)) }
            current = ""
        }
        for ch in d {
            if ch == "M" || ch == "L" || ch == "C" || ch == "Z" || ch == "z" {
                pushNumber()
                flush()
                command = ch
                if ch == "Z" || ch == "z" { flush(); command = nil }
            } else if ch == "," || ch == " " {
                pushNumber()
            } else if ch == "-" && !current.isEmpty {
                // negative sign begins a new number
                pushNumber()
                current.append(ch)
            } else {
                current.append(ch)
            }
        }
        pushNumber()
        flush()
        return path
    }

    /// Parse a `"12.5%"` string to a 0..1 fraction.
    static func percent(_ s: String) -> CGFloat {
        let trimmed = s.hasSuffix("%") ? String(s.dropLast()) : s
        return CGFloat(Double(trimmed) ?? 0) / 100
    }
}
