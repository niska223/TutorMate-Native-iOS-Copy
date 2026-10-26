import SwiftUI

struct TutorSettingsView: View {
    @EnvironmentObject private var app: AppController
    @State private var confirmSignOut = false
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
                    Toggle(isOn: $app.faceIDEnabled) { Label("Face ID", systemImage: "faceid") }.tint(TMStyle.blue)
                    Divider()
                    Label("Change password", systemImage: "lock.fill")
                    Divider()
                    Label("Data & Backup", systemImage: "icloud.fill")
                    Text("Cloud backup requires Firebase configuration.").font(.caption).foregroundStyle(TMStyle.muted)
                }
                TMCard {
                    Text("Notifications").font(.headline)
                    Toggle(isOn: $app.notificationsEnabled) { Label("Push notifications", systemImage: "bell.fill") }.tint(TMStyle.blue)
                    Divider()
                    Toggle(isOn: $app.paymentAlertsEnabled) { Label("Payment alerts", systemImage: "creditcard.fill") }.tint(TMStyle.blue)
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
                    Button(role: .destructive) { confirmSignOut = true } label: { Label("Sign out of TutorMate", systemImage: "rectangle.portrait.and.arrow.right") }
                }
            }.padding(20).frame(maxWidth: 800).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas)
        .confirmationDialog("Sign out of TutorMate?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) { app.signOut() }
        }
    }
}
