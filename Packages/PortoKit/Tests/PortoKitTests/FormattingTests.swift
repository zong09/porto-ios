import XCTest
@testable import PortoKit

final class FormattingTests: XCTestCase {
    func testMoneyFormat2dpEnUS() {
        XCTAssertEqual(MoneyFormat.format(1234.5, .usd), "$1,234.50")
        XCTAssertEqual(MoneyFormat.format(1000000, .thb), "฿1,000,000.00")
    }

    func testCurrencyConverter() {
        let c = CurrencyConverter(fx: 36.5)
        XCTAssertEqual(c.convert(10, from: .usd, to: .thb), 365, accuracy: 0.001)
        XCTAssertEqual(c.convert(365, from: .thb, to: .usd), 10, accuracy: 0.001)
        XCTAssertEqual(c.convert(5, from: .usd, to: .usd), 5, accuracy: 0.001)
    }

    func testDualCurrencyDisplay() {
        let c = CurrencyConverter(fx: 36.5)
        // 3650 THB -> primary USD 100.00, secondary THB (3,650.00)
        let d = MoneyFormat.dual(thb: 3650, display: .usd, converter: c)
        XCTAssertEqual(d.primary, "$100.00")
        XCTAssertEqual(d.secondary, "(฿3,650.00)")
    }

    func testBangkokDateFormat() {
        // 2026-01-01T16:00:00Z == 2026-01-01 23:00 Asia/Bangkok (still same day)
        let date = Date(timeIntervalSince1970: 1_767_283_200) // 2026-01-01T16:00:00Z
        XCTAssertEqual(BangkokDate.string(from: date), "2026-01-01")
    }

    func testLocalizationLookup() {
        XCTAssertEqual(L10n.string("common.overview", .th), "ภาพรวม")
        XCTAssertEqual(L10n.string("common.overview", .en), "Overview")
        XCTAssertEqual(L10n.string("nonexistent.key", .en), "nonexistent.key")
    }
}
