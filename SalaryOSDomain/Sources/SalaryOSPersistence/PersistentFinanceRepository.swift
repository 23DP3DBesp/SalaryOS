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
    var scheduledOccurrenceID: String?
    var entriesData: Data
    var createdAt: Date

    init(_ posting: LedgerPosting, entriesData: Data) {
        id = posting.id
        kindRawValue = posting.kind.rawValue
        occurredAt = posting.occurredAt
        descriptionText = posting.description
        notes = posting.notes
        relatedPostingID = posting.relatedPostingID
        scheduledOccurrenceID = posting.scheduledOccurrenceID
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
            notes: notes, relatedPostingID: relatedPostingID,
            scheduledOccurrenceID: scheduledOccurrenceID, entries: entries, createdAt: createdAt
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

@Model
final class PersistedSavingsGoal {
    var id: UUID
    var name: String
    var currencyCode: String
    var targetAmount: Decimal
    var targetDate: Date?
    var linkedAccountID: UUID?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(_ goal: SavingsGoal) {
        id = goal.id
        name = goal.name
        currencyCode = goal.currency.code
        targetAmount = goal.target.amount
        targetDate = goal.targetDate
        linkedAccountID = goal.linkedAccountID
        notes = goal.notes
        createdAt = goal.createdAt
        updatedAt = goal.updatedAt
        isArchived = goal.isArchived
    }

    func domainValue() throws -> SavingsGoal {
        try SavingsGoal(
            id: id, name: name,
            target: Money(targetAmount, currency: Currency(code: currencyCode)),
            targetDate: targetDate, linkedAccountID: linkedAccountID, notes: notes,
            createdAt: createdAt, updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

@Model
final class PersistedSavingsContribution {
    var id: UUID
    var goalID: UUID
    var currencyCode: String
    var amount: Decimal
    var contributedAt: Date
    var note: String?
    var createdAt: Date

    init(_ contribution: SavingsContribution) {
        id = contribution.id
        goalID = contribution.goalID
        currencyCode = contribution.amount.currency.code
        amount = contribution.amount.amount
        contributedAt = contribution.contributedAt
        note = contribution.note
        createdAt = contribution.createdAt
    }

    func domainValue() throws -> SavingsContribution {
        try SavingsContribution(
            id: id, goalID: goalID,
            amount: Money(amount, currency: Currency(code: currencyCode)),
            contributedAt: contributedAt, note: note, createdAt: createdAt
        )
    }
}

@Model
final class PersistedLoan {
    var id: UUID
    var name: String
    var lender: String
    var currencyCode: String
    var principalAmount: Decimal
    var rateTypeRawValue: String
    var annualInterestRate: Decimal
    var durationMonths: Int
    var startDate: Date
    var feesAmount: Decimal
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(_ loan: Loan) {
        id = loan.id
        name = loan.name
        lender = loan.lender
        currencyCode = loan.principal.currency.code
        principalAmount = loan.principal.amount
        rateTypeRawValue = loan.rateType.rawValue
        annualInterestRate = loan.annualInterestRate
        durationMonths = loan.durationMonths
        startDate = loan.startDate
        feesAmount = loan.fees.amount
        notes = loan.notes
        createdAt = loan.createdAt
        updatedAt = loan.updatedAt
        isArchived = loan.isArchived
    }

    func domainValue() throws -> Loan {
        guard let rateType = LoanRateType(rawValue: rateTypeRawValue) else {
            throw PersistenceMappingError.invalidLoanRateType(rateTypeRawValue)
        }
        let currency = try Currency(code: currencyCode)
        return try Loan(
            id: id, name: name, lender: lender,
            principal: Money(principalAmount, currency: currency), annualInterestRate: annualInterestRate,
            rateType: rateType, durationMonths: durationMonths, startDate: startDate,
            fees: Money(feesAmount, currency: currency), notes: notes,
            createdAt: createdAt, updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

@Model
final class PersistedLoanRateChange {
    var id: UUID
    var loanID: UUID
    var annualInterestRate: Decimal
    var effectiveDate: Date
    var createdAt: Date

    init(_ value: LoanRateChange) {
        id = value.id
        loanID = value.loanID
        annualInterestRate = value.annualInterestRate
        effectiveDate = value.effectiveDate
        createdAt = value.createdAt
    }

    func domainValue(loan: Loan) throws -> LoanRateChange {
        try LoanRateChange(id: id, loanID: loanID, annualInterestRate: annualInterestRate, effectiveDate: effectiveDate, loan: loan, createdAt: createdAt)
    }
}

@Model
final class PersistedLoanExtraPayment {
    var id: UUID
    var loanID: UUID
    var currencyCode: String
    var principalReduction: Decimal
    var paidAt: Date
    var note: String?
    var createdAt: Date

    init(_ value: LoanExtraPayment) {
        id = value.id
        loanID = value.loanID
        currencyCode = value.principalReduction.currency.code
        principalReduction = value.principalReduction.amount
        paidAt = value.paidAt
        note = value.note
        createdAt = value.createdAt
    }

    func domainValue(loan: Loan) throws -> LoanExtraPayment {
        try LoanExtraPayment(
            id: id, loanID: loanID,
            principalReduction: Money(principalReduction, currency: Currency(code: currencyCode)),
            paidAt: paidAt, loan: loan, note: note, createdAt: createdAt
        )
    }
}

@Model
final class PersistedWorkEntry {
    var id: UUID
    var employer: String
    var descriptionText: String
    var startedAt: Date
    var endedAt: Date
    var unpaidBreakMinutes: Int
    var currencyCode: String
    var hourlyRate: Decimal
    var notes: String?
    var createdAt: Date
    var updatedAt: Date

    init(_ entry: WorkEntry) {
        id = entry.id
        employer = entry.employer
        descriptionText = entry.description
        startedAt = entry.startedAt
        endedAt = entry.endedAt
        unpaidBreakMinutes = entry.unpaidBreakMinutes
        currencyCode = entry.hourlyRate.currency.code
        hourlyRate = entry.hourlyRate.amount
        notes = entry.notes
        createdAt = entry.createdAt
        updatedAt = entry.updatedAt
    }

    func domainValue() throws -> WorkEntry {
        try WorkEntry(
            id: id, employer: employer, description: descriptionText,
            startedAt: startedAt, endedAt: endedAt,
            unpaidBreakMinutes: unpaidBreakMinutes,
            hourlyRate: Money(hourlyRate, currency: Currency(code: currencyCode)),
            notes: notes, createdAt: createdAt, updatedAt: updatedAt
        )
    }
}

@Model
final class PersistedScheduledOperation {
    var id: UUID
    var name: String
    var kindRawValue: String
    var amount: Decimal
    var currencyCode: String
    var accountID: UUID
    var categoryID: UUID
    var recurrenceRawValue: String
    var startDate: Date
    var endDate: Date?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var isArchived: Bool

    init(_ operation: ScheduledOperation) {
        id = operation.id
        name = operation.name
        kindRawValue = operation.kind.rawValue
        amount = operation.amount.amount
        currencyCode = operation.amount.currency.code
        accountID = operation.accountID
        categoryID = operation.categoryID
        recurrenceRawValue = operation.recurrence.rawValue
        startDate = operation.startDate
        endDate = operation.endDate
        notes = operation.notes
        createdAt = operation.createdAt
        updatedAt = operation.updatedAt
        isArchived = operation.isArchived
    }

    func domainValue() throws -> ScheduledOperation {
        guard let kind = ScheduledOperationKind(rawValue: kindRawValue),
              let recurrence = RecurrenceFrequency(rawValue: recurrenceRawValue) else {
            throw PersistenceMappingError.invalidScheduledOperation(id)
        }
        return try ScheduledOperation(
            id: id, name: name, kind: kind,
            amount: Money(amount, currency: Currency(code: currencyCode)),
            accountID: accountID, categoryID: categoryID, recurrence: recurrence,
            startDate: startDate, endDate: endDate, notes: notes,
            createdAt: createdAt, updatedAt: updatedAt, isArchived: isArchived
        )
    }
}

enum PersistenceMappingError: Error {
    case invalidAccountType(String)
    case invalidCategoryKind(String)
    case invalidTransactionKind(String)
    case invalidBudgetPeriod(String)
    case invalidDebtDirection(String)
    case invalidLoanRateType(String)
    case invalidScheduledOperation(UUID)
}

/// Keeps each posting and its entries in one persisted record so they are saved atomically.
@MainActor
final class PersistentFinanceRepository: AccountRepository, CategoryRepository, LedgerRepository, BudgetRepository, DebtRepository, SavingsGoalRepository, LoanRepository, WorkTimeRepository, ScheduledOperationRepository {
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
            .filter { $0.occurredAt < interval.end }
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

    func save(_ goal: SavingsGoal) throws {
        let goalRecords = try context.fetch(FetchDescriptor<PersistedSavingsGoal>())
        try ensureUniqueIDs(goalRecords)
        if let accountID = goal.linkedAccountID {
            let accountRecords = try context.fetch(FetchDescriptor<PersistedAccount>())
            guard let accountRecord = accountRecords.first(where: { $0.id == accountID }) else {
                throw RepositoryError.accountNotFound(accountID)
            }
            let account = try accountRecord.domainValue()
            guard account.currency == goal.currency else {
                throw MoneyError.currencyMismatch(expected: account.currency.code, actual: goal.currency.code)
            }
        }
        let oldContributionRecords = try context.fetch(FetchDescriptor<PersistedSavingsContribution>()).filter { $0.goalID == goal.id }
        let oldContributions = try oldContributionRecords.map { try $0.domainValue() }
        _ = try SavingsGoalProgress(goal: goal, contributions: oldContributions)
        if let existing = goalRecords.first(where: { $0.id == goal.id }) {
            guard existing.currencyCode == goal.currency.code,
                  existing.createdAt == goal.createdAt,
                  existing.linkedAccountID == goal.linkedAccountID else {
                throw RepositoryError.invalidLedgerReference(goal.id)
            }
            existing.name = goal.name
            existing.targetAmount = goal.target.amount
            existing.notes = goal.notes
            existing.updatedAt = .now
            existing.isArchived = goal.isArchived
        } else {
            context.insert(PersistedSavingsGoal(goal))
        }
        try commit()
    }

    func goal(id: UUID) throws -> SavingsGoal? {
        let records = try context.fetch(FetchDescriptor<PersistedSavingsGoal>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func goals(includeArchived: Bool = false) throws -> [SavingsGoal] {
        let records = try context.fetch(FetchDescriptor<PersistedSavingsGoal>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func record(_ contribution: SavingsContribution) throws {
        let goalRecords = try context.fetch(FetchDescriptor<PersistedSavingsGoal>())
        try ensureUniqueIDs(goalRecords)
        guard let record = goalRecords.first(where: { $0.id == contribution.goalID }) else {
            throw RepositoryError.savingsGoalNotFound(contribution.goalID)
        }
        let contributionRecords = try context.fetch(FetchDescriptor<PersistedSavingsContribution>())
        try ensureUniqueIDs(contributionRecords)
        guard !contributionRecords.contains(where: { $0.id == contribution.id }) else {
            throw RepositoryError.duplicateIdentifier(contribution.id)
        }
        let goal = try record.domainValue()
        guard !goal.isArchived else { throw RepositoryError.invalidLedgerReference(goal.id) }
        let values = try contributionRecords.filter { $0.goalID == goal.id }.map { try $0.domainValue() } + [contribution]
        _ = try SavingsGoalProgress(goal: goal, contributions: values)
        context.insert(PersistedSavingsContribution(contribution))
        try commit()
    }

    func contributions(for goalID: UUID) throws -> [SavingsContribution] {
        let records = try context.fetch(FetchDescriptor<PersistedSavingsContribution>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.goalID == goalID }.map { try $0.domainValue() }.sorted { $0.contributedAt > $1.contributedAt }
    }

    func progress(for goalID: UUID, asOf date: Date = .now, calendar: Calendar = .current) throws -> SavingsGoalProgress {
        guard let goal = try goal(id: goalID) else { throw RepositoryError.savingsGoalNotFound(goalID) }
        return try SavingsGoalProgress(goal: goal, contributions: contributions(for: goalID), asOf: date, calendar: calendar)
    }

    func save(_ loan: Loan) throws {
        let records = try context.fetch(FetchDescriptor<PersistedLoan>())
        try ensureUniqueIDs(records)
        if let existing = records.first(where: { $0.id == loan.id }) {
            guard existing.principalAmount == loan.principal.amount,
                  existing.currencyCode == loan.principal.currency.code,
                  existing.rateTypeRawValue == loan.rateType.rawValue,
                  existing.durationMonths == loan.durationMonths,
                  existing.startDate == loan.startDate,
                  existing.feesAmount == loan.fees.amount else {
                throw RepositoryError.loanTermsConflict(loan.id)
            }
            existing.name = loan.name
            existing.lender = loan.lender
            existing.notes = loan.notes
            existing.isArchived = loan.isArchived
            existing.updatedAt = .now
        } else {
            context.insert(PersistedLoan(loan))
        }
        try commit()
    }

    func loan(id: UUID) throws -> Loan? {
        let records = try context.fetch(FetchDescriptor<PersistedLoan>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func loans(includeArchived: Bool = false) throws -> [Loan] {
        let records = try context.fetch(FetchDescriptor<PersistedLoan>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func record(_ rateChange: LoanRateChange) throws {
        guard let loan = try loan(id: rateChange.loanID) else { throw RepositoryError.loanNotFound(rateChange.loanID) }
        _ = try LoanRateChange(id: rateChange.id, loanID: rateChange.loanID, annualInterestRate: rateChange.annualInterestRate, effectiveDate: rateChange.effectiveDate, loan: loan, createdAt: rateChange.createdAt)
        let records = try context.fetch(FetchDescriptor<PersistedLoanRateChange>())
        try ensureUniqueIDs(records)
        guard !records.contains(where: { $0.id == rateChange.id }) else { throw RepositoryError.duplicateIdentifier(rateChange.id) }
        guard !records.contains(where: { $0.loanID == rateChange.loanID && $0.effectiveDate == rateChange.effectiveDate }) else {
            throw RepositoryError.duplicateLoanRateDate(rateChange.effectiveDate)
        }
        context.insert(PersistedLoanRateChange(rateChange))
        try commit()
    }

    func rateChanges(for loanID: UUID) throws -> [LoanRateChange] {
        guard let loan = try loan(id: loanID) else { throw RepositoryError.loanNotFound(loanID) }
        let records = try context.fetch(FetchDescriptor<PersistedLoanRateChange>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.loanID == loanID }.map { try $0.domainValue(loan: loan) }.sorted { $0.effectiveDate < $1.effectiveDate }
    }

    func record(_ payment: LoanExtraPayment) throws {
        guard let loan = try loan(id: payment.loanID) else { throw RepositoryError.loanNotFound(payment.loanID) }
        let records = try context.fetch(FetchDescriptor<PersistedLoanExtraPayment>())
        try ensureUniqueIDs(records)
        guard !records.contains(where: { $0.id == payment.id }) else { throw RepositoryError.duplicateIdentifier(payment.id) }
        let existing = try records.filter { $0.loanID == loan.id }.map { try $0.domainValue(loan: loan) }
        _ = try LoanCalculator.schedule(for: loan, rateChanges: rateChanges(for: loan.id), extraPayments: existing + [payment])
        context.insert(PersistedLoanExtraPayment(payment))
        try commit()
    }

    func extraPayments(for loanID: UUID) throws -> [LoanExtraPayment] {
        guard let loan = try loan(id: loanID) else { throw RepositoryError.loanNotFound(loanID) }
        let records = try context.fetch(FetchDescriptor<PersistedLoanExtraPayment>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.loanID == loanID }.map { try $0.domainValue(loan: loan) }.sorted { $0.paidAt < $1.paidAt }
    }

    func schedule(for loanID: UUID, calendar: Calendar = .current) throws -> LoanSchedule {
        guard let loan = try loan(id: loanID) else { throw RepositoryError.loanNotFound(loanID) }
        return try LoanCalculator.schedule(for: loan, rateChanges: rateChanges(for: loanID), extraPayments: extraPayments(for: loanID), calendar: calendar)
    }

    func save(_ entry: WorkEntry) throws {
        let records = try context.fetch(FetchDescriptor<PersistedWorkEntry>())
        try ensureUniqueIDs(records)
        let existingEntries = try records.map { try $0.domainValue() }
        try WorkTimeCalculator.validateNoOverlap(entry, among: existingEntries)
        if let record = records.first(where: { $0.id == entry.id }) {
            record.employer = entry.employer
            record.descriptionText = entry.description
            record.startedAt = entry.startedAt
            record.endedAt = entry.endedAt
            record.unpaidBreakMinutes = entry.unpaidBreakMinutes
            record.currencyCode = entry.hourlyRate.currency.code
            record.hourlyRate = entry.hourlyRate.amount
            record.notes = entry.notes
            record.updatedAt = .now
        } else {
            context.insert(PersistedWorkEntry(entry))
        }
        try commit()
    }

    func entry(id: UUID) throws -> WorkEntry? {
        let records = try context.fetch(FetchDescriptor<PersistedWorkEntry>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func entries(from start: Date, through end: Date) throws -> [WorkEntry] {
        let records = try context.fetch(FetchDescriptor<PersistedWorkEntry>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.startedAt >= start && $0.startedAt <= end }
            .map { try $0.domainValue() }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func entries(overlapping start: Date, end: Date) throws -> [WorkEntry] {
        let records = try context.fetch(FetchDescriptor<PersistedWorkEntry>())
        try ensureUniqueIDs(records)
        return try records.filter { $0.startedAt < end && $0.endedAt > start }
            .map { try $0.domainValue() }
            .sorted { $0.startedAt > $1.startedAt }
    }

    func save(_ operation: ScheduledOperation) throws {
        let accountRecords = try context.fetch(FetchDescriptor<PersistedAccount>())
        guard let accountRecord = accountRecords.first(where: { $0.id == operation.accountID }) else {
            throw RepositoryError.accountNotFound(operation.accountID)
        }
        let account = try accountRecord.domainValue()
        guard !account.isArchived, account.currency == operation.amount.currency else {
            throw RepositoryError.invalidLedgerReference(operation.accountID)
        }
        let categoryRecords = try context.fetch(FetchDescriptor<PersistedCategory>())
        guard let categoryRecord = categoryRecords.first(where: { $0.id == operation.categoryID }) else {
            throw RepositoryError.categoryNotFound(operation.categoryID)
        }
        guard let categoryKind = CategoryKind(rawValue: categoryRecord.kindRawValue),
              operation.kind == .income ? (categoryKind == .income || categoryKind == .salary) : (categoryKind == .expense) else {
            throw RepositoryError.invalidLedgerReference(operation.categoryID)
        }
        let records = try context.fetch(FetchDescriptor<PersistedScheduledOperation>())
        try ensureUniqueIDs(records)
        if let existing = records.first(where: { $0.id == operation.id }) {
            existing.name = operation.name
            existing.kindRawValue = operation.kind.rawValue
            existing.amount = operation.amount.amount
            existing.currencyCode = operation.amount.currency.code
            existing.accountID = operation.accountID
            existing.categoryID = operation.categoryID
            existing.recurrenceRawValue = operation.recurrence.rawValue
            existing.startDate = operation.startDate
            existing.endDate = operation.endDate
            existing.notes = operation.notes
            existing.updatedAt = .now
            existing.isArchived = operation.isArchived
        } else {
            context.insert(PersistedScheduledOperation(operation))
        }
        try commit()
    }

    func operation(id: UUID) throws -> ScheduledOperation? {
        let records = try context.fetch(FetchDescriptor<PersistedScheduledOperation>())
        try ensureUniqueIDs(records)
        return try records.first(where: { $0.id == id })?.domainValue()
    }

    func operations(includeArchived: Bool = false) throws -> [ScheduledOperation] {
        let records = try context.fetch(FetchDescriptor<PersistedScheduledOperation>())
        try ensureUniqueIDs(records)
        return try records.filter { includeArchived || !$0.isArchived }.map { try $0.domainValue() }
    }

    func postedOccurrenceIDs() throws -> Set<String> {
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        return Set(records.compactMap(\.scheduledOccurrenceID))
    }

    func postOccurrence(operationID: UUID, dueDate: Date, occurredAt: Date = .now) throws -> LedgerPosting {
        guard let operation = try operation(id: operationID), !operation.isArchived else {
            throw RepositoryError.scheduledOperationNotFound(operationID)
        }
        let occurrence = try RecurrenceCalendar.occurrences(for: operation, from: dueDate, through: dueDate, calendar: .current)
            .first(where: { Calendar.current.isDate($0.dueDate, inSameDayAs: dueDate) })
        guard let occurrence else { throw ScheduledOperationError.invalidCalendarDate }
        let records = try context.fetch(FetchDescriptor<PersistedLedgerPosting>())
        try ensureUniqueIDs(records)
        guard !records.contains(where: { $0.scheduledOccurrenceID == occurrence.id }) else {
            throw RepositoryError.scheduledOccurrenceAlreadyPosted(operationID, occurrence.dueDate)
        }
        guard let account = try account(id: operation.accountID),
              let category = try category(id: operation.categoryID) else {
            throw RepositoryError.invalidLedgerReference(operationID)
        }
        let posting = switch operation.kind {
        case .income:
            try LedgerFactory.income(amount: operation.amount, to: account, categoryID: category.id, description: operation.name, notes: operation.notes, occurredAt: occurredAt)
        case .expense:
            try LedgerFactory.expense(amount: operation.amount, from: account, categoryID: category.id, description: operation.name, notes: operation.notes, occurredAt: occurredAt)
        }
        let identifiedPosting = try LedgerPosting(
            id: posting.id, kind: posting.kind, occurredAt: posting.occurredAt,
            description: posting.description, notes: posting.notes,
            relatedPostingID: posting.relatedPostingID, scheduledOccurrenceID: occurrence.id,
            entries: posting.entries, createdAt: posting.createdAt
        )
        try validateReferences(in: identifiedPosting)
        context.insert(PersistedLedgerPosting(identifiedPosting, entriesData: try encoder.encode(identifiedPosting.entries)))
        try commit()
        return identifiedPosting
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
    public let repository: any AccountRepository & CategoryRepository & LedgerRepository & BudgetRepository & DebtRepository & SavingsGoalRepository & LoanRepository & WorkTimeRepository & ScheduledOperationRepository

    public init(inMemory: Bool = false) throws {
        let schema = Schema([PersistedAccount.self, PersistedCategory.self, PersistedLedgerPosting.self, PersistedBudget.self, PersistedDebt.self, PersistedDebtPayment.self, PersistedSavingsGoal.self, PersistedSavingsContribution.self, PersistedLoan.self, PersistedLoanRateChange.self, PersistedLoanExtraPayment.self, PersistedWorkEntry.self, PersistedScheduledOperation.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContainer = container
        repository = PersistentFinanceRepository(context: ModelContext(container))
    }
}
