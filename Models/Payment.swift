import Foundation

struct Payment: Identifiable, Codable {
    var id = UUID()
    var studentName: String
    var description: String
    var amount: Double
    var date: Date
    var isPaid: Bool
}
