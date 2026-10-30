import Foundation

enum AttendanceStatus: String, CaseIterable, Codable, Identifiable {
    case present = "Present"
    case absent = "Absent"
    case late = "Late"

    var id: String { rawValue }
}

struct AttendanceRecord: Identifiable, Codable {
    var id = UUID()
    var studentID: UUID? = nil
    var classID: UUID? = nil
    var studentName: String
    var className: String
    var date: Date
    var status: AttendanceStatus

    static func stableDocumentID(studentID: UUID, classID: UUID, date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(studentID.uuidString)_\(classID.uuidString)_\(String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0))"
    }
}

