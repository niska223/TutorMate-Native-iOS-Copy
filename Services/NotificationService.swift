import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch { return false }
    }
    func sendTestReminder() {
        let content = UNMutableNotificationContent()
        content.title = "TutorMate"
        content.body = "This is a sample class reminder."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        UNUserNotificationCenter.current().add(request)
    }
}
