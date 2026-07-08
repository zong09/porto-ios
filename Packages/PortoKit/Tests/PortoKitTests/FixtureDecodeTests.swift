import XCTest
@testable import PortoKit

/// Decodes GET responses captured from the LIVE backend (`make fixtures`) into Contract models.
/// Assertions are value-agnostic (data changes per demo seed): they prove the shapes decode and
/// basic invariants hold, not specific numbers.
final class FixtureDecodeTests: XCTestCase {
    private func load(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"),
                                "missing fixture \(name).json")
        return try Data(contentsOf: url)
    }

    func testPortfoliosDecode() throws {
        let p = try JSONDecoder().decode([Portfolio].self, from: load("portfolios"))
        for pf in p { XCTAssertTrue((0...5).contains(pf.color)) }
    }

    func testAssetsEnrichedDecode() throws {
        let a = try JSONDecoder().decode([Asset].self, from: load("assets"))
        for asset in a {
            XCTAssertFalse(asset.symbol.isEmpty)
            if let q = asset.position?.quantity { XCTAssertTrue(q.isFinite) }
        }
    }

    func testTransactionsDecode() throws {
        // Backend sends quantity/price/fee as strings — flexible decode must yield real Doubles.
        let t = try JSONDecoder().decode([Transaction].self, from: load("transactions"))
        for tx in t {
            XCTAssertTrue(tx.quantity.isFinite)
            XCTAssertTrue(tx.price.isFinite)
            XCTAssertTrue(tx.fee.isFinite)
        }
    }

    func testStringNumericDecodesToDouble() throws {
        let json = #"[{"id":"t","assetId":"a","side":"buy","quantity":"18","price":"189.5","fee":"0","date":"2026-06-01"}]"#.data(using: .utf8)!
        let t = try JSONDecoder().decode([Transaction].self, from: json)
        XCTAssertEqual(t[0].quantity, 18, accuracy: 0.0001)
        XCTAssertEqual(t[0].price, 189.5, accuracy: 0.0001)
    }

    func testLiabilitiesDecode() throws {
        let l = try JSONDecoder().decode([Liability].self, from: load("liabilities"))
        for liab in l { XCTAssertTrue(liab.amount.isFinite) }
        let lt = try JSONDecoder().decode([LiabilityTransaction].self, from: load("liability-transactions"))
        for tx in lt { XCTAssertTrue(tx.amount.isFinite) }
    }

    func testSummaryAndHistoryDecode() throws {
        let s = try JSONDecoder().decode(NetWorthSummary.self, from: load("net-worth-summary"))
        XCTAssertTrue(s.fx > 0)
        XCTAssertTrue(s.netWorthThb.isFinite)
        let h = try JSONDecoder().decode([NetWorthHistoryItem].self, from: load("net-worth-history"))
        for pt in h { XCTAssertFalse(pt.date.isEmpty) }
    }

    func testAuthFixtures() throws {
        _ = try JSONDecoder().decode(AuthConfig.self, from: load("auth-config"))
        let me = try JSONDecoder().decode(MePayload.self, from: load("me"))
        XCTAssertFalse(me.userId.isEmpty)
    }
}
