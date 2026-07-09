import CoreGraphics

private struct SquarifyRect { var x: Double; var y: Double; var w: Double; var h: Double }

/// Squarified treemap layout. Ported 1:1 from the web
/// `frontend/src/pages/Overview.tsx` `squarify` function.
///
/// - Parameters:
///   - items: `(area, data)` pairs. Areas are laid out largest-first.
///   - rect: the bounding rectangle to fill.
/// - Returns: one `(rect, data)` per input item; total area is conserved.
public func squarify<T>(_ items: [(area: Double, data: T)], rect: CGRect)
    -> [(rect: CGRect, data: T)] {
    var out: [(rect: CGRect, data: T)] = []

    // worst aspect ratio for a row of `areas` laid along a side of length `side`
    func worst(_ areas: [Double], _ side: Double) -> Double {
        var mx = -Double.infinity
        var mn = Double.infinity
        var sum = 0.0
        for a in areas {
            sum += a
            if a > mx { mx = a }
            if a < mn { mn = a }
        }
        let s2 = side * side
        let sum2 = sum * sum
        return Swift.max((s2 * mx) / sum2, sum2 / (s2 * mn))
    }

        // lay a completed row into `r`, returning the leftover rect
    func lay(_ row: [(area: Double, data: T)], _ r: SquarifyRect) -> SquarifyRect {
        let sum = row.reduce(0.0) { $0 + $1.area }
        if r.w <= r.h {
            let rh = sum / r.w
            var cx = r.x
            for o in row {
                let tw = o.area / rh
                out.append((CGRect(x: cx, y: r.y, width: tw, height: rh), o.data))
                cx += tw
            }
            return SquarifyRect(x: r.x, y: r.y + rh, w: r.w, h: Swift.max(0, r.h - rh))
        }
        let rw = sum / r.h
        var cy = r.y
        for o in row {
            let th = o.area / rw
            out.append((CGRect(x: r.x, y: cy, width: rw, height: th), o.data))
            cy += th
        }
        return SquarifyRect(x: r.x + rw, y: r.y, w: Swift.max(0, r.w - rw), h: r.h)
    }

    var r = SquarifyRect(x: rect.origin.x, y: rect.origin.y, w: rect.size.width, h: rect.size.height)
    // stable descending sort by area (JS Array.sort is stable)
    var queue = items.enumerated()
        .sorted { $0.element.area != $1.element.area ? $0.element.area > $1.element.area : $0.offset < $1.offset }
        .map { $0.element }
    var row: [(area: Double, data: T)] = []
    while !queue.isEmpty {
        let next = queue[0]
        let side = Swift.max(0.01, Swift.min(r.w, r.h))
        let cur = row.map { $0.area }
        if row.isEmpty || worst(cur, side) >= worst(cur + [next.area], side) {
            row.append(next)
            queue.removeFirst()
        } else {
            r = lay(row, r)
            row = []
        }
    }
    if !row.isEmpty { _ = lay(row, r) }
    return out
}

/// Give every item at least `minFrac` of `totalArea` so tiny slices stay legible;
/// the deficit is taken proportionally from the remaining (larger) items.
/// Ported 1:1 from `frontend/src/pages/Overview.tsx` `redistributeAreas`.
public func redistributeAreas(_ values: [Double], totalArea: Double, minFrac: Double) -> [Double] {
    let total = values.reduce(0.0, +)
    let n = values.count
    if total <= 0 || n == 0 { return values.map { _ in 0 } }
    let minArea = Swift.min(totalArea * minFrac, totalArea / Double(n))
    var pinned = values.map { _ in false }
    var areas = values.map { ($0 / total) * totalArea }
    for _ in 0..<n {
        var changed = false
        for i in areas.indices where !pinned[i] && areas[i] < minArea {
            pinned[i] = true
            changed = true
        }
        if !changed { break }
        let pinnedCount = pinned.filter { $0 }.count
        let freeArea = totalArea - Double(pinnedCount) * minArea
        let freeValue = values.indices.reduce(0.0) { $0 + (pinned[$1] ? 0 : values[$1]) }
        areas = values.indices.map { i in
            pinned[i] ? minArea : (freeValue > 0 ? (values[i] / freeValue) * freeArea : 0)
        }
    }
    return areas
}
