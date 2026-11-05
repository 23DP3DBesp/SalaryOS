import SalaryOSDomain
import SwiftUI

struct SavingsGoalsView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository
    @State private var goals: [SavingsGoalProgress] = []
    @State private var accounts: [Account] = []
    @State private var editorGoal: SavingsGoal?
    @State private var isEditorPresented = false
    @State private var contributionGoal: SavingsGoalProgress?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if goals.isEmpty {
                ContentUnavailableView("savings.empty.title", systemImage: "target", description: Text("savings.empty.description"))
            } else {
                List {
                    ForEach(goals, id: \.goal.id) { item in
                        VStack(alignment: .leading, spacing: 9) {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.goal.name).font(.headline)
                                    if let id = item.goal.linkedAccountID, let account = accounts.first(where: { $0.id == id }) {
                                        Text(account.name).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text(money(item.goal.target)).font(.headline)
                            }
                            ProgressView(value: NSDecimalNumber(decimal: item.progressFraction).doubleValue)
                                .tint(item.status == .reached ? .green : .primary)
                            HStack {
                                Text("\(String(localized: "savings.saved")): \(money(item.saved))")
                                Spacer()
                                Text("\(String(localized: "savings.remaining")): \(money(item.remaining))")
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if let required = item.requiredMonthlyContribution {
                                Text("\(String(localized: "savings.monthly-needed")): \(money(required))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if let targetDate = item.goal.targetDate {
                                Text("\(String(localized: "savings.target-date")): \(targetDate.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            if item.status == .active {
                                Button("savings.add-contribution", systemImage: "plus.circle") { contributionGoal = item }
                                    .font(.subheadline)
                            } else {
                                Label("savings.reached", systemImage: "checkmark.circle").foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 6)
                        .contextMenu {
                            Button("savings.edit", systemImage: "pencil") { editorGoal = item.goal; isEditorPresented = true }
                            Button("savings.archive", systemImage: "archivebox") { archive(item.goal) }
                            if !item.contributions.isEmpty {
                                Divider()
                                Text("savings.contribution-history")
                                ForEach(item.contributions) { contribution in
                                    Text("\(contribution.contributedAt.formatted(date: .abbreviated, time: .omitted)): \(money(contribution.amount))")
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("navigation.savings")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("savings.add-goal", systemImage: "plus") { editorGoal = nil; isEditorPresented = true }
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: reload) {
            SavingsGoalEditor(repository: repository, existingGoal: editorGoal)
        }
        .sheet(item: $contributionGoal, onDismiss: reload) { progress in
            SavingsContributionEditor(repository: repository, progress: progress)
        }
        .task { reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func money(_ value: Money) -> String { value.amount.formatted(.currency(code: value.currency.code)) }

    private func reload() {
        do {
            accounts = try repository.accounts(includeArchived: true)
            goals = try repository.goals(includeArchived: false)
                .map { try repository.progress(for: $0.id, asOf: .now, calendar: .current) }
                .sorted { lhs, rhs in
                    if lhs.status != rhs.status { return lhs.status == .active }
                    return lhs.goal.createdAt > rhs.goal.createdAt
                }
        } catch { errorMessage = error.localizedDescription }
    }

    private func archive(_ goal: SavingsGoal) {
        do { var changed = goal; changed.setArchived(true); try repository.save(changed); reload() }
        catch { errorMessage = error.localizedDescription }
    }
}

private struct SavingsGoalEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository
    let existingGoal: SavingsGoal?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var target = ""
    @State private var currencyCode = "EUR"
    @State private var hasDate = false
    @State private var targetDate = Calendar.current.date(byAdding: .month, value: 6, to: .now) ?? .now
    @State private var accountID: UUID?
    @State private var notes = ""
    @State private var accounts: [Account] = []
    @State private var errorMessage: String?

    private var compatibleAccounts: [Account] { accounts.filter { $0.currency.code == currencyCode.uppercased() } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("savings.name", text: $name)
                HStack {
                    TextField("savings.target", text: $target)
#if os(iOS)
                        .keyboardType(.decimalPad)
#endif
                    TextField("savings.currency", text: $currencyCode).frame(maxWidth: 72).disabled(existingGoal != nil)
                }
                .disabled(existingGoal != nil)
                Toggle("savings.has-target-date", isOn: $hasDate)
                if hasDate { DatePicker("savings.target-date", selection: $targetDate, displayedComponents: .date) }
                Picker("savings.link-account", selection: $accountID) {
                    Text("savings.no-linked-account").tag(UUID?.none)
                    ForEach(compatibleAccounts) { account in Text(account.name).tag(Optional(account.id)) }
                }
                .disabled(existingGoal != nil)
                TextField("savings.notes", text: $notes, axis: .vertical).lineLimit(2...5)
            }
            .navigationTitle(existingGoal == nil ? "savings.add-goal" : "savings.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save", action: save).disabled(name.isEmpty || Decimal(string: target) == nil) }
            }
            .task { load() }
            .onChange(of: currencyCode) { _, _ in
                if let accountID, !compatibleAccounts.contains(where: { $0.id == accountID }) { self.accountID = nil }
            }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 360, minHeight: 400)
    }

    private func load() {
        do { accounts = try repository.accounts(includeArchived: false) }
        catch { errorMessage = error.localizedDescription }
        guard let existingGoal else { return }
        name = existingGoal.name
        target = NSDecimalNumber(decimal: existingGoal.target.amount).stringValue
        currencyCode = existingGoal.currency.code
        if let date = existingGoal.targetDate { hasDate = true; targetDate = date }
        accountID = existingGoal.linkedAccountID
        notes = existingGoal.notes ?? ""
    }

    private func save() {
        do {
            guard let decimal = Decimal(string: target.replacingOccurrences(of: ",", with: ".")) else { throw SavingsGoalError.nonPositiveTarget }
            let money = try Money(decimal, currency: Currency(code: currencyCode.uppercased()))
            if var existingGoal {
                try existingGoal.update(name: name, target: money, targetDate: hasDate ? targetDate : nil, notes: notes)
                try repository.save(existingGoal)
            } else {
                try repository.save(SavingsGoal(name: name, target: money, targetDate: hasDate ? targetDate : nil, linkedAccountID: accountID, notes: notes))
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct SavingsContributionEditor: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository
    let progress: SavingsGoalProgress
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var note = ""
    @State private var accounts: [Account] = []
    @State private var accountID: UUID?
    @State private var errorMessage: String?

    private var goal: SavingsGoal { progress.goal }
    private var compatibleAccounts: [Account] {
        accounts.filter { !$0.type.isLiability && $0.currency == goal.currency && $0.id != goal.linkedAccountID }
    }

    var body: some View {
        NavigationStack {
            Form {
                LabeledContent("savings.remaining", value: progress.remaining.amount.formatted(.currency(code: goal.currency.code)))
                TextField("savings.contribution-amount", text: $amount)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Picker("savings.contribution-account", selection: $accountID) {
                    Text("transactions.field.choose-account").tag(UUID?.none)
                    ForEach(compatibleAccounts) { account in Text(account.name).tag(Optional(account.id)) }
                }
                TextField("savings.contribution-note", text: $note)
            }
            .navigationTitle("savings.add-contribution")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(Decimal(string: amount) == nil || accountID == nil)
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
            guard let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")) else { throw SavingsGoalError.nonPositiveContribution }
            guard let accountID else { return }
            let contribution = try SavingsContribution(goalID: goal.id, amount: Money(decimal, currency: goal.currency), note: note)
            _ = try repository.record(contribution, from: accountID)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
