import Foundation
import UserNotifications

enum DailyPracticeReminderScheduler {
    private static let identifier = "daily-practice-reminder"

    static func sync(settings: DailyPracticeReminderSettings, shouldRemindToday: Bool, now: Date = Date()) async -> Bool {
        guard settings.isEnabled else {
            await cancel()
            return true
        }

        let center = UNUserNotificationCenter.current()
        let isAuthorized: Bool
        do {
            isAuthorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            await cancel()
            return false
        }

        guard isAuthorized else {
            await cancel()
            return false
        }

        await schedule(settings: settings, shouldRemindToday: shouldRemindToday, now: now)
        return true
    }

    static func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func schedule(settings: DailyPracticeReminderSettings, shouldRemindToday: Bool, now: Date) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "今日功课"
        content.body = "愿以清净心，安住完成今日诵持。"
        content.sound = .default

        let dateComponents = nextReminderDateComponents(settings: settings, shouldRemindToday: shouldRemindToday, now: now)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }

    static func nextReminderDateComponents(
        settings: DailyPracticeReminderSettings,
        shouldRemindToday: Bool,
        now: Date
    ) -> DateComponents {
        let calendar = Calendar.current
        var reminderComponents = calendar.dateComponents([.year, .month, .day], from: now)
        reminderComponents.calendar = calendar
        reminderComponents.hour = settings.hour
        reminderComponents.minute = settings.minute
        reminderComponents.second = 0

        let todayReminderDate = reminderComponents.date ?? now
        let shouldUseToday = shouldRemindToday && todayReminderDate > now
        let targetDate = shouldUseToday ? todayReminderDate : calendar.date(byAdding: .day, value: 1, to: todayReminderDate) ?? todayReminderDate
        return calendar.dateComponents([.year, .month, .day, .hour, .minute], from: targetDate)
    }
}
