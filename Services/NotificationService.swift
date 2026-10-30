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

    func scheduleReminder(for session: ClassSession, minutesBefore: Int = 15) async throws {
        guard let triggerDate = Self.reminderDate(for: session, minutesBefore: minutesBefore) else { throw ReminderError.invalidTime }
        guard triggerDate > .now else { return }
        let content = UNMutableNotificationContent()
        content.title = "Upcoming TutorMate class"
        content.body = "\(session.title) · \(session.location) starts in \(minutesBefore) minutes."
        content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate)
        let request = UNNotificationRequest(identifier: "tutormate.class.\(session.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
        try await UNUserNotificationCenter.current().add(request)
    }

    static func reminderDate(for session: ClassSession, minutesBefore: Int = 15, calendar: Calendar = .current) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a"
        guard let time = formatter.date(from: session.time) else { return nil }
        let parts = calendar.dateComponents([.year, .month, .day], from: session.date)
        let clock = calendar.dateComponents([.hour, .minute], from: time)
        guard let start = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: clock.hour, minute: clock.minute)) else { return nil }
        return start.addingTimeInterval(TimeInterval(-minutesBefore * 60))
    }

    func cancelReminder(for sessionID: UUID) {
        let identifier = "tutormate.class.\(sessionID.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func cancelAllClassReminders() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let ids = requests.map(\.identifier).filter { $0.hasPrefix("tutormate.class.") }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}

enum ReminderError: LocalizedError {
    case invalidTime
    var errorDescription: String? { "Class time must use a format such as 4:00 PM." }
}
