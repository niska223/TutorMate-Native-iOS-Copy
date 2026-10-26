
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var app: AppController

    let role: UserRole

    @State private var step = 1
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var subject = "Mathematics"
    @State private var notifications = true
    @State private var errorMessage = ""
    @State private var isCreatingAccount = false

    var body: some View {
        NavigationStack {
            ZStack {
                TMStyle.canvas.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 7) {
                        ForEach(1...3, id: \.self) { number in
                            Capsule()
                                .fill(
                                    number <= step
                                        ? TMStyle.blue
                                        : TMStyle.line
                                )
                                .frame(height: 5)
                        }
                    }

                    Text("Set up your \(role.rawValue.lowercased()) profile")
                        .font(
                            .system(size: 28, weight: .bold, design: .rounded)
                        )
                        .foregroundStyle(TMStyle.ink)

                    Text("Step \(step) of 3")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TMStyle.blue)

                    if step == 1 {
                        TextField("Full name", text: $name)
                            .textFieldStyle(TMFieldStyle())

                        TextField("Email address", text: $email)
                            .textFieldStyle(TMFieldStyle())
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField(
                            "Create password (at least 6 characters)",
                            text: $password
                        )
                        .textFieldStyle(TMFieldStyle())

                    } else if step == 2 {
                        if role == .tutor {
                            Text("Choose your main teaching subject")
                                .font(.headline)
                                .foregroundStyle(TMStyle.ink)

                            Picker("Subject", selection: $subject) {
                                ForEach(
                                    [
                                        "Mathematics",
                                        "ICT",
                                        "Physics",
                                        "Science",
                                        "English"
                                    ],
                                    id: \.self
                                ) { item in
                                    Text(item)
                                }
                            }
                            .pickerStyle(.inline)
                        } else {
                            Label(
                                "Your classes and progress will appear in your student space.",
                                systemImage: "book.closed.fill"
                            )
                            .padding()
                            .background(
                                .white,
                                in: RoundedRectangle(cornerRadius: 16)
                            )
                        }

                    } else {
                        Toggle(
                            "Allow class and payment notifications",
                            isOn: $notifications
                        )
                        .tint(TMStyle.blue)

                        Text("You can change this preference later in Settings.")
                            .font(.caption)
                            .foregroundStyle(TMStyle.muted)
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(TMStyle.red)
                    }

                    Spacer()

                    PrimaryButton(
                        title: step < 3
                            ? "Continue"
                            : (isCreatingAccount
                                ? "Creating account..."
                                : "Create account"),
                        icon: "arrow.right"
                    ) {
                        handleContinue()
                    }
                    .disabled(isCreatingAccount)
                }
                .padding(24)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        errorMessage = ""

                        if step > 1 {
                            step -= 1
                        } else {
                            app.route = role == .tutor
                                ? .tutorAuth
                                : .studentAuth
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                }
            }
        }
    }

    private func handleContinue() {
        errorMessage = ""

        if step == 1 {
            guard !name.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                errorMessage = "Please enter your full name."
                return
            }

            guard email.contains("@"), email.contains(".") else {
                errorMessage = "Please enter a valid email address."
                return
            }

            guard password.count >= 6 else {
                errorMessage = "Please use a password with at least 6 characters."
                return
            }
        }

        if step < 3 {
            step += 1
            return
        }

        guard FirebaseService.shared.isConfigured else {
            errorMessage = "Firebase is not configured. Check GoogleService-Info.plist and restart the app."
            return
        }

        isCreatingAccount = true

        Task { @MainActor in
            defer { isCreatingAccount = false }

            let cleanName = name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let cleanEmail = email.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            do {
                // 1. Create the Firebase Authentication account.
                try await FirebaseService.shared.createAccount(
                    email: cleanEmail,
                    password: password
                )

                // 2. Save the matching profile in Cloud Firestore.
                try await FirebaseService.shared.saveCurrentUserProfile(
                    displayName: cleanName,
                    role: role.rawValue.lowercased()
                )

                // 3. Continue through the existing TutorMate flow.
                app.notificationsEnabled = notifications

                app.register(
                    role: role,
                    name: cleanName,
                    email: cleanEmail
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

