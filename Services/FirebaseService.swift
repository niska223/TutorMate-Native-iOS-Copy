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

    // MARK: - Attendance

    func recordAttendance(tagPayload: String, studentEmail: String, role: String) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        try await Firestore.firestore().collection("attendance").addDocument(data: [
            "tagPayload": tagPayload,
            "studentEmail": studentEmail,
            "role": role.lowercased(),
            "createdAt": FieldValue.serverTimestamp(),
            "source": "NFC",
            "createdBy": user.uid
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
        }
    }
}

