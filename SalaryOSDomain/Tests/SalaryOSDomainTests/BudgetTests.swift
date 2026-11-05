import Foundation
import Testing
@testable import SalaryOSDomain

@Suite("Budget domain")
struct BudgetTests {
    @Test func progressKeepsNegativeRemainingWhenOverLimit() throws {
        let eur = try Currency(code: "EUR")
        let budget = try Budget(name: "Food", categoryID: UUID(), limit: Money(100, currency: eur))
        let progress = try BudgetProgress(
            budget: budget, spent: Money(125, currency: eur),
            periodStart: .now.addingTimeInterval(-100), periodEnd: .now.addingTimeInterval(100)
        )
        #expect(progress.isOverLimit)
        #expect(progress.remaining.amount == -25)
    }

    @Test func monthlyIntervalUsesCalendarBoundaries() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = ISO8601DateFormatter().date(from: "2026-02-15T12:00:00Z")!
        let interval = try BudgetCalendar.interval(for: .monthly, containing: date, calendar: calendar)
        #expect(interval.start == ISO8601DateFormatter().date(from: "2026-02-01T00:00:00Z"))
        #expect(interval.end == ISO8601DateFormatter().date(from: "2026-03-01T00:00:00Z"))
    }

    @Test func rejectsNonPositiveLimit() {
        #expect(throws: BudgetError.nonPositiveLimit) {
            try Budget(name: "Food", categoryID: UUID(), limit: Money(0, currency: Currency(code: "EUR")))
        }
    }
}
