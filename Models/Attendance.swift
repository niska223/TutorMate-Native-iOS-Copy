import Foundation

enum AttendanceStatus: String, CaseIterable, Codable, Identifiable {
    case present = "Present", absent = "Absent", late = "Late"
    var id: String { rawValue }
}
struct AttendanceRecord: Identifiable, Codable {
    var id = UUID()
    var studentName: String
    var className: String
    var date: Date
    var status: AttendanceStatus
}
