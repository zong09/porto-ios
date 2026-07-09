import Foundation

// MARK: - Enums (raw values match backend exactly)

public enum AssetType: String, Codable, Sendable, CaseIterable {
    case crypto, th, us, fund, deposit
}

public enum Currency: String, Codable, Sendable, CaseIterable {
    case thb = "THB"
    case usd = "USD"
}

/// Request side. Stored side is only buy|sell; deposit/withdraw map on the backend.
public enum TransactionSide: String, Codable, Sendable {
    case buy, sell, deposit, withdraw
}

public enum Direction: String, Codable, Sendable {
    case long, short
}

public enum LiabilityTxType: String, Codable, Sendable {
    case pay, add
}

// MARK: - Domain models (GET response shapes)

public struct Portfolio: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    /// 0..5 palette index.
    public let color: Int
    public let sortOrder: Int?

    public init(id: String, name: String, color: Int, sortOrder: Int? = nil) {
        self.id = id; self.name = name; self.color = color; self.sortOrder = sortOrder
    }
}

public struct PositionSummary: Codable, Sendable, Hashable {
    public let quantity: Double
    public let avgCost: Double
    public let totalCost: Double
    public let realizedPnl: Double
    public let direction: Direction

    public init(quantity: Double, avgCost: Double, totalCost: Double, realizedPnl: Double, direction: Direction) {
        self.quantity = quantity; self.avgCost = avgCost; self.totalCost = totalCost
        self.realizedPnl = realizedPnl; self.direction = direction
    }
}

/// Enriched asset shape returned by `GET /assets`.
/// NOTE: POST/PATCH return the RAW entity (no portfolio/currentPrice/position) — never decode a
/// mutation response as `Asset`; always refetch.
public struct Asset: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let portfolioId: String
    public let type: AssetType
    public let symbol: String
    public let name: String
    public let currency: Currency
    public let direction: Direction?
    public let cgId: String?
    public let yahooSymbol: String?
    public let manualPrice: Double?
    public let sortOrder: Int?
    public let portfolio: Portfolio?
    public let currentPrice: Double?
    public let change24h: Double?
    public let position: PositionSummary?

    public init(id: String, portfolioId: String, type: AssetType, symbol: String, name: String,
                currency: Currency, direction: Direction? = nil, cgId: String? = nil,
                yahooSymbol: String? = nil, manualPrice: Double? = nil, sortOrder: Int? = nil,
                portfolio: Portfolio? = nil, currentPrice: Double? = nil, change24h: Double? = nil,
                position: PositionSummary? = nil) {
        self.id = id; self.portfolioId = portfolioId; self.type = type; self.symbol = symbol
        self.name = name; self.currency = currency; self.direction = direction; self.cgId = cgId
        self.yahooSymbol = yahooSymbol; self.manualPrice = manualPrice; self.sortOrder = sortOrder
        self.portfolio = portfolio; self.currentPrice = currentPrice; self.change24h = change24h
        self.position = position
    }
}

public struct Transaction: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let assetId: String
    public let side: TransactionSide
    public let quantity: Double
    public let price: Double
    public let fee: Double
    /// "YYYY-MM-DD"
    public let date: String
    public let createdAt: String?
    public let asset: Asset?

    public init(id: String, assetId: String, side: TransactionSide, quantity: Double, price: Double,
                fee: Double, date: String, createdAt: String? = nil, asset: Asset? = nil) {
        self.id = id; self.assetId = assetId; self.side = side; self.quantity = quantity
        self.price = price; self.fee = fee; self.date = date; self.createdAt = createdAt; self.asset = asset
    }

    // quantity/price/fee arrive as JSON strings from the backend (numeric columns).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        assetId = try c.decode(String.self, forKey: .assetId)
        side = try c.decode(TransactionSide.self, forKey: .side)
        quantity = try c.decodeFlexibleDouble(forKey: .quantity)
        price = try c.decodeFlexibleDouble(forKey: .price)
        fee = try c.decodeFlexibleDouble(forKey: .fee)
        date = try c.decode(String.self, forKey: .date)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        asset = try c.decodeIfPresent(Asset.self, forKey: .asset)
    }
}

public struct Liability: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let amount: Double
    public let currency: Currency

    public init(id: String, name: String, amount: Double, currency: Currency) {
        self.id = id; self.name = name; self.amount = amount; self.currency = currency
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        amount = try c.decodeFlexibleDouble(forKey: .amount)
        currency = try c.decode(Currency.self, forKey: .currency)
    }
}

public struct LiabilityRef: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let currency: Currency
    public init(id: String, name: String, currency: Currency) {
        self.id = id; self.name = name; self.currency = currency
    }
}

public struct LiabilityTransaction: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let liabilityId: String
    public let type: LiabilityTxType
    public let amount: Double
    public let date: String
    public let createdAt: String?
    public let liability: LiabilityRef?

    public init(id: String, liabilityId: String, type: LiabilityTxType, amount: Double, date: String,
                createdAt: String? = nil, liability: LiabilityRef? = nil) {
        self.id = id; self.liabilityId = liabilityId; self.type = type; self.amount = amount
        self.date = date; self.createdAt = createdAt; self.liability = liability
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        liabilityId = try c.decode(String.self, forKey: .liabilityId)
        type = try c.decode(LiabilityTxType.self, forKey: .type)
        amount = try c.decodeFlexibleDouble(forKey: .amount)
        date = try c.decode(String.self, forKey: .date)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        liability = try c.decodeIfPresent(LiabilityRef.self, forKey: .liability)
    }
}

public struct NetWorthSummary: Codable, Sendable, Hashable {
    public let totalAssetsThb: Double
    public let totalLiabilitiesThb: Double
    public let netWorthThb: Double
    public let todayPlThb: Double
    public let totalCostThb: Double
    /// THB per 1 USD.
    public let fx: Double

    public init(totalAssetsThb: Double, totalLiabilitiesThb: Double, netWorthThb: Double,
                todayPlThb: Double, totalCostThb: Double, fx: Double) {
        self.totalAssetsThb = totalAssetsThb; self.totalLiabilitiesThb = totalLiabilitiesThb
        self.netWorthThb = netWorthThb; self.todayPlThb = todayPlThb
        self.totalCostThb = totalCostThb; self.fx = fx
    }
}

public struct NetWorthHistoryItem: Codable, Sendable, Identifiable, Hashable {
    public let id: String
    public let date: String
    public let totalAssetsThb: Double
    public let totalLiabilitiesThb: Double
    public let netWorthThb: Double
    public let fxRate: Double?

    public init(id: String, date: String, totalAssetsThb: Double, totalLiabilitiesThb: Double,
                netWorthThb: Double, fxRate: Double? = nil) {
        self.id = id; self.date = date; self.totalAssetsThb = totalAssetsThb
        self.totalLiabilitiesThb = totalLiabilitiesThb; self.netWorthThb = netWorthThb; self.fxRate = fxRate
    }
}

/// Price-history datapoint. `t` = epoch milliseconds, `p` = price.
public struct ChartDatapoint: Codable, Sendable, Hashable {
    public let t: Double
    public let p: Double
    public init(t: Double, p: Double) { self.t = t; self.p = p }
}

// MARK: - Auth

/// login/register user object uses `id`.
public struct AuthUser: Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let email: String
    public let isDemo: Bool?
    public init(id: String, name: String, email: String, isDemo: Bool? = nil) {
        self.id = id; self.name = name; self.email = email; self.isDemo = isDemo
    }
}

public struct AuthResponse: Codable, Sendable {
    public let token: String
    public let user: AuthUser
    public init(token: String, user: AuthUser) { self.token = token; self.user = user }
}

/// `/auth/me` returns `userId` (JWT payload), distinct from login's `id`.
public struct MePayload: Codable, Sendable {
    public let userId: String
    public let email: String?
    public let name: String?
    public let isDemo: Bool?
}

public struct AuthConfig: Codable, Sendable {
    public let enableDemo: Bool
    public let enableRegister: Bool
    public init(enableDemo: Bool, enableRegister: Bool) {
        self.enableDemo = enableDemo; self.enableRegister = enableRegister
    }
}
