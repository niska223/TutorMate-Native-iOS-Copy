import SwiftUI

struct StudentClassesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your classes", subtitle: "Class information linked to your account.")
                TMCard {
                    Label("Class access is not available", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundStyle(TMStyle.ink)
                    Text("The active Firestore rules do not grant student accounts access to class or assignment records. No sample schedule is shown.")
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                }
            }
            .padding(18)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .navigationTitle("Classes")
        .navigationBarTitleDisplayMode(.inline)
    }
}
