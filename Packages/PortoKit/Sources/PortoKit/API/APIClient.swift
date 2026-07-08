import Foundation

/// URLSession-backed `APIClientProtocol`.
/// - Bearer token from the injected `SessionStoring`.
/// - Any HTTP 401 -> clears the session, invokes `onUnauthorized`, throws `.unauthorized`
///   (mirrors the web Axios response interceptor; there is no refresh token).
/// - Error bodies (`{statusCode, message: string|string[], error}`) decode into `APIError.server`
///   so Thai messages surface verbatim.
public final class APIClient: APIClientProtocol, @unchecked Sendable {
    private let baseURL: URL
    private let session: SessionStoring
    private let urlSession: URLSession
    private let onUnauthorized: @Sendable () -> Void
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(config: AppConfig,
                session: SessionStoring,
                urlSession: URLSession = .shared,
                onUnauthorized: @escaping @Sendable () -> Void = {}) {
        self.baseURL = APIClient.resolveBaseURL(config)
        self.session = session
        self.urlSession = urlSession
        self.onUnauthorized = onUnauthorized
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
    }

    /// In DEBUG, a UserDefaults override (`porto.debugBaseURL`) wins — used for LAN IP on device.
    static func resolveBaseURL(_ config: AppConfig) -> URL {
        #if DEBUG
        if config.allowDebugBaseURLOverride,
           let s = UserDefaults.standard.string(forKey: "porto.debugBaseURL"),
           let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)), !s.isEmpty {
            return u
        }
        #endif
        return config.apiBaseURL
    }

    public func send<Response: Decodable & Sendable>(
        _ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type
    ) async throws -> Response {
        let data = try await perform(endpoint, body: body)
        if data.isEmpty, let empty = EmptyResponse() as? Response { return empty }
        do { return try decoder.decode(Response.self, from: data) }
        catch { throw APIError.decoding(String(describing: error)) }
    }

    public func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {
        _ = try await perform(endpoint, body: body)
    }

    private func perform(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws -> Data {
        guard var comps = URLComponents(url: baseURL.appendingPathComponent(endpoint.path),
                                        resolvingAgainstBaseURL: false) else {
            throw APIError.transport("URL ไม่ถูกต้อง")
        }
        if !endpoint.query.isEmpty { comps.queryItems = endpoint.query }
        guard let url = comps.url else { throw APIError.transport("URL ไม่ถูกต้อง") }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        if let token = session.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try encoder.encode(body)
        }

        let data: Data, response: URLResponse
        do { (data, response) = try await urlSession.data(for: req) }
        catch let err as URLError where err.code == .notConnectedToInternet || err.code == .networkConnectionLost {
            throw APIError.offline
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("ไม่มีการตอบกลับจากเซิร์ฟเวอร์")
        }
        switch http.statusCode {
        case 200...299:
            return data
        case 401:
            session.clear()
            onUnauthorized()
            throw APIError.unauthorized
        default:
            if let body = try? decoder.decode(APIErrorBody.self, from: data) {
                throw APIError.server(status: http.statusCode, body: body)
            }
            throw APIError.http(status: http.statusCode, raw: String(data: data, encoding: .utf8))
        }
    }
}

struct EmptyResponse: Decodable {}
