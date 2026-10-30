import Foundation

struct Payment: Identifiable, Codable {
    var id = UUID()
    var studentName: String
    var description: String
    var amount: Double
    var date: Date
    var isPaid: Bool

    var validationError: String? {
        if studentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Student is required." }
        if description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Description is required." }
        if !amount.isFinite || amount <= 0 { return "Amount must be greater than zero." }
        return nil
    }
}
