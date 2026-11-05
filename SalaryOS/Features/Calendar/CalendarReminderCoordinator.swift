import Foundation
import SalaryOSDomain
import UserNotifications

@MainActor
final class CalendarReminderCoordinator {
    private let center = UNUserNotificationCenter.current()
    private let identifierPrefix = "salaryos.calendar."

    func requestPermission() async throws -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound])
        @unknown default:
            return false
        }
    }

    func refresh(operations: [ScheduledOperation], postedIDs: Set<String>, calendar: Calendar = .current) async throws {
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard try await requestPermission() else { return }

        let today = calendar.startOfDay(for: .now)
        guard let horizon = calendar.date(byAdding: .year, value: 10, to: today) else { return }
        let candidates = try operations.flatMap { operation in
            try RecurrenceCalendar.occurrences(for: operation, from: today, through: horizon, calendar: calendar)
                .filter { !postedIDs.contains($0.id) }
        }
        .sorted { $0.dueDate < $1.dueDate }

        var scheduledCount = 0
        for occurrence in candidates {
            var dateComponents = calendar.dateComponents([.year, .month, .day], from: occurrence.dueDate)
            dateComponents.hour = 9
            dateComponents.minute = 0
            guard let reminderDate = calendar.date(from: dateComponents), reminderDate > .now else { continue }
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            let content = UNMutableNotificationContent()
            content.title = occurrence.operation.name
            content.body = "\(occurrence.operation.amount.amount.formatted(.number.precision(.fractionLength(0...2)))) \(occurrence.operation.amount.currency.code) · \(occurrence.dueDate.formatted(date: .abbreviated, time: .omitted))"
            content.sound = .default
            let request = UNNotificationRequest(
                identifier: identifierPrefix + occurrence.id,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
            scheduledCount += 1
            if scheduledCount == 48 { break }
        }
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)
    }
}
