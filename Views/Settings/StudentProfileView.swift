import SwiftUI

struct StudentProfileView: View {
    @EnvironmentObject private var app: AppController
    @State private var showWidgets = false
    @State private var confirmSignOut = false
    @State private var profileName = ""
    @State private var isSavingName = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your profile", subtitle: "Account details and preferences.")
                TMCard {
                    HStack(spacing: 14) {
                        AvatarView(name: app.displayName, color: TMStyle.violet)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(app.displayName).font(.headline)
                            Text(app.email).font(.body).foregroundStyle(TMStyle.muted).textSelection(.enabled)
                            StatusPill(text: "Student account", color: TMStyle.violet)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Student profile, \(app.displayName), \(app.email)")
                }

                TMCard {
                    Text("Personal information").font(.headline)
                    TextField("Display name", text: $profileName)
                        .textContentType(.name)
                        .textInputAutocapitalization(.words)
                        .accessibilityLabel("Profile display name")
                    Button {
                        Task { await saveProfileName() }
                    } label: {
                        if isSavingName {
                            ProgressView("Saving profile name…")
                        } else {
                            Label("Save name", systemImage: "checkmark.circle")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSavingName || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || profileName == app.displayName)
                    .accessibilityHint("Updates only the display name on your own account profile")
                    Divider()
                    Label(app.email, systemImage: "envelope.fill")
                        .font(.body)
                        .textSelection(.enabled)
                    Text("Email and account role are managed by your sign-in account.")
                        .font(.footnote)
                        .foregroundStyle(TMStyle.muted)
                }

                TMCard {
                    Text("Student records").font(.headline)
                    Text("Your class schedule, attendance and payment records are unavailable under the active Firestore rules. No other student's information is requested or shown.")
                        .font(.body)
                        .foregroundStyle(TMStyle.muted)
                }

                TMCard {
                    Text("Home Screen Widgets").font(.headline)
                    HStack {
                        Image(systemName: "rectangle.inset.filled").font(.title2).foregroundStyle(TMStyle.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("TutorMate widget preview").font(.subheadline.weight(.semibold))
                            Text("Preview the widget design.").font(.footnote).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                    }
                    Button("Preview widgets") { showWidgets = true }
                        .buttonStyle(.bordered)
                }

                TMCard {
                    Label("Your account is private", systemImage: "lock.shield")
                    Text("Student access to classes, attendance and payments requires approved rules and a verified account link.")
                        .font(.footnote)
                        .foregroundStyle(TMStyle.muted)
                    Divider()
                    Button(role: .destructive) { confirmSignOut = true } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityHint("Signs out of the current TutorMate account")
                }
            }
            .padding(18)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(TMStyle.canvas)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if profileName.isEmpty { profileName = app.displayName } }
        .sheet(isPresented: $showWidgets) { WidgetPreviewSheet() }
        .confirmationDialog("Sign out?", isPresented: $confirmSignOut) {
            Button("Sign out", role: .destructive) { app.signOut() }
        } message: {
            Text("You will return to the welcome screen.")
        }
    }

    @MainActor
    private func saveProfileName() async {
        isSavingName = true
        defer { isSavingName = false }
        if !(await app.updateStudentProfileName(profileName)) {
            profileName = app.displayName
        }
    }
}
