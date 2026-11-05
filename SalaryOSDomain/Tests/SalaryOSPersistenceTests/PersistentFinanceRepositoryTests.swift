import Foundation
import XCTest
import SalaryOSDomain
import SalaryOSPersistence

final class PersistentFinanceRepositoryTests: XCTestCase {
    @MainActor
    func testDebtPaymentUpdatesAccountLedgerAndReversalRestoresOutstanding() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let opening = try Money(Decimal(1_000), currency: eur)
        let account = try Account(name: "Bank", type: .current, currency: eur, openingBalance: opening)
        let debt = try Debt(name: "Laptop loan", counterparty: "Alex", direction: .payable, principal: opening)
        try repository.save(account)
        try repository.save(debt)

        let payment = try DebtPayment(debtID: debt.id, amount: Money(Decimal(250), currency: eur))
        let posting = try repository.record(payment, using: account.id)
        XCTAssertEqual(posting.kind, .transfer)
        XCTAssertEqual(posting.debtPaymentID, payment.id)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(750))
        XCTAssertEqual(try repository.summary(for: debt.id).outstanding.amount, Decimal(750))
        XCTAssertThrowsError(try repository.record(payment, using: account.id))
        XCTAssertEqual(try repository.postings(from: nil, through: nil).count, 1)

        _ = try repository.reverse(postingID: posting.id, description: "Undo debt payment", occurredAt: .now)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(1_000))
        XCTAssertEqual(try repository.summary(for: debt.id).outstanding.amount, Decimal(1_000))
        XCTAssertTrue(try repository.summary(for: debt.id).payments.isEmpty)
    }

    @MainActor
    func testReceivableRepaymentMovesFundsIntoSelectedAccount() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Bank", type: .current, currency: eur)
        let principal = try Money(Decimal(500), currency: eur)
        let debt = try Debt(name: "Loan to Sam", counterparty: "Sam", direction: .receivable, principal: principal)
        try repository.save(account)
        try repository.save(debt)

        let payment = try DebtPayment(debtID: debt.id, amount: Money(Decimal(150), currency: eur))
        let posting = try repository.record(payment, using: account.id)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(150))
        XCTAssertEqual(try repository.summary(for: debt.id).outstanding.amount, Decimal(350))
        XCTAssertEqual(posting.entries.first(where: { $0.accountID == debt.id })?.side, .credit)
    }

    @MainActor
    func testSavingsContributionMovesFundsAndReversalRestoresGoalProgress() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let opening = try Money(Decimal(1_000), currency: eur)
        let account = try Account(name: "Main", type: .current, currency: eur, openingBalance: opening)
        let goal = try SavingsGoal(name: "Emergency fund", target: Money(Decimal(2_000), currency: eur))
        try repository.save(account)
        try repository.save(goal)

        let contribution = try SavingsContribution(goalID: goal.id, amount: Money(Decimal(250), currency: eur))
        let posting = try repository.record(contribution, from: account.id)
        XCTAssertEqual(posting.savingsContributionID, contribution.id)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(750))
        XCTAssertEqual(try repository.progress(for: goal.id, asOf: .now, calendar: .current).saved.amount, Decimal(250))

        _ = try repository.reverse(postingID: posting.id, description: "Undo savings contribution", occurredAt: .now)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(1_000))
        XCTAssertEqual(try repository.progress(for: goal.id, asOf: .now, calendar: .current).saved.amount, .zero)
    }

    @MainActor
    func testLoanExtraPaymentPostsToLedgerAndReversalRestoresSchedule() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let opening = try Money(Decimal(5_000), currency: eur)
        let account = try Account(name: "Main", type: .current, currency: eur, openingBalance: opening)
        let loan = try Loan(
            name: "Car loan", lender: "Bank", principal: opening, annualInterestRate: 0,
            rateType: .fixed, durationMonths: 10,
            startDate: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!,
            fees: Money(.zero, currency: eur)
        )
        try repository.save(account)
        try repository.save(loan)

        let payment = try LoanExtraPayment(
            loanID: loan.id, principalReduction: Money(Decimal(500), currency: eur),
            paidAt: ISO8601DateFormatter().date(from: "2025-02-10T00:00:00Z")!, loan: loan
        )
        let posting = try repository.record(payment, from: account.id)
        XCTAssertEqual(posting.loanExtraPaymentID, payment.id)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(4_500))
        XCTAssertEqual(try repository.schedule(for: loan.id, calendar: .current).totalExtraPrincipal.amount, Decimal(500))

        _ = try repository.reverse(postingID: posting.id, description: "Undo extra payment", occurredAt: .now)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(5_000))
        XCTAssertEqual(try repository.schedule(for: loan.id, calendar: .current).totalExtraPrincipal.amount, .zero)
    }

    @MainActor
    func testRegularLoanPaymentPostsPrincipalAndInterestAndReversalRestoresSchedule() throws {
        let repository = try FinancePersistenceStack(inMemory: true).repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Main", type: .current, currency: eur, openingBalance: Money(Decimal(2_000), currency: eur))
        let interestCategory = try Category(name: "Loan interest", kind: .expense)
        let loan = try Loan(
            name: "Car loan", lender: "Bank", principal: Money(Decimal(2_000), currency: eur),
            annualInterestRate: 12, durationMonths: 12,
            startDate: ISO8601DateFormatter().date(from: "2025-01-01T00:00:00Z")!,
            fees: Money(.zero, currency: eur)
        )
        try repository.save(account)
        try repository.save(interestCategory)
        try repository.save(loan)
        let before = try repository.schedule(for: loan.id, calendar: .current)
        let installment = try XCTUnwrap(before.installments.first)
        let payment = try LoanPayment(
            loanID: loan.id, installmentNumber: installment.id,
            principalPaid: Money(installment.principalPaid.amount, currency: eur),
            interestPaid: Money(installment.interest.amount, currency: eur),
            paidAt: installment.dueDate, loan: loan
        )

        let posting = try repository.record(payment, from: account.id, interestCategoryID: interestCategory.id)
        XCTAssertEqual(posting.loanPaymentID, payment.id)
        XCTAssertEqual(posting.kind, .adjustment)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(2_000) - payment.amount)
        let paidSchedule = try repository.schedule(for: loan.id, calendar: .current)
        XCTAssertTrue(try XCTUnwrap(paidSchedule.installments.first).isPaid)
        XCTAssertEqual(paidSchedule.installments.first?.closingBalance.amount, installment.closingBalance.amount)

        _ = try repository.reverse(postingID: posting.id, description: "Undo installment", occurredAt: .now)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(2_000))
        XCTAssertFalse(try XCTUnwrap(repository.schedule(for: loan.id, calendar: .current).installments.first).isPaid)
    }

    @MainActor
    func testScheduledMonthlyOccurrencesKeepAnchorAndPostingIsIdempotent() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Bank", type: .current, currency: eur)
        let category = try Category(name: "Rent", kind: .expense)
        try repository.save(account)
        try repository.save(category)
        let anchor = ISO8601DateFormatter().date(from: "2026-01-31T00:00:00Z")!
        let operation = try ScheduledOperation(
            name: "Rent", kind: .expense, amount: Money(Decimal(500), currency: eur),
            accountID: account.id, categoryID: category.id, recurrence: .monthly, startDate: anchor
        )
        let occurrences = try RecurrenceCalendar.occurrences(
            for: operation,
            from: ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z")!,
            through: ISO8601DateFormatter().date(from: "2026-03-31T00:00:00Z")!,
            calendar: calendar
        )
        XCTAssertEqual(occurrences.map { calendar.component(.day, from: $0.dueDate) }, [31, 28, 31])
        try repository.save(operation)

        let posting = try repository.postOccurrence(operationID: operation.id, dueDate: occurrences[0].dueDate, occurredAt: occurrences[0].dueDate)
        XCTAssertEqual(posting.scheduledOccurrenceID, occurrences[0].id)
        XCTAssertThrowsError(try repository.postOccurrence(operationID: operation.id, dueDate: occurrences[0].dueDate, occurredAt: occurrences[0].dueDate))
        XCTAssertEqual(try repository.postings(from: nil, through: nil).count, 1)

        var edited = try XCTUnwrap(repository.operation(id: operation.id))
        let nextAnchor = ISO8601DateFormatter().date(from: "2026-04-30T00:00:00Z")!
        try edited.update(
            name: "Updated rent", kind: .expense, amount: Money(Decimal(700), currency: eur),
            accountID: account.id, categoryID: category.id, recurrence: .monthly,
            startDate: nextAnchor, endDate: nil, notes: "New terms"
        )
        try repository.save(edited)
        let savedEdit = try XCTUnwrap(repository.operation(id: operation.id))
        XCTAssertEqual(savedEdit.name, "Updated rent")
        XCTAssertEqual(savedEdit.amount.amount, Decimal(700))
        XCTAssertEqual(savedEdit.startDate, nextAnchor)
        XCTAssertEqual(try repository.posting(id: posting.id)?.description, "Rent")
    }

    @MainActor
    func testBudgetProgressUsesExpensesAndSubtractsRefunds() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Everyday", type: .current, currency: eur, openingBalance: Money(Decimal(500), currency: eur))
        let food = try Category(name: "Food", kind: .expense)
        try repository.save(account)
        try repository.save(food)
        let now = Date.now
        let expense = try LedgerFactory.expense(
            amount: Money(Decimal(80), currency: eur), from: account,
            categoryID: food.id, description: "Groceries", occurredAt: now
        )
        try repository.post(expense)
        let refund = try LedgerFactory.refund(
            amount: Money(Decimal(15), currency: eur), to: account,
            expenseCategoryID: food.id, originalPostingID: expense.id,
            description: "Returned item", occurredAt: now
        )
        try repository.post(refund)
        let budget = try Budget(name: "Food", categoryID: food.id, limit: Money(Decimal(100), currency: eur))
        try repository.save(budget)

        let progress = try repository.progress(for: budget, on: now, calendar: .current)
        XCTAssertEqual(progress.spent.amount, Decimal(65))
        XCTAssertEqual(progress.remaining.amount, Decimal(35))
    }

    @MainActor
    func testBudgetRejectsIncomeCategory() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let income = try Category(name: "Salary", kind: .salary)
        try repository.save(income)
        let eur = try Currency(code: "EUR")
        let budget = try Budget(name: "Invalid", categoryID: income.id, limit: Money(Decimal(100), currency: eur))
        XCTAssertThrowsError(try repository.save(budget)) { error in
            XCTAssertEqual(error as? RepositoryError, .budgetCategoryMustBeExpense(income.id))
        }
    }

    @MainActor
    func testPersistsAccountsCategoriesPostingsAndBalance() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let opening = try Money(Decimal(string: "100.00")!, currency: eur)
        let account = try Account(name: "Daily account", type: .current, currency: eur, openingBalance: opening)
        let incomeCategory = try Category(name: "Salary", kind: .income)
        let expenseCategory = try Category(name: "Food", kind: .expense)
        try repository.save(account)
        try repository.save(incomeCategory)
        try repository.save(expenseCategory)

        let income = try LedgerFactory.income(
            amount: Money(Decimal(string: "50.00")!, currency: eur), to: account,
            categoryID: incomeCategory.id, description: "Pay"
        )
        try repository.post(income)
        let expense = try LedgerFactory.expense(
            amount: Money(Decimal(string: "12.35")!, currency: eur), from: account,
            categoryID: expenseCategory.id, description: "Lunch", occurredAt: Date(timeIntervalSince1970: 10)
        )
        try repository.post(expense)

        XCTAssertEqual(try repository.accounts(includeArchived: false), [account])
        XCTAssertEqual(try repository.category(id: expenseCategory.id), expenseCategory)
        XCTAssertEqual(try repository.posting(id: income.id), income)
        XCTAssertEqual(try repository.postings(from: Date(timeIntervalSince1970: 5), through: Date(timeIntervalSince1970: 15)), [expense])
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(string: "137.65"))
    }

    @MainActor
    func testSalaryCategoryCanReceiveAndPersistVariableMonthlyIncome() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Bank", type: .current, currency: eur)
        let salaryCategory = try Category(name: "Salary", kind: .salary)
        try repository.save(account)
        try repository.save(salaryCategory)

        let firstPay = try LedgerFactory.income(
            amount: Money(Decimal(string: "1450.25")!, currency: eur), to: account,
            categoryID: salaryCategory.id, description: "September salary",
            occurredAt: Date(timeIntervalSince1970: 1_758_787_200)
        )
        let secondPay = try LedgerFactory.income(
            amount: Money(Decimal(string: "1822.80")!, currency: eur), to: account,
            categoryID: salaryCategory.id, description: "October salary",
            occurredAt: Date(timeIntervalSince1970: 1_760_515_200)
        )
        try repository.post(firstPay)
        try repository.post(secondPay)

        XCTAssertEqual(try repository.postings(from: nil, through: nil).count, 2)
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(string: "3273.05"))
        XCTAssertEqual(try repository.categories(kind: .salary, includeArchived: false), [salaryCategory])
    }

    @MainActor
    func testRejectsDuplicatePostingAndMissingLedgerReferences() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Wallet", type: .cash, currency: eur)
        let category = try Category(name: "Other income", kind: .income)
        try repository.save(account)
        try repository.save(category)
        let posting = try LedgerFactory.income(
            amount: Money(Decimal(1), currency: eur), to: account,
            categoryID: category.id, description: "Gift"
        )
        try repository.post(posting)
        XCTAssertThrowsError(try repository.post(posting))

        let missingAccount = try Account(name: "Unstored", type: .current, currency: eur)
        let invalid = try LedgerFactory.income(
            amount: Money(Decimal(2), currency: eur), to: missingAccount,
            categoryID: category.id, description: "Invalid"
        )
        XCTAssertThrowsError(try repository.post(invalid))
    }
    @MainActor
    func testRefundCannotExceedOriginalExpense() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let account = try Account(name: "Bank", type: .current, currency: eur, openingBalance: Money(Decimal(100), currency: eur))
        let food = try Category(name: "Food", kind: .expense)
        try repository.save(account)
        try repository.save(food)
        let expense = try LedgerFactory.expense(
            amount: Money(Decimal(20), currency: eur), from: account,
            categoryID: food.id, description: "Meal"
        )
        try repository.post(expense)
        let refund = try LedgerFactory.refund(
            amount: Money(Decimal(15), currency: eur), to: account,
            expenseCategoryID: food.id, originalPostingID: expense.id, description: "Partial refund"
        )
        try repository.post(refund)
        let excessiveRefund = try LedgerFactory.refund(
            amount: Money(Decimal(6), currency: eur), to: account,
            expenseCategoryID: food.id, originalPostingID: expense.id, description: "Too much"
        )
        XCTAssertThrowsError(try repository.post(excessiveRefund)) { error in
            XCTAssertEqual(error as? RepositoryError, .refundExceedsOriginal(expense.id))
        }
        XCTAssertEqual(try repository.balance(for: account).amount, Decimal(95))
    }

    @MainActor
    func testAccountAndCategoryAccountingDefinitionsCannotChange() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let accountID = UUID()
        try repository.save(try Account(id: accountID, name: "Bank", type: .current, currency: eur))
        XCTAssertThrowsError(try repository.save(try Account(id: accountID, name: "Bank", type: .creditCard, currency: eur))) { error in
            XCTAssertEqual(error as? RepositoryError, .accountDefinitionConflict(accountID))
        }
        let categoryID = UUID()
        try repository.save(try Category(id: categoryID, name: "Food", kind: .expense))
        XCTAssertThrowsError(try repository.save(try Category(id: categoryID, name: "Food", kind: .income))) { error in
            XCTAssertEqual(error as? RepositoryError, .categoryDefinitionConflict(categoryID))
        }
    }

    @MainActor
    func testReverseAndCorrectAreAuditableAndAtomic() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let bank = try Account(name: "Bank", type: .current, currency: eur, openingBalance: Money(Decimal(10), currency: eur))
        let salary = try Category(name: "Salary", kind: .income)
        try repository.save(bank)
        try repository.save(salary)
        let original = try LedgerFactory.income(
            amount: Money(Decimal(90), currency: eur), to: bank,
            categoryID: salary.id, description: "Old amount"
        )
        try repository.post(original)
        let invalidReplacement = try LedgerFactory.income(
            amount: Money(Decimal(100), currency: eur), to: bank,
            categoryID: UUID(), description: "Missing category"
        )
        XCTAssertThrowsError(try repository.correct(
            postingID: original.id, reversingDescription: "Rejected correction", replacingWith: invalidReplacement
        ))
        XCTAssertEqual(try repository.postings(from: nil, through: nil).count, 1)
        XCTAssertEqual(try repository.balance(for: bank).amount, Decimal(100))

        let corrected = try LedgerFactory.income(
            amount: Money(Decimal(100), currency: eur), to: bank,
            categoryID: salary.id, description: "Corrected amount"
        )
        try repository.correct(postingID: original.id, reversingDescription: "Correct old amount", replacingWith: corrected)

        let postings = try repository.postings(from: nil, through: nil)
        XCTAssertEqual(postings.count, 3)
        XCTAssertTrue(postings.contains { $0.kind == .reversal && $0.relatedPostingID == original.id })
        XCTAssertEqual(try repository.balance(for: bank).amount, Decimal(110))
        XCTAssertThrowsError(try repository.reverse(postingID: original.id, description: "Again", occurredAt: .now)) { error in
            XCTAssertEqual(error as? RepositoryError, .alreadyReversed(original.id))
        }
    }

}
