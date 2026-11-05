import Foundation

public enum SavingsGoalError: Error, Equatable {
    case emptyName
    case nonPositiveTarget
    case nonPositiveContribution
    case invalidTargetDate
    case contributionCurrencyMismatch
}

public enum SavingsGoalStatus: String, Codable, Sendable {
    case active
    case reached
    case archived
}

public struct SavingsGoal: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public let currency: Currency
    public private(set) var target: Money
    public private(set) var targetDate: Date?
    public let linkedAccountID: UUID?
    public private(set) var notes: String?
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool

    public init(
        id: UUID = UUID(), name: String, target: Money, targetDate: Date? = nil,
        linkedAccountID: UUID? = nil, notes: String? = nil, createdAt: Date = .now,
        updatedAt: Date = .now, isArchived: Bool = false
    ) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SavingsGoalError.emptyName }
        guard target.amount > .zero else { throw SavingsGoalError.nonPositiveTarget }
        if let targetDate, targetDate < createdAt { throw SavingsGoalError.invalidTargetDate }
        self.id = id
        self.name = name
        currency = target.currency
        self.target = target
        self.targetDate = targetDate
        self.linkedAccountID = linkedAccountID
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public mutating func update(name: String, target: Money, targetDate: Date?, notes: String?) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SavingsGoalError.emptyName }
        guard target.amount > .zero else { throw SavingsGoalError.nonPositiveTarget }
        guard target.currency == currency else {
            throw MoneyError.currencyMismatch(expected: currency.code, actual: target.currency.code)
        }
        if let targetDate, targetDate < createdAt { throw SavingsGoalError.invalidTargetDate }
        self.name = name
        self.target = target
        self.targetDate = targetDate
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updatedAt = .now
    }

    public mutating func setArchived(_ archived: Bool) {
        isArchived = archived
        updatedAt = .now
    }
}

public struct SavingsContribution: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let goalID: UUID
    public let amount: Money
    public let contributedAt: Date
    public let note: String?
    public let createdAt: Date

    public init(id: UUID = UUID(), goalID: UUID, amount: Money, contributedAt: Date = .now, note: String? = nil, createdAt: Date = .now) throws {
        guard amount.amount > .zero else { throw SavingsGoalError.nonPositiveContribution }
        self.id = id
        self.goalID = goalID
        self.amount = amount
        self.contributedAt = contributedAt
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
    }
}

public struct SavingsGoalProgress: Equatable, Sendable {
    public let goal: SavingsGoal
    public let contributions: [SavingsContribution]
    public let saved: Money
    public let remaining: Money
    public let status: SavingsGoalStatus
    public let requiredMonthlyContribution: Money?

    public var progressFraction: Decimal {
        guard goal.target.amount > .zero else { return .zero }
        return min(saved.amount / goal.target.amount, 1)
    }

    public init(goal: SavingsGoal, contributions: [SavingsContribution], asOf date: Date = .now, calendar: Calendar = .current) throws {
        var total = Decimal.zero
        for contribution in contributions where contribution.goalID == goal.id {
            guard contribution.amount.currency == goal.currency else { throw SavingsGoalError.contributionCurrencyMismatch }
            total += contribution.amount.amount
        }
        let values = contributions.filter { $0.goalID == goal.id }.sorted { $0.contributedAt > $1.contributedAt }
        saved = try Money(total, currency: goal.currency)
        remaining = try Money(max(.zero, goal.target.amount - total), currency: goal.currency)
        status = goal.isArchived ? .archived : (total >= goal.target.amount ? .reached : .active)
        self.goal = goal
        self.contributions = values
        if let targetDate = goal.targetDate, status == .active {
            let monthComponents = calendar.dateComponents([.year, .month], from: date, to: targetDate)
            let months = max(1, (monthComponents.year ?? 0) * 12 + (monthComponents.month ?? 0) + 1)
            requiredMonthlyContribution = try Money(remaining.amount / Decimal(months), currency: goal.currency)
        } else {
            requiredMonthlyContribution = nil
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
