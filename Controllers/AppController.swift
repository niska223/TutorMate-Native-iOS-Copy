import SwiftUI
import WidgetKit

@MainActor
final class AppController: ObservableObject {
    @Published var route: AppRoute = .welcome
    @Published var displayName = "Niska Wijesinghe"
    @Published var email = "niska@example.com"
    @Published var notificationsEnabled = true
    @Published var faceIDEnabled = true
    @Published var paymentAlertsEnabled = true
    @Published var toastMessage: String?

    @Published var students: [Student] = [
        Student(name: "Maya Silva", email: "maya@example.com", grade: "Grade 11", phone: "077 123 4567", attendanceRate: 94, score: 86, paid: true),
        Student(name: "Nethmi Fernando", email: "nethmi@example.com", grade: "Grade 10", phone: "071 234 5678", attendanceRate: 88, score: 92, paid: true),
        Student(name: "Aiden Perera", email: "aiden@example.com", grade: "Grade 11", phone: "076 345 6789", attendanceRate: 80, score: 78, paid: false),
        Student(name: "Savin Jay", email: "savin@example.com", grade: "Grade 9", phone: "075 456 7890", attendanceRate: 96, score: 90, paid: true),
        Student(name: "Rashmi de Silva", email: "rashmi@example.com", grade: "Grade 10", phone: "072 567 8901", attendanceRate: 91, score: 84, paid: false)
    ]
    @Published var sessions: [ClassSession] = [
        ClassSession(title: "Grade 11 Mathematics", subject: "Mathematics", date: Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now, time: "10:30 AM", duration: "60 min", location: "Room 02", students: 5),
        ClassSession(title: "ICT Group B", subject: "ICT", date: Calendar.current.date(byAdding: .hour, value: 7, to: .now) ?? .now, time: "5:30 PM", duration: "90 min", location: "Online", students: 8),
        ClassSession(title: "Physics Revision", subject: "Physics", date: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now, time: "3:00 PM", duration: "60 min", location: "Room 01", students: 6),
        ClassSession(title: "Algebra Practice", subject: "Mathematics", date: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now, time: "4:00 PM", duration: "60 min", location: "Online", students: 5)
    ] { didSet { syncWidgetData() } }
    @Published var attendance: [AttendanceRecord] = [
        AttendanceRecord(studentName: "Maya Silva", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Nethmi Fernando", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Aiden Perera", className: "Grade 11 Mathematics", date: .now, status: .absent),
        AttendanceRecord(studentName: "Savin Jay", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Rashmi de Silva", className: "Grade 11 Mathematics", date: .now, status: .present)
    ]
    @Published var payments: [Payment] = [
        Payment(studentName: "Maya Silva", description: "June fee", amount: 120, date: .now, isPaid: true),
        Payment(studentName: "Nethmi Fernando", description: "June fee", amount: 120, date: .now, isPaid: true),
        Payment(studentName: "Aiden Perera", description: "June fee", amount: 160, date: .now, isPaid: false)
    ]
    @Published var assessments: [Assessment] = [
        Assessment(title: "Algebra Quiz", subject: "Mathematics", dateLabel: "Jun 12", score: 86),
        Assessment(title: "Database Basics", subject: "ICT", dateLabel: "Jun 6", score: 92),
        Assessment(title: "Mechanics Test", subject: "Physics", dateLabel: "May 28", score: 81)
    ]
    @Published var studentPoints = 340
    @Published var nfcCheckedIn = false

    init() { syncWidgetData() }

    /// Publishes the next scheduled class to the WidgetKit extension through the shared App Group.
    private func syncWidgetData() {
        let upcoming = sessions.filter { $0.date >= .now }.sorted { $0.date < $1.date }.first
        let payload: [String: String] = [
            "classTitle": upcoming?.title ?? "No upcoming class",
            "classTime": upcoming.map { "\($0.time) · \($0.location)" } ?? "Open TutorMate to schedule a class",
            "tutorName": displayName,
            // Demo value matching the Student dashboard. Connect this to real attendance history when available.
            "attendanceStreak": "5 classes",
            "updatedAt": ISO8601DateFormatter().string(from: .now)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let defaults = UserDefaults(suiteName: "group.com.example.tutormate") {
            defaults.set(data, forKey: "tutormate.widget.nextClass")
            WidgetCenter.shared.reloadTimelines(ofKind: "TutorMateWidget")
        }
    }

    var collectedIncome: Double { payments.filter(\.isPaid).reduce(0) { $0 + $1.amount } }
    var outstandingIncome: Double { payments.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount } }

    func signIn(name: String, email: String, role: UserRole) {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { displayName = name }
        if !email.isEmpty { self.email = email }
        route = role == .tutor ? .tutor : .student
    }
    func register(role: UserRole, name: String, email: String) {
        signIn(name: name, email: email, role: role)
    }
    func signOut() { route = .welcome }
    func showToast(_ message: String) {
        toastMessage = message
    }
    func markAttendance(student: Student, status: AttendanceStatus, session: ClassSession? = nil) {
        let className = session?.title ?? "Grade 11 Mathematics"
        if let i = attendance.firstIndex(where: { $0.studentName == student.name && $0.className == className && Calendar.current.isDateInToday($0.date) }) {
            attendance[i].status = status
        } else {
            attendance.append(AttendanceRecord(studentName: student.name, className: className, date: .now, status: status))
        }
        showToast("\(student.name): \(status.rawValue)")
    }
    func addClass(title: String, subject: String, date: Date, time: String, location: String) {
        sessions.append(ClassSession(title: title, subject: subject, date: date, time: time, duration: "60 min", location: location, students: 0))
        showToast("Class added successfully")
    }
    func addStudent(name: String, email: String, grade: String) {
        students.append(Student(name: name, email: email, grade: grade, phone: "Not provided", attendanceRate: 100, score: 0, paid: false))
        showToast("Student added successfully")
    }
    func addPayment(name: String, amount: Double, description: String) {
        payments.append(Payment(studentName: name, description: description, amount: amount, date: .now, isPaid: false))
        showToast("Payment record added")
    }
    func markPaid(_ payment: Payment) {
        guard let i = payments.firstIndex(where: { $0.id == payment.id }) else { return }
        payments[i].isPaid = true
        if let j = students.firstIndex(where: { $0.name == payment.studentName }) { students[j].paid = true }
        showToast("Payment marked as paid")
    }
}
