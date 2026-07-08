import XCTest
import CoreGraphics
import SwiftUI
@testable import PortoDesign
import PortoKit

final class PortoDesignTests: XCTestCase {
    // Wave-0 invariant: theme id order is stable.
    func testThemeIDStable() {
        XCTAssertEqual(ThemeID.allCases.map(\.rawValue), ["sunset", "ocean", "berry"])
    }
}

// MARK: - Theme

final class ThemeTests: XCTestCase {
    func testSunsetExactHex() {
        let sunset = Theme.palette(.sunset)
        XCTAssertEqual(sunset.palette[0], Color(hex: "#EC6530"))
        XCTAssertEqual(sunset.swatchBg, Color(hex: "#FAF5EC"))
        XCTAssertEqual(sunset.typeColor[.crypto], Color(hex: "#E6A23C"))
    }

    func testHexComponentsExact() {
        let c = hexComponents("#EC6530")
        XCTAssertEqual(c.r, 236.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.g, 101.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.b, 48.0 / 255, accuracy: 1e-9)
        XCTAssertEqual(c.a, 1.0, accuracy: 1e-9)
    }

    func testPaletteSizesAndMeta() {
        for id in Theme.order {
            let t = Theme.palette(id)
            XCTAssertEqual(t.palette.count, 6)
            XCTAssertEqual(t.typeColor.count, 5)
        }
        XCTAssertEqual(Theme.meta(.sunset).name, "Sunset")
        XCTAssertEqual(Theme.meta(.ocean).desc, "เย็นสบาย · ฟ้า–เขียวน้ำทะเล")
    }

    func testPaletteCyclesByModulo() {
        let t = Theme.palette(.ocean)
        XCTAssertEqual(t.paletteColor(6), t.paletteColor(0))
        XCTAssertEqual(t.paletteColor(7), t.paletteColor(1))
    }
}

// MARK: - Squarify

final class SquarifyTests: XCTestCase {
    func testTotalAreaConservedAndWithinBounds() {
        let rect = CGRect(x: 0, y: 0, width: 200, height: 100)
        let items: [(area: Double, data: Int)] = [
            (10000, 1), (5000, 2), (2500, 3), (1500, 4), (1000, 5),
        ]
        // Total input area == rect area for a clean conservation check.
        let total = items.reduce(0) { $0 + $1.area }
        XCTAssertEqual(total, Double(rect.width * rect.height), accuracy: 1e-6)

        let out = squarify(items, rect: rect)
        XCTAssertEqual(out.count, items.count)

        let laidArea = out.reduce(0.0) { $0 + Double($1.rect.width * $1.rect.height) }
        XCTAssertEqual(laidArea, total, accuracy: 1e-6)

        for entry in out {
            XCTAssertGreaterThanOrEqual(entry.rect.minX, rect.minX - 1e-6)
            XCTAssertGreaterThanOrEqual(entry.rect.minY, rect.minY - 1e-6)
            XCTAssertLessThanOrEqual(entry.rect.maxX, rect.maxX + 1e-6)
            XCTAssertLessThanOrEqual(entry.rect.maxY, rect.maxY + 1e-6)
        }
    }

    func testDeterministicOrderLargestFirst() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let items: [(area: Double, data: String)] = [
            (10, "small"), (50, "big"), (25, "mid"),
        ]
        let a = squarify(items, rect: rect).map { $0.data }
        let b = squarify(items, rect: rect).map { $0.data }
        XCTAssertEqual(a, b) // deterministic
        // largest area laid first
        XCTAssertEqual(a.first, "big")
    }

    func testRedistributeSumEqualsTotalAndFloor() {
        let values = [100.0, 1.0, 1.0, 1.0]
        let totalArea = 1000.0
        let minFrac = 0.1
        let out = redistributeAreas(values, totalArea: totalArea, minFrac: minFrac)
        XCTAssertEqual(out.reduce(0, +), totalArea, accuracy: 1e-6)
        let minArea = min(totalArea * minFrac, totalArea / Double(values.count))
        for a in out {
            XCTAssertGreaterThanOrEqual(a, minArea - 1e-6)
        }
    }

    func testRedistributeEmptyAndZero() {
        XCTAssertEqual(redistributeAreas([], totalArea: 100, minFrac: 0.1), [])
        XCTAssertEqual(redistributeAreas([0, 0], totalArea: 100, minFrac: 0.1), [0, 0])
    }
}

// MARK: - Sankey

final class SankeyTests: XCTestCase {
    func testClampedHeightsSumWithinAvailAndFloor() {
        let values = [100.0, 2.0, 2.0]
        let avail = 200.0
        let minH = 30.0
        let out = clampedHeights(values, avail: avail, minH: minH)
        XCTAssertLessThanOrEqual(out.reduce(0, +), avail + 1e-6)
        let positive = values.filter { $0 > 0 }.count
        let effMin = min(minH, avail / Double(positive))
        for (v, h) in zip(values, out) where v > 0 {
            XCTAssertGreaterThanOrEqual(h, effMin - 1e-6)
        }
    }

    func testClampedHeightsZeroInput() {
        XCTAssertEqual(clampedHeights([0, 0, 0], avail: 100, minH: 10), [0, 0, 0])
        XCTAssertEqual(clampedHeights([], avail: 100, minH: 10), [])
    }

    func testClampedHeightsNegativeGetsZero() {
        let out = clampedHeights([-5, 10], avail: 100, minH: 10)
        XCTAssertEqual(out[0], 0)
        XCTAssertGreaterThan(out[1], 0)
    }

    func testComputeSankeyEmptyReturnsEmpty() {
        let empty = SankeyInput(left: [], right: [], flows: [], SW: 300, SH: 200, LX: 20, RX: 260)
        let r = computeSankey(empty)
        XCTAssertTrue(r.ribbons.isEmpty)
        XCTAssertTrue(r.left.isEmpty)
        XCTAssertTrue(r.right.isEmpty)
    }

    func testComputeSankeyZeroTotalReturnsEmpty() {
        let input = SankeyInput(
            left: [SankeySideNode(label: "A", color: "#EC6530", value: 0)],
            right: [SankeySideNode(label: "B", color: "#3AA9AC", value: 0)],
            flows: [SankeyFlow(leftIndex: 0, rightIndex: 0, value: 0)],
            SW: 300, SH: 200, LX: 20, RX: 260)
        let r = computeSankey(input)
        XCTAssertTrue(r.ribbons.isEmpty)
    }

    func testComputeSankeyProducesGeometry() {
        let input = SankeyInput(
            left: [
                SankeySideNode(label: "Crypto", color: "#EC6530", value: 60),
                SankeySideNode(label: "US", color: "#3AA9AC", value: 40),
            ],
            right: [
                SankeySideNode(label: "Port A", color: "#FFAE6E", value: 70),
                SankeySideNode(label: "Port B", color: "#C76B8E", value: 30),
            ],
            flows: [
                SankeyFlow(leftIndex: 0, rightIndex: 0, value: 40),
                SankeyFlow(leftIndex: 0, rightIndex: 1, value: 20),
                SankeyFlow(leftIndex: 1, rightIndex: 0, value: 30),
                SankeyFlow(leftIndex: 1, rightIndex: 1, value: 10),
            ],
            SW: 300, SH: 200, LX: 20, RX: 260)
        let r = computeSankey(input)
        XCTAssertEqual(r.left.count, 2)
        XCTAssertEqual(r.right.count, 2)
        XCTAssertEqual(r.ribbons.count, 4)
        for ribbon in r.ribbons {
            XCTAssertTrue(ribbon.d.hasPrefix("M"))
            XCTAssertTrue(ribbon.d.hasSuffix("Z"))
        }
    }
}
