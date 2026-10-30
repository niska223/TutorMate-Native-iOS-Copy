import Foundation
import LocalAuthentication

final class FaceIDService {
    var unavailableMessage: String? {
        let context = LAContext()
        var error: NSError?
        guard !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }

        switch (error as? LAError)?.code {
        case .biometryNotEnrolled:
            return "Face ID is not enrolled. On a physical iPhone, set it up in Settings > Face ID & Passcode. In Simulator, choose Features > Face ID > Enrolled."
        case .passcodeNotSet:
            return "Set a device passcode before enabling Face ID for TutorMate."
        case .biometryNotAvailable:
            return "Face ID is unavailable on this device. Use a Face ID-capable iPhone or enable Face ID in the Simulator Features menu."
        case .biometryLockout:
            return "Face ID is locked. Unlock the device with its passcode, then try again."
        default:
            return error?.localizedDescription ?? "Face ID is unavailable. Check the device's Face ID settings."
        }
    }

    var isAvailable: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    func authenticate(reason: String = "Sign in to TutorMate") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }

        do {
            return try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
        } catch {
            return false
        }
    }
}
