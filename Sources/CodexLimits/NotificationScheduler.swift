import Foundation
import UserNotifications

actor NotificationScheduler {
    static let shared = NotificationScheduler()

    private let center = UNUserNotificationCenter.current()
    private let weeklyResetIdentifier = "codexlimits.weekly-reset"

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else {
            return
        }

        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func scheduleWeeklyResetNotification(at date: Date?) async {
        center.removePendingNotificationRequests(withIdentifiers: [weeklyResetIdentifier])

        guard let date, date > Date() else {
            return
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Codex Limits"
        content.body = "Your weekly Codex limit has refreshed."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: weeklyResetIdentifier,
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}
