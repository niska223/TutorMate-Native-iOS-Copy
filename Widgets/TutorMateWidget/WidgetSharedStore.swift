import Foundation
import WidgetKit

struct WidgetPayload: Codable {
    let schemaVersion: Int
    let role: String
    let classTitle: String?
    let subject: String?
    let classDate: Date?
    let classTime: String?
    let location: String?
    let tutorName: String?
    let attendanceStreak: Int?
    let updatedAt: Date

    init(role: String, classTitle: String?, subject: String?, classDate: Date?, classTime: String?, location: String?, tutorName: String?, attendanceStreak: Int?) {
        schemaVersion = 1
        self.role = role
        self.classTitle = classTitle
        self.subject = subject
        self.classDate = classDate
        self.classTime = classTime
        self.location = location
        self.tutorName = tutorName
        self.attendanceStreak = attendanceStreak
        updatedAt = .now
    }

    static func streak(from records: [(date: Date, attended: Bool)]) -> Int? {
        let attendedDays = Set(records.filter(\.attended)
            .map { Calendar.current.startOfDay(for: $0.date) }).sorted(by: >)
        guard let newest = attendedDays.first else { return nil }
        let today = Calendar.current.startOfDay(for: .now)
        guard Calendar.current.dateComponents([.day], from: newest, to: today).day ?? 99 <= 1 else { return 0 }
        var count = 0
        var expected = newest
        for day in attendedDays {
            guard Calendar.current.isDate(day, inSameDayAs: expected) else { break }
            count += 1
            guard let previous = Calendar.current.date(byAdding: .day, value: -1, to: expected) else { break }
            expected = previous
        }
        return count
    }
}

enum WidgetSharedStore {
    static let group = "group.com.example.tutormate"
    static let key = "tutormate.widget.payload.v1"
    static func save(_ payload: WidgetPayload) {
        guard let defaults = UserDefaults(suiteName: group), let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: key)
        WidgetCenter.shared.reloadTimelines(ofKind: "TutorMateWidget")
    }
    static func load(now: Date = .now) -> WidgetPayload? {
        guard let data = UserDefaults(suiteName: group)?.data(forKey: key),
              let payload = try? JSONDecoder().decode(WidgetPayload.self, from: data),
              payload.schemaVersion == 1,
              now.timeIntervalSince(payload.updatedAt) < 7 * 24 * 60 * 60 else { return nil }
        return payload
    }
    static func clear() { UserDefaults(suiteName: group)?.removeObject(forKey: key); WidgetCenter.shared.reloadTimelines(ofKind: "TutorMateWidget") }
}
