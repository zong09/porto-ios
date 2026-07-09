import SwiftUI
import PortoKit
import PortoDesign

/// The four liability edit modes, ported from `LiabilityModal.tsx`.
public enum LiabilityFormMode: String, CaseIterable, Sendable {
    /// Create a new liability, or (when editing) directly set its outstanding balance/name/currency.
    case set
    /// Record a payment (reduces the balance).
    case pay
    /// Record additional debt (increases the balance).
    case add
}

/// Create or edit a liability, or record a pay/add adjustment. Ported from `LiabilityModal.tsx`.
public struct LiabilityFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    private let store: AppDataStore
    private let prefs: PreferencesStore
    private let editing: Liability?
    private let initialMode: LiabilityFormMode
    private let onDone: () -> Void

    public init(
        store: AppDataStore,
        prefs: PreferencesStore,
        editing: Liability? = nil,
        initialMode: LiabilityFormMode = .set,
        onDone: @escaping () -> Void = {}
    ) {
        self.store = store
        self.prefs = prefs
        self.editing = editing
        self.initialMode = editing == nil ? .set : initialMode
        self.onDone = onDone
    }

    private var isEdit: Bool { editing != nil }

    @State private var name: String = ""
    @State private var amount: String = ""
    @State private var currency: Currency = .thb
    @State private var mode: LiabilityFormMode = .set
    @State private var delta: String = ""

    @State private var error: String?
    @State private var loading = false
    @State private var didInitialize = false

    private var th: Bool { prefs.language == .th }

    public var body: some View {
        NavigationStack {
            Form {
                if let editing {
                    Section {
                        HStack {
                            Text(th ? "ยอดปัจจุบัน" : "Current balance")
                            Spacer()
                            Text(MoneyFormat.format(editing.amount, editing.currency)).bold()
                        }
                        Picker("mode", selection: $mode) {
                            Text(th ? "แก้ไขยอดสุทธิ" : "Set balance").tag(LiabilityFormMode.set)
                            Text(th ? "จ่ายหนี้" : "Pay").tag(LiabilityFormMode.pay)
                            Text(th ? "เพิ่มหนี้" : "Add debt").tag(LiabilityFormMode.add)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                    }
                }

                if !isEdit || mode == .set {
                    Section {
                        TextField(th ? "ชื่อหนี้สิน" : "Liability Name", text: $name)
                        HStack {
                            NumericField(title: "Amount", text: $amount)
                            Picker("currency", selection: $currency) {
                                Text("THB").tag(Currency.thb)
                                Text("USD").tag(Currency.usd)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 140)
                            .labelsHidden()
                        }
                    } header: {
                        Text(th ? "ยอดหนี้สิน" : "Outstanding Balance")
                    }
                }

                if isEdit, mode != .set {
                    Section {
                        NumericField(title: mode == .pay ? "Payment amount" : "Debt added", text: $delta)
                        if let editing, let d = FormSupport.parseDouble(delta), d > 0 {
                            let next = max(0, mode == .pay ? editing.amount - d : editing.amount + d)
                            HStack {
                                Text(th ? "ยอดใหม่" : "New balance")
                                Spacer()
                                Text(MoneyFormat.format(next, editing.currency)).bold()
                            }
                        }
                    } header: {
                        Text(mode == .pay
                            ? (th ? "จำนวนเงินที่จ่าย" : "Payment amount")
                            : (th ? "จำนวนหนี้ที่เพิ่ม" : "Debt added"))
                    }
                }

                if let error {
                    Section { FormErrorBanner(message: error) }
                }
            }
            .navigationTitle(isEdit ? (th ? "แก้ไขหนี้สิน" : "Edit Liability") : prefs.t("modals.liability.createTitle"))
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
        if isEdit && mode == .pay { return th ? "จ่ายหนี้" : "Pay" }
        if isEdit && mode == .add { return th ? "เพิ่มหนี้" : "Add Debt" }
        return prefs.t("common.save")
    }

    private func initializeIfNeeded() {
        guard !didInitialize else { return }
        if let editing {
            name = editing.name
            amount = String(editing.amount)
            currency = editing.currency
        } else {
            name = ""
            amount = ""
            currency = .thb
        }
        mode = initialMode
        delta = ""
        didInitialize = true
    }

    private func submit() {
        error = nil

        if isEdit, let editing, mode != .set {
            guard let d = FormSupport.parseDouble(delta), d > 0 else {
                error = th ? "กรุณากรอกจำนวนเงินให้ถูกต้อง (> 0)" : "Please enter a valid amount (> 0)"
                return
            }
            loading = true
            Task {
                do {
                    let req = AdjustLiabilityRequest(
                        type: mode == .pay ? .pay : .add,
                        amount: d,
                        date: BangkokDate.todayString()
                    )
                    try await store.adjustLiability(editing.id, req)
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
            return
        }

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else {
            error = th ? "กรุณากรอกชื่อรายการหนี้สิน" : "Please enter a liability name"
            return
        }
        guard let parsedAmount = FormSupport.parseDouble(amount), parsedAmount >= 0 else {
            error = th ? "กรุณากรอกยอดหนี้สินให้ถูกต้อง" : "Please enter a valid balance"
            return
        }

        loading = true
        Task {
            do {
                if let editing {
                    try await store.updateLiability(editing.id, UpdateLiabilityRequest(name: trimmedName, amount: parsedAmount, currency: currency.rawValue))
                } else {
                    try await store.createLiability(CreateLiabilityRequest(name: trimmedName, amount: parsedAmount, currency: currency.rawValue))
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
    LiabilityFormSheet(store: PreviewFactory.store(), prefs: PreferencesStore())
}
