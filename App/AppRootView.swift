import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var app: AppController
    var body: some View {
        Group {
            switch app.route {
            case .welcome: WelcomeView()
            case .tutorAuth: AuthenticationView(role: .tutor)
            case .studentAuth: AuthenticationView(role: .student)
            case .tutorOnboarding: OnboardingView(role: .tutor)
            case .studentOnboarding: OnboardingView(role: .student)
            case .tutor: TutorRootView()
            case .student: StudentRootView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: app.route)
    }
}
