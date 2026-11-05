import SalaryOSDomain
import SwiftUI

struct DebtsView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository
    @State private var summaries: [DebtSummary] = []
    @State private var isEditorPresented = false
    @State private var selectedDebt: Debt?
    @State private var paymentDebt: DebtSummary?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if summaries.isEmpty {
                ContentUnavailableView("debt.empty.title", systemImage: "person.text.rectangle", description: Text("debt.empty.description"))
            } else {
                List {
                    ForEach(summaries, id: \.debt.id) { summary in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(summary.debt.name).font(.headline)
                                    HStack(spacing: 4) {
                                        Text(summary.debt.counterparty)
                                        Text("·")
                                        Text(summary.debt.direction.localizationKey)
                                    }
                                    .font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 3) {
                                    Text(money(summary.outstanding)).font(.headline)
                                    Text("debt.outstanding").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Text("\(String(localized: "debt.paid")): \(money(summary.paid))")
                                Spacer()
                                Text("\(String(localized: "debt.principal")): \(money(summary.debt.principal))")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if let dueDate = summary.debt.dueDate {
                                Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if summary.status == .open {
                                Button("debt.record-payment", systemImage: "plus.circle") { paymentDebt = summary }
                                    .font(.subheadline)
                            } else {
                                Label("debt.settled", systemImage: "checkmark.circle")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("debt.edit", systemImage: "pencil") { selectedDebt = summary.debt; isEditorPresented = true }
                            Button("debt.archive", systemImage: "archivebox") { archive(summary.debt) }
                            if !summary.payments.isEmpty {
                                Divider()
                                Text("debt.payment-history")
                                ForEach(summary.payments) { payment in
                                    Text("\(payment.paidAt.formatted(date: .abbreviated, time: .omitted)): \(money(payment.amount))")
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("navigation.debts")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("debt.add", systemImage: "plus") { selectedDebt = nil; isEditorPresented = true }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: reload) {
            DebtEditorView(repository: repository, existingDebt: selectedDebt)
        }
        .sheet(item: $paymentDebt, onDismiss: reload) { summary in
            DebtPaymentEditor(repository: repository, summary: summary)
        }
        .task { reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func money(_ value: Money) -> String { value.amount.formatted(.currency(code: value.currency.code)) }

    private func reload() {
        do {
            summaries = try repository.debts(includeArchived: false).map { try repository.summary(for: $0.id) }
                .sorted { lhs, rhs in
                    if lhs.status != rhs.status { return lhs.status == .open }
                    return lhs.debt.createdAt > rhs.debt.createdAt
                }
        } catch { errorMessage = error.localizedDescription }
    }

    private func archive(_ debt: Debt) {
        do { var value = debt; value.setArchived(true); try repository.save(value); reload() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct DebtEditorView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository
    let existingDebt: Debt?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var counterparty = ""
    @State private var direction: DebtDirection = .payable
    @State private var amount = ""
    @State private var currencyCode = "EUR"
    @State private var hasDueDate = false
    @State private var dueDate = Date.now
    @State private var notes = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("debt.name", text: $name)
                TextField("debt.counterparty", text: $counterparty)
                Picker("debt.direction", selection: $direction) {
                    ForEach(DebtDirection.allCases, id: \.self) { item in Text(item.localizationKey).tag(item) }
                }
                .disabled(existingDebt != nil)
                HStack {
                    TextField("debt.principal", text: $amount)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    TextField("debt.currency", text: $currencyCode)
                        .frame(maxWidth: 70)
                        .disabled(existingDebt != nil)
                }
                .disabled(existingDebt != nil)
                Toggle("debt.has-due-date", isOn: $hasDueDate)
                if hasDueDate { DatePicker("debt.due-date", selection: $dueDate, displayedComponents: .date) }
                TextField("debt.notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle(existingDebt == nil ? "debt.add" : "debt.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save", action: save).disabled(name.isEmpty || counterparty.isEmpty || Decimal(string: amount) == nil) }
            }
            .task { load() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 420)
    }

    private func load() {
        guard let existingDebt else { return }
        name = existingDebt.name
        counterparty = existingDebt.counterparty
        direction = existingDebt.direction
        amount = NSDecimalNumber(decimal: existingDebt.principal.amount).stringValue
        currencyCode = existingDebt.principal.currency.code
        if let due = existingDebt.dueDate { hasDueDate = true; dueDate = due }
        notes = existingDebt.notes ?? ""
    }

    private func save() {
        do {
            if var existingDebt {
                try existingDebt.updateDetails(name: name, counterparty: counterparty, dueDate: hasDueDate ? dueDate : nil, notes: notes)
                try repository.save(existingDebt)
            } else {
                guard let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { throw DebtError.nonPositivePrincipal }
                let currency = try Currency(code: currencyCode.uppercased())
                let principal = try Money(decimal, currency: currency)
                try repository.save(Debt(name: name, counterparty: counterparty, direction: direction, principal: principal, dueDate: hasDueDate ? dueDate : nil, notes: notes))
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct DebtPaymentEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository
    let summary: DebtSummary
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var accounts: [Account] = []
    @State private var accountID: UUID?
    @State private var errorMessage: String?

    private var debt: Debt { summary.debt }
    private var compatibleAccounts: [Account] {
        accounts.filter { !$0.type.isLiability && $0.currency == debt.principal.currency }
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("debt.outstanding", value: summary.outstanding.amount.formatted(.currency(code: debt.principal.currency.code)))
                TextField("debt.payment-amount", text: $amount)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Picker("debt.payment-account", selection: $accountID) {
                    Text("transactions.field.choose-account").tag(UUID?.none)
                    ForEach(compatibleAccounts) { account in Text(account.name).tag(Optional(account.id)) }
                }
                TextField("debt.payment-note", text: $note)
            }
            .navigationTitle("debt.record-payment")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(Decimal(string: amount).map { $0 > .zero && $0 <= summary.outstanding.amount } != true || accountID == nil)
                }
            }
            .task { loadAccounts() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 320)
    }

    private func loadAccounts() {
        do {
            accounts = try repository.accounts(includeArchived: false)
            accountID = compatibleAccounts.first?.id
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            guard let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { throw DebtError.nonPositivePayment }
            guard let accountID else { return }
            let payment = try DebtPayment(debtID: debt.id, amount: Money(decimal, currency: debt.principal.currency), note: note)
            _ = try repository.record(payment, using: accountID)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension DebtDirection {
    var localizationKey: LocalizedStringKey {
        switch self { case .payable: "debt.direction.payable"; case .receivable: "debt.direction.receivable" }
    }
}
