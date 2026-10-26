import Foundation

enum AppRoute: Equatable {
    case welcome, tutorAuth, studentAuth, tutorOnboarding, studentOnboarding, tutor, student
}
enum UserRole: String, CaseIterable, Identifiable {
    case tutor = "Tutor"
    case student = "Student"
    var id: String { rawValue }
}
enum TutorSection: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard", classes = "Classes", students = "Students"
    case attendance = "Attendance", payments = "Payments", finance = "Finance", settings = "Settings"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .dashboard: "house.fill"
        case .classes: "calendar"
        case .students: "person.2.fill"
        case .attendance: "checkmark.circle.fill"
        case .payments: "creditcard.fill"
        case .finance: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}
enum StudentSection: String, CaseIterable, Identifiable {
    case home = "Home", classes = "Classes", progress = "Progress", profile = "Profile"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .home: "house.fill"
        case .classes: "calendar"
        case .progress: "chart.line.uptrend.xyaxis"
        case .profile: "person.crop.circle.fill"
        }
    }
}
