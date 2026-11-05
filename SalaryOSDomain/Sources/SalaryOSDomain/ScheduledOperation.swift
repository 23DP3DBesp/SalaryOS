import Foundation

public enum ScheduledOperationKind: String, Codable, CaseIterable, Sendable {
    case income
    case expense
}

public enum RecurrenceFrequency: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
    case yearly
}

public enum ScheduledOperationError: Error, Equatable {
    case emptyName
    case invalidAmount
    case invalidDateRange
    case invalidCalendarDate
    case currencyMismatch
}

public struct ScheduledOperation: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var name: String
    public let kind: ScheduledOperationKind
    public private(set) var amount: Money
    public let accountID: UUID
    public let categoryID: UUID
    public let recurrence: RecurrenceFrequency
    public let startDate: Date
    public let endDate: Date?
    public private(set) var notes: String?
    public let createdAt: Date
    public private(set) var updatedAt: Date
    public private(set) var isArchived: Bool

    public init(
        id: UUID = UUID(), name: String, kind: ScheduledOperationKind, amount: Money,
        accountID: UUID, categoryID: UUID, recurrence: RecurrenceFrequency,
        startDate: Date, endDate: Date? = nil, notes: String? = nil,
        createdAt: Date = .now, updatedAt: Date = .now, isArchived: Bool = false
    ) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ScheduledOperationError.emptyName }
        guard amount.amount > .zero else { throw ScheduledOperationError.invalidAmount }
        if let endDate, endDate < startDate { throw ScheduledOperationError.invalidDateRange }
        self.id = id
        self.name = cleaned
        self.kind = kind
        self.amount = amount
        self.accountID = accountID
        self.categoryID = categoryID
        self.recurrence = recurrence
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isArchived = isArchived
    }

    public mutating func update(name: String, amount: Money, notes: String?) throws {
        let cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw ScheduledOperationError.emptyName }
        guard amount.amount > .zero else { throw ScheduledOperationError.invalidAmount }
        guard amount.currency == self.amount.currency else { throw ScheduledOperationError.currencyMismatch }
        self.name = cleaned
        self.amount = amount
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        updatedAt = .now
    }

    public mutating func setArchived(_ archived: Bool) { isArchived = archived; updatedAt = .now }
}

public struct ScheduledOccurrence: Identifiable, Hashable, Sendable {
    public let id: String
    public let operationID: UUID
    public let dueDate: Date
    public let operation: ScheduledOperation
}

public enum RecurrenceCalendar {
    public static func occurrences(
        for operation: ScheduledOperation,
        from start: Date,
        through end: Date,
        calendar: Calendar = .current
    ) throws -> [ScheduledOccurrence] {
        guard start <= end else { throw ScheduledOperationError.invalidDateRange }
        let anchor = calendar.startOfDay(for: operation.startDate)
        let requestedStart = max(calendar.startOfDay(for: start), anchor)
        let upperBound = min(calendar.startOfDay(for: end), operation.endDate.map(calendar.startOfDay(for:)) ?? calendar.startOfDay(for: end))
        guard requestedStart <= upperBound else { return [] }
        var result: [ScheduledOccurrence] = []
        let anchorComponents = calendar.dateComponents([.year, .month, .day], from: anchor)
        for index in 0..<10_000 {
            guard let dueDate = occurrenceDate(index: index, anchor: anchor, components: anchorComponents, frequency: operation.recurrence, calendar: calendar) else {
                throw ScheduledOperationError.invalidCalendarDate
            }
            if dueDate > upperBound { break }
            guard dueDate >= requestedStart else { continue }
            let parts = calendar.dateComponents([.year, .month, .day], from: dueDate)
            let dayKey = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            result.append(ScheduledOccurrence(id: "\(operation.id.uuidString):\(dayKey)", operationID: operation.id, dueDate: dueDate, operation: operation))
        }
        return result
    }

    private static func occurrenceDate(index: Int, anchor: Date, components: DateComponents, frequency: RecurrenceFrequency, calendar: Calendar) -> Date? {
        if index == 0 { return anchor }
        switch frequency {
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: index, to: anchor)
        case .monthly:
            guard let anchorMonth = calendar.dateInterval(of: .month, for: anchor)?.start,
                  let month = calendar.date(byAdding: .month, value: index, to: anchorMonth),
                  let interval = calendar.dateInterval(of: .month, for: month) else { return nil }
            let range = calendar.range(of: .day, in: .month, for: month) ?? 1..<29
            let day = min(components.day ?? 1, range.upperBound - 1)
            return calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        case .yearly:
            guard let firstOfYear = calendar.dateInterval(of: .year, for: anchor)?.start,
                  let year = calendar.date(byAdding: .year, value: index, to: firstOfYear),
                  let monthStart = calendar.date(from: DateComponents(year: calendar.component(.year, from: year), month: components.month ?? 1, day: 1)),
                  let interval = calendar.dateInterval(of: .month, for: monthStart) else { return nil }
            let range = calendar.range(of: .day, in: .month, for: monthStart) ?? 1..<29
            let day = min(components.day ?? 1, range.upperBound - 1)
            return calendar.date(byAdding: .day, value: day - 1, to: interval.start)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
