import SwiftUI
import WidgetKit

@MainActor
final class AppController: ObservableObject {

    // MARK: - Navigation and Profile

    @Published var route: AppRoute = .welcome
    @Published var displayName = "Niska Wijesinghe"
    @Published var email = "niska@example.com"
    @Published var notificationsEnabled = true
    @Published var faceIDEnabled = true
    @Published var paymentAlertsEnabled = true
    @Published var toastMessage: String?

    // MARK: - Students

    @Published var students: [Student] = [
        Student(name: "Maya Silva", email: "maya@example.com", grade: "Grade 11", phone: "077 123 4567", attendanceRate: 94, score: 86, paid: true),
        Student(name: "Nethmi Fernando", email: "nethmi@example.com", grade: "Grade 10", phone: "071 234 5678", attendanceRate: 88, score: 92, paid: true),
        Student(name: "Aiden Perera", email: "aiden@example.com", grade: "Grade 11", phone: "076 345 6789", attendanceRate: 80, score: 78, paid: false),
        Student(name: "Savin Jay", email: "savin@example.com", grade: "Grade 9", phone: "075 456 7890", attendanceRate: 96, score: 90, paid: true),
        Student(name: "Rashmi de Silva", email: "rashmi@example.com", grade: "Grade 10", phone: "072 567 8901", attendanceRate: 91, score: 84, paid: false)
    ]

    @Published private(set) var isLoadingStudents = false
    private var persistedStudentIDs = Set<UUID>()
    private var studentLoadTask: Task<Void, Never>?

    // MARK: - Classes (currently local)

    @Published var sessions: [ClassSession] = [
        ClassSession(title: "Grade 11 Mathematics", subject: "Mathematics", date: Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now, time: "10:30 AM", duration: "60 min", location: "Room 02", students: 5),
        ClassSession(title: "ICT Group B", subject: "ICT", date: Calendar.current.date(byAdding: .hour, value: 7, to: .now) ?? .now, time: "5:30 PM", duration: "90 min", location: "Online", students: 8),
        ClassSession(title: "Physics Revision", subject: "Physics", date: Calendar.current.date(byAdding: .day, value: 2, to: .now) ?? .now, time: "3:00 PM", duration: "60 min", location: "Room 01", students: 6),
        ClassSession(title: "Algebra Practice", subject: "Mathematics", date: Calendar.current.date(byAdding: .day, value: 3, to: .now) ?? .now, time: "4:00 PM", duration: "60 min", location: "Online", students: 5)
    ] {
        didSet { syncWidgetData() }
    }

    // MARK: - Attendance (currently local)

    @Published var attendance: [AttendanceRecord] = [
        AttendanceRecord(studentName: "Maya Silva", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Nethmi Fernando", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Aiden Perera", className: "Grade 11 Mathematics", date: .now, status: .absent),
        AttendanceRecord(studentName: "Savin Jay", className: "Grade 11 Mathematics", date: .now, status: .present),
        AttendanceRecord(studentName: "Rashmi de Silva", className: "Grade 11 Mathematics", date: .now, status: .present)
    ]

    // MARK: - Payments (currently local)

    @Published var payments: [Payment] = [
        Payment(studentName: "Maya Silva", description: "June fee", amount: 120, date: .now, isPaid: true),
        Payment(studentName: "Nethmi Fernando", description: "June fee", amount: 120, date: .now, isPaid: true),
        Payment(studentName: "Aiden Perera", description: "June fee", amount: 160, date: .now, isPaid: false)
    ]

    // MARK: - Assessments and Gamification (currently local)

    @Published var assessments: [Assessment] = [
        Assessment(title: "Algebra Quiz", subject: "Mathematics", dateLabel: "Jun 12", score: 86),
        Assessment(title: "Database Basics", subject: "ICT", dateLabel: "Jun 6", score: 92),
        Assessment(title: "Mechanics Test", subject: "Physics", dateLabel: "May 28", score: 81)
    ]

    @Published var studentPoints = 340
    @Published var nfcCheckedIn = false

    init() {
        syncWidgetData()
    }

    // MARK: - Widget

    private func syncWidgetData() {
        let upcoming = sessions
            .filter { $0.date >= .now }
            .sorted { $0.date < $1.date }
            .first

        let payload: [String: String] = [
            "classTitle": upcoming?.title ?? "No upcoming class",
            "classTime": upcoming.map { "\($0.time) · \($0.location)" } ?? "Open TutorMate to schedule a class",
            "tutorName": displayName,
            "attendanceStreak": "5 classes",
            "updatedAt": ISO8601DateFormatter().string(from: .now)
        ]

        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let defaults = UserDefaults(suiteName: "group.com.example.tutormate") {
            defaults.set(data, forKey: "tutormate.widget.nextClass")
            WidgetCenter.shared.reloadTimelines(ofKind: "TutorMateWidget")
        }
    }

    // MARK: - Finance Calculations

    var collectedIncome: Double {
        payments.filter(\.isPaid).reduce(0) { $0 + $1.amount }
    }

    var outstandingIncome: Double {
        payments.filter { !$0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    // MARK: - Sign In and Sign Out

    func signIn(name: String, email: String, role: UserRole) {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = name
        }
        if !email.isEmpty {
            self.email = email
        }

        syncWidgetData()
        route = role == .tutor ? .tutor : .student

        if role == .tutor && FirebaseService.shared.isConfigured {
            studentLoadTask?.cancel()
            studentLoadTask = Task { @MainActor in
                await loadTutorStudents()
            }
        }
    }

    func register(role: UserRole, name: String, email: String) {
        signIn(name: name, email: email, role: role)
    }

    func signOut() {
        studentLoadTask?.cancel()
        studentLoadTask = nil

        do {
            if FirebaseService.shared.isConfigured {
                try FirebaseService.shared.signOut()
            }
        } catch {
            showToast("Sign-out error: \(error.localizedDescription)")
        }

        isLoadingStudents = false
        persistedStudentIDs.removeAll()
        route = .welcome
    }

    // MARK: - Load Students from Firestore

    func loadTutorStudents() async {
        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured.")
            return
        }

        isLoadingStudents = true
        defer { isLoadingStudents = false }

        do {
            let savedStudents = try await FirebaseService.shared.fetchStudents()

            guard route == .tutor else { return }

            students = savedStudents
            persistedStudentIDs = Set(savedStudents.map(\.id))

            showToast(
                savedStudents.isEmpty
                    ? "No saved students yet. Add your first student."
                    : "Loaded \(savedStudents.count) saved student(s)."
            )
        } catch {
            guard route == .tutor else { return }

            students = []
            persistedStudentIDs.removeAll()
            showToast("Could not load students: \(error.localizedDescription)")
        }
    }

    // MARK: - Toasts

    func showToast(_ message: String) {
        toastMessage = message
    }

    // MARK: - Attendance (currently local)

    func markAttendance(student: Student, status: AttendanceStatus, session: ClassSession? = nil) {
        let className = session?.title ?? "Grade 11 Mathematics"

        if let index = attendance.firstIndex(where: {
            $0.studentName == student.name &&
            $0.className == className &&
            Calendar.current.isDateInToday($0.date)
        }) {
            attendance[index].status = status
        } else {
            attendance.append(
                AttendanceRecord(
                    studentName: student.name,
                    className: className,
                    date: .now,
                    status: status
                )
            )
        }

        showToast("\(student.name): \(status.rawValue)")
    }

    // MARK: - Add Class (currently local)

    func addClass(title: String, subject: String, date: Date, time: String, location: String) {
        sessions.append(
            ClassSession(
                title: title,
                subject: subject,
                date: date,
                time: time,
                duration: "60 min",
                location: location,
                students: 0
            )
        )
        showToast("Class added locally. Cloud saving is not connected yet.")
    }

    // MARK: - Add Student (Firestore)

    func addStudent(name: String, email: String, grade: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanGrade = grade.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            showToast("Enter the student's name.")
            return
        }
        guard !cleanEmail.isEmpty else {
            showToast("Enter the student's email.")
            return
        }
        guard !cleanGrade.isEmpty else {
            showToast("Enter the student's grade.")
            return
        }

        let newStudent = Student(
            name: cleanName,
            email: cleanEmail,
            grade: cleanGrade,
            phone: "Not provided",
            attendanceRate: 100,
            score: 0,
            paid: false
        )

        guard FirebaseService.shared.isConfigured else {
            students.append(newStudent)
            showToast("Student added locally only. Firebase is not configured.")
            return
        }

        Task { @MainActor in
            do {
                try await FirebaseService.shared.saveStudent(newStudent)
                guard route == .tutor else { return }

                if !students.contains(where: { $0.id == newStudent.id }) {
                    students.append(newStudent)
                }
                persistedStudentIDs.insert(newStudent.id)
                showToast("Student saved successfully.")
            } catch {
                showToast("Could not save student: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Add Payment (currently local)

    func addPayment(name: String, amount: Double, description: String) {
        payments.append(
            Payment(
                studentName: name,
                description: description,
                amount: amount,
                date: .now,
                isPaid: false
            )
        )
        showToast("Payment added locally. Cloud saving is not connected yet.")
    }

    // MARK: - Mark Payment as Paid

    func markPaid(_ payment: Payment) {
        guard let paymentIndex = payments.firstIndex(where: { $0.id == payment.id }) else {
            return
        }

        payments[paymentIndex].isPaid = true

        if let studentIndex = students.firstIndex(where: { $0.name == payment.studentName }) {
            students[studentIndex].paid = true
            let updatedStudent = students[studentIndex]

            if persistedStudentIDs.contains(updatedStudent.id) {
                Task { @MainActor in
                    do {
                        try await FirebaseService.shared.updateStudent(updatedStudent)
                        showToast("Student payment status saved.")
                    } catch {
                        showToast(
                            "Student payment status changed locally but could not be saved: \(error.localizedDescription)"
                        )
                    }
                }
            }
        }

        showToast("Payment marked as paid.")
    }
}

