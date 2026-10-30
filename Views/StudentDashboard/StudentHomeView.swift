import SwiftUI

struct StudentHomeView: View {
    @EnvironmentObject private var app: AppController
    var onOpenClasses: () -> Void
    var onOpenProgress: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(
                    title: "Hello, \(app.displayName.split(separator: " ").first.map(String.init) ?? "Student")",
                    subtitle: "Your TutorMate account overview."
                )

                TMCard {
                    Label("Signed in as a student", systemImage: "person.crop.circle.fill")
                        .font(.headline)
                        .foregroundStyle(TMStyle.ink)
                    Text(app.email)
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                        .textSelection(.enabled)
                }

                TMCard {
                    Label("Student records are restricted", systemImage: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(TMStyle.ink)
                    Text("The current Firestore rules let student accounts read their own account profile only. Class schedules, attendance, payments and progress are hidden until student access is securely approved and configured.")
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                    Button("View classes", action: onOpenClasses)
                        .buttonStyle(.bordered)
                    Button("View progress", action: onOpenProgress)
                        .buttonStyle(.bordered)
                }
            }
            .padding(18)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
    }
}
