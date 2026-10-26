import Foundation
import LocalAuthentication

final class FaceIDService {
    func authenticate(reason: String = "Sign in to TutorMate") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else { return false }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch { return false }
    }
}
