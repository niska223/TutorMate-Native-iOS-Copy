import Foundation
import Combine

#if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
#endif

@MainActor
final class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    @Published private(set) var isConfigured = false

    private init() {
        refreshConfiguration()
    }

    // MARK: - Configuration

    private func refreshConfiguration() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if FirebaseApp.app() == nil,
           Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil {
            FirebaseApp.configure()
        }
        isConfigured = FirebaseApp.app() != nil
        #else
        isConfigured = false
        #endif
    }

    private func ensureConfigured() throws {
        refreshConfiguration()
        guard isConfigured else {
            throw FirebaseSetupError.missingConfiguration
        }
    }

    var statusDescription: String {
        isConfigured
            ? "Firebase is configured."
            : "Add GoogleService-Info.plist to the TutorMate app target."
    }

    var currentUserEmail: String? {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        return Auth.auth().currentUser?.email
        #else
        return nil
        #endif
    }

    // MARK: - Authentication

    func signIn(email: String, password: String) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()
        _ = try await Auth.auth().signIn(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    func createAccount(email: String, password: String) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()
        _ = try await Auth.auth().createUser(
            withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password
        )
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    func signOut() throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()
        try Auth.auth().signOut()
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    // MARK: - User Profile

    func saveCurrentUserProfile(displayName: String, role: String) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }
        guard let email = user.email else {
            throw FirebaseSetupError.missingEmail
        }

        let cleanName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedRole = role.lowercased()

        guard !cleanName.isEmpty else {
            throw FirebaseSetupError.missingDisplayName
        }
        guard ["tutor", "student"].contains(normalizedRole) else {
            throw FirebaseSetupError.invalidRole
        }

        let profileRef = Firestore.firestore().collection("users").document(user.uid)
        let snapshot = try await profileRef.getDocument()

        if snapshot.exists {
            let existingRole = snapshot.data()?["role"] as? String
            guard existingRole?.lowercased() == normalizedRole else {
                throw FirebaseSetupError.roleMismatch
            }

            try await profileRef.updateData([
                "displayName": cleanName,
                "updatedAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await profileRef.setData([
                "uid": user.uid,
                "displayName": cleanName,
                "email": email,
                "role": normalizedRole,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    // MARK: - Student Storage

    /// Creates or replaces a student record owned by the signed-in tutor.
    /// This deliberately does not read the target student document first,
    /// because Firestore rules may deny reads of a document that does not exist.
    func saveStudent(_ student: Student) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let documentID = student.id.uuidString
        let studentData: [String: Any] = [
            "id": documentID,
            "name": student.name,
            "email": student.email,
            "grade": student.grade,
            "phone": student.phone,
            "attendanceRate": student.attendanceRate,
            "score": student.score,
            "paid": student.paid,
            "tutorId": user.uid,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // One write request: Firestore evaluates create/update rules directly.
        try await db.collection("students").document(documentID).setData(studentData)
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Updates an existing student record without changing its creation timestamp.
    func updateStudent(_ student: Student) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let studentData: [String: Any] = [
            "id": student.id.uuidString,
            "name": student.name,
            "email": student.email,
            "grade": student.grade,
            "phone": student.phone,
            "attendanceRate": student.attendanceRate,
            "score": student.score,
            "paid": student.paid,
            "tutorId": user.uid
        ]

        try await db.collection("students")
            .document(student.id.uuidString)
            .updateData(studentData)
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Loads only the records belonging to the authenticated tutor.
    func fetchStudents() async throws -> [Student] {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let snapshot = try await db.collection("students")
            .whereField("tutorId", isEqualTo: user.uid)
            .getDocuments()

        return try snapshot.documents.map { document in
            let data = document.data()
            guard
                let idString = data["id"] as? String,
                let id = UUID(uuidString: idString),
                let name = data["name"] as? String,
                let email = data["email"] as? String,
                let grade = data["grade"] as? String,
                let phone = data["phone"] as? String,
                let attendanceRate = data["attendanceRate"] as? Int,
                let score = data["score"] as? Int,
                let paid = data["paid"] as? Bool
            else {
                throw FirebaseSetupError.invalidStudentData
            }

            return Student(
                id: id,
                name: name,
                email: email,
                grade: grade,
                phone: phone,
                attendanceRate: attendanceRate,
                score: score,
                paid: paid
            )
        }
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    // MARK: - Class Storage

    /// Saves a new class belonging to the signed-in tutor.
    func saveClass(_ session: ClassSession) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users")
            .document(user.uid)
            .getDocument()

        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let documentID = session.id.uuidString
        let classData: [String: Any] = [
            "id": documentID,
            "title": session.title,
            "subject": session.subject,
            "date": Timestamp(date: session.date),
            "time": session.time,
            "duration": session.duration,
            "location": session.location,
            "students": session.students,
            "tutorId": user.uid,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // New classes have new UUIDs, so this creates their first document.
        try await db.collection("classes")
            .document(documentID)
            .setData(classData)
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Loads only the classes belonging to the signed-in tutor.
    func fetchClasses() async throws -> [ClassSession] {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users")
            .document(user.uid)
            .getDocument()

        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let snapshot = try await db.collection("classes")
            .whereField("tutorId", isEqualTo: user.uid)
            .getDocuments()

        return try snapshot.documents.map { document in
            let data = document.data()

            guard
                let idString = data["id"] as? String,
                let id = UUID(uuidString: idString),
                let title = data["title"] as? String,
                let subject = data["subject"] as? String,
                let timestamp = data["date"] as? Timestamp,
                let time = data["time"] as? String,
                let duration = data["duration"] as? String,
                let location = data["location"] as? String,
                let studentCount = data["students"] as? Int
            else {
                throw FirebaseSetupError.invalidClassData
            }

            return ClassSession(
                id: id,
                title: title,
                subject: subject,
                date: timestamp.dateValue(),
                time: time,
                duration: duration,
                location: location,
                students: studentCount
            )
        }
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    // MARK: - Manual Attendance Storage

    /// Saves or updates a tutor's attendance record for a verified student and class.
    /// The document ID comes from AttendanceRecord.id, so changing a status updates
    /// the same daily record instead of creating duplicate documents.
    func saveAttendanceRecord(
        _ record: AttendanceRecord,
        student: Student,
        session: ClassSession
    ) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        // Confirm both referenced documents belong to this tutor before writing.
        let studentSnapshot = try await db.collection("students")
            .document(student.id.uuidString)
            .getDocument()
        guard studentSnapshot.data()?["tutorId"] as? String == user.uid else {
            throw FirebaseSetupError.studentNotOwned
        }

        let classSnapshot = try await db.collection("classes")
            .document(session.id.uuidString)
            .getDocument()
        guard classSnapshot.data()?["tutorId"] as? String == user.uid else {
            throw FirebaseSetupError.classNotOwned
        }

        let recordID = record.id.uuidString
        let recordDate = Timestamp(date: record.date)
        let data: [String: Any] = [
            "id": recordID,
            "studentId": student.id.uuidString,
            "studentName": student.name,
            "classId": session.id.uuidString,
            "className": session.title,
            "date": recordDate,
            "status": record.status.rawValue,
            "tutorId": user.uid,
            "recordType": "manual",
            // Keep createdAt stable when the status is updated.
            "createdAt": recordDate,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("attendance")
            .document(recordID)
            .setData(data, merge: true)
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Loads manual attendance records owned by the signed-in tutor.
    /// NFC scan events share the collection but are excluded from this model list.
    func fetchAttendanceRecords() async throws -> [AttendanceRecord] {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let snapshot = try await db.collection("attendance")
            .whereField("tutorId", isEqualTo: user.uid)
            .getDocuments()

        var records: [AttendanceRecord] = []
        for document in snapshot.documents {
            let data = document.data()
            guard (data["recordType"] as? String) == "manual" else {
                continue
            }

            guard
                let idString = data["id"] as? String,
                let id = UUID(uuidString: idString),
                let studentName = data["studentName"] as? String,
                let className = data["className"] as? String,
                let timestamp = data["date"] as? Timestamp,
                let statusString = data["status"] as? String,
                let status = AttendanceStatus(rawValue: statusString)
            else {
                throw FirebaseSetupError.invalidAttendanceData
            }

            records.append(
                AttendanceRecord(
                    id: id,
                    studentName: studentName,
                    className: className,
                    date: timestamp.dateValue(),
                    status: status
                )
            )
        }

        return records.sorted { $0.date > $1.date }
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    // MARK: - Payment Storage

    /// Creates a payment record owned by the signed-in tutor.
    /// This does not read the target document first, because rules may deny
    /// reads of a document that does not exist yet.
    func savePayment(_ payment: Payment) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let documentID = payment.id.uuidString
        let paymentData: [String: Any] = [
            "id": documentID,
            "studentName": payment.studentName,
            "description": payment.description,
            "amount": payment.amount,
            "date": Timestamp(date: payment.date),
            "isPaid": payment.isPaid,
            "tutorId": user.uid,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("payments").document(documentID).setData(paymentData)
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Loads only the payment records belonging to the signed-in tutor.
    func fetchPayments() async throws -> [Payment] {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let snapshot = try await db.collection("payments")
            .whereField("tutorId", isEqualTo: user.uid)
            .getDocuments()

        let payments = try snapshot.documents.map { document in
            let data = document.data()
            guard
                let idString = data["id"] as? String,
                let id = UUID(uuidString: idString),
                let studentName = data["studentName"] as? String,
                let description = data["description"] as? String,
                let amount = Self.paymentAmount(from: data["amount"]),
                let timestamp = data["date"] as? Timestamp,
                let isPaid = data["isPaid"] as? Bool
            else {
                throw FirebaseSetupError.invalidPaymentData
            }

            return Payment(
                id: id,
                studentName: studentName,
                description: description,
                amount: amount,
                date: timestamp.dateValue(),
                isPaid: isPaid
            )
        }

        return payments.sorted { $0.date > $1.date }
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    /// Marks an existing payment as paid without creating a second document.
    func updatePaymentPaidStatus(_ payment: Payment) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        let documentRef = db.collection("payments").document(payment.id.uuidString)
        let snapshot = try await documentRef.getDocument()

        guard snapshot.exists else {
            throw FirebaseSetupError.paymentNotFound
        }
        guard snapshot.data()?["tutorId"] as? String == user.uid else {
            throw FirebaseSetupError.paymentNotOwned
        }

        try await documentRef.updateData([
            "isPaid": true,
            "updatedAt": FieldValue.serverTimestamp()
        ])
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }

    private static func paymentAmount(from value: Any?) -> Double? {
        if let amount = value as? Double {
            return amount
        }
        if let amount = value as? Int {
            return Double(amount)
        }
        if let amount = value as? Int64 {
            return Double(amount)
        }
        if let amount = value as? NSNumber {
            return amount.doubleValue
        }
        return nil
    }

    // MARK: - NFC Scan Event Logging

    func recordAttendance(tagPayload: String, studentEmail: String, role: String) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        let db = Firestore.firestore()
        let tutorProfile = try await db.collection("users").document(user.uid).getDocument()
        guard tutorProfile.data()?["role"] as? String == "tutor" else {
            throw FirebaseSetupError.notTutor
        }

        try await db.collection("attendance").addDocument(data: [
            "tagPayload": tagPayload,
            "studentEmail": studentEmail,
            "role": role.lowercased(),
            "createdAt": FieldValue.serverTimestamp(),
            "source": "NFC",
            "createdBy": user.uid,
            "tutorId": user.uid,
            "recordType": "nfc_scan"
        ])
        #else
        throw FirebaseSetupError.sdkMissing
        #endif
    }
}

// MARK: - Firebase Errors

enum FirebaseSetupError: LocalizedError {
    case missingConfiguration
    case sdkMissing
    case notSignedIn
    case missingEmail
    case missingDisplayName
    case invalidRole
    case roleMismatch
    case notTutor
    case invalidStudentData
    case invalidClassData
    case invalidAttendanceData
    case studentNotOwned
    case classNotOwned
    case invalidPaymentData
    case paymentNotFound
    case paymentNotOwned

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Firebase is not configured. Check GoogleService-Info.plist."
        case .sdkMissing:
            return "The Firebase SDK is unavailable. Check your Xcode package dependencies."
        case .notSignedIn:
            return "Please sign in to Firebase before saving data."
        case .missingEmail:
            return "The Firebase account does not have an email address."
        case .missingDisplayName:
            return "Please enter your name."
        case .invalidRole:
            return "The account role must be Tutor or Student."
        case .roleMismatch:
            return "This account is registered for a different role. Choose the correct sign-in option."
        case .notTutor:
            return "Only an authenticated tutor can manage student records."
        case .invalidStudentData:
            return "A student record in Firestore is missing required fields."
        case .invalidClassData:
            return "A class record in Firestore is missing required fields or has an invalid date."
        case .invalidAttendanceData:
            return "An attendance record in Firestore is missing required fields or has an invalid status."
        case .studentNotOwned:
            return "The selected student does not belong to the signed-in tutor. Save or reload the student first."
        case .classNotOwned:
            return "The selected class does not belong to the signed-in tutor. Save or reload the class first."
        case .invalidPaymentData:
            return "A payment record in Firestore is missing required fields or has an invalid amount."
        case .paymentNotFound:
            return "That payment was not found in Firestore. Reload payments and try again."
        case .paymentNotOwned:
            return "That payment does not belong to the signed-in tutor."
        }
    }
}

