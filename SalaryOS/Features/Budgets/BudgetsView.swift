import SalaryOSDomain
import SwiftUI

struct BudgetsView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository
    @State private var budgets: [Budget] = []
    @State private var progress: [UUID: BudgetProgress] = [:]
    @State private var categories: [UUID: SalaryOSDomain.Category] = [:]
    @State private var isEditorPresented = false
    @State private var selectedBudget: Budget?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if budgets.isEmpty {
                ContentUnavailableView("budget.empty.title", systemImage: "chart.bar.xaxis", description: Text("budget.empty.description"))
            } else {
                List {
                    ForEach(budgets) { budget in
                        Button { selectedBudget = budget; isEditorPresented = true } label: {
                            budgetRow(budget)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("budget.edit", systemImage: "pencil") { selectedBudget = budget; isEditorPresented = true }
                            Button("budget.archive", systemImage: "archivebox") { archive(budget) }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("navigation.budgets")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("budget.add", systemImage: "plus") { selectedBudget = nil; isEditorPresented = true }
                    .disabled(expenseCategories.isEmpty)
            }
        }
        .sheet(isPresented: $isEditorPresented, onDismiss: reload) {
            BudgetEditorView(repository: repository, existingBudget: selectedBudget)
        }
        .task { reload() }
        .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("common.ok", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var expenseCategories: [SalaryOSDomain.Category] {
        categories.values.filter { $0.kind == .expense && !$0.isArchived }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    @ViewBuilder
    private func budgetRow(_ budget: Budget) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(budget.name).font(.headline)
                    Text(categories[budget.categoryID]?.name ?? "budget.category.missing")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(money(budget.limit)).font(.headline)
                    Text("budget.limit.label").font(.caption).foregroundStyle(.secondary)
                }
            }
            if let current = progress[budget.id] {
                ProgressView(value: min(max(NSDecimalNumber(decimal: current.spent.amount / budget.limit.amount).doubleValue, 0), 1))
                    .tint(current.isOverLimit ? .red : .primary)
                HStack {
                    Text("\(money(current.spent)) / \(money(budget.limit))")
                    Spacer()
                    Text(current.remaining.amount < .zero ? "\(money(current.remaining)) \(String(localized: "budget.over"))" : "\(money(current.remaining)) \(String(localized: "budget.remaining"))")
                }
                .font(.caption).foregroundStyle(current.isOverLimit ? .red : .secondary)
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }

    private func money(_ value: Money) -> String {
        value.amount.formatted(.currency(code: value.currency.code))
    }

    private func reload() {
        do {
            budgets = try repository.budgets(includeArchived: false).sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            categories = Dictionary(uniqueKeysWithValues: try repository.categories(kind: .expense, includeArchived: true).map { ($0.id, $0) })
            progress = try Dictionary(uniqueKeysWithValues: budgets.map { ($0.id, try repository.progress(for: $0, on: .now, calendar: .current)) })
        } catch { errorMessage = error.localizedDescription }
    }

    private func archive(_ budget: Budget) {
        do {
            var archived = budget
            archived.setArchived(true)
            try repository.save(archived)
            reload()
        } catch { errorMessage = error.localizedDescription }
    }
}

private struct BudgetEditorView: View {
    let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository
    let existingBudget: Budget?
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var amount = ""
    @State private var categoryID: UUID?
    @State private var period: BudgetPeriod = .monthly
    @State private var categories: [SalaryOSDomain.Category] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("budget.name", text: $name)
                TextField("budget.limit.label", text: $amount)
#if os(iOS)
                    .keyboardType(.decimalPad)
#endif
                Picker("budget.category", selection: $categoryID) {
                    ForEach(categories) { category in Text(category.name).tag(Optional(category.id)) }
                }
                .disabled(existingBudget != nil)
                Picker("budget.period", selection: $period) {
                    ForEach(BudgetPeriod.allCases, id: \.self) { value in Text(value.localizationKey).tag(value) }
                }
                .disabled(existingBudget != nil)
            }
            .navigationTitle(existingBudget == nil ? "budget.add" : "budget.edit")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("common.save", action: save).disabled(categoryID == nil || Decimal(string: amount) == nil) }
            }
            .task { load() }
            .alert("common.error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("common.ok", role: .cancel) { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
        .frame(minWidth: 340, minHeight: 300)
    }

    private func load() {
        do {
            categories = try repository.categories(kind: .expense, includeArchived: false)
            if let existingBudget {
                name = existingBudget.name
                amount = NSDecimalNumber(decimal: existingBudget.limit.amount).stringValue
                categoryID = existingBudget.categoryID
                period = existingBudget.period
            } else {
                categoryID = categories.first?.id
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func save() {
        do {
            guard let categoryID, let decimal = Decimal(string: amount.replacingOccurrences(of: ",", with: ".")), decimal > .zero else {
                throw BudgetError.nonPositiveLimit
            }
            let money = try Money(decimal, currency: Currency(code: "EUR"))
            if var existingBudget {
                try existingBudget.update(name: name, limit: money)
                try repository.save(existingBudget)
            } else {
                try repository.save(Budget(name: name, categoryID: categoryID, limit: money, period: period))
            }
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}

private extension BudgetPeriod {
    var localizationKey: LocalizedStringKey {
        switch self {
        case .weekly: "budget.period.weekly"
        case .monthly: "budget.period.monthly"
        case .yearly: "budget.period.yearly"
        }
    }
}
