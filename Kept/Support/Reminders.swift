import Foundation
import SwiftData
import UserNotifications

/// Local reminders. They are rebuilt from the habits whenever something changes, so there is never anything stale to
/// clean up: remove every Kept request, then add one per habit (or per weekday for fixed-day habits).
enum Reminders {
    private static let prefix = "kept."

    @discardableResult
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func syncAll() async {
        let context = SharedStore.makeContext()
        let habits = (try? context.fetch(FetchDescriptor<Habit>(predicate: #Predicate { !$0.archived }))) ?? []
        await sync(habits)
    }

    static func sync(_ habits: [Habit]) async {
        let center = UNUserNotificationCenter.current()
        let existing = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)
        guard !habits.filter({ $0.reminderMinutes != nil }).isEmpty,
              await center.notificationSettings().authorizationStatus == .authorized else { return }

        for habit in habits where !habit.archived {
            guard let minutes = habit.reminderMinutes else { continue }
            let weekdays: [Int?]
            if case .weekdays(let days) = habit.schedule { weekdays = days.sorted() } else { weekdays = [nil] }
            for weekday in weekdays {
                var parts = DateComponents(hour: minutes / 60, minute: minutes % 60)
                parts.weekday = weekday
                let content = UNMutableNotificationContent()
                content.title = habit.name
                content.body = "Time for this one."
                content.sound = .default
                let id = "\(prefix)\(habit.id.uuidString).\(weekday ?? 0)"
                let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: true)
                try? await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }
}
