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
}

