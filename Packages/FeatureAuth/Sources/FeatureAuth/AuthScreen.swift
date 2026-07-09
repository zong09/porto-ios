import SwiftUI
import PortoKit
import PortoDesign
import PortoForms

/// Login / register / demo gate. Fetches `GET /auth/config` to know whether demo and self
/// registration are enabled, then drives login/register/demo against `APIClientProtocol` and
/// persists the result via `SessionStoring`. `onAuthenticated` is called once the session is
/// saved — Wave 3 wires this to trigger `AppDataStore.loadAll()` and dismiss the gate.
public struct AuthScreen: View {
    private enum Mode { case login, register }

    private let api: APIClientProtocol
    private let session: SessionStoring
    private let preferences: PreferencesStore
    private let onAuthenticated: () -> Void

    @State private var mode: Mode = .login
    @State private var email = ""
    @State private var name = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var authConfig: AuthConfig?
    @State private var didLoadConfig = false

    public init(api: APIClientProtocol,
                session: SessionStoring,
                preferences: PreferencesStore,
                onAuthenticated: @escaping () -> Void) {
        self.api = api
        self.session = session
        self.preferences = preferences
        self.onAuthenticated = onAuthenticated
    }

    private func t(_ key: String) -> String { preferences.t(key) }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 6) {
                    Text(mode == .login ? t("login.loginTitle") : t("login.signupTitle"))
                        .font(.title2.bold())
                    Text(mode == .login ? t("login.loginDesc") : t("login.signupDesc"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                form
                    .card()

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                actions
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            guard !didLoadConfig else { return }
            didLoadConfig = true
            do {
                authConfig = try await api.get(.authConfig(), as: AuthConfig.self)
            } catch let e as APIError {
                // Non-fatal: default to login-only if config can't be fetched.
                errorMessage = e.displayMessage
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(t("login.title"))
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(t("login.desc"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var form: some View {
        VStack(spacing: 12) {
            if mode == .register {
                VStack(alignment: .leading, spacing: 4) {
                    Text(t("login.nameLabel")).font(.caption).foregroundStyle(.secondary)
                    TextField(t("login.namePlaceholder"), text: $name)
                        .textContentType(.name)
                        #if os(iOS)
                        .textInputAutocapitalization(.words)
                        #endif
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(t("login.emailLabel")).font(.caption).foregroundStyle(.secondary)
                TextField("email@example.com", text: $email)
                    .textContentType(.emailAddress)
                    #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(t("login.passwordLabel")).font(.caption).foregroundStyle(.secondary)
                SecureField("••••••", text: $password)
                    .textContentType(mode == .login ? .password : .newPassword)
            }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                Task { await submit() }
            } label: {
                if isSubmitting {
                    ProgressView().frame(maxWidth: .infinity)
                } else {
                    Text(mode == .login ? t("login.loginBtn") : t("login.signupBtn"))
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSubmitting)

            if mode == .login, authConfig?.enableRegister != false {
                HStack {
                    Text(t("login.noAccount")).font(.footnote).foregroundStyle(.secondary)
                    Button(t("login.signupBtn")) { switchMode(.register) }
                        .font(.footnote.bold())
                }
            } else if mode == .register {
                if authConfig?.enableRegister == false {
                    Text(t("login.signupDisabled"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(t("login.hasAccount")).font(.footnote).foregroundStyle(.secondary)
                    Button(t("login.loginBtn")) { switchMode(.login) }
                        .font(.footnote.bold())
                }
            }

            if authConfig?.enableDemo == true {
                HStack(spacing: 8) {
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                    Text(t("login.orText")).font(.caption).foregroundStyle(.secondary)
                    Rectangle().frame(height: 1).foregroundStyle(.secondary.opacity(0.3))
                }

                Button {
                    Task { await submitDemo() }
                } label: {
                    Text(t("login.demoBtn")).frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isSubmitting)
            }

            Text(t("login.secureNote"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private func switchMode(_ newMode: Mode) {
        mode = newMode
        errorMessage = nil
    }

    // MARK: - Validation

    private func isValidEmail(_ value: String) -> Bool {
        let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    private func validate() -> String? {
        if mode == .register, name.trimmingCharacters(in: .whitespaces).isEmpty {
            return t("login.nameRequired")
        }
        if !isValidEmail(email) {
            return t("login.emailInvalid")
        }
        if password.count < 4 {
            return t("login.passwordMinLength")
        }
        return nil
    }

    // MARK: - Submission

    private func submit() async {
        if let validationError = validate() {
            errorMessage = validationError
            return
        }
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response: AuthResponse
            switch mode {
            case .login:
                response = try await api.send(.login(), body: LoginRequest(email: email, pass: password), as: AuthResponse.self)
            case .register:
                response = try await api.send(.register(), body: RegisterRequest(email: email, name: name, pass: password), as: AuthResponse.self)
            }
            session.save(token: response.token, user: response.user)
            onAuthenticated()
        } catch let e as APIError {
            errorMessage = e.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitDemo() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            let response = try await api.send(.demo(), body: nil, as: AuthResponse.self)
            session.save(token: response.token, user: response.user)
            onAuthenticated()
        } catch let e as APIError {
            errorMessage = e.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AuthScreen(
        api: PreviewAPIClient(),
        session: PreviewSessionStore(),
        preferences: PreferencesStore(),
        onAuthenticated: {}
    )
}

// MARK: - Preview support

private final class PreviewSessionStore: SessionStoring, @unchecked Sendable {
    var token: String?
    var currentUser: AuthUser?
    var isAuthenticated: Bool { token != nil }
    func save(token: String, user: AuthUser) { self.token = token; self.currentUser = user }
    func clear() { token = nil; currentUser = nil }
}

private struct PreviewAPIClient: APIClientProtocol {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type) async throws -> Response {
        if endpoint.path == "/auth/config" {
            return AuthConfig(enableDemo: true, enableRegister: true) as! Response
        }
        throw APIError.offline
    }
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {}
}
