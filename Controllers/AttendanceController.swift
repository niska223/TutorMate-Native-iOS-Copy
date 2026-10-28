import Foundation

@MainActor
final class AttendanceController {
    func record(
        _ student: Student,
        status: AttendanceStatus,
        session: ClassSession?,
        in app: AppController
    ) {
        app.markAttendance(student: student, status: status, session: session)
    }
}

