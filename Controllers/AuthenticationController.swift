import Foundation

@MainActor
final class AuthenticationController {
    func signIn(name: String, email: String, role: UserRole, app: AppController) {
        app.signIn(name: name, email: email, role: role)
    }
}
