import Foundation

public enum HTTPMethod: String, Sendable {
    case GET, POST, PATCH, PUT, DELETE
}

/// A single API endpoint: method + path (relative to `AppConfig.apiBaseURL`) + optional query.
public struct Endpoint: Sendable {
    public let method: HTTPMethod
    public let path: String
    public let query: [URLQueryItem]

    public init(_ method: HTTPMethod, _ path: String, query: [URLQueryItem] = []) {
        self.method = method; self.path = path; self.query = query
    }

    // MARK: Auth
    public static func login() -> Endpoint { .init(.POST, "/auth/login") }
    public static func register() -> Endpoint { .init(.POST, "/auth/register") }
    public static func demo() -> Endpoint { .init(.POST, "/auth/demo") }
    public static func authConfig() -> Endpoint { .init(.GET, "/auth/config") }
    public static func me() -> Endpoint { .init(.GET, "/auth/me") }
    public static func clearData() -> Endpoint { .init(.POST, "/auth/clear") }

    // MARK: Portfolios
    public static func portfolios() -> Endpoint { .init(.GET, "/portfolios") }
    public static func createPortfolio() -> Endpoint { .init(.POST, "/portfolios") }
    public static func updatePortfolio(_ id: String) -> Endpoint { .init(.PATCH, "/portfolios/\(id)") }
    public static func deletePortfolio(_ id: String) -> Endpoint { .init(.DELETE, "/portfolios/\(id)") }
    public static func reorderPortfolios() -> Endpoint { .init(.PATCH, "/portfolios/reorder") }

    // MARK: Assets
    public static func assets() -> Endpoint { .init(.GET, "/assets") }
    public static func createAsset() -> Endpoint { .init(.POST, "/assets") }
    public static func updateAsset(_ id: String) -> Endpoint { .init(.PATCH, "/assets/\(id)") }
    public static func deleteAsset(_ id: String) -> Endpoint { .init(.DELETE, "/assets/\(id)") }
    public static func reorderAssets() -> Endpoint { .init(.PATCH, "/assets/reorder") }

    // MARK: Transactions
    public static func transactions() -> Endpoint { .init(.GET, "/transactions") }
    public static func createTransaction() -> Endpoint { .init(.POST, "/transactions") }
    public static func updateTransaction(_ id: String) -> Endpoint { .init(.PUT, "/transactions/\(id)") }
    public static func deleteTransaction(_ id: String) -> Endpoint { .init(.DELETE, "/transactions/\(id)") }

    // MARK: Liabilities
    public static func liabilities() -> Endpoint { .init(.GET, "/liabilities") }
    public static func liabilityTransactions() -> Endpoint { .init(.GET, "/liabilities/transactions") }
    public static func createLiability() -> Endpoint { .init(.POST, "/liabilities") }
    public static func updateLiability(_ id: String) -> Endpoint { .init(.PATCH, "/liabilities/\(id)") }
    public static func deleteLiability(_ id: String) -> Endpoint { .init(.DELETE, "/liabilities/\(id)") }
    public static func adjustLiability(_ id: String) -> Endpoint { .init(.POST, "/liabilities/\(id)/transactions") }

    // MARK: Net worth
    public static func netWorthSummary() -> Endpoint { .init(.GET, "/net-worth/summary") }
    public static func netWorthHistory(days: Int?) -> Endpoint {
        .init(.GET, "/net-worth/history", query: days.map { [URLQueryItem(name: "days", value: String($0))] } ?? [])
    }
    public static func snapshot() -> Endpoint { .init(.POST, "/net-worth/snapshot") }

    // MARK: Prices
    public static func cryptoHistory(cgId: String, days: Int) -> Endpoint {
        .init(.GET, "/prices/crypto/\(cgId)/history", query: [URLQueryItem(name: "days", value: String(days))])
    }
    public static func stockHistory(symbol: String, range: String) -> Endpoint {
        .init(.GET, "/prices/stock/\(symbol)/history", query: [URLQueryItem(name: "range", value: range)])
    }

    // MARK: Backup
    public static func backupExport() -> Endpoint { .init(.POST, "/backup/export") }
    public static func backupImport() -> Endpoint { .init(.POST, "/backup/import") }
}
