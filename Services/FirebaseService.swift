
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

    private func refreshConfiguration() {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        if FirebaseApp.app() == nil,
           Bundle.main.url(
               forResource: "GoogleService-Info",
               withExtension: "plist"
           ) != nil {
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

    func saveCurrentUserProfile(
        displayName: String,
        role: String
    ) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        guard let email = user.email else {
            throw FirebaseSetupError.missingEmail
        }

        let cleanName = displayName.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let normalizedRole = role.lowercased()

        guard !cleanName.isEmpty else {
            throw FirebaseSetupError.missingDisplayName
        }

        guard ["tutor", "student"].contains(normalizedRole) else {
            throw FirebaseSetupError.invalidRole
        }

        let db = Firestore.firestore()
        let profileRef = db.collection("users").document(user.uid)
        let snapshot = try await profileRef.getDocument()

        if snapshot.exists {
            let existingRole = snapshot.data()?["role"] as? String

            guard existingRole?.lowercased() == normalizedRole else {
                throw FirebaseSetupError.roleMismatch
            }

            // Keep the original UID, email, role and creation date.
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

    // MARK: - Attendance

    func recordAttendance(
        tagPayload: String,
        studentEmail: String,
        role: String
    ) async throws {
        #if canImport(FirebaseCore) && canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        try ensureConfigured()

        guard let user = Auth.auth().currentUser else {
            throw FirebaseSetupError.notSignedIn
        }

        try await Firestore.firestore()
            .collection("attendance")
            .addDocument(data: [
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

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Firebase is not configured. Check GoogleService-Info.plist."
        case .sdkMissing:
            return "The Firebase SDK is unavailable in this build. Check Xcode package dependencies."
        case .notSignedIn:
            return "Please sign in to Firebase before saving your data."
        case .missingEmail:
            return "The Firebase account does not have an email address."
        case .missingDisplayName:
            return "Please enter your name."
        case .invalidRole:
            return "The account role must be Tutor or Student."
        case .roleMismatch:
            return "This account is registered for a different user role. Choose the correct sign-in option."
        }
    }
}

