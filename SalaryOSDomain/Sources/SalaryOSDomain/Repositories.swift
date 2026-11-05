import Foundation

public enum RepositoryError: Error, Equatable {
    case duplicateIdentifier(UUID)
    case accountNotFound(UUID)
    case categoryNotFound(UUID)
    case accountDefinitionConflict(UUID)
    case categoryDefinitionConflict(UUID)
    case invalidLedgerReference(UUID)
    case archivedAccount(UUID)
    case archivedCategory(UUID)
    case invalidRefundReference(UUID)
    case refundExceedsOriginal(UUID)
    case invalidReversal(UUID)
    case alreadyReversed(UUID)
    case budgetCategoryMustBeExpense(UUID)
    case debtNotFound(UUID)
    case debtPaymentNotFound(UUID)
}

@MainActor
public protocol AccountRepository: AnyObject {
    func save(_ account: Account) throws
    func account(id: UUID) throws -> Account?
    func accounts(includeArchived: Bool) throws -> [Account]
}

@MainActor
public protocol CategoryRepository: AnyObject {
    func save(_ category: Category) throws
    func category(id: UUID) throws -> Category?
    func categories(kind: CategoryKind?, includeArchived: Bool) throws -> [Category]
}

@MainActor
public protocol LedgerRepository: AnyObject {
    func post(_ posting: LedgerPosting) throws
    func reverse(postingID: UUID, description: String, occurredAt: Date) throws -> LedgerPosting
    func correct(postingID: UUID, reversingDescription: String, replacingWith posting: LedgerPosting) throws
    func posting(id: UUID) throws -> LedgerPosting?
    func postings(from start: Date?, through end: Date?) throws -> [LedgerPosting]
    func balance(for account: Account) throws -> Money
}

@MainActor
public protocol BudgetRepository: AnyObject {
    func save(_ budget: Budget) throws
    func budget(id: UUID) throws -> Budget?
    func budgets(includeArchived: Bool) throws -> [Budget]
    func progress(for budget: Budget, on date: Date, calendar: Calendar) throws -> BudgetProgress
}

@MainActor
public protocol DebtRepository: AnyObject {
    func save(_ debt: Debt) throws
    func debt(id: UUID) throws -> Debt?
    func debts(includeArchived: Bool) throws -> [Debt]
    func record(_ payment: DebtPayment) throws
    func payments(for debtID: UUID) throws -> [DebtPayment]
    func summary(for debtID: UUID) throws -> DebtSummary
}
