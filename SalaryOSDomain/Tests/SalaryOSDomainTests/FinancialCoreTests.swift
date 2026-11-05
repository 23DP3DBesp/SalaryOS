import Foundation
import XCTest
@testable import SalaryOSDomain

final class FinancialCoreTests: XCTestCase {
    private let eur = try! Currency(code: "EUR")
    private let usd = try! Currency(code: "USD")

    private func money(_ amount: String, currency: Currency? = nil) throws -> Money {
        guard let decimal = Decimal(string: amount) else { throw TestDataError.invalidDecimal(amount) }
        return try Money(decimal, currency: currency ?? eur)
    }

    private func account(_ name: String, type: AccountType = .current, balance: String = "0") throws -> Account {
        try Account(name: name, type: type, currency: eur, openingBalance: money(balance))
    }

    func testCurrencyUsesISO4217MinorUnits() throws {
        XCTAssertEqual(try Currency(code: "eur").code, "EUR")
        XCTAssertEqual(try Currency(code: "EUR").fractionDigits, 2)
        XCTAssertEqual(try Currency(code: "JPY").fractionDigits, 0)
        XCTAssertEqual(try Currency(code: "KWD").fractionDigits, 3)
        XCTAssertThrowsError(try Currency(code: "EURO"))
    }

    func testMoneyRoundsUsingDecimalAtCurrencyPrecision() throws {
        XCTAssertEqual(try money("1.005").amount, Decimal(string: "1.01"))
        XCTAssertEqual(try money("-1.005").amount, Decimal(string: "-1.01"))
        let jpy = try Currency(code: "JPY")
        XCTAssertEqual(try money("100.5", currency: jpy).amount, Decimal(101))
    }

    func testArithmeticRejectsDifferentCurrencies() throws {
        XCTAssertThrowsError(try money("2").adding(money("1", currency: usd)))
    }

    func testAccountEnforcesSignedOpeningBalanceConvention() throws {
        XCTAssertThrowsError(try account("Card", type: .creditCard, balance: "25"))
        XCTAssertThrowsError(try account("Cash", balance: "-25"))
        XCTAssertEqual(try account("Card", type: .creditCard, balance: "-25").openingBalance.amount, Decimal(-25))
    }

    func testIncomeAndExpenseProduceBalancedLedgerEntries() throws {
        let cash = try account("Main")
        let income = try LedgerFactory.income(amount: money("2000"), to: cash, categoryID: UUID(), description: "Salary")
        let expense = try LedgerFactory.expense(amount: money("42.15"), from: cash, categoryID: UUID(), description: "Groceries")
        XCTAssertEqual(income.entries.count, 2)
        XCTAssertEqual(income.entries[0].side, .debit)
        XCTAssertEqual(income.entries[1].side, .credit)
        XCTAssertEqual(expense.entries[0].accountKind, .expense)
        XCTAssertEqual(expense.entries[1].accountKind, .asset)
    }

    func testTransferDoesNotUseIncomeOrExpenseAccounts() throws {
        let bank = try account("Bank")
        let wallet = try account("Wallet", type: .cash)
        let transfer = try LedgerFactory.transfer(amount: money("50"), from: bank, to: wallet, description: "Cash withdrawal")
        XCTAssertEqual(transfer.kind, .transfer)
        XCTAssertEqual(transfer.entries.map(\.accountKind), [.asset, .asset])
    }

    func testRefundReferencesOriginalExpenseAndBalances() throws {
        let bank = try account("Bank")
        let originalID = UUID()
        let refund = try LedgerFactory.refund(
            amount: money("10"), to: bank, expenseCategoryID: UUID(), originalPostingID: originalID,
            description: "Returned item"
        )
        XCTAssertEqual(refund.relatedPostingID, originalID)
        XCTAssertEqual(refund.entries.map(\.side), [.debit, .credit])
    }

    func testPostingRejectsUnbalancedEntriesAndMultipleCurrencies() throws {
        let debit = try LedgerEntry(accountID: UUID(), accountKind: .asset, side: .debit, money: money("10"))
        let shortCredit = try LedgerEntry(accountID: UUID(), accountKind: .income, side: .credit, money: money("9"))
        XCTAssertThrowsError(try LedgerPosting(kind: .income, description: "Bad", entries: [debit, shortCredit]))
        let dollarCredit = try LedgerEntry(accountID: UUID(), accountKind: .income, side: .credit, money: money("10", currency: usd))
        XCTAssertThrowsError(try LedgerPosting(kind: .income, description: "Mixed", entries: [debit, dollarCredit])) { error in
            XCTAssertEqual(error as? LedgerError, .multipleCurrenciesUnsupported)
        }
    }

    func testCodableDecodingRevalidatesMoneyAndLedgerInvariants() throws {
        let valid = try money("1.23")
        let encoded = try JSONEncoder().encode(valid)
        XCTAssertEqual(try JSONDecoder().decode(Money.self, from: encoded), valid)

        let unbalanced = """
        {"id":"00000000-0000-0000-0000-000000000001","kind":"income","occurredAt":0,"description":"Bad","entries":[],"createdAt":0}
        """.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(LedgerPosting.self, from: unbalanced))
    }

    func testFactoryRejectsCurrencyMismatchAndSameAccountTransfer() throws {
        let bank = try account("Bank")
        XCTAssertThrowsError(try LedgerFactory.expense(amount: money("5", currency: usd), from: bank, categoryID: UUID(), description: "Invalid"))
        XCTAssertThrowsError(try LedgerFactory.transfer(amount: money("5"), from: bank, to: bank, description: "Invalid"))
    }
}

private enum TestDataError: Error {
    case invalidDecimal(String)
}
