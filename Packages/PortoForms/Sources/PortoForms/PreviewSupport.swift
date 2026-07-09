import Foundation
import PortoKit

/// Minimal no-op API client + preview `AppDataStore` factory, used only by `#Preview` blocks in
/// this package. Never shipped behind app logic.
struct PreviewAPIClient: APIClientProtocol, @unchecked Sendable {
    func send<Response>(_ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type) async throws -> Response where Response: Decodable & Sendable {
        throw APIError.offline
    }
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {
        throw APIError.offline
    }
}

@MainActor
enum PreviewFactory {
    static func store() -> AppDataStore {
        AppDataStore(api: PreviewAPIClient(), preferences: PreferencesStore())
    }
}
