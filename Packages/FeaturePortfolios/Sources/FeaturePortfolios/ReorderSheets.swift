import SwiftUI
import PortoKit
import PortoDesign

/// Full-portfolio-list reorder sheet. `.onMove` + Done commits an optimistic
/// `store.reorderPortfolios(orderedIds)` (the store itself handles rollback + refetch on failure).
struct ReorderPortfoliosSheet: View {
    let store: AppDataStore
    let theme: Theme
    let language: Language
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Portfolio]

    init(store: AppDataStore, theme: Theme, language: Language) {
        self.store = store
        self.theme = theme
        self.language = language
        _items = State(initialValue: store.portfolios)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, p in
                    HStack(spacing: 10) {
                        Circle().fill(theme.paletteColor(p.color)).frame(width: 10, height: 10)
                        Text(p.name)
                    }
                    .tag(idx)
                }
                .onMove { indices, newOffset in
                    items.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle(language == .th ? "จัดลำดับพอร์ต" : "Reorder Portfolios")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .th ? "ยกเลิก" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .th ? "เสร็จสิ้น" : "Done") {
                        let ids = items.map(\.id)
                        dismiss()
                        Task { try? await store.reorderPortfolios(ids) }
                    }
                }
            }
        }
    }
}

/// Reorders the assets within a single portfolio. `orderedIds` passed to `reorderAssets` covers
/// only this portfolio's assets — the store keeps every other asset's position unchanged.
struct ReorderAssetsSheet: View {
    let store: AppDataStore
    let portfolio: Portfolio
    let theme: Theme
    let language: Language
    @Environment(\.dismiss) private var dismiss
    @State private var items: [Asset]

    init(store: AppDataStore, portfolio: Portfolio, theme: Theme, language: Language) {
        self.store = store
        self.portfolio = portfolio
        self.theme = theme
        self.language = language
        _items = State(initialValue: store.assets
            .filter { $0.portfolioId == portfolio.id }
            .sorted { ($0.sortOrder ?? Int.max) < ($1.sortOrder ?? Int.max) })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { a in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(a.symbol).font(.subheadline.bold())
                        if !a.name.isEmpty, a.name != a.symbol {
                            Text(a.name).font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { indices, newOffset in
                    items.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            #if os(iOS)
            .environment(\.editMode, .constant(.active))
            #endif
            .navigationTitle(portfolio.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(language == .th ? "ยกเลิก" : "Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(language == .th ? "เสร็จสิ้น" : "Done") {
                        let ids = items.map(\.id)
                        dismiss()
                        Task { try? await store.reorderAssets(ids) }
                    }
                }
            }
        }
    }
}
