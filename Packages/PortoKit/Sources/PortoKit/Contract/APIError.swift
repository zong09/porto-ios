import Foundation

/// Backend error body: `{ statusCode, message: string | string[], error }`.
/// Messages are often Thai and MUST be surfaced verbatim to the user.
public struct APIErrorBody: Decodable, Sendable {
    public let statusCode: Int?
    public let error: String?
    public let messages: [String]

    private enum CodingKeys: String, CodingKey { case statusCode, error, message }

    public init(statusCode: Int?, error: String?, messages: [String]) {
        self.statusCode = statusCode; self.error = error; self.messages = messages
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.statusCode = try c.decodeIfPresent(Int.self, forKey: .statusCode)
        self.error = try c.decodeIfPresent(String.self, forKey: .error)
        // message can be a single string or an array of strings.
        if let arr = try? c.decode([String].self, forKey: .message) {
            self.messages = arr
        } else if let single = try? c.decode(String.self, forKey: .message) {
            self.messages = [single]
        } else {
            self.messages = []
        }
    }
}

public enum APIError: Error, Sendable {
    /// HTTP 401 — token invalid/expired. Callers force logout.
    case unauthorized
    /// Any non-2xx with a decoded backend body.
    case server(status: Int, body: APIErrorBody)
    /// Non-2xx whose body could not be decoded.
    case http(status: Int, raw: String?)
    case decoding(String)
    case transport(String)
    case offline

    /// User-facing message; joins backend messages, else a sensible fallback.
    public var displayMessage: String {
        switch self {
        case .unauthorized:
            return "เซสชันหมดอายุ กรุณาเข้าสู่ระบบใหม่"
        case let .server(_, body):
            let joined = body.messages.joined(separator: "\n")
            return joined.isEmpty ? (body.error ?? "เกิดข้อผิดพลาด") : joined
        case let .http(status, _):
            return "เกิดข้อผิดพลาด (HTTP \(status))"
        case .decoding:
            return "ข้อมูลไม่ถูกต้อง"
        case let .transport(m):
            return m
        case .offline:
            return "ออฟไลน์ — เชื่อมต่ออินเทอร์เน็ตไม่ได้"
        }
    }
}
