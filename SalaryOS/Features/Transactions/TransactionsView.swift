import Observation
import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

@MainActor
@Observable
private final class TransactionsViewModel {
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    var postings: [LedgerPosting] = []
    var accounts: [UUID: Account] = [:]
    var categories: [UUID: SalaryOSDomain.Category] = [:]
    var debts: [UUID: Debt] = [:]
    var savingsGoals: [UUID: SavingsGoal] = [:]
    var loans: [UUID: Loan] = [:]
    var errorMessage: String?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository & DebtRepository & SavingsGoalRepository & LoanRepository) {
        self.repository = repository
    }

    func reload() {
        do {
            postings = try repository.postings(from: nil, through: nil).sorted { $0.occurredAt > $1.occurredAt }
            accounts = Dictionary(uniqueKeysWithValues: try repository.accounts(includeArchived: true).map { ($0.id, $0) })
            categories = Dictionary(uniqueKeysWithValues: try repository.categories(kind: nil, includeArchived: true).map { ($0.id, $0) })
            debts = Dictionary(uniqueKeysWithValues: try repository.debts(includeArchived: true).map { ($0.id, $0) })
            savingsGoals = Dictionary(uniqueKeysWithValues: try repository.goals(includeArchived: true).map { ($0.id, $0) })
            loans = Dictionary(uniqueKeysWithValues: try repository.loans(includeArchived: true).map { ($0.id, $0) })
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum TransactionSheet: Identifiable {
    case create
    case details(LedgerPosting)
    case duplicate(LedgerPosting)
    case correct(LedgerPosting)

    var id: String {
        switch self {
        case .create: "create"
        case .details(let posting): "details-\(posting.id)"
        case .duplicate(let posting): "duplicate-\(posting.id)"
        case .correct(let posting): "correct-\(posting.id)"
        }
    }
}

struct TransactionsView: View {
    @State private var model: TransactionsViewModel
    private let repository: any AccountRepository & CategoryRepository & LedgerRepository & DebtRepository & SavingsGoalRepository & LoanRepository
    @State private var searchText = ""
    @State private var kindFilter: TransactionKind?
    @Binding private var isEditorPresented: Bool
    @State private var activeSheet: TransactionSheet?

    init(repository: any AccountRepository & CategoryRepository & LedgerRepository & DebtRepository & SavingsGoalRepository & LoanRepository, isEditorPresented: Binding<Bool> = .constant(false)) {
        self.repository = repository
        _model = State(initialValue: TransactionsViewModel(repository: repository))
        _isEditorPresented = isEditorPresented
    }

    private var filteredPostings: [LedgerPosting] {
        model.postings.filter { posting in
            (kindFilter == nil || posting.kind == kindFilter)
                && (searchText.isEmpty
                    || posting.description.localizedCaseInsensitiveContains(searchText)
                    || (posting.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
                    || posting.entries.contains { entry in
                        model.accounts[entry.accountID]?.name.localizedCaseInsensitiveContains(searchText) == true
                            || model.categories[entry.accountID]?.name.localizedCaseInsensitiveContains(searchText) == true
                            || model.debts[entry.accountID]?.name.localizedCaseInsensitiveContains(searchText) == true
                            || model.savingsGoals[entry.accountID]?.name.localizedCaseInsensitiveContains(searchText) == true
                            || model.loans[entry.accountID]?.name.localizedCaseInsensitiveContains(searchText) == true
                    })
        }
    }

    var body: some View {
        Group {
            if model.postings.isEmpty {
                ContentUnavailableView {
                    Label("transactions.empty.title", systemImage: "list.bullet.rectangle")
                } description: {
                    Text("transactions.empty.description")
                } actions: {
                    Button("transactions.add") { activeSheet = .create }
                        .buttonStyle(.borderedProminent)
                }
            } else if filteredPostings.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                List(filteredPostings) { posting in
                    Button { activeSheet = .details(posting) } label: {
                        TransactionRow(posting: posting)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("transactions.open-details-hint")
                }
                .financeListStyle()
            }
        }
        .navigationTitle("navigation.transactions")
        .searchable(text: $searchText, prompt: Text("transactions.search"))
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    Picker("transactions.filter.kind", selection: $kindFilter) {
                        Text("transactions.filter.all").tag(nil as TransactionKind?)
                        ForEach(TransactionKind.allCases, id: \.self) { kind in
                            Text(kind.localizedKey).tag(kind as TransactionKind?)
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .accessibilityLabel("transactions.filter.kind")
            }
            ToolbarItem(placement: .primaryAction) {
                Button { activeSheet = .create } label: {
                    Label("transactions.add", systemImage: "plus")
                }
            }
        }
        .onChange(of: isEditorPresented) { _, isPresented in
            if isPresented {
                activeSheet = .create
                isEditorPresented = false
            }
        }
        .sheet(item: $activeSheet, onDismiss: model.reload) { sheet in
            switch sheet {
            case .create:
                TransactionEditorView(repository: repository)
            case .details(let posting):
                TransactionDetailView(
                    posting: posting, accounts: model.accounts, categories: model.categories,
                    debts: model.debts, savingsGoals: model.savingsGoals, loans: model.loans,
                    repository: repository,
                    onDuplicate: { activeSheet = .duplicate(posting) },
                    onCorrect: { activeSheet = .correct(posting) },
                    onUpdated: model.reload
                )
            case .duplicate(let posting):
                TransactionEditorView(repository: repository, duplicate: posting)
            case .correct(let posting):
                TransactionEditorView(repository: repository, correcting: posting)
            }
        }
        .alert("common.error-title", isPresented: errorPresented) {
            Button("common.done", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "common.unknown-error")
        }
        .onAppear {
            model.reload()
            if isEditorPresented {
                activeSheet = .create
                isEditorPresented = false
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
    }
}

private struct TransactionRow: View {
    let posting: LedgerPosting

    private var amount: Money? { posting.primaryAmount }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: posting.kind.symbol)
                .foregroundStyle(posting.kind == .expense ? .red : .secondary)
                .frame(width: 34, height: 34)
                .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Text(posting.description).font(.headline).lineLimit(1)
                Text(posting.occurredAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if let amount {
                Text(amount.amount.formatted(.currency(code: amount.currency.code)))
                    .font(.body.monospacedDigit())
                    .foregroundStyle(posting.kind == .expense ? .red : .primary)
            }
        }
        .contentShape(Rectangle())
        .padding(.vertical, 3)
    }
}

private struct TransactionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let posting: LedgerPosting
    let accounts: [UUID: Account]
    let categories: [UUID: SalaryOSDomain.Category]
    let debts: [UUID: Debt]
    let savingsGoals: [UUID: SavingsGoal]
    let loans: [UUID: Loan]
    let repository: any AccountRepository & CategoryRepository & LedgerRepository
    let onDuplicate: () -> Void
    let onCorrect: () -> Void
    let onUpdated: () -> Void
    @State private var isReverseConfirmationPresented = false
    @State private var errorMessage: String?

    private var canReverseOrCorrect: Bool {
        posting.kind == .income || posting.kind == .expense || posting.kind == .transfer
    }

    var body: some View {
        NavigationStack {
            List {
                Section("transactions.details.section") {
                    LabeledContent("transactions.details.type") { Text(posting.kind.localizedKey) }
                    LabeledContent("transactions.details.date", value: posting.occurredAt.formatted(date: .long, time: .shortened))
                    if let notes = posting.notes, !notes.isEmpty {
                        LabeledContent("transactions.details.notes", value: notes)
                    }
                    if let relatedID = posting.relatedPostingID {
                        LabeledContent("transactions.details.related-id", value: relatedID.uuidString)
                    }
                }
                Section("transactions.details.entries") {
                    ForEach(Array(posting.entries.enumerated()), id: \.offset) { element in
                        let entry = element.element
                        HStack {
                            VStack(alignment: .leading) {
                                Text(label(for: entry))
                                Text(entry.accountKind.localizedKey)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(entry.money.amount.formatted(.currency(code: entry.money.currency.code)))
                                .monospacedDigit()
                            Text(entry.side.localizedKey)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                if canReverseOrCorrect {
                    Section("transactions.details.actions") {
                        if posting.debtPaymentID == nil {
                            Button("transactions.edit", action: onCorrect)
                            Button("transactions.duplicate", action: onDuplicate)
                        }
                        Button("transactions.reverse", role: .destructive) {
                            isReverseConfirmationPresented = true
                        }
                    }
                }
            }
            .navigationTitle(posting.description)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .confirmationDialog("transactions.reverse.confirmation", isPresented: $isReverseConfirmationPresented, titleVisibility: .visible) {
                Button("transactions.reverse.confirm", role: .destructive, action: reverse)
                Button("common.cancel", role: .cancel) { }
            }
            .alert("common.error-title", isPresented: Binding(
                get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
            )) {
                Button("common.done", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "common.unknown-error")
            }
        }
        .frame(minWidth: 360, minHeight: 380)
    }

    private func reverse() {
        do {
            _ = try repository.reverse(
                postingID: posting.id,
                description: String(localized: "transactions.reversal.description"),
                occurredAt: .now
            )
            onUpdated()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func label(for entry: LedgerEntry) -> String {
        if let account = accounts[entry.accountID] { return account.name }
        if let debt = debts[entry.accountID] { return debt.name }
        if let goal = savingsGoals[entry.accountID] { return goal.name }
        if let loan = loans[entry.accountID] { return loan.name }
        if let category = categories[entry.accountID] {
            return category.kind == .salary ? String(localized: "transaction-kind.salary") : category.name
        }
        return entry.accountID.uuidString
    }
}

extension TransactionKind {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .income: "transaction-kind.income"
        case .expense: "transaction-kind.expense"
        case .transfer: "transaction-kind.transfer"
        case .refund: "transaction-kind.refund"
        case .adjustment: "transaction-kind.adjustment"
        case .reversal: "transaction-kind.reversal"
        }
    }

    var symbol: String {
        switch self {
        case .income: "arrow.down.left"
        case .expense: "arrow.up.right"
        case .transfer: "arrow.left.arrow.right"
        case .refund: "arrow.uturn.backward"
        case .adjustment: "slider.horizontal.3"
        case .reversal: "arrow.uturn.backward"
        }
    }
}

extension LedgerAccountKind {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .asset: "ledger-kind.asset"
        case .liability: "ledger-kind.liability"
        case .income: "ledger-kind.income"
        case .expense: "ledger-kind.expense"
        }
    }
}

extension EntrySide {
    var localizedKey: LocalizedStringKey {
        switch self {
        case .debit: "ledger-side.debit"
        case .credit: "ledger-side.credit"
        }
    }
}
