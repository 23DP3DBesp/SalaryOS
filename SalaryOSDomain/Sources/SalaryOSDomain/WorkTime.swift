import Foundation

public enum WorkTimeError: Error, Equatable {
    case emptyEmployer
    case emptyDescription
    case endMustFollowStart
    case invalidBreak
    case negativeHourlyRate
    case overlappingEntries(UUID, UUID)
}

public struct WorkEntry: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public private(set) var employer: String
    public private(set) var description: String
    public let startedAt: Date
    public let endedAt: Date
    public private(set) var unpaidBreakMinutes: Int
    public private(set) var hourlyRate: Money
    public private(set) var notes: String?
    public let createdAt: Date
    public private(set) var updatedAt: Date

    public var durationSeconds: Int { max(0, Int(endedAt.timeIntervalSince(startedAt))) }
    public var paidSeconds: Int { max(0, durationSeconds - unpaidBreakMinutes * 60) }
    public var paidHours: Decimal { Decimal(paidSeconds) / Decimal(3600) }
    public func estimatedGross() throws -> Money {
        try Money(hourlyRate.amount * paidHours, currency: hourlyRate.currency)
    }

    public init(
        id: UUID = UUID(), employer: String, description: String,
        startedAt: Date, endedAt: Date, unpaidBreakMinutes: Int = 0,
        hourlyRate: Money, notes: String? = nil,
        createdAt: Date = .now, updatedAt: Date = .now
    ) throws {
        let employer = employer.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !employer.isEmpty else { throw WorkTimeError.emptyEmployer }
        guard !description.isEmpty else { throw WorkTimeError.emptyDescription }
        guard endedAt > startedAt else { throw WorkTimeError.endMustFollowStart }
        let durationMinutes = Int(endedAt.timeIntervalSince(startedAt) / 60)
        guard unpaidBreakMinutes >= 0, unpaidBreakMinutes < durationMinutes else { throw WorkTimeError.invalidBreak }
        guard hourlyRate.amount >= .zero else { throw WorkTimeError.negativeHourlyRate }
        self.id = id
        self.employer = employer
        self.description = description
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.unpaidBreakMinutes = unpaidBreakMinutes
        self.hourlyRate = hourlyRate
        self.notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct WorkTimeSummary: Equatable, Sendable {
    public let employer: String
    public let hours: Decimal
    public let estimatedGross: Money
    public let entryCount: Int

    public init(employer: String, entries: [WorkEntry], currency: Currency) throws {
        var totalSeconds = 0
        var gross = Decimal.zero
        for entry in entries where entry.employer == employer && entry.hourlyRate.currency == currency {
            totalSeconds += entry.paidSeconds
            gross += try entry.estimatedGross().amount
        }
        self.employer = employer
        hours = Decimal(totalSeconds) / Decimal(3600)
        estimatedGross = try Money(gross, currency: currency)
        entryCount = entries.filter { $0.employer == employer && $0.hourlyRate.currency == currency }.count
    }
}

public enum WorkTimeCalculator {
    public static func monthlySummaries(entries: [WorkEntry], monthContaining date: Date, calendar: Calendar = .current) throws -> [WorkTimeSummary] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        let monthEntries = entries.filter { $0.startedAt >= interval.start && $0.startedAt < interval.end }
        let groups = Dictionary(grouping: monthEntries) { "\($0.employer)|\($0.hourlyRate.currency.code)" }
        return try groups.values.compactMap { values in
            guard let first = values.first else { return nil }
            return try WorkTimeSummary(employer: first.employer, entries: values, currency: first.hourlyRate.currency)
        }
        .sorted {
            if $0.employer != $1.employer { return $0.employer.localizedStandardCompare($1.employer) == .orderedAscending }
            return $0.estimatedGross.currency.code < $1.estimatedGross.currency.code
        }
    }

    public static func validateNoOverlap(_ candidate: WorkEntry, among entries: [WorkEntry]) throws {
        if let conflict = entries.first(where: { $0.id != candidate.id && candidate.startedAt < $0.endedAt && $0.startedAt < candidate.endedAt }) {
            throw WorkTimeError.overlappingEntries(candidate.id, conflict.id)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
