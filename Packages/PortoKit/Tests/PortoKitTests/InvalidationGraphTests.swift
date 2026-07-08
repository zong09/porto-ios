import XCTest
@testable import PortoKit

/// Asserts each mutation refetches exactly the queries the web `useApi.ts` invalidates.
@MainActor
final class InvalidationGraphTests: XCTestCase {
    private var mock: MockAPIClient!
    private var store: AppDataStore!

    override func setUp() async throws {
        mock = MockAPIClient()
        store = AppDataStore(api: mock, preferences: PreferencesStore(defaults: Self.ephemeralDefaults()))
    }

    private static func ephemeralDefaults() -> UserDefaults {
        UserDefaults(suiteName: "porto.tests.\(UUID().uuidString)")!
    }

    func testCreatePortfolioInvalidatesPortfoliosAndAssets() async throws {
        mock.reset()
        try await store.createPortfolio(.init(name: "X"))
        XCTAssertTrue(mock.contains(.POST, "/portfolios"))
        XCTAssertTrue(mock.contains(.GET, "/portfolios"))
        XCTAssertTrue(mock.contains(.GET, "/assets"))
    }

    func testCreateAssetInvalidatesAssetsSummaryTransactions() async throws {
        mock.reset()
        try await store.createAsset(.init(portfolioId: "p1", type: .crypto, symbol: "BTC", currency: .usd))
        XCTAssertTrue(mock.contains(.POST, "/assets"))
        XCTAssertTrue(mock.contains(.GET, "/assets"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
        XCTAssertTrue(mock.contains(.GET, "/transactions"))
    }

    func testUpdateAssetInvalidatesAssetsSummaryOnly() async throws {
        mock.reset()
        try await store.updateAsset("a1", .init(name: "New"))
        XCTAssertTrue(mock.contains(.PATCH, "/assets/a1"))
        XCTAssertTrue(mock.contains(.GET, "/assets"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
        XCTAssertFalse(mock.contains(.GET, "/transactions"), "asset update must NOT refetch transactions")
    }

    func testTransactionMutationInvalidatesTxAssetsSummary() async throws {
        mock.reset()
        try await store.createTransaction(.init(assetId: "a1", side: .buy, quantity: 1, price: 10))
        XCTAssertTrue(mock.contains(.POST, "/transactions"))
        XCTAssertTrue(mock.contains(.GET, "/transactions"))
        XCTAssertTrue(mock.contains(.GET, "/assets"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
    }

    func testCreateLiabilityInvalidatesLiabilitiesSummary() async throws {
        mock.reset()
        try await store.createLiability(.init(name: "Loan", amount: 100))
        XCTAssertTrue(mock.contains(.POST, "/liabilities"))
        XCTAssertTrue(mock.contains(.GET, "/liabilities"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
    }

    func testAdjustLiabilityInvalidatesAll() async throws {
        mock.reset()
        try await store.adjustLiability("l1", .init(type: .pay, amount: 100, date: "2026-06-01"))
        XCTAssertTrue(mock.contains(.POST, "/liabilities/l1/transactions"))
        XCTAssertTrue(mock.contains(.GET, "/liabilities"))
        XCTAssertTrue(mock.contains(.GET, "/liabilities/transactions"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
    }

    func testSnapshotInvalidatesHistory() async throws {
        mock.reset()
        try await store.takeSnapshot()
        XCTAssertTrue(mock.contains(.POST, "/net-worth/snapshot"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/history"))
    }

    func testRefreshAllSequence() async throws {
        mock.reset()
        await store.refreshAll()
        XCTAssertTrue(mock.contains(.GET, "/assets"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/summary"))
        XCTAssertTrue(mock.contains(.POST, "/net-worth/snapshot"))
        XCTAssertTrue(mock.contains(.GET, "/net-worth/history"))
    }
}
