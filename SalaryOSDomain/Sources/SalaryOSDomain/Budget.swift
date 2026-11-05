import Foundation

public enum BudgetError: Error, Equatable {
    case emptyName
    case nonPositiveLimit
    case invalidPeriod
    case invalidSpentAmount
}

public enum BudgetPeriod: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly
}

/// A category spending limit for a recurring calendar period.
public struct Budget: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public let categoryID: UUID
    public let currency: Currency
    public private(set) var limit: Money
    public let period: BudgetPeriod
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool

    public init(
        id: UUID = UUID(), name: String, categoryID: UUID, limit: Money,
        period: BudgetPeriod = .monthly, createdAt: Date = .now,
        updatedAt: Date = .now, isArchived: Bool = false
    ) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw BudgetError.emptyName }
        guard limit.amount > .zero else { throw BudgetError.nonPositiveLimit }
        self.id = id
        self.name = cleanedName
        self.categoryID = categoryID
        self.currency = limit.currency
        self.limit = limit
        self.period = period
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public mutating func update(name: String, limit: Money) throws {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedName.isEmpty else { throw BudgetError.emptyName }
        guard limit.amount > .zero else { throw BudgetError.nonPositiveLimit }
        guard limit.currency == currency else {
            throw MoneyError.currencyMismatch(expected: currency.code, actual: limit.currency.code)
        }
        self.name = cleanedName
        self.limit = limit
        updatedAt = .now
    }

    public mutating func setArchived(_ archived: Bool) {
        isArchived = archived
        updatedAt = .now
    }
}

public struct BudgetProgress: Equatable, Sendable {
    public let budget: Budget
    public let spent: Money
    public let remaining: Money
    public let periodStart: Date
    public let periodEnd: Date

    public var isOverLimit: Bool { spent.amount > budget.limit.amount }

    public init(budget: Budget, spent: Money, periodStart: Date, periodEnd: Date) throws {
        guard spent.currency == budget.currency else {
            throw MoneyError.currencyMismatch(expected: budget.currency.code, actual: spent.currency.code)
        }
        guard spent.amount >= .zero else { throw BudgetError.invalidSpentAmount }
        guard periodStart < periodEnd else { throw BudgetError.invalidPeriod }
        self.budget = budget
        self.spent = spent
        self.remaining = try Money(budget.limit.amount - spent.amount, currency: budget.currency)
        self.periodStart = periodStart
        self.periodEnd = periodEnd
    }
}

/// Returns the half-open calendar interval containing `date` for the budget period.
public enum BudgetCalendar {
    public static func interval(for period: BudgetPeriod, containing date: Date, calendar: Calendar = .current) throws -> (start: Date, end: Date) {
        guard let start = calendar.dateInterval(of: period.calendarComponent, for: date)?.start,
              let interval = calendar.dateInterval(of: period.calendarComponent, for: date) else {
            throw BudgetError.invalidPeriod
        }
        let end = interval.end.addingTimeInterval(-1)
        return (start, end)
    }
}

private extension BudgetPeriod {
    var calendarComponent: Calendar.Component {
        switch self {
        case .weekly: .weekOfYear
        case .monthly: .month
        case .yearly: .year
        }
    }
}
