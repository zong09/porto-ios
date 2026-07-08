import XCTest
@testable import PortoKit

/// Wave 0 smoke test — proves the Contract models decode. Wave 1A replaces/extends this with
/// fixture-driven decode + invalidation-graph tests.
final class ContractDecodeTests: XCTestCase {
    func testSummaryDecodes() throws {
        let json = """
        {"totalAssetsThb":1000.5,"totalLiabilitiesThb":200,"netWorthThb":800.5,
         "todayPlThb":12.3,"totalCostThb":900,"fx":36.5}
        """.data(using: .utf8)!
        let s = try JSONDecoder().decode(NetWorthSummary.self, from: json)
        XCTAssertEqual(s.netWorthThb, 800.5, accuracy: 0.0001)
        XCTAssertEqual(s.fx, 36.5, accuracy: 0.0001)
    }

    func testErrorBodyDecodesStringOrArray() throws {
        let arr = #"{"statusCode":400,"message":["a","b"],"error":"Bad Request"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(APIErrorBody.self, from: arr).messages, ["a", "b"])
        let single = #"{"statusCode":401,"message":"unauthorized","error":"Unauthorized"}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(APIErrorBody.self, from: single).messages, ["unauthorized"])
    }

    func testCreateAssetRequestOmitsNilKeys() throws {
        let req = CreateAssetRequest(portfolioId: "p1", type: .crypto, symbol: "BTC", currency: .usd, cgId: "bitcoin")
        let data = try JSONEncoder().encode(req)
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNil(obj["manualPrice"], "nil optionals must be omitted for forbidNonWhitelisted")
        XCTAssertNil(obj["name"])
        XCTAssertEqual(obj["cgId"] as? String, "bitcoin")
    }
}
