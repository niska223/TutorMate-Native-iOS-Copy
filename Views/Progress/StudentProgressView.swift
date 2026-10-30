import SwiftUI

struct StudentProgressView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your progress", subtitle: "Attendance and assessment records for your account.")
                TMCard {
                    Label("Progress records are not available", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(TMStyle.ink)
                    Text("The active Firestore rules do not allow student accounts to read attendance or assessment records. TutorMate is not displaying example scores or streaks as your personal results.")
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                }
            }
            .padding(18)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.inline)
    }
}
