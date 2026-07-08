import Foundation

/// Central observable data store. Mirrors the web `useApi.ts` query cache + invalidation graph:
/// every mutation refetches exactly the queries the web invalidates. Enriched `/assets` is the
/// source of truth for holdings; mutation responses (raw entities) are never decoded — we refetch.
@MainActor
@Observable
public final class AppDataStore {
    // Query state
    public private(set) var portfolios: [Portfolio] = []
    public private(set) var assets: [Asset] = []
    public private(set) var transactions: [Transaction] = []
    public private(set) var liabilities: [Liability] = []
    public private(set) var liabilityTransactions: [LiabilityTransaction] = []
    public private(set) var summary: NetWorthSummary?
    public private(set) var history: [NetWorthHistoryItem] = []

    public var lastError: APIError?
    public private(set) var isRefreshing = false
    /// Set true when the last refresh failed / data may be stale (widget + banner use this).
    public private(set) var isStale = false

    private let api: APIClientProtocol
    private let preferences: PreferencesStore
    private let snapshotStore: SharedSnapshotStore?
    /// Days of history to keep loaded (web loads 365).
    public var historyDays: Int = 365

    public init(api: APIClientProtocol,
                preferences: PreferencesStore,
                snapshotStore: SharedSnapshotStore? = nil) {
        self.api = api
        self.preferences = preferences
        self.snapshotStore = snapshotStore
    }

    // MARK: - Fetches

    public func fetchPortfolios() async throws {
        portfolios = try await api.get(.portfolios(), as: [Portfolio].self)
    }
    public func fetchAssets() async throws {
        assets = try await api.get(.assets(), as: [Asset].self)
    }
    public func fetchTransactions() async throws {
        transactions = try await api.get(.transactions(), as: [Transaction].self)
    }
    public func fetchLiabilities() async throws {
        liabilities = try await api.get(.liabilities(), as: [Liability].self)
    }
    public func fetchLiabilityTransactions() async throws {
        liabilityTransactions = try await api.get(.liabilityTransactions(), as: [LiabilityTransaction].self)
    }
    public func fetchSummary() async throws {
        summary = try await api.get(.netWorthSummary(), as: NetWorthSummary.self)
    }
    public func fetchHistory(days: Int? = nil) async throws {
        history = try await api.get(.netWorthHistory(days: days ?? historyDays), as: [NetWorthHistoryItem].self)
    }

    /// Post-login / first-load: pull every query.
    public func loadAll() async {
        await runGroup([
            { try await self.fetchPortfolios() },
            { try await self.fetchAssets() },
            { try await self.fetchTransactions() },
            { try await self.fetchLiabilities() },
            { try await self.fetchLiabilityTransactions() },
            { try await self.fetchSummary() },
            { try await self.fetchHistory() },
        ])
        writeSnapshot()
    }

    // MARK: - Portfolios
    public func createPortfolio(_ req: CreatePortfolioRequest) async throws {
        try await api.send(.createPortfolio(), body: req)
        try await invalidatePortfolios()
    }
    public func updatePortfolio(_ id: String, _ req: UpdatePortfolioRequest) async throws {
        try await api.send(.updatePortfolio(id), body: req)
        try await invalidatePortfolios()
    }
    public func deletePortfolio(_ id: String) async throws {
        try await api.send(.deletePortfolio(id), body: nil)
        try await invalidatePortfolios()
    }
    /// Optimistic reorder: apply locally, PATCH, rollback + refetch on error.
    public func reorderPortfolios(_ orderedIds: [String]) async throws {
        let prev = portfolios
        portfolios = orderedIds.compactMap { id in prev.first { $0.id == id } }
        do {
            try await api.send(.reorderPortfolios(), body: ReorderRequest(orderedIds: orderedIds))
        } catch {
            portfolios = prev
            try? await fetchPortfolios()
            throw error
        }
        try? await fetchPortfolios()
    }
    private func invalidatePortfolios() async throws {
        try await fetchPortfolios()
        try await fetchAssets() // enriched portfolio name/color
    }

    // MARK: - Assets
    public func createAsset(_ req: CreateAssetRequest) async throws {
        try await api.send(.createAsset(), body: req)
        try await invalidateAfterAssetMutation(includeTransactions: true)
    }
    /// For the opening-transaction flow: create the asset and return its id (refetch, then locate).
    public func createAssetReturningId(_ req: CreateAssetRequest) async throws -> String? {
        struct RawId: Decodable { let id: String }
        let raw = try await api.send(.createAsset(), body: req, as: RawId.self)
        try await invalidateAfterAssetMutation(includeTransactions: true)
        return raw.id
    }
    public func updateAsset(_ id: String, _ req: UpdateAssetRequest) async throws {
        try await api.send(.updateAsset(id), body: req)
        try await invalidateAfterAssetMutation(includeTransactions: false)
    }
    public func deleteAsset(_ id: String) async throws {
        try await api.send(.deleteAsset(id), body: nil)
        try await invalidateAfterAssetMutation(includeTransactions: true)
    }
    public func reorderAssets(_ orderedIds: [String]) async throws {
        let prev = assets
        let set = Set(orderedIds)
        let reordered = orderedIds.compactMap { id in prev.first { $0.id == id } }
        assets = reordered + prev.filter { !set.contains($0.id) }
        do {
            try await api.send(.reorderAssets(), body: ReorderRequest(orderedIds: orderedIds))
        } catch {
            assets = prev
            try? await fetchAssets()
            throw error
        }
        try? await fetchAssets()
    }
    private func invalidateAfterAssetMutation(includeTransactions: Bool) async throws {
        try await fetchAssets()
        try await fetchSummary()
        if includeTransactions { try await fetchTransactions() }
    }

    // MARK: - Transactions
    public func createTransaction(_ req: CreateTransactionRequest) async throws {
        try await api.send(.createTransaction(), body: req)
        try await invalidateAfterTransactionMutation()
    }
    public func updateTransaction(_ id: String, _ req: CreateTransactionRequest) async throws {
        try await api.send(.updateTransaction(id), body: req)
        try await invalidateAfterTransactionMutation()
    }
    public func deleteTransaction(_ id: String) async throws {
        try await api.send(.deleteTransaction(id), body: nil)
        try await invalidateAfterTransactionMutation()
    }
    private func invalidateAfterTransactionMutation() async throws {
        try await fetchTransactions()
        try await fetchAssets()
        try await fetchSummary()
    }

    // MARK: - Liabilities
    public func createLiability(_ req: CreateLiabilityRequest) async throws {
        try await api.send(.createLiability(), body: req)
        try await invalidateLiabilities()
    }
    public func updateLiability(_ id: String, _ req: UpdateLiabilityRequest) async throws {
        try await api.send(.updateLiability(id), body: req)
        try await invalidateLiabilities()
    }
    public func deleteLiability(_ id: String) async throws {
        try await api.send(.deleteLiability(id), body: nil)
        try await invalidateLiabilities()
    }
    public func adjustLiability(_ id: String, _ req: AdjustLiabilityRequest) async throws {
        try await api.send(.adjustLiability(id), body: req)
        try await fetchLiabilities()
        try await fetchLiabilityTransactions()
        try await fetchSummary()
    }
    private func invalidateLiabilities() async throws {
        try await fetchLiabilities()
        try await fetchSummary()
    }

    // MARK: - Snapshot / refresh
    public func takeSnapshot() async throws {
        try await api.send(.snapshot(), body: nil)
        try await fetchHistory()
    }

    /// Pull-to-refresh / foreground / post-login: assets+summary in parallel, snapshot, history,
    /// then persist SharedSnapshot + reload widgets.
    public func refreshAll() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await runGroup([
            { try await self.fetchAssets() },
            { try await self.fetchSummary() },
        ])
        do {
            try await api.send(.snapshot(), body: nil)
            try await fetchHistory()
            isStale = false
        } catch APIError.unauthorized {
            isStale = true
        } catch {
            isStale = true
            lastError = error as? APIError
        }
        writeSnapshot()
    }

    // MARK: - SharedSnapshot
    /// Last 30 net-worth points (oldest -> newest) for the widget sparkline.
    public func sparklinePoints() -> [Double] {
        Array(history.suffix(30)).map(\.netWorthThb)
    }

    public func writeSnapshot() {
        guard let summary, let snapshotStore else { return }
        let snap = SharedSnapshot(
            netWorthThb: summary.netWorthThb,
            todayPlThb: summary.todayPlThb,
            totalAssetsThb: summary.totalAssetsThb,
            totalLiabilitiesThb: summary.totalLiabilitiesThb,
            fx: summary.fx,
            sparkline: sparklinePoints(),
            displayCurrency: preferences.displayCurrency,
            themeID: preferences.themeID,
            updatedAt: Date()
        )
        snapshotStore.write(snap)
    }

    public func reset() {
        portfolios = []; assets = []; transactions = []; liabilities = []
        liabilityTransactions = []; summary = nil; history = []
        lastError = nil; isStale = false
    }

    // MARK: - Helpers
    private func runGroup(_ tasks: [@Sendable () async throws -> Void]) async {
        await withTaskGroup(of: APIError?.self) { group in
            for task in tasks {
                group.addTask {
                    do { try await task(); return nil }
                    catch let e as APIError { return e }
                    catch { return APIError.transport(error.localizedDescription) }
                }
            }
            for await err in group where err != nil {
                if case .unauthorized = err! { self.lastError = err }
                else { self.lastError = err }
            }
        }
    }
}
