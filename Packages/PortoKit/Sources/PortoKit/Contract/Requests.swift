import Foundation

// Per-request DTOs with EXACT keys. `ValidationPipe forbidNonWhitelisted` rejects unknown keys,
// so these encode only the documented fields. Optionals are omitted when nil (synthesized
// Codable uses encodeIfPresent for optionals).

public struct RegisterRequest: Codable, Sendable {
    public let email: String
    public let name: String
    public let pass: String
    public init(email: String, name: String, pass: String) {
        self.email = email; self.name = name; self.pass = pass
    }
}

public struct LoginRequest: Codable, Sendable {
    public let email: String
    public let pass: String
    public init(email: String, pass: String) { self.email = email; self.pass = pass }
}

public struct CreatePortfolioRequest: Codable, Sendable {
    public let name: String
    public let color: Int?
    public init(name: String, color: Int? = nil) { self.name = name; self.color = color }
}

public struct UpdatePortfolioRequest: Codable, Sendable {
    public let name: String
    public let color: Int?
    public init(name: String, color: Int? = nil) { self.name = name; self.color = color }
}

public struct ReorderRequest: Codable, Sendable {
    public let orderedIds: [String]
    public init(orderedIds: [String]) { self.orderedIds = orderedIds }
}

public struct CreateAssetRequest: Codable, Sendable {
    public let portfolioId: String
    public let type: AssetType
    public let symbol: String
    public let name: String?
    public let currency: Currency
    public let cgId: String?
    public let yahooSymbol: String?
    public let manualPrice: Double?
    public let direction: Direction?
    public init(portfolioId: String, type: AssetType, symbol: String, name: String? = nil,
                currency: Currency, cgId: String? = nil, yahooSymbol: String? = nil,
                manualPrice: Double? = nil, direction: Direction? = nil) {
        self.portfolioId = portfolioId; self.type = type; self.symbol = symbol; self.name = name
        self.currency = currency; self.cgId = cgId; self.yahooSymbol = yahooSymbol
        self.manualPrice = manualPrice; self.direction = direction
    }
}

public struct UpdateAssetRequest: Codable, Sendable {
    public let name: String?
    public let manualPrice: Double?
    public init(name: String? = nil, manualPrice: Double? = nil) {
        self.name = name; self.manualPrice = manualPrice
    }
}

public struct CreateTransactionRequest: Codable, Sendable {
    public let assetId: String
    public let side: TransactionSide
    public let quantity: Double
    public let price: Double?
    public let fee: Double?
    public let date: String?
    public init(assetId: String, side: TransactionSide, quantity: Double, price: Double? = nil,
                fee: Double? = nil, date: String? = nil) {
        self.assetId = assetId; self.side = side; self.quantity = quantity
        self.price = price; self.fee = fee; self.date = date
    }
}

public struct CreateLiabilityRequest: Codable, Sendable {
    public let name: String
    public let amount: Double
    public let currency: String?
    public init(name: String, amount: Double, currency: String? = nil) {
        self.name = name; self.amount = amount; self.currency = currency
    }
}

public struct UpdateLiabilityRequest: Codable, Sendable {
    public let name: String?
    public let amount: Double?
    public let currency: String?
    public init(name: String? = nil, amount: Double? = nil, currency: String? = nil) {
        self.name = name; self.amount = amount; self.currency = currency
    }
}

public struct AdjustLiabilityRequest: Codable, Sendable {
    public let type: LiabilityTxType
    public let amount: Double
    public let date: String
    public init(type: LiabilityTxType, amount: Double, date: String) {
        self.type = type; self.amount = amount; self.date = date
    }
}

public struct BackupExportRequest: Codable, Sendable {
    public let password: String
    public init(password: String) { self.password = password }
}

public struct BackupImportRequest: Codable, Sendable {
    public let password: String
    /// base64-encoded backup file bytes.
    public let data: String
    public init(password: String, data: String) { self.password = password; self.data = data }
}

public struct BackupExportResponse: Codable, Sendable {
    public let data: String
}
