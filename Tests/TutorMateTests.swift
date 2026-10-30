import XCTest
@testable import TutorMate

final class TutorMateTests: XCTestCase {
    @MainActor
    func testSignInRoutesToTutorHome() {
        let app = AppController()
        app.signIn(name: "Test Tutor", email: "tutor@example.com", role: .tutor)
        XCTAssertEqual(app.route, .tutor)
        XCTAssertEqual(app.displayName, "Test Tutor")
    }

    @MainActor
    func testFinanceTotalsUseActualPaymentRecords() {
        let app = AppController()
        app.payments = [
            Payment(studentName: "A", description: "Term 1", amount: 50, date: .now, isPaid: true),
            Payment(studentName: "B", description: "Term 1", amount: 25, date: .now, isPaid: false)
        ]
        XCTAssertEqual(app.collectedIncome, 50)
        XCTAssertEqual(app.outstandingIncome, 25)
        XCTAssertEqual(app.collectedIncome + app.outstandingIncome, 75)
    }

    func testStudentValidationRejectsMissingOrMalformedFields() {
        let invalid = Student(name: "  ", email: "bad", grade: "", phone: "", attendanceRate: 0, score: 0, paid: false)
        XCTAssertNotNil(invalid.validationError)
        let valid = Student(name: "A Student", email: "a@example.com", grade: "Grade 10", phone: "", attendanceRate: 0, score: 0, paid: false)
        XCTAssertNil(valid.validationError)
    }

    func testClassValidationRequiresScheduleDetails() {
        let invalid = ClassSession(title: "Math", subject: "", date: .now, time: "", duration: "60 min", location: "", students: 0)
        XCTAssertNotNil(invalid.validationError)
        let valid = ClassSession(title: "Math", subject: "Mathematics", date: .now, time: "4:00 PM", duration: "60 min", location: "Room 1", students: 0)
        XCTAssertNil(valid.validationError)
    }

    func testPaymentValidationRejectsNonPositiveAndNonFiniteAmounts() {
        let base = Payment(studentName: "Student", description: "Fee", amount: 0, date: .now, isPaid: false)
        XCTAssertNotNil(base.validationError)
        var infinite = base; infinite.amount = .infinity
        XCTAssertNotNil(infinite.validationError)
        var good = base; good.amount = 10
        XCTAssertNil(good.validationError)
    }

    func testAttendanceStatusesAndStableDailyDocumentID() {
        XCTAssertEqual(AttendanceStatus.allCases.map(\.rawValue), ["Present", "Absent", "Late"])
        let calendar = Calendar(identifier: .gregorian)
        let first = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 9))!
        let sameDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 30, hour: 17))!
        let nextDay = calendar.date(from: DateComponents(year: 2026, month: 10, day: 31, hour: 9))!
        let student = UUID(), classID = UUID()
        XCTAssertEqual(AttendanceRecord.stableDocumentID(studentID: student, classID: classID, date: first, calendar: calendar),
                       AttendanceRecord.stableDocumentID(studentID: student, classID: classID, date: sameDay, calendar: calendar))
        XCTAssertNotEqual(AttendanceRecord.stableDocumentID(studentID: student, classID: classID, date: first, calendar: calendar),
                          AttendanceRecord.stableDocumentID(studentID: student, classID: classID, date: nextDay, calendar: calendar))
    }

    func testReminderDateUsesClassDateAndTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2027, month: 1, day: 2))!
        let session = ClassSession(title: "Math", subject: "Mathematics", date: date, time: "4:00 PM", duration: "60 min", location: "Room", students: 0)
        let reminder = NotificationService.reminderDate(for: session, calendar: calendar)
        XCTAssertEqual(calendar.component(.hour, from: reminder!), 15)
        XCTAssertEqual(calendar.component(.minute, from: reminder!), 45)
        var invalid = session; invalid.time = "not a time"
        XCTAssertNil(NotificationService.reminderDate(for: invalid, calendar: calendar))
    }

    @MainActor
    func testStudentRoleRoutesToStudentDashboard() {
        let app = AppController()
        app.signIn(name: "Test Student", email: "student@example.com", role: .student)
        XCTAssertEqual(app.route, .student)
    }

    @MainActor
    func testStudentSessionDoesNotExposeTutorOrSampleRecords() {
        let app = AppController()
        app.signIn(name: "Test Student", email: "student@example.com", role: .student)
        XCTAssertTrue(app.students.isEmpty)
        XCTAssertTrue(app.sessions.isEmpty)
        XCTAssertTrue(app.attendance.isEmpty)
        XCTAssertTrue(app.payments.isEmpty)
        XCTAssertTrue(app.assessments.isEmpty)
        XCTAssertEqual(app.studentPoints, 0)
    }
}
