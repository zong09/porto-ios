import Foundation
@testable import PortoKit

/// Records every (method, path) and returns canned JSON so AppDataStore's invalidation graph can
/// be asserted without a network. Thread-safe (fetches run concurrently via TaskGroup).
final class MockAPIClient: APIClientProtocol, @unchecked Sendable {
    struct Call: Equatable { let method: HTTPMethod; let path: String }

    private let lock = NSLock()
    private var _calls: [Call] = []
    var calls: [Call] { lock.withLock { _calls } }

    func reset() { lock.withLock { _calls = [] } }
    func paths(_ method: HTTPMethod) -> [String] { calls.filter { $0.method == method }.map(\.path) }
    func contains(_ method: HTTPMethod, _ path: String) -> Bool { calls.contains(Call(method: method, path: path)) }

    private func record(_ e: Endpoint) {
        lock.withLock { _calls.append(Call(method: e.method, path: e.path)) }
    }

    func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type
    ) async throws -> Response {
        record(endpoint)
        return try JSONDecoder().decode(Response.self, from: cannedData(for: endpoint))
    }

    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {
        record(endpoint)
    }

    private func cannedData(for e: Endpoint) -> Data {
        if e.path == "/net-worth/summary" {
            return Data(#"{"totalAssetsThb":100,"totalLiabilitiesThb":0,"netWorthThb":100,"todayPlThb":0,"totalCostThb":90,"fx":36.5}"#.utf8)
        }
        if e.method == .POST && e.path == "/assets" { return Data(#"{"id":"newAsset"}"#.utf8) }
        // default: empty list for GET collections.
        return Data("[]".utf8)
    }
}
