import Foundation
import XCTest
import SalaryOSDomain
import SalaryOSPersistence
import SalaryOSApplication

final class DashboardSnapshotTests: XCTestCase {
    @MainActor
    func testDashboardGroupsCurrenciesAndExcludesTransfersFromCashflow() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        let usd = try Currency(code: "USD")
        let bank = try Account(name: "Bank", type: .current, currency: eur, openingBalance: Money(Decimal(100), currency: eur))
        let cash = try Account(name: "Cash", type: .cash, currency: eur, openingBalance: Money(Decimal(20), currency: eur))
        let dollars = try Account(name: "Dollars", type: .savings, currency: usd, openingBalance: Money(Decimal(5), currency: usd))
        let salary = try Category(name: "Salary", kind: .salary)
        let food = try Category(name: "Food", kind: .expense)
        for account in [bank, cash, dollars] { try repository.save(account) }
        try repository.save(salary)
        try repository.save(food)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let asOf = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12)))
        try repository.post(try LedgerFactory.income(
            amount: Money(Decimal(50), currency: eur), to: bank, categoryID: salary.id,
            description: "Pay", occurredAt: asOf
        ))
        let expense = try LedgerFactory.expense(
            amount: Money(Decimal(10), currency: eur), from: bank, categoryID: food.id,
            description: "Lunch", occurredAt: asOf
        )
        try repository.post(expense)
        try repository.post(try LedgerFactory.refund(
            amount: Money(Decimal(3), currency: eur), to: bank, expenseCategoryID: food.id,
            originalPostingID: expense.id, description: "Partial return", occurredAt: asOf
        ))
        try repository.post(try LedgerFactory.transfer(
            amount: Money(Decimal(15), currency: eur), from: bank, to: cash,
            description: "Cash withdrawal", occurredAt: asOf
        ))

        let snapshot = try LoadDashboardSnapshot(accountRepository: repository, ledgerRepository: repository)
            .execute(asOf: asOf, calendar: calendar)
        let euroSummary = try XCTUnwrap(snapshot.currencies.first { $0.currency == eur })
        let dollarSummary = try XCTUnwrap(snapshot.currencies.first { $0.currency == usd })

        XCTAssertEqual(euroSummary.balance, Decimal(163))
        XCTAssertEqual(euroSummary.incomeThisMonth, Decimal(50))
        XCTAssertEqual(euroSummary.expensesThisMonth, Decimal(7))
        XCTAssertEqual(dollarSummary.balance, Decimal(5))
        XCTAssertEqual(dollarSummary.incomeThisMonth, .zero)
        XCTAssertEqual(snapshot.accounts.count, 3)
        XCTAssertEqual(snapshot.recentPostings.count, 4)
        XCTAssertEqual(euroSummary.history.count, 6)
    }

    @MainActor
    func testArchivedAccountsAreExcludedAndEmptyChartsStayEmpty() throws {
        let stack = try FinancePersistenceStack(inMemory: true)
        let repository = stack.repository
        let eur = try Currency(code: "EUR")
        var account = try Account(name: "Old account", type: .current, currency: eur, openingBalance: Money(Decimal(100), currency: eur))
        account.setArchived(true)
        try repository.save(account)
        let snapshot = try LoadDashboardSnapshot(accountRepository: repository, ledgerRepository: repository)
            .execute(asOf: Date(timeIntervalSince1970: 1_780_000_000))
        XCTAssertTrue(snapshot.accounts.isEmpty)
        XCTAssertTrue(snapshot.currencies.isEmpty)
        XCTAssertTrue(snapshot.recentPostings.isEmpty)
    }
}
