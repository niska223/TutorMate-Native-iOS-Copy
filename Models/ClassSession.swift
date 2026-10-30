import Foundation

struct ClassSession: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var subject: String
    var date: Date
    var time: String
    var duration: String
    var location: String
    var students: Int

    /// Combines the Firestore calendar date and separately stored time string.
    /// Date-only timestamps often represent midnight, which must not make a
    /// later class today appear to be already past.
    var scheduledDateTime: Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current

        for format in ["h:mm a", "H:mm", "HH:mm", "h a"] {
            formatter.dateFormat = format
            guard let parsedTime = formatter.date(from: time) else { continue }
            let parts = Calendar.current.dateComponents([.hour, .minute], from: parsedTime)
            if let hour = parts.hour, let minute = parts.minute,
               let combined = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) {
                return combined
            }
        }
        return date
    }

    var validationError: String? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Class title is required." }
        if subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Subject is required." }
        if time.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Class time is required." }
        if location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Location is required." }
        if students < 0 { return "Student count cannot be negative." }
        return nil
    }
}

