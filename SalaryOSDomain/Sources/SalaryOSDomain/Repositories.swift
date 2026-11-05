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
    case savingsGoalNotFound(UUID)
    case savingsContributionNotFound(UUID)
    case loanNotFound(UUID)
    case loanPaymentNotFound(UUID)
    case loanTermsConflict(UUID)
    case duplicateLoanRateDate(Date)
    case workEntryNotFound(UUID)
    case scheduledOperationNotFound(UUID)
    case scheduledOccurrenceAlreadyPosted(UUID, Date)
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
    func record(_ payment: DebtPayment, using accountID: UUID) throws -> LedgerPosting
    func payments(for debtID: UUID) throws -> [DebtPayment]
    func summary(for debtID: UUID) throws -> DebtSummary
}

@MainActor
public protocol SavingsGoalRepository: AnyObject {
    func save(_ goal: SavingsGoal) throws
    func goal(id: UUID) throws -> SavingsGoal?
    func goals(includeArchived: Bool) throws -> [SavingsGoal]
    func record(_ contribution: SavingsContribution) throws
    func record(_ contribution: SavingsContribution, from accountID: UUID) throws -> LedgerPosting
    func contributions(for goalID: UUID) throws -> [SavingsContribution]
    func progress(for goalID: UUID, asOf date: Date, calendar: Calendar) throws -> SavingsGoalProgress
}

@MainActor
public protocol LoanRepository: AnyObject {
    func save(_ loan: Loan) throws
    func loan(id: UUID) throws -> Loan?
    func loans(includeArchived: Bool) throws -> [Loan]
    func record(_ rateChange: LoanRateChange) throws
    func rateChanges(for loanID: UUID) throws -> [LoanRateChange]
    func record(_ payment: LoanExtraPayment) throws
    func record(_ payment: LoanExtraPayment, from accountID: UUID) throws -> LedgerPosting
    func extraPayments(for loanID: UUID) throws -> [LoanExtraPayment]
    func record(_ payment: LoanPayment, from accountID: UUID, interestCategoryID: UUID?) throws -> LedgerPosting
    func payments(for loanID: UUID) throws -> [LoanPayment]
    func schedule(for loanID: UUID, calendar: Calendar) throws -> LoanSchedule
}

@MainActor
public protocol SalaryRepository: AnyObject {
    func record(_ salary: SalaryRecord, to accountID: UUID) throws -> LedgerPosting
    func salaryRecords(for taxYear: Int) throws -> [SalaryRecord]
}

@MainActor
public protocol WorkTimeRepository: AnyObject {
    func save(_ entry: WorkEntry) throws
    func entry(id: UUID) throws -> WorkEntry?
    func entries(from start: Date, through end: Date) throws -> [WorkEntry]
    func entries(overlapping start: Date, end: Date) throws -> [WorkEntry]
}

@MainActor
public protocol ScheduledOperationRepository: AnyObject {
    func save(_ operation: ScheduledOperation) throws
    func operation(id: UUID) throws -> ScheduledOperation?
    func operations(includeArchived: Bool) throws -> [ScheduledOperation]
    func postedOccurrenceIDs() throws -> Set<String>
    func postOccurrence(operationID: UUID, dueDate: Date, occurredAt: Date) throws -> LedgerPosting
}
