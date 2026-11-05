import SalaryOSDomain
import SalaryOSPersistence
import SwiftUI

private enum EntryTransactionKind: String, CaseIterable, Identifiable {
    case income, salary, expense, transfer, refund

    var id: String { rawValue }
    var domainKind: TransactionKind {
        switch self {
        case .income, .salary: .income
        case .expense: .expense
        case .transfer: .transfer
        case .refund: .refund
        }
    }

    var localizedKey: LocalizedStringKey { self == .salary ? "transaction-kind.salary" : domainKind.localizedKey }
}

struct TransactionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let repository: any AccountRepository & CategoryRepository & LedgerRepository
    let duplicate: LedgerPosting?
    let correcting: LedgerPosting?
    let salaryOnly: Bool
    let presetAmount: Decimal?

    private var sourcePosting: LedgerPosting? { correcting ?? duplicate }

    @State private var entryKind: EntryTransactionKind = .expense
    @State private var accounts: [Account] = []
    @State private var categories: [SalaryOSDomain.Category] = []
    @State private var originalExpenses: [LedgerPosting] = []
    @State private var accountID: UUID?
    @State private var destinationAccountID: UUID?
    @State private var categoryID: UUID?
    @State private var originalPostingID: UUID?
    @State private var amountText = ""
    @State private var descriptionText = ""
    @State private var notesText = ""
    @State private var occurredAt = Date.now
    @State private var isCategoryEditorPresented = false
    @State private var errorMessage: String?

    init(
        repository: any AccountRepository & CategoryRepository & LedgerRepository,
        duplicate: LedgerPosting? = nil,
        correcting: LedgerPosting? = nil,
        salaryOnly: Bool = false,
        presetAmount: Decimal? = nil
    ) {
        self.repository = repository
        self.duplicate = duplicate
        self.correcting = correcting
        self.salaryOnly = salaryOnly
        self.presetAmount = presetAmount
        let source = correcting ?? duplicate
        _entryKind = State(initialValue: salaryOnly ? .salary : Self.initialKind(for: source))
        _accountID = State(initialValue: Self.primaryAccountID(for: source))
        _destinationAccountID = State(initialValue: Self.destinationAccountID(for: source))
        _categoryID = State(initialValue: Self.categoryID(for: source))
        _descriptionText = State(initialValue: source?.description ?? (salaryOnly ? String(localized: "salary.default-description") : ""))
        _notesText = State(initialValue: source?.notes ?? "")
        _occurredAt = State(initialValue: source?.occurredAt ?? .now)
    }

    private var selectedAccount: Account? {
        accounts.first { $0.id == accountID }
    }

    private var destinationAccounts: [Account] {
        accounts.filter { $0.id != accountID && $0.currency == selectedAccount?.currency }
    }

    private var selectedOriginalExpense: LedgerPosting? {
        originalExpenses.first { $0.id == originalPostingID }
    }

    private var availableCategories: [SalaryOSDomain.Category] {
        switch entryKind {
        case .income:
            return categories.filter { $0.kind == .income || $0.kind == .salary }
        case .salary:
            return categories.filter { $0.kind == .salary }
        case .expense:
            return categories.filter { $0.kind == .expense }
        case .transfer:
            return []
        case .refund:
            guard let original = selectedOriginalExpense else { return [] }
            let originalCategoryIDs = Set(original.entries.filter { $0.accountKind == .expense }.map(\.accountID))
            return categories.filter { $0.kind == .expense && originalCategoryIDs.contains($0.id) }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("transactions.section.operation") {
                    if salaryOnly {
                        LabeledContent("transactions.field.type") { Text(EntryTransactionKind.salary.localizedKey) }
                    } else {
                        Picker("transactions.field.type", selection: $entryKind) {
                            ForEach(EntryTransactionKind.allCases.filter { correcting == nil || ($0 != .refund && $0 != .salary) }) { kind in
                                Text(kind.localizedKey).tag(kind)
                            }
                        }
                        .onChange(of: entryKind) { _, _ in setDefaults() }
                    }

                    if entryKind == .refund {
                        Picker("transactions.field.original-expense", selection: $originalPostingID) {
                            Text("transactions.field.choose-expense").tag(nil as UUID?)
                            ForEach(originalExpenses) { posting in
                                Text("\(posting.description) · \(posting.occurredAt.formatted(date: .abbreviated, time: .omitted))")
                                    .tag(posting.id as UUID?)
                            }
                        }
                        .onChange(of: originalPostingID) { _, _ in categoryID = availableCategories.first?.id }
                    }

                    Picker(entryKind == .transfer ? "transactions.field.from-account" : "transactions.field.account", selection: $accountID) {
                        Text("transactions.field.choose-account").tag(nil as UUID?)
                        ForEach(accounts) { account in
                            Text("\(account.name) · \(account.currency.code)").tag(account.id as UUID?)
                        }
                    }

                    if entryKind == .transfer {
                        Picker("transactions.field.to-account", selection: $destinationAccountID) {
                            Text("transactions.field.choose-account").tag(nil as UUID?)
                            ForEach(destinationAccounts) { account in
                                Text(account.name).tag(account.id as UUID?)
                            }
                        }
                    }

                    if entryKind != .transfer {
                        Picker("transactions.field.category", selection: $categoryID) {
                            Text("transactions.field.choose-category").tag(nil as UUID?)
                            ForEach(availableCategories) { category in
                                Text(category.name).tag(category.id as UUID?)
                            }
                        }
                        if !salaryOnly { Button("transactions.category.add") { isCategoryEditorPresented = true } }
                    }
                }

                Section("transactions.section.details") {
                    TextField("transactions.field.amount", text: $amountText)
                        .decimalKeyboard()
                    TextField("transactions.field.description", text: $descriptionText)
                    TextField("transactions.field.notes", text: $notesText, axis: .vertical)
                    DatePicker("transactions.field.date", selection: $occurredAt, displayedComponents: [.date, .hourAndMinute])
                }

                if let selectedAccount {
                    LabeledContent("transactions.field.currency", value: selectedAccount.currency.code)
                }

                if accounts.isEmpty {
                    ContentUnavailableView("transactions.no-accounts.title", systemImage: "building.columns", description: Text("transactions.no-accounts.description"))
                } else if entryKind != .transfer && availableCategories.isEmpty {
                    ContentUnavailableView("transactions.no-categories.title", systemImage: "tag", description: Text("transactions.no-categories.description"))
                }

                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle(correcting == nil ? Text("transactions.add-title") : Text("transactions.edit-title"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 500)
        .task {
            load()
            if let presetAmount { amountText = localizedAmount(presetAmount) }
            if let sourceAmount { amountText = localizedAmount(sourceAmount) }
        }
        .sheet(isPresented: $isCategoryEditorPresented) {
            CategoryEditorView(kind: categoryKind, repository: repository) { category in
                load()
                categoryID = category.id
            }
        }
    }

    private var sourceAmount: Decimal? {
        guard let sourcePosting else { return nil }
        switch sourcePosting.kind {
        case .income:
            return sourcePosting.entries.first(where: { $0.accountKind == .asset && $0.side == .debit })?.money.amount
        case .expense:
            return sourcePosting.entries.first(where: { $0.accountKind == .expense && $0.side == .debit })?.money.amount
        case .transfer:
            return sourcePosting.entries.first(where: { ($0.accountKind == .asset || $0.accountKind == .liability) && $0.side == .credit })?.money.amount
        case .refund, .adjustment, .reversal:
            return nil
        }
    }

    private func localizedAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = selectedAccount?.currency.fractionDigits ?? 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? NSDecimalNumber(decimal: amount).stringValue
    }

    private static func initialKind(for posting: LedgerPosting?) -> EntryTransactionKind {
        switch posting?.kind {
        case .income: .income
        case .expense: .expense
        case .transfer: .transfer
        case .refund: .refund
        case .adjustment, .reversal, .none: .expense
        }
    }

    private static func primaryAccountID(for posting: LedgerPosting?) -> UUID? {
        guard let posting else { return nil }
        let side: EntrySide = posting.kind == .income ? .debit : posting.kind == .transfer ? .credit : .credit
        return posting.entries.first(where: {
            ($0.accountKind == .asset || $0.accountKind == .liability) && $0.side == side
        })?.accountID
    }

    private static func destinationAccountID(for posting: LedgerPosting?) -> UUID? {
        guard posting?.kind == .transfer else { return nil }
        return posting?.entries.first(where: {
            ($0.accountKind == .asset || $0.accountKind == .liability) && $0.side == .debit
        })?.accountID
    }

    private static func categoryID(for posting: LedgerPosting?) -> UUID? {
        guard let posting else { return nil }
        let side: EntrySide = posting.kind == .income ? .credit : posting.kind == .expense ? .debit : .credit
        return posting.entries.first(where: {
            ($0.accountKind == .income || $0.accountKind == .expense) && $0.side == side
        })?.accountID
    }

    private var categoryKind: CategoryKind {
        switch entryKind {
        case .income: .income
        case .salary: .salary
        case .expense, .refund: .expense
        case .transfer: .income
        }
    }

    private var canSave: Bool {
        selectedAccount != nil
            && !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Decimal(string: amountText, locale: locale) != nil
            && (entryKind == .transfer ? destinationAccountID != nil : categoryID != nil)
            && (entryKind != .refund || originalPostingID != nil)
    }

    private func load() {
        do {
            accounts = try repository.accounts(includeArchived: false)
            categories = try repository.categories(kind: nil, includeArchived: false)
            originalExpenses = try repository.postings(from: nil, through: nil)
                .filter { $0.kind == .expense }
                .sorted { $0.occurredAt > $1.occurredAt }
            setDefaults()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setDefaults() {
        if !accounts.contains(where: { $0.id == accountID }) { accountID = accounts.first?.id }
        if !destinationAccounts.contains(where: { $0.id == destinationAccountID }) {
            destinationAccountID = destinationAccounts.first?.id
        }
        if entryKind == .refund {
            if !originalExpenses.contains(where: { $0.id == originalPostingID }) {
                originalPostingID = originalExpenses.first?.id
            }
        }
        if !availableCategories.contains(where: { $0.id == categoryID }) {
            categoryID = availableCategories.first?.id
        }
    }

    private func save() {
        guard let selectedAccount,
              let input = Decimal(string: amountText, locale: locale)
        else { return }
        do {
            let money = try Money(input, currency: selectedAccount.currency).requiringPositive()
            let description = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
            let notes = notesText.trimmingCharacters(in: .whitespacesAndNewlines)
            let posting: LedgerPosting
            switch entryKind {
            case .income, .salary:
                guard let categoryID else { return }
                posting = try LedgerFactory.income(amount: money, to: selectedAccount, categoryID: categoryID, description: description, notes: notes.nilIfBlank, occurredAt: occurredAt)
            case .expense:
                guard let categoryID else { return }
                posting = try LedgerFactory.expense(amount: money, from: selectedAccount, categoryID: categoryID, description: description, notes: notes.nilIfBlank, occurredAt: occurredAt)
            case .transfer:
                guard let destinationAccount = destinationAccounts.first(where: { $0.id == destinationAccountID }) else {
                    errorMessage = String(localized: "transactions.error.choose-destination", locale: locale)
                    return
                }
                posting = try LedgerFactory.transfer(amount: money, from: selectedAccount, to: destinationAccount, description: description, notes: notes.nilIfBlank, occurredAt: occurredAt)
            case .refund:
                guard let categoryID else { return }
                guard let originalPostingID else {
                    errorMessage = String(localized: "transactions.error.choose-original", locale: locale)
                    return
                }
                posting = try LedgerFactory.refund(amount: money, to: selectedAccount, expenseCategoryID: categoryID, originalPostingID: originalPostingID, description: description, notes: notes.nilIfBlank, occurredAt: occurredAt)
            }
            if let correcting {
                try repository.correct(
                    postingID: correcting.id,
                    reversingDescription: String(localized: "transactions.reversal.for-correction", locale: locale),
                    replacingWith: posting
                )
            } else {
                try repository.post(posting)
            }
            dismiss()
        } catch let error as MoneyError {
            errorMessage = String(localized: error == .notPositive ? "transactions.error.positive-amount" : "transactions.error.invalid-amount", locale: locale)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CategoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let kind: CategoryKind
    let repository: any AccountRepository & CategoryRepository & LedgerRepository
    let onSave: (SalaryOSDomain.Category) -> Void
    @State private var name = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("transactions.category.name", text: $name)
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(.red).font(.footnote)
                }
            }
            .navigationTitle("transactions.category.add-title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save", action: save).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 320, minHeight: 200)
    }

    private func save() {
        do {
            let category = try SalaryOSDomain.Category(name: name, kind: kind)
            try repository.save(category)
            onSave(category)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension View {
    @ViewBuilder func decimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
