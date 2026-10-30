import SwiftUI
import WidgetKit

@MainActor
final class AppController: ObservableObject {

    // MARK: - Navigation and Profile

    @Published var route: AppRoute = .welcome
    @Published var displayName = "TutorMate User"
    @Published var email = ""
    @Published private(set) var activeRole: UserRole?
    @Published var notificationsEnabled = UserDefaults.standard.bool(forKey: "tutormate.classReminders.enabled")
    @Published var faceIDEnabled = UserDefaults.standard.bool(forKey: "tutormate.faceID.enabled")
    @Published private(set) var isSendingPasswordReset = false
    @Published var toastMessage: String?

    // MARK: - Students

    @Published var students: [Student] = []

    @Published private(set) var isLoadingStudents = false
    private var persistedStudentIDs = Set<UUID>()
    private var studentLoadTask: Task<Void, Never>?

    @Published private(set) var isLoadingClasses = false
    private var classLoadTask: Task<Void, Never>?
    private var persistedClassIDs = Set<UUID>()

    @Published private(set) var isLoadingAttendance = false
    private var attendanceLoadTask: Task<Void, Never>?

    @Published private(set) var isLoadingPayments = false
    @Published private(set) var updatingPaymentIDs = Set<UUID>()
    private var paymentLoadTask: Task<Void, Never>?
    private var persistedPaymentIDs = Set<UUID>()

    // MARK: - Classes (currently local)

    @Published var sessions: [ClassSession] = [] {
        didSet { syncWidgetData() }
    }

    // MARK: - Attendance (currently local)

    @Published var attendance: [AttendanceRecord] = []

    // MARK: - Payments (currently local)

    @Published var payments: [Payment] = []

    // MARK: - Assessments and Gamification (currently local)

    @Published var assessments: [Assessment] = []

    @Published var studentPoints = 0
    @Published var nfcCheckedIn = false

    init() {
        syncWidgetData()
    }

    // MARK: - Widget

    private func syncWidgetData() {
        guard route == .tutor else {
            WidgetSharedStore.clear()
            return
        }
        let upcoming = sessions
            .filter { $0.scheduledDateTime >= .now }
            .sorted { $0.scheduledDateTime < $1.scheduledDateTime }
            .first

        WidgetSharedStore.save(WidgetPayload(role: "tutor", classTitle: upcoming?.title,
            subject: upcoming?.subject, classDate: upcoming?.scheduledDateTime, classTime: upcoming?.time,
            location: upcoming?.location, tutorName: displayName,
            attendanceStreak: WidgetPayload.streak(from: attendance.map { (date: $0.date, attended: $0.status == .present || $0.status == .late) })))
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
        activeRole = role
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = name
        }
        if !email.isEmpty {
            self.email = email
        }

        route = role == .tutor ? .tutor : .student
        syncWidgetData()

        if role == .tutor && FirebaseService.shared.isConfigured {
            studentLoadTask?.cancel()
            classLoadTask?.cancel()
            attendanceLoadTask?.cancel()
            paymentLoadTask?.cancel()

            // Don't show demo records while the tutor's saved data loads.
            students = []
            sessions = []
            attendance = []
            payments = []
            persistedStudentIDs.removeAll()
            persistedClassIDs.removeAll()
            persistedPaymentIDs.removeAll()
            updatingPaymentIDs.removeAll()

            studentLoadTask = Task { @MainActor in
                await loadTutorStudents()
            }

            classLoadTask = Task { @MainActor in
                await loadTutorClasses()
            }

            attendanceLoadTask = Task { @MainActor in
                await loadTutorAttendance()
            }

            paymentLoadTask = Task { @MainActor in
                await loadTutorPayments()
            }
        } else {
            studentLoadTask?.cancel()
            classLoadTask?.cancel()
            attendanceLoadTask?.cancel()
            paymentLoadTask?.cancel()
            students = []
            sessions = []
            attendance = []
            payments = []
            assessments = []
            studentPoints = 0
            persistedStudentIDs.removeAll()
            persistedClassIDs.removeAll()
            persistedPaymentIDs.removeAll()
            updatingPaymentIDs.removeAll()
        }
    }

    func register(role: UserRole, name: String, email: String) {
        signIn(name: name, email: email, role: role)
    }

    func restoreAuthentication() async {
        guard route == .welcome, FirebaseService.shared.isConfigured else { return }
        if faceIDEnabled, FirebaseService.shared.currentUserEmail != nil {
            do {
                guard let profile = try await FirebaseService.shared.restoredProfile() else { return }
                // Route to the credential screen with the saved Firebase session.
                // Face ID is invoked only when the user taps its button there.
                activeRole = profile.role
                displayName = profile.name
                email = profile.email
                route = profile.role == .tutor ? .tutorAuth : .studentAuth
            } catch {
                showToast("Could not restore your account: \(error.localizedDescription)")
            }
            return
        }
        do {
            guard let profile = try await FirebaseService.shared.restoredProfile() else { return }
            signIn(name: profile.name, email: profile.email, role: profile.role)
        } catch {
            showToast("Saved session could not be restored: \(error.localizedDescription)")
        }
    }

    /// Locks the app UI while preserving Firebase's local session so Face ID
    /// can unlock that account on the next sign-in screen.
    func lockWithFaceID() {
        guard faceIDEnabled,
              FirebaseService.shared.currentUserEmail != nil,
              let activeRole else {
            showToast("Enable Face ID and keep your account signed in before using Lock with Face ID.")
            return
        }

        studentLoadTask?.cancel()
        classLoadTask?.cancel()
        attendanceLoadTask?.cancel()
        paymentLoadTask?.cancel()
        students = []
        sessions = []
        attendance = []
        payments = []
        assessments = []
        studentPoints = 0
        persistedStudentIDs.removeAll()
        persistedClassIDs.removeAll()
        persistedPaymentIDs.removeAll()
        updatingPaymentIDs.removeAll()
        route = activeRole == .tutor ? .tutorAuth : .studentAuth
    }

    func signOut() {
        studentLoadTask?.cancel()
        studentLoadTask = nil
        classLoadTask?.cancel()
        classLoadTask = nil
        attendanceLoadTask?.cancel()
        attendanceLoadTask = nil
        paymentLoadTask?.cancel()
        paymentLoadTask = nil

        do {
            if FirebaseService.shared.isConfigured {
                try FirebaseService.shared.signOut()
            }
        } catch {
            showToast("Sign-out error: \(error.localizedDescription)")
        }

        activeRole = nil
        isLoadingStudents = false
        isLoadingClasses = false
        isLoadingAttendance = false
        isLoadingPayments = false
        persistedStudentIDs.removeAll()
        persistedClassIDs.removeAll()
        persistedPaymentIDs.removeAll()
        updatingPaymentIDs.removeAll()
        students = []
        sessions = []
        attendance = []
        payments = []
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

    // MARK: - Load Classes from Firestore

    func loadTutorClasses() async {
        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured.")
            return
        }

        isLoadingClasses = true
        defer { isLoadingClasses = false }

        do {
            let savedClasses = try await FirebaseService.shared.fetchClasses()

            // Do not update the tutor workspace if the user signed out meanwhile.
            guard route == .tutor else { return }

            sessions = savedClasses.sorted { $0.date < $1.date }
            persistedClassIDs = Set(savedClasses.map(\.id))
            if notificationsEnabled { await refreshClassReminders() }

            showToast(
                savedClasses.isEmpty
                    ? "No saved classes yet. Add your first class."
                    : "Loaded \(savedClasses.count) saved class(es)."
            )
        } catch {
            guard route == .tutor else { return }

            // Do not show the sample schedule as if it came from the database.
            sessions = []
            showToast("Could not load classes: \(error.localizedDescription)")
        }
    }

    // MARK: - Toasts

    func showToast(_ message: String) {
        toastMessage = message
    }

    func setFaceIDEnabled(_ enabled: Bool) {
        faceIDEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "tutormate.faceID.enabled")
    }

    func updateStudentProfileName(_ proposedName: String) async -> Bool {
        guard route == .student else { return false }
        let cleanName = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            showToast("Name cannot be empty.")
            return false
        }
        do {
            try await FirebaseService.shared.updateStudentProfileName(cleanName)
            displayName = cleanName
            showToast("Profile name updated.")
            return true
        } catch {
            showToast("Could not update your profile: \(error.localizedDescription)")
            return false
        }
    }

    func sendPasswordResetEmail() async {
        guard let email = FirebaseService.shared.currentUserEmail else {
            showToast("Enter your account email on the sign-in screen to reset your password.")
            return
        }
        await sendPasswordResetEmail(to: email)
    }

    func sendPasswordResetEmail(to email: String) async {
        guard !isSendingPasswordReset else { return }
        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        do {
            try await FirebaseService.shared.sendPasswordResetEmail(to: email)
            showToast("Password reset email sent. Follow the link in your inbox to choose a new password.")
        } catch {
            showToast("Could not send the password reset email: \(error.localizedDescription)")
        }
    }

    // MARK: - Attendance (Firestore)

    func loadTutorAttendance() async {
        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured.")
            return
        }

        isLoadingAttendance = true
        defer { isLoadingAttendance = false }

        do {
            let savedRecords = try await FirebaseService.shared.fetchAttendanceRecords()
            guard route == .tutor else { return }
            attendance = savedRecords
        } catch {
            guard route == .tutor else { return }
            attendance = []
            showToast("Could not load attendance: \(error.localizedDescription)")
        }
    }

    func markAttendance(
        student: Student,
        status: AttendanceStatus,
        session: ClassSession? = nil
    ) {
        let selectedSession = session
        let className = selectedSession?.title ?? ""

        let record: AttendanceRecord
        if let index = attendance.firstIndex(where: {
            (($0.studentID == student.id) || ($0.studentID == nil && $0.studentName == student.name)) &&
            (($0.classID == selectedSession?.id) || ($0.classID == nil && $0.className == className)) &&
            Calendar.current.isDateInToday($0.date)
        }) {
            attendance[index].status = status
            record = attendance[index]
        } else {
            let newRecord = AttendanceRecord(
                studentID: student.id,
                classID: selectedSession?.id,
                studentName: student.name,
                className: className,
                date: .now,
                status: status
            )
            attendance.append(newRecord)
            record = newRecord
        }

        guard FirebaseService.shared.isConfigured else {
            showToast("Attendance marked on this device only. Firebase is not configured.")
            return
        }

        guard persistedStudentIDs.contains(student.id) else {
            showToast("Attendance is shown locally, but this student is not saved in Firestore yet.")
            return
        }

        guard let selectedSession,
              persistedClassIDs.contains(selectedSession.id) else {
            showToast("Attendance is shown locally, but this class is not saved in Firestore yet.")
            return
        }

        Task { @MainActor in
            do {
                try await FirebaseService.shared.saveAttendanceRecord(
                    record,
                    student: student,
                    session: selectedSession
                )

                guard route == .tutor else { return }
                showToast("Attendance saved successfully.")
            } catch {
                guard route == .tutor else { return }
                showToast("Attendance could not be saved: \(error.localizedDescription)")
            }
        }
    }

    func recordNFCAttendance(student: Student, session: ClassSession) async throws {
        guard route == .tutor, persistedStudentIDs.contains(student.id), persistedClassIDs.contains(session.id) else {
            throw FirebaseSetupError.notTutor
        }
        let existing = attendance.first {
            (($0.studentID == student.id) || ($0.studentID == nil && $0.studentName == student.name)) &&
            (($0.classID == session.id) || ($0.classID == nil && $0.className == session.title)) &&
            Calendar.current.isDateInToday($0.date)
        }
        let record = AttendanceRecord(id: existing?.id ?? UUID(), studentID: student.id, classID: session.id,
            studentName: student.name, className: session.title, date: existing?.date ?? .now, status: .present)
        try await FirebaseService.shared.saveAttendanceRecord(record, student: student, session: session)
        if let index = attendance.firstIndex(where: { $0.studentName == student.name && $0.className == session.title && Calendar.current.isDateInToday($0.date) }) { attendance[index].status = .present }
        else { attendance.append(record) }
        showToast("NFC attendance saved.")
    }

    // MARK: - Add Class (Firestore)

    @discardableResult
    func addClass(
        title: String,
        subject: String,
        date: Date,
        time: String,
        location: String
    ) async -> Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTime = time.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanTitle.isEmpty else {
            showToast("Enter a class title.")
            return false
        }

        guard !cleanSubject.isEmpty, !cleanTime.isEmpty, !cleanLocation.isEmpty else {
            showToast("Complete the class details before saving.")
            return false
        }

        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured. The class was not saved.")
            return false
        }

        let newSession = ClassSession(
            title: cleanTitle,
            subject: cleanSubject,
            date: date,
            time: cleanTime,
            duration: "60 min",
            location: cleanLocation,
            students: 0
        )

        do {
            try await FirebaseService.shared.saveClass(newSession)

            guard route == .tutor else { return false }

            sessions.append(newSession)
            persistedClassIDs.insert(newSession.id)
            if notificationsEnabled { await scheduleClassReminder(newSession) }
            showToast("Class saved successfully.")
            return true
        } catch {
            showToast("Could not save class: \(error.localizedDescription)")
            return false
        }
    }

    func updateClass(_ session: ClassSession) async -> Bool {
        do {
            try await FirebaseService.shared.updateClass(session)
            if let index = sessions.firstIndex(where: { $0.id == session.id }) { sessions[index] = session }
            NotificationService.shared.cancelReminder(for: session.id)
            if notificationsEnabled { await scheduleClassReminder(session) }
            showToast("Class updated successfully."); return true
        } catch { showToast("Could not update class: \(error.localizedDescription)"); return false }
    }

    func deleteClass(_ session: ClassSession) async -> Bool {
        do {
            try await FirebaseService.shared.deleteClass(session)
            sessions.removeAll { $0.id == session.id }; persistedClassIDs.remove(session.id)
            NotificationService.shared.cancelReminder(for: session.id)
            showToast("Class deleted."); return true
        } catch { showToast("Could not delete class: \(error.localizedDescription)"); return false }
    }

    func setClassRemindersEnabled(_ enabled: Bool) async {
        if enabled {
            guard await NotificationService.shared.requestPermission() else { notificationsEnabled = false; showToast("Notification permission was not granted."); return }
            notificationsEnabled = true
            UserDefaults.standard.set(true, forKey: "tutormate.classReminders.enabled")
            await refreshClassReminders()
        } else {
            notificationsEnabled = false
            UserDefaults.standard.set(false, forKey: "tutormate.classReminders.enabled")
            await NotificationService.shared.cancelAllClassReminders()
        }
    }

    private func refreshClassReminders() async {
        await NotificationService.shared.cancelAllClassReminders()
        for session in sessions { await scheduleClassReminder(session) }
    }

    private func scheduleClassReminder(_ session: ClassSession) async {
        do { try await NotificationService.shared.scheduleReminder(for: session) }
        catch { showToast("Reminder not scheduled: \(error.localizedDescription)") }
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
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            showToast("Enter a valid student email address.")
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

    func updateStudent(_ student: Student) async -> Bool {
        guard !student.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              student.email.contains("@"), !student.grade.isEmpty else {
            showToast("Enter a name, valid email and grade."); return false
        }
        do {
            try await FirebaseService.shared.updateStudent(student)
            if let i = students.firstIndex(where: { $0.id == student.id }) { students[i] = student }
            showToast("Student updated."); return true
        } catch { showToast("Could not update student: \(error.localizedDescription)"); return false }
    }

    func deleteStudent(_ student: Student) async -> Bool {
        do {
            try await FirebaseService.shared.deleteStudent(student)
            students.removeAll { $0.id == student.id }
            persistedStudentIDs.remove(student.id)
            showToast("Student deleted."); return true
        } catch { showToast("Could not delete student: \(error.localizedDescription)"); return false }
    }

    // MARK: - Load Payments from Firestore

    func loadTutorPayments() async {
        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured.")
            return
        }

        isLoadingPayments = true
        defer { isLoadingPayments = false }

        do {
            let savedPayments = try await FirebaseService.shared.fetchPayments()
            guard route == .tutor else { return }

            payments = savedPayments
            persistedPaymentIDs = Set(savedPayments.map(\.id))

            showToast(
                savedPayments.isEmpty
                    ? "No saved payments yet. Add your first payment."
                    : "Loaded \(savedPayments.count) saved payment(s)."
            )
        } catch {
            guard route == .tutor else { return }

            payments = []
            persistedPaymentIDs.removeAll()
            showToast(firestorePermissionMessage(from: error, fallback: "Could not load payments"))
        }
    }

    // MARK: - Add Payment (Firestore)

    @discardableResult
    func addPayment(name: String, amount: Double, description: String) async -> Bool {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleanName.isEmpty else {
            showToast("Enter the student's name.")
            return false
        }
        guard amount > 0 else {
            showToast("Enter a valid payment amount.")
            return false
        }
        guard !cleanDescription.isEmpty else {
            showToast("Enter a payment description.")
            return false
        }

        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured. The payment was not saved.")
            return false
        }

        let newPayment = Payment(
            studentName: cleanName,
            description: cleanDescription,
            amount: amount,
            date: .now,
            isPaid: false
        )

        do {
            try await FirebaseService.shared.savePayment(newPayment)
            guard route == .tutor else { return false }

            payments.insert(newPayment, at: 0)
            persistedPaymentIDs.insert(newPayment.id)
            showToast("Payment saved successfully.")
            return true
        } catch {
            showToast(firestorePermissionMessage(from: error, fallback: "Could not save payment"))
            return false
        }
    }

    // MARK: - Mark Payment as Paid

    func markPaid(_ payment: Payment) {
        guard payments.contains(where: { $0.id == payment.id }) else {
            return
        }
        guard !payment.isPaid else {
            return
        }
        guard !updatingPaymentIDs.contains(payment.id) else {
            return
        }

        guard FirebaseService.shared.isConfigured else {
            showToast("Firebase is not configured. The payment was not updated.")
            return
        }

        guard persistedPaymentIDs.contains(payment.id) else {
            showToast("This payment is not saved in Firestore yet. Reload payments and try again.")
            return
        }

        updatingPaymentIDs.insert(payment.id)

        Task { @MainActor in
            defer { updatingPaymentIDs.remove(payment.id) }

            do {
                var updatedPayment = payment
                updatedPayment.isPaid = true
                try await FirebaseService.shared.updatePayment(updatedPayment)
                guard route == .tutor else { return }

                guard let paymentIndex = payments.firstIndex(where: { $0.id == payment.id }) else {
                    return
                }
                payments[paymentIndex].isPaid = true

                showToast("Payment marked as paid.")
            } catch {
                guard route == .tutor else { return }
                showToast(firestorePermissionMessage(from: error, fallback: "Could not mark payment as paid"))
            }
        }
    }

    func updatePayment(_ payment: Payment) async -> Bool {
        guard !payment.studentName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !payment.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              payment.amount.isFinite, payment.amount > 0 else { showToast("Enter a student, description and valid amount."); return false }
        do {
            try await FirebaseService.shared.updatePayment(payment)
            if let i = payments.firstIndex(where: { $0.id == payment.id }) { payments[i] = payment }
            showToast("Payment updated."); return true
        } catch { showToast(firestorePermissionMessage(from: error, fallback: "Could not update payment")); return false }
    }

    private func firestorePermissionMessage(from error: Error, fallback: String) -> String {
        let text = error.localizedDescription.lowercased()
        if text.contains("permission") || text.contains("insufficient") {
            return "\(fallback): Firestore rules are blocking payments. In Firebase Console, open Firestore → Rules, paste FIRESTORE_RULES.txt from this project, click Publish, then try again."
        }
        return "\(fallback): \(error.localizedDescription)"
    }
}

