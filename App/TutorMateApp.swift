
import SwiftUI
import FirebaseCore

@main
struct TutorMateApp: App {
    @StateObject private var app = AppController()

    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(app)
                .tint(TMStyle.blue)
        }
    }
}

