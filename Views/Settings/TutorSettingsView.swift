import SwiftUI

struct TutorSettingsView: View {
    @EnvironmentObject private var app: AppController
    @State private var confirmSignOut = false
    @State private var confirmPasswordReset = false
    private let faceID = FaceIDService()
    private var faceIDBinding: Binding<Bool> {
        Binding(get: { app.faceIDEnabled }, set: { enabled in
            guard enabled else { app.setFaceIDEnabled(false); return }
            guard faceID.isAvailable else {
                app.showToast(faceID.unavailableMessage ?? "Face ID is unavailable on this device.")
                return
            }
            // Enabling the preference must not open the biometric prompt here.
            // The sign-in screen requests Face ID only when the user taps its button.
            app.setFaceIDEnabled(true)
        })
    }
    private var reminderBinding: Binding<Bool> {
        Binding(get: { app.notificationsEnabled }, set: { enabled in
            Task { await app.setClassRemindersEnabled(enabled) }
        })
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your account", subtitle: "Manage your profile, security and app preferences.")
                TMCard {
                    HStack(spacing: 14) {
                        AvatarView(name: app.displayName, color: TMStyle.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(app.displayName).font(.headline).foregroundStyle(TMStyle.ink)
                            Text(app.email).font(.caption).foregroundStyle(TMStyle.muted)
                            StatusPill(text: "Tutor account", color: TMStyle.blue)
                        }
                    }
                }
                TMCard {
                    Text("Security & privacy").font(.headline)
                    Toggle(isOn: faceIDBinding) { Label("Face ID", systemImage: "faceid") }.tint(TMStyle.blue)
                    Text("Face ID is requested by iOS after device availability is confirmed. On Simulator, enable Features > Face ID > Enrolled first.")
                        .font(.footnote)
                        .foregroundStyle(TMStyle.muted)
                    Divider()
                    Button {
                        confirmPasswordReset = true
                    } label: {
                        if app.isSendingPasswordReset {
                            ProgressView("Sending password reset email…")
                        } else {
                            Label("Change password", systemImage: "lock.fill")
                        }
                    }
                    .disabled(app.isSendingPasswordReset)
                    .accessibilityHint("Sends a secure password reset link to your account email")
                    Divider()
                    Label("Data & Backup", systemImage: "icloud.fill")
                    Text("Tutor records sync to Firestore when connected. A manual export and restore feature is not implemented.")
                        .font(.footnote)
                        .foregroundStyle(TMStyle.muted)
                }
                TMCard {
                    Text("Notifications").font(.headline)
                    Toggle(isOn: reminderBinding) { Label("Class reminders", systemImage: "bell.fill") }.tint(TMStyle.blue)
                    Divider()
                    Label("Payment alerts", systemImage: "creditcard.fill")
                    Text("Payment alerts are not configured yet.")
                        .font(.footnote)
                        .foregroundStyle(TMStyle.muted)
                    Button("Send test notification") {
                        Task {
                            if await NotificationService.shared.requestPermission() {
                                NotificationService.shared.sendTestReminder()
                                app.showToast("Test notification scheduled")
                            } else { app.showToast("Notification permission was not granted") }
                        }
                    }.font(.subheadline.weight(.semibold))
                }
                TMCard {
                    Text("Privacy & account").font(.headline)
                    if app.faceIDEnabled {
                        Button {
                            app.lockWithFaceID()
                        } label: {
                            Label("Lock with Face ID", systemImage: "faceid")
                        }
                        .accessibilityHint("Returns to sign in while keeping this account available for Face ID unlock")
                    }
                    Button(role: .destructive) { confirmSignOut = true } label: { Label("Sign out of TutorMate", systemImage: "rectangle.portrait.and.arrow.right") }
                }
            }.padding(20).frame(maxWidth: 800).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
        .confirmationDialog("Sign out of TutorMate?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { app.signOut() }
        }
        .alert("Change password", isPresented: $confirmPasswordReset) {
            Button("Send reset email") {
                Task { await app.sendPasswordResetEmail() }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Firebase will send a secure password reset link to \(app.email). Open that link to choose a new password.")
        }
    }
}
