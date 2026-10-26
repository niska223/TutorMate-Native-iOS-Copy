import Foundation

struct Student: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var email: String
    var grade: String
    var phone: String
    var attendanceRate: Int
    var score: Int
    var paid: Bool
}
