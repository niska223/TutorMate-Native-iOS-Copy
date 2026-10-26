import SwiftUI

struct StudentProfileView: View {
    @EnvironmentObject private var app: AppController
    @State private var showWidgets = false
    @State private var confirmSignOut = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageTitle(title: "Your profile", subtitle: "Account details, preferences and helpful shortcuts.")
                TMCard {
                    HStack(spacing: 14) {
                        AvatarView(name: app.displayName, color: TMStyle.violet)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(app.displayName).font(.headline)
                            Text(app.email).font(.caption).foregroundStyle(TMStyle.muted)
                            StatusPill(text: "Student account", color: TMStyle.violet)
                        }
                    }
                }
                TMCard {
                    Text("Personal information").font(.headline)
                    Label(app.displayName, systemImage: "person.fill")
                    Divider()
                    Label(app.email, systemImage: "envelope.fill")
                    Divider()
                    Label("Grade 11", systemImage: "graduationcap.fill")
                }
                TMCard {
                    Text("Payments").font(.headline)
                    HStack { Text("June tuition fee"); Spacer(); StatusPill(text: "Paid") }
                    HStack { Text("July tuition fee"); Spacer(); StatusPill(text: "Due soon", color: TMStyle.orange) }
                }
                TMCard {
                    Text("Notifications").font(.headline)
                    Toggle("Class and result notifications", isOn: $app.notificationsEnabled).tint(TMStyle.blue)
                }
                TMCard {
                    Text("Home Screen Widgets").font(.headline)
                    HStack {
                        Image(systemName: "rectangle.inset.filled").font(.title2).foregroundStyle(TMStyle.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your next class at a glance").font(.subheadline.weight(.semibold))
                            Text("Preview the TutorMate widget design").font(.caption).foregroundStyle(TMStyle.muted)
                        }
                        Spacer()
                    }
                    Button("Preview widgets") { showWidgets = true }.buttonStyle(.bordered)
                }
                TMCard {
                    Label("Data & Privacy", systemImage: "lock.shield")
                    Divider()
                    Label("Help & About", systemImage: "questionmark.circle")
                    Divider()
                    Button(role: .destructive) { confirmSignOut = true } label: { Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right") }
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity, alignment: .topLeading)
        }.background(TMStyle.canvas).navigationTitle("Profile").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWidgets) { WidgetPreviewSheet() }
            .confirmationDialog("Sign out?", isPresented: $confirmSignOut) {
                Button("Sign out", role: .destructive) { app.signOut() }
            }
    }
}
