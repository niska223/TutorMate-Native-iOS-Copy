import Foundation

@MainActor
final class ClassController {
    func create(title: String, subject: String, date: Date, time: String, location: String, in app: AppController) {
        app.addClass(title: title, subject: subject, date: date, time: time, location: location)
    }
}
