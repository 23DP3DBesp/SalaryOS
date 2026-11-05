import Foundation
import SwiftData
import SalaryOSDomain

@Model
final class PersistedAccount {
    var id: UUID
    var name: String
    var typeRawValue: String
    var currencyCode: String
    var openingAmount: Decimal
    var institution: String?
    var details: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(_ account: Account) {
        id = account.id
        name = account.name
        typeRawValue = account.type.rawValue
        currencyCode = account.currency.code
        openingAmount = account.openingBalance.amount
        institution = account.institution
        details = account.details
        createdAt = account.createdAt
        updatedAt = account.updatedAt
        isArchived = account.isArchived
    }

    func domainValue() throws -> Account {
        guard let type = AccountType(rawValue: typeRawValue) else {
            throw PersistenceMappingError.invalidAccountType(typeRawValue)
        }
        let currency = try Currency(code: currencyCode)
        let balance = try Money(openingAmount, currency: currency)
        return try Account(
            id: id, name: name, type: type, currency: currency, openingBalance: balance,
            institution: institution, details: details, createdAt: createdAt,
            updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

@Model
final class PersistedCategory {
    var id: UUID
    var name: String
    var kindRawValue: String
    var parentID: UUID?
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(_ category: SalaryOSDomain.Category) {
        id = category.id
        name = category.name
        kindRawValue = category.kind.rawValue
        parentID = category.parentID
        isArchived = category.isArchived
        createdAt = category.createdAt
        updatedAt = category.updatedAt
    }

    func domainValue() throws -> SalaryOSDomain.Category {
        guard let kind = CategoryKind(rawValue: kindRawValue) else {
            throw PersistenceMappingError.invalidCategoryKind(kindRawValue)
        }
        return try SalaryOSDomain.Category(
            id: id, name: name, kind: kind, parentID: parentID,
            isArchived: isArchived, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

@Model
final class PersistedLedgerPosting {
    var id: UUID
    var kindRawValue: String
    var occurredAt: Date
    var descriptionText: String
    var notes: String?
    var relatedPostingID: UUID?
    var entriesData: Data
    var createdAt: Date

    init(_ posting: LedgerPosting, entriesData: Data) {
        id = posting.id
        kindRawValue = posting.kind.rawValue
        occurredAt = posting.occurredAt
        descriptionText = posting.description
        notes = posting.notes
        relatedPostingID = posting.relatedPostingID
        self.entriesData = entriesData
        createdAt = posting.createdAt
    }

    func domainValue() throws -> LedgerPosting {
        guard let kind = TransactionKind(rawValue: kindRawValue) else {
            throw PersistenceMappingError.invalidTransactionKind(kindRawValue)
        }
        let entries = try JSONDecoder().decode([LedgerEntry].self, from: entriesData)
        return try LedgerPosting(
            id: id, kind: kind, occurredAt: occurredAt, description: descriptionText,
            notes: notes, relatedPostingID: relatedPostingID, entries: entries, createdAt: createdAt
        )
    }
}

@Model
final class PersistedBudget {
    var id: UUID
    var name: String
    var categoryID: UUID
    var currencyCode: String
    var limitAmount: Decimal
    var periodRawValue: String
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(_ budget: Budget) {
        id = budget.id
        name = budget.name
        categoryID = budget.categoryID
        currencyCode = budget.currency.code
        limitAmount = budget.limit.amount
        periodRawValue = budget.period.rawValue
        createdAt = budget.createdAt
        updatedAt = budget.updatedAt
        isArchived = budget.isArchived
    }

    func domainValue() throws -> Budget {
        guard let period = BudgetPeriod(rawValue: periodRawValue) else {
            throw PersistenceMappingError.invalidBudgetPeriod(periodRawValue)
        }
        return try Budget(
            id: id, name: name, categoryID: categoryID,
            limit: Money(limitAmount, currency: Currency(code: currencyCode)),
            period: period, createdAt: createdAt, updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

@Model
final class PersistedDebt {
    var id: UUID
    var name: String
    var counterparty: String
    var directionRawValue: String
    var currencyCode: String
    var principalAmount: Decimal
    var createdAt: Date
    var dueDate: Date?
    var notes: String?
    var updatedAt: Date
    var isArchived: Bool

    init(_ debt: Debt) {
        id = debt.id
        name = debt.name
        counterparty = debt.counterparty
        directionRawValue = debt.direction.rawValue
        currencyCode = debt.principal.currency.code
        principalAmount = debt.principal.amount
        createdAt = debt.createdAt
        dueDate = debt.dueDate
        notes = debt.notes
        updatedAt = debt.updatedAt
        isArchived = debt.isArchived
    }

    func domainValue() throws -> Debt {
        guard let direction = DebtDirection(rawValue: directionRawValue) else {
            throw PersistenceMappingError.invalidDebtDirection(directionRawValue)
        }
        return try Debt(
            id: id, name: name, counterparty: counterparty, direction: direction,
            principal: Money(principalAmount, currency: Currency(code: currencyCode)),
            createdAt: createdAt, dueDate: dueDate, notes: notes,
            updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

@Model
final class PersistedDebtPayment {
    var id: UUID
    var debtID: UUID
    var currencyCode: String
    var amount: Decimal
    var paidAt: Date
    var note: String?
    var createdAt: Date

    init(_ payment: DebtPayment) {
        id = payment.id
        debtID = payment.debtID
        currencyCode = payment.amount.currency.code
        amount = payment.amount.amount
        paidAt = payment.paidAt
        note = payment.note
        createdAt = payment.createdAt
    }

    func domainValue() throws -> DebtPayment {
        try DebtPayment(
            id: id, debtID: debtID,
            amount: Money(amount, currency: Currency(code: currencyCode)),
            paidAt: paidAt, note: note, createdAt: createdAt
        )
    }
}

enum PersistenceMappingError: Error {
    case invalidAccountType(String)
    case invalidCategoryKind(String)
    case invalidTransactionKind(String)
    case invalidBudgetPeriod(String)
    case invalidDebtDirection(String)
}

/// Keeps each posting and its entries in one persisted record so they are saved atomically.
@MainActor
final class PersistentFinanceRepository: AccountRepository, CategoryRepository, LedgerRepository, BudgetRepository, DebtRepository {
    private let context: ModelContext
    private let encoder = JSONEncoder()

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ account: Account) throws {
        let records = try context.fetch(FetchDescriptor<PersistedAccount>())
        try ensureUniqueIDs(records)
        if let existing = records.first(where: { $0.id == account.id }) {
            guard existing.typeRawValue == account.type.rawValue,
                  existing.currencyCode == account.currency.code,
                  existing.openingAmount == account.openingBalance.amount
            else { throw RepositoryError.accountDefinitionConflict(account.id) }
            existing.name = account.name
            existing.institution = account.institution
            existing.details = account.details
            existing.updatedAt = .now
            existing.isArchived = account.isArchived
        } else {
            context.insert(PersistedAccount(account))
        }
        try commit()
    }

    func account(id: UUID) throws -> Account? {
        let records = try context.fetch(FetchDescriptor<PersistedAccount>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func accounts(includeArchived: Bool = false) throws -> [Account] {
        let records = try context.fetch(FetchDescriptor<PersistedAccount>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func save(_ category: SalaryOSDomain.Category) throws {
        let records = try context.fetch(FetchDescriptor<PersistedCategory>())
        try ensureUniqueIDs(records)
        var ancestorID = category.parentID
        var visitedAncestors = Set<UUID>()
        while let currentID = ancestorID {
            guard currentID != category.id,
                  visitedAncestors.insert(currentID).inserted,
                  let parent = records.first(where: { $0.id == currentID }),
                  parent.kindRawValue == category.kind.rawValue
            else { throw RepositoryError.invalidLedgerReference(currentID) }
            ancestorID = parent.parentID
        }
        if let existing = records.first(where: { $0.id == category.id }) {
            guard existing.kindRawValue == category.kind.rawValue else {
                throw RepositoryError.categoryDefinitionConflict(category.id)
            }
            existing.name = category.name
            existing.parentID = category.parentID
            existing.isArchived = category.isArchived
            existing.updatedAt = .now
        } else {
            context.insert(PersistedCategory(category))
        }
        try commit()
    }

    func category(id: UUID) throws -> SalaryOSDomain.Category? {
        let records = try context.fetch(FetchDescriptor<PersistedCategory>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func categories(kind: CategoryKind? = nil, includeArchived: Bool = false) throws -> [SalaryOSDomain.Category] {
        let records = try context.fetch(FetchDescriptor<PersistedCategory>())
        try ensureUniqueIDs(records)
        return try records.filter { record in
            (includeArchived || !record.isArchived)
                && (kind == nil || record.kindRawValue == kind?.rawValue)
        }.map { try $0.domainValue() }
    }

    func post(_ posting: LedgerPosting) throws {
        let existing = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(existing)
        guard !existing.contains(where: { $0.id == posting.id }) else {
            throw RepositoryError.duplicateIdentifier(posting.id)
        }
        try validateReferences(in: posting)
        let data = try encoder.encode(posting.entries)
        context.insert(PersistedLedgerPosting(posting, entriesData: data))
        try commit()
    }

    func reverse(postingID: UUID, description: String, occurredAt: Date) throws -> LedgerPosting {
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        guard let record = records.first(where: { $0.id == postingID }) else {
            throw RepositoryError.invalidReversal(postingID)
        }
        let original = try record.domainValue()
        let reversal = try LedgerFactory.reversal(of: original, description: description, occurredAt: occurredAt)
        try validateReferences(in: reversal)
        context.insert(PersistedLedgerPosting(reversal, entriesData: try encoder.encode(reversal.entries)))
        try commit()
        return reversal
    }

    func correct(postingID: UUID, reversingDescription: String, replacingWith posting: LedgerPosting) throws {
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        guard let record = records.first(where: { $0.id == postingID }), posting.id != postingID else {
            throw RepositoryError.invalidReversal(postingID)
        }
        guard !records.contains(where: { $0.id == posting.id }) else {
            throw RepositoryError.duplicateIdentifier(posting.id)
        }
        guard posting.kind == .income || posting.kind == .expense || posting.kind == .transfer else {
            throw RepositoryError.invalidReversal(postingID)
        }
        let original = try record.domainValue()
        let reversal = try LedgerFactory.reversal(of: original, description: reversingDescription)
        try validateReferences(in: reversal)
        try validateReferences(in: posting)
        context.insert(PersistedLedgerPosting(reversal, entriesData: try encoder.encode(reversal.entries)))
        context.insert(PersistedLedgerPosting(posting, entriesData: try encoder.encode(posting.entries)))
        try commit()
    }

    func posting(id: UUID) throws -> LedgerPosting? {
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func postings(from start: Date? = nil, through end: Date? = nil) throws -> [LedgerPosting] {
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        return try records.filter { record in
                if let start, record.occurredAt < start { return false }
                if let end, record.occurredAt > end { return false }
                return true
            }
            .sorted { $0.occurredAt < $1.occurredAt }
            .map { try $0.domainValue() }
    }

    func balance(for account: Account) throws -> Money {
        let postings = try self.postings(from: nil, through: nil)
        var amount = account.openingBalance.amount
        for posting in postings {
            for entry in posting.entries where entry.accountID == account.id {
                guard entry.money.currency == account.currency else {
                    throw MoneyError.currencyMismatch(expected: account.currency.code, actual: entry.money.currency.code)
                }
                amount += entry.side == .debit ? entry.money.amount : -entry.money.amount
            }
        }
        return try Money(amount, currency: account.currency)
    }

    func save(_ budget: Budget) throws {
        let categories = try context.fetch(FetchDescriptor<PersistedCategory>())
        guard let category = categories.first(where: { $0.id == budget.categoryID }),
              category.kindRawValue == CategoryKind.expense.rawValue else {
            throw RepositoryError.budgetCategoryMustBeExpense(budget.categoryID)
        }
        let records = try context.fetch(FetchDescriptor<PersistedBudget>())
        try ensureUniqueIDs(records)
        if let existing = records.first(where: { $0.id == budget.id }) {
            existing.name = budget.name
            existing.limitAmount = budget.limit.amount
            existing.updatedAt = .now
            existing.isArchived = budget.isArchived
        } else {
            context.insert(PersistedBudget(budget))
        }
        try commit()
    }

    func budget(id: UUID) throws -> Budget? {
        let records = try context.fetch(FetchDescriptor<PersistedBudget>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func budgets(includeArchived: Bool = false) throws -> [Budget] {
        let records = try context.fetch(FetchDescriptor<PersistedBudget>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func progress(for budget: Budget, on date: Date = .now, calendar: Calendar = .current) throws -> BudgetProgress {
        let interval = try BudgetCalendar.interval(for: budget.period, containing: date, calendar: calendar)
        let postings = try self.postings(from: interval.start, through: interval.end)
        var spent = Decimal.zero
        for posting in postings {
            guard posting.kind == .expense || posting.kind == .refund else { continue }
            for entry in posting.entries where entry.accountID == budget.categoryID {
                guard entry.money.currency == budget.currency else {
                    throw MoneyError.currencyMismatch(expected: budget.currency.code, actual: entry.money.currency.code)
                }
                spent += posting.kind == .expense ? entry.money.amount : -entry.money.amount
            }
        }
        return try BudgetProgress(
            budget: budget, spent: Money(max(.zero, spent), currency: budget.currency),
            periodStart: interval.start, periodEnd: interval.end
        )
    }

    func save(_ debt: Debt) throws {
        let records = try context.fetch(FetchDescriptor<PersistedDebt>())
        try ensureUniqueIDs(records)
        let existingPayments = try context.fetch(FetchDescriptor<PersistedDebtPayment>()).filter { $0.debtID == debt.id }.map { try $0.domainValue() }
        _ = try DebtSummary(debt: debt, payments: existingPayments)
        if let existing = records.first(where: { $0.id == debt.id }) {
            guard existing.directionRawValue == debt.direction.rawValue,
                  existing.currencyCode == debt.principal.currency.code,
                  existing.principalAmount == debt.principal.amount,
                  existing.createdAt == debt.createdAt else {
                throw RepositoryError.invalidLedgerReference(debt.id)
            }
            existing.name = debt.name
            existing.counterparty = debt.counterparty
            existing.dueDate = debt.dueDate
            existing.notes = debt.notes
            existing.updatedAt = .now
            existing.isArchived = debt.isArchived
        } else {
            context.insert(PersistedDebt(debt))
        }
        try commit()
    }

    func debt(id: UUID) throws -> Debt? {
        let records = try context.fetch(FetchDescriptor<PersistedDebt>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func debts(includeArchived: Bool = false) throws -> [Debt] {
        let records = try context.fetch(FetchDescriptor<PersistedDebt>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func record(_ payment: DebtPayment) throws {
        let debtRecords = try context.fetch(FetchDescriptor<PersistedDebt>())
        try ensureUniqueIDs(debtRecords)
        guard let debtRecord = debtRecords.first(where: { $0.id == payment.debtID }) else {
            throw RepositoryError.debtNotFound(payment.debtID)
        }
        let paymentRecords = try context.fetch(FetchDescriptor<PersistedDebtPayment>())
        try ensureUniqueIDs(paymentRecords)
        guard !paymentRecords.contains(where: { $0.id == payment.id }) else {
            throw RepositoryError.duplicateIdentifier(payment.id)
        }
        let debt = try debtRecord.domainValue()
        let priorPayments = try paymentRecords.filter { $0.debtID == debt.id }.map { try $0.domainValue() }
        _ = try DebtSummary(debt: debt, payments: priorPayments).recording(payment)
        context.insert(PersistedDebtPayment(payment))
        try commit()
    }

    func payments(for debtID: UUID) throws -> [DebtPayment] {
        let records = try context.fetch(FetchDescriptor<PersistedDebtPayment>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.debtID == debtID }.map { try $0.domainValue() }.sorted { $0.paidAt > $1.paidAt }
    }

    func summary(for debtID: UUID) throws -> DebtSummary {
        guard let debt = try debt(id: debtID) else { throw RepositoryError.debtNotFound(debtID) }
        return try DebtSummary(debt: debt, payments: payments(for: debtID))
    }


    private func ensureUniqueIDs<Record: Identifiable>(_ records: [Record]) throws where Record.ID == UUID {
        var identifiers = Set<UUID>()
        for record in records where !identifiers.insert(record.id).inserted {
            throw RepositoryError.duplicateIdentifier(record.id)
        }
    }

    private func commit() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private func validateReferences(in posting: LedgerPosting) throws {
        let accounts = try context.fetch(FetchDescriptor<PersistedAccount>())
        let categories = try context.fetch(FetchDescriptor<PersistedCategory>())
        try ensureUniqueIDs(accounts)
        try ensureUniqueIDs(categories)
        for entry in posting.entries {
            switch entry.accountKind {
            case .asset, .liability:
                guard let record = accounts.first(where: { $0.id == entry.accountID }) else {
                    throw RepositoryError.accountNotFound(entry.accountID)
                }
                let account = try record.domainValue()
                guard !account.isArchived else { throw RepositoryError.archivedAccount(account.id) }
                guard account.currency == entry.money.currency,
                      (account.type.isLiability ? LedgerAccountKind.liability : .asset) == entry.accountKind
                else { throw RepositoryError.invalidLedgerReference(entry.accountID) }
            case .income, .expense:
                guard let category = categories.first(where: { $0.id == entry.accountID }) else {
                    throw RepositoryError.categoryNotFound(entry.accountID)
                }
                let categoryKind = CategoryKind(rawValue: category.kindRawValue)
                let validIncomeCategory = entry.accountKind == .income && (categoryKind == .income || categoryKind == .salary)
                let validExpenseCategory = entry.accountKind == .expense && categoryKind == .expense
                guard validIncomeCategory || validExpenseCategory else {
                    throw RepositoryError.invalidLedgerReference(entry.accountID)
                }
                guard !category.isArchived else { throw RepositoryError.archivedCategory(category.id) }
            }
        }
        let storedPostings = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        if posting.kind == .refund {
            try validateRefund(posting, storedPostings: storedPostings)
        } else if posting.kind == .reversal {
            try validateReversal(posting, storedPostings: storedPostings)
        }
    }

    private func validateReversal(_ reversal: LedgerPosting, storedPostings: [PersistedLedgerPosting]) throws {
        guard let originalID = reversal.relatedPostingID,
              let storedOriginal = storedPostings.first(where: { $0.id == originalID }),
              let original = try? storedOriginal.domainValue(),
              original.kind != .refund, original.kind != .reversal
        else { throw RepositoryError.invalidReversal(reversal.relatedPostingID ?? reversal.id) }
        guard !storedPostings.contains(where: { $0.relatedPostingID == originalID && $0.kindRawValue == TransactionKind.reversal.rawValue }) else {
            throw RepositoryError.alreadyReversed(originalID)
        }
        if original.kind == .expense,
           storedPostings.contains(where: { $0.relatedPostingID == originalID && $0.kindRawValue == TransactionKind.refund.rawValue }) {
            throw RepositoryError.invalidReversal(originalID)
        }
        let expectedEntries = try original.entries.map { entry in
            try LedgerEntry(
                accountID: entry.accountID,
                accountKind: entry.accountKind,
                side: entry.side == .debit ? .credit : .debit,
                money: entry.money
            )
        }
        guard reversal.entries == expectedEntries else { throw RepositoryError.invalidReversal(originalID) }
    }

    private func validateRefund(_ refund: LedgerPosting, storedPostings: [PersistedLedgerPosting]) throws {
        guard let originalID = refund.relatedPostingID,
              let storedOriginal = storedPostings.first(where: { $0.id == originalID }),
              let original = try? storedOriginal.domainValue(), original.kind == .expense
        else { throw RepositoryError.invalidRefundReference(refund.relatedPostingID ?? refund.id) }

        let originalTotals = Self.amountsByExpenseCategory(in: original, side: .debit)
        let alreadyRefunded = try storedPostings
            .filter { $0.relatedPostingID == originalID }
            .map { try $0.domainValue() }
            .filter { $0.kind == .refund }
            .reduce(into: [UUID: Decimal]()) { totals, posting in
                for (categoryID, amount) in Self.amountsByExpenseCategory(in: posting, side: .credit) {
                    totals[categoryID, default: .zero] += amount
                }
            }
        let requested = Self.amountsByExpenseCategory(in: refund, side: .credit)
        guard !requested.isEmpty,
              requested.keys.allSatisfy({ originalTotals[$0] != nil })
        else { throw RepositoryError.invalidRefundReference(originalID) }
        for (categoryID, amount) in requested {
            guard let originalAmount = originalTotals[categoryID],
                  alreadyRefunded[categoryID, default: .zero] + amount <= originalAmount
            else { throw RepositoryError.refundExceedsOriginal(originalID) }
        }
    }

    private static func amountsByExpenseCategory(in posting: LedgerPosting, side: EntrySide) -> [UUID: Decimal] {
        posting.entries
            .filter { $0.accountKind == .expense && $0.side == side }
            .reduce(into: [UUID: Decimal]()) { totals, entry in
                totals[entry.accountID, default: .zero] += entry.money.amount
            }
    }
}

@MainActor
public final class FinancePersistenceStack {
    public let modelContainer: ModelContainer
    public let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository

    public init(inMemory: Bool = false) throws {
        let schema = Schema([PersistedAccount.self, PersistedCategory.self, PersistedLedgerPosting.self, PersistedBudget.self, PersistedDebt.self, PersistedDebtPayment.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContainer = container
        repository = PersistentFinanceRepository(context: ModelContext(container))
    }
}
