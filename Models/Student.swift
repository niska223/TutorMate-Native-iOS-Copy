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

    var validationError: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Name is required." }
        let address = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = address.split(separator: "@")
        if components.count != 2 || !components[1].contains(".") { return "A valid email is required." }
        if grade.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Grade is required." }
        return nil
    }
}
