import SwiftUI
import PortoKit
import PortoDesign

/// Create or rename a portfolio. Ported from `PortfolioModal.tsx`.
public struct PortfolioFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let editing: Portfolio?
    private let onDone: () -> Void

    public init(
        store: AppDataStore,
        prefs: PreferencesStore,
        editing: Portfolio? = nil,
        onDone: @escaping () -> Void = {}
    ) {
        self.store = store
        self.prefs = prefs
        self.editing = editing
        self.onDone = onDone
    }

    private var isEdit: Bool { editing != nil }

    @State private var name: String = ""
    @State private var error: String?
    @State private var loading = false
    @State private var didInitialize = false

    public var body: some View {
        NavigationStack {
            Form {
                Section(prefs.t("portfolios.portNameLabel")) {
                    TextField(prefs.t("portfolios.placeholderName"), text: $name)
                }
                if let error {
                    Section { FormErrorBanner(message: error) }
                }
            }
            .navigationTitle(isEdit
                ? (prefs.language == .th ? "แก้ไขชื่อพอร์ต" : "Rename Portfolio")
                : prefs.t("portfolios.createPortTitle"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(prefs.t("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(submitLabel) { submit() }
                        .disabled(loading)
                }
            }
            .onAppear { initializeIfNeeded() }
        }
    }

    private var submitLabel: String {
        if loading { return prefs.t("common.loading") }
        return isEdit ? prefs.t("common.save") : (prefs.language == .th ? "สร้างพอร์ต" : "Create")
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        name = editing?.name ?? ""
        didInitialize = true
    }

    private func submit() {
        error = nil
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            error = prefs.t("portfolios.nameRequired")
            return
        }
        loading = true
        Task {
            do {
                if let editing {
                    try await store.updatePortfolio(editing.id, UpdatePortfolioRequest(name: trimmedName))
                } else {
                    try await store.createPortfolio(CreatePortfolioRequest(name: trimmedName))
                }
                loading = false
                onDone()
                dismiss()
            } catch let apiError as APIError {
                loading = false
                error = apiError.displayMessage
            } catch {
                loading = false
                self.error = prefs.t("common.error")
            }
        }
    }
}

#Preview {
    PortfolioFormSheet(store: PreviewFactory.store(), prefs: PreferencesStore())
}
