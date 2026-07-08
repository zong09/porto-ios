import SwiftUI
import PortoKit
import PortoDesign
import PortoForms
#if os(iOS)
import UIKit
import UniformTypeIdentifiers
#endif

/// Theme / currency / language preferences, data backup export & import, logout, and clear-data.
/// `onLoggedOut` is called after `SessionStoring.clear()` — Wave 3 wires this to return to the
/// login gate.
public struct SettingsScreen: View {
    private let store: AppDataStore
    private let preferences: PreferencesStore
    private let session: SessionStoring
    private let api: APIClientProtocol
    private let onLoggedOut: () -> Void

    @State private var showExportSheet = false
    @State private var showImportSheet = false
    @State private var showClearConfirm = false
    @State private var showLogoutConfirm = false
    @State private var isBusy = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var exportedFileURL: IdentifiableURL?

    public init(store: AppDataStore,
                preferences: PreferencesStore,
                session: SessionStoring,
                api: APIClientProtocol,
                onLoggedOut: @escaping () -> Void) {
        self.store = store
        self.preferences = preferences
        self.session = session
        self.api = api
        self.onLoggedOut = onLoggedOut
    }

    private func t(_ key: String) -> String { preferences.t(key) }
    private var theme: Theme { Theme.palette(ThemeID(rawValue: preferences.themeID) ?? .default) }

    public var body: some View {
        List {
            Section(t("settings.themeLabel")) {
                Text(t("settings.subtitle"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                themePicker
            }

            Section {
                Picker(t("common.settings"), selection: Binding(
                    get: { preferences.displayCurrency },
                    set: { preferences.displayCurrency = $0 }
                )) {
                    Text("USD").tag(Currency.usd)
                    Text("THB").tag(Currency.thb)
                }
                .pickerStyle(.segmented)

                Picker("Language / ภาษา", selection: Binding(
                    get: { preferences.language },
                    set: { preferences.language = $0 }
                )) {
                    Text("ไทย").tag(Language.th)
                    Text("English").tag(Language.en)
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Currency & Language")
            }

            Section {
                Text(t("settings.backupDesc"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    showExportSheet = true
                } label: {
                    Label(t("settings.exportBtn"), systemImage: "square.and.arrow.up")
                }
                Button {
                    showImportSheet = true
                } label: {
                    Label(t("settings.importBtn"), systemImage: "square.and.arrow.down")
                }
            } header: {
                Text(t("settings.backupLabel"))
            }

            Section {
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(t("footer.clearAll"), systemImage: "trash")
                }

                Button(role: .destructive) {
                    showLogoutConfirm = true
                } label: {
                    Label(t("common.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            if let successMessage {
                Section {
                    Text(successMessage).foregroundStyle(.green).font(.footnote)
                }
            }

            Section {
                Text(t("footer.secureText"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(t("settings.title"))
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(api: api, preferences: preferences, isBusy: $isBusy) { url in
                exportedFileURL = url
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ImportSheet(api: api, store: store, preferences: preferences, isBusy: $isBusy) { message, success in
                if success { successMessage = message } else { errorMessage = message }
            }
        }
        #if os(iOS)
        .sheet(item: $exportedFileURL) { wrapper in
            ShareSheet(activityItems: [wrapper.url])
        }
        #endif
        .alert(t("footer.confirmClearAll"), isPresented: $showClearConfirm) {
            Button(t("settings.cancel"), role: .cancel) {}
            Button(t("footer.clearAll"), role: .destructive) {
                Task { await clearData() }
            }
        }
        .alert(t("common.logout"), isPresented: $showLogoutConfirm) {
            Button(t("settings.cancel"), role: .cancel) {}
            Button(t("common.logout"), role: .destructive) {
                session.clear()
                store.reset()
                onLoggedOut()
            }
        }
    }

    private var themePicker: some View {
        HStack(spacing: 12) {
            ForEach(Theme.order, id: \.self) { id in
                let meta = Theme.meta(id)
                let t = Theme.palette(id)
                let isSelected = preferences.themeID == id.rawValue
                Button {
                    preferences.themeID = id.rawValue
                } label: {
                    VStack(spacing: 6) {
                        HStack(spacing: 2) {
                            ForEach(Array(t.palette.prefix(4).enumerated()), id: \.offset) { _, color in
                                Circle().fill(color).frame(width: 12, height: 12)
                            }
                        }
                        Text(meta.name).font(.caption2.weight(.semibold))
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(t.swatchBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func clearData() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try await api.send(.clearData(), body: nil)
            store.reset()
            successMessage = t("footer.clearSuccess")
            errorMessage = nil
        } catch let e as APIError {
            errorMessage = e.displayMessage
        } catch {
            errorMessage = t("footer.clearError")
        }
    }
}

// MARK: - Export sheet

private struct ExportSheet: View {
    let api: APIClientProtocol
    let preferences: PreferencesStore
    @Binding var isBusy: Bool
    let onExported: (IdentifiableURL) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var errorMessage: String?

    private func t(_ key: String) -> String { preferences.t(key) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(t("settings.exportDesc")).font(.caption).foregroundStyle(.secondary)
                    SecureField(t("settings.passwordLabel"), text: $password)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(t("settings.exportTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("settings.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("settings.exportBtn")) {
                        Task { await export() }
                    }
                    .disabled(password.count < 8 || isBusy)
                }
            }
        }
    }

    private func export() async {
        isBusy = true
        defer { isBusy = false }
        do {
            let response = try await api.send(.backupExport(), body: BackupExportRequest(password: password), as: BackupExportResponse.self)
            guard let data = Data(base64Encoded: response.data) else {
                errorMessage = t("common.error")
                return
            }
            let filename = "porto-backup-\(BangkokDate.todayString()).porto"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            dismiss()
            onExported(IdentifiableURL(url: url))
        } catch let e as APIError {
            errorMessage = e.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Import sheet

private struct ImportSheet: View {
    let api: APIClientProtocol
    let store: AppDataStore
    let preferences: PreferencesStore
    @Binding var isBusy: Bool
    let onFinished: (String, Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var pickedFileData: Data?
    @State private var pickedFileName: String?
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    private func t(_ key: String) -> String { preferences.t(key) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(t("settings.importDesc")).font(.caption).foregroundStyle(.secondary)
                    Text(t("settings.importWarn")).font(.caption).foregroundStyle(.orange)
                    Button {
                        showFileImporter = true
                    } label: {
                        HStack {
                            Text(t("settings.fileLabel"))
                            Spacer()
                            Text(pickedFileName ?? "—").foregroundStyle(.secondary)
                        }
                    }
                    SecureField(t("settings.passwordLabel"), text: $password)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(t("settings.importTitle"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(t("settings.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(t("settings.importBtn")) {
                        Task { await performImport() }
                    }
                    .disabled(pickedFileData == nil || password.count < 8 || isBusy)
                }
            }
            #if os(iOS)
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.data, .item], allowsMultipleSelection: false) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    loadFile(at: url)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                }
            }
            #endif
        }
    }

    private func loadFile(at url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            pickedFileData = try Data(contentsOf: url)
            pickedFileName = url.lastPathComponent
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func performImport() async {
        guard let data = pickedFileData else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let base64 = data.base64EncodedString()
            try await api.send(.backupImport(), body: BackupImportRequest(password: password, data: base64))
            await store.loadAll()
            dismiss()
            onFinished(t("settings.importBtn"), true)
        } catch let e as APIError {
            errorMessage = e.displayMessage
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Share sheet (iOS)

#if os(iOS)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

#Preview {
    NavigationStack {
        SettingsScreen(
            store: AppDataStore(api: PreviewAPIClient(), preferences: PreferencesStore()),
            preferences: PreferencesStore(),
            session: PreviewSessionStore(),
            api: PreviewAPIClient(),
            onLoggedOut: {}
        )
    }
}

private final class PreviewSessionStore: SessionStoring, @unchecked Sendable {
    var token: String? = "preview"
    var currentUser: AuthUser?
    var isAuthenticated: Bool { token != nil }
    func save(token: String, user: AuthUser) { self.token = token; self.currentUser = user }
    func clear() { token = nil; currentUser = nil }
}

private struct PreviewAPIClient: APIClientProtocol {
    func send<Response: Decodable & Sendable>(_ endpoint: Endpoint, body: (any Encodable & Sendable)?, as type: Response.Type) async throws -> Response {
        throw APIError.offline
    }
    func send(_ endpoint: Endpoint, body: (any Encodable & Sendable)?) async throws {}
}
