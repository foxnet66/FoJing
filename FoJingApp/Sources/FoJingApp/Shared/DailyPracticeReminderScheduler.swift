import Foundation
import UserNotifications

enum DailyPracticeReminderScheduler {
    private static let identifier = "daily-practice-reminder"

    static func sync(settings: DailyPracticeReminderSettings) async -> Bool {
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

        await schedule(settings: settings)
        return true
    }

    static func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func schedule(settings: DailyPracticeReminderSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let content = UNMutableNotificationContent()
        content.title = "今日功课"
        content.body = "愿以清净心，安住完成今日诵持。"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = settings.hour
        dateComponents.minute = settings.minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
