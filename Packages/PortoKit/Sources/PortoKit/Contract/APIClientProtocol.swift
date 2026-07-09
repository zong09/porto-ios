import Foundation

/// Abstraction over the network layer. Implemented by `APIClient` (Wave 1A); feature code and
/// tests depend on this protocol, never the concrete type.
public protocol APIClientProtocol: Sendable {
    /// Sends `endpoint` with an optional Encodable body and decodes the 2xx JSON response.
    /// Throws `APIError`. On HTTP 401 throws `.unauthorized` (callers force logout).
    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint,
        body: (any Encodable & Sendable)?,
        as type: Response.Type
    ) async throws -> Response

    /// For endpoints whose 2xx body is ignored (e.g. `{ success: true }`, reorder, delete).
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws
}

public extension APIClientProtocol {
    func get<Response: Decodable & Sendable>(_ endpoint: Endpoint, as type: Response.Type) async throws -> Response {
        try await send(endpoint, body: nil, as: type)
    }
}
