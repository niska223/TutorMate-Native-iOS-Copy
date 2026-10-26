import Foundation

struct Assessment: Identifiable, Hashable {
    var id = UUID()
    var title: String
    var subject: String
    var dateLabel: String
    var score: Int
}
