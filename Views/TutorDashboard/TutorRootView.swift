import SwiftUI

struct TutorRootView: View {
    @EnvironmentObject private var app: AppController
    @State private var section: TutorSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "graduationcap.fill")
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(TMStyle.blue, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading) {
                            Text("TutorMate")
                                .font(.headline)
                                .foregroundStyle(TMStyle.ink)
                            Text("Tutor workspace")
                                .font(.caption)
                                .foregroundStyle(TMStyle.muted)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("WORKSPACE") {
                    ForEach(TutorSection.allCases) { item in
                        NavigationLink(value: item) {
                            Label(item.rawValue, systemImage: item.icon)
                                .foregroundStyle(section == item ? TMStyle.blue : TMStyle.ink)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(TMStyle.canvas)
            .navigationTitle("TutorMate")
        } detail: {
            NavigationStack {
                Group {
                    switch section ?? .dashboard {
                    case .dashboard:
                        TutorDashboardView(onSelect: { section = $0 })
                    case .classes:
                        TutorClassesView()
                    case .students:
                        TutorStudentsView()
                    case .attendance:
                        TutorAttendanceView(
                            onManageClasses: { section = .classes },
                            onManageStudents: { section = .students }
                        )
                    case .payments:
                        TutorPaymentsView()
                    case .finance:
                        TutorFinanceView()
                    case .settings:
                        TutorSettingsView()
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button("Notifications", systemImage: "bell") {
                                app.showToast("You're all caught up")
                            }
                            if app.faceIDEnabled {
                                Button("Lock with Face ID", systemImage: "faceid") {
                                    app.lockWithFaceID()
                                }
                            }
                            Button("Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                                app.signOut()
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .overlay(alignment: .top) {
            if let message = app.toastMessage {
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(TMStyle.ink, in: Capsule())
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                            if app.toastMessage == message {
                                app.toastMessage = nil
                            }
                        }
                    }
            }
        }
    }
}
