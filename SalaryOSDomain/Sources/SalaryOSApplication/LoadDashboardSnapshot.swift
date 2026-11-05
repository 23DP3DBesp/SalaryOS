import Foundation
import SalaryOSDomain

public struct MonthlyCashflow: Identifiable, Equatable, Sendable {
    public var id: Date { month }
    public let month: Date
    public var income: Decimal
    public var expenses: Decimal

    public init(month: Date, income: Decimal = .zero, expenses: Decimal = .zero) {
        self.month = month
        self.income = income
        self.expenses = expenses
    }
}

public struct DashboardCurrencySummary: Identifiable, Sendable {
    public var id: String { currency.code }
    public let currency: Currency
    public let balance: Decimal
    public let incomeThisMonth: Decimal
    public let expensesThisMonth: Decimal
    public let hasBalance: Bool
    public let history: [MonthlyCashflow]

    public var hasCashflow: Bool {
        incomeThisMonth != .zero || expensesThisMonth != .zero
    }
}

public struct DashboardAccountBalance: Identifiable, Sendable {
    public var id: UUID { account.id }
    public let account: Account
    public let balance: Money
}

public struct DashboardSnapshot: Sendable {
    public let accounts: [DashboardAccountBalance]
    public let currencies: [DashboardCurrencySummary]
    public let recentPostings: [LedgerPosting]
}

@MainActor
public struct LoadDashboardSnapshot {
    private let accountRepository: any AccountRepository
    private let ledgerRepository: any LedgerRepository

    public init(accountRepository: any AccountRepository, ledgerRepository: any LedgerRepository) {
        self.accountRepository = accountRepository
        self.ledgerRepository = ledgerRepository
    }

    public func execute(asOf date: Date = .now, calendar: Calendar = .current) throws -> DashboardSnapshot {
        let accounts = try accountRepository.accounts(includeArchived: false)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let accountBalances = try accounts.map { account in
            DashboardAccountBalance(account: account, balance: try ledgerRepository.balance(for: account))
        }
        let allPostings = try ledgerRepository.postings(from: nil, through: nil)
        let recentPostings = Array(allPostings.sorted { $0.occurredAt > $1.occurredAt }.prefix(5))
        let currentMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        let months = (0..<6).compactMap { offset in
            calendar.date(byAdding: .month, value: offset - 5, to: currentMonth)
        }
        let oldestMonth = months.first ?? currentMonth
        var currencies = Set(accounts.map(\.currency))
        currencies.formUnion(allPostings.filter { $0.occurredAt >= oldestMonth }.compactMap { $0.entries.first?.money.currency })

        var histories: [Currency: [Date: MonthlyCashflow]] = [:]
        for currency in currencies {
            histories[currency] = Dictionary(uniqueKeysWithValues: months.map { ($0, MonthlyCashflow(month: $0)) })
        }
        for posting in allPostings where posting.occurredAt >= oldestMonth {
            guard let currency = posting.entries.first?.money.currency,
                  let month = calendar.dateInterval(of: .month, for: posting.occurredAt)?.start,
                  var monthData = histories[currency]?[month]
            else { continue }
            switch posting.kind {
            case .income:
                monthData.income += posting.entries
                    .filter { $0.accountKind == .income && $0.side == .credit }
                    .reduce(.zero) { $0 + $1.money.amount }
            case .expense:
                monthData.expenses += posting.entries
                    .filter { $0.accountKind == .expense && $0.side == .debit }
                    .reduce(.zero) { $0 + $1.money.amount }
            case .refund:
                monthData.expenses -= posting.entries
                    .filter { $0.accountKind == .expense && $0.side == .credit }
                    .reduce(.zero) { $0 + $1.money.amount }
            case .reversal:
                guard let originalID = posting.relatedPostingID,
                      let original = allPostings.first(where: { $0.id == originalID })
                else { continue }
                switch original.kind {
                case .income:
                    monthData.income -= posting.entries
                        .filter { $0.accountKind == .income && $0.side == .debit }
                        .reduce(.zero) { $0 + $1.money.amount }
                case .expense:
                    monthData.expenses -= posting.entries
                        .filter { $0.accountKind == .expense && $0.side == .credit }
                        .reduce(.zero) { $0 + $1.money.amount }
                case .transfer, .refund, .adjustment, .reversal:
                    break
                }
            case .transfer, .adjustment:
                break
            }
            histories[currency]?[month] = monthData
        }

        let summaries = currencies.map { currency in
            let history = (histories[currency] ?? [:]).values.sorted { $0.month < $1.month }
            let current = history.first { $0.month == currentMonth }
            return DashboardCurrencySummary(
                currency: currency,
                balance: accountBalances.filter { $0.account.currency == currency }
                    .reduce(.zero) { $0 + $1.balance.amount },
                incomeThisMonth: current?.income ?? .zero,
                expensesThisMonth: current?.expenses ?? .zero,
                hasBalance: accountBalances.contains { $0.account.currency == currency },
                history: history
            )
        }.sorted { $0.currency.code < $1.currency.code }

        return DashboardSnapshot(accounts: accountBalances, currencies: summaries, recentPostings: recentPostings)
    }
}
