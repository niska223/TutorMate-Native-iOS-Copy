
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var app: AppController

    let role: UserRole

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error = ""
    @State private var isSigningIn = false
    @State private var isAuthenticatingWithFaceID = false

    private let faceIDService = FaceIDService()

    var body: some View {
        NavigationStack {
            ZStack {
                TMStyle.canvas.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(
                            systemName: role == .tutor
                                ? "ipad.landscape"
                                : "iphone"
                        )
                        .font(.system(size: 42))
                        .foregroundStyle(TMStyle.blue)
                        .frame(width: 76, height: 76)
                        .background(
                            TMStyle.blueSoft,
                            in: RoundedRectangle(cornerRadius: 22)
                        )

                        Eyebrow(
                            text: role == .tutor
                                ? "TUTOR SPACE"
                                : "STUDENT SPACE"
                        )

                        Text("Welcome back")
                            .font(
                                .system(size: 32, weight: .bold, design: .rounded)
                            )
                            .foregroundStyle(TMStyle.ink)

                        Text(
                            "Sign in to continue to your \(role.rawValue.lowercased()) account."
                        )
                        .foregroundStyle(TMStyle.muted)

                        VStack(alignment: .leading, spacing: 14) {
                            fieldLabel("Name (optional)")

                            TextField("Your name", text: $name)
                                .textContentType(.name)
                                .textFieldStyle(TMFieldStyle())

                            fieldLabel("Email address")

                            TextField("name@example.com", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(TMFieldStyle())

                            fieldLabel("Password")

                            HStack {
                                Group {
                                    if showPassword {
                                        TextField("Password", text: $password)
                                    } else {
                                        SecureField("Password", text: $password)
                                    }
                                }

                                Button {
                                    showPassword.toggle()
                                } label: {
                                    Image(
                                        systemName: showPassword
                                            ? "eye.slash"
                                            : "eye"
                                    )
                                    .foregroundStyle(TMStyle.muted)
                                }
                            }
                            .padding(13)
                            .background(
                                .white,
                                in: RoundedRectangle(cornerRadius: 13)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 13)
                                    .stroke(TMStyle.line)
                            )

                            if !error.isEmpty {
                                Text(error)
                                    .font(.caption)
                                    .foregroundStyle(TMStyle.red)
                            }

                            PrimaryButton(
                                title: isSigningIn ? "Signing in..." : "Sign In",
                                icon: "arrow.right"
                            ) {
                                Task { @MainActor in
                                    await signInWithFirebase()
                                }
                            }
                            .disabled(isSigningIn || isAuthenticatingWithFaceID)

                            Button {
                                Task { @MainActor in
                                    await signInWithFaceID()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    if isAuthenticatingWithFaceID {
                                        ProgressView()
                                            .tint(TMStyle.blue)
                                    } else {
                                        Image(systemName: "faceid")
                                    }

                                    Text("Sign in with Face ID")
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(TMStyle.blue)
                                .frame(maxWidth: .infinity)
                            }
                            .disabled(isSigningIn || isAuthenticatingWithFaceID)

                            Button("Create an account") {
                                error = ""
                                app.route = role == .tutor
                                    ? .tutorOnboarding
                                    : .studentOnboarding
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TMStyle.blue)
                            .frame(maxWidth: .infinity)

                            Text(
                                "Use your Firebase account to sign in. Face ID is available after you have signed in on this device."
                            )
                            .font(.caption2)
                            .foregroundStyle(TMStyle.muted)
                            .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        app.route = .welcome
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(TMStyle.ink)
                    }
                }
            }
        }
    }

    @MainActor
    private func signInWithFirebase() async {
        error = ""

        let cleanEmail = email.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard cleanEmail.contains("@"),
              password.count >= 6 else {
            error = "Enter a valid email address and a password of at least 6 characters."
            return
        }

        guard FirebaseService.shared.isConfigured else {
            error = "Firebase is not configured. Check GoogleService-Info.plist and restart the app."
            return
        }

        isSigningIn = true
        defer { isSigningIn = false }

        let displayName: String
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = cleanEmail.components(separatedBy: "@").first ?? "User"
        } else {
            displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            try await FirebaseService.shared.signIn(
                email: cleanEmail,
                password: password
            )

            // Create the profile for existing Firebase accounts too,
            // if this account does not have a profile yet.
            try await FirebaseService.shared.saveCurrentUserProfile(
                displayName: displayName,
                role: role.rawValue.lowercased()
            )

            app.signIn(
                name: displayName,
                email: cleanEmail,
                role: role
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func signInWithFaceID() async {
        error = ""
        isAuthenticatingWithFaceID = true

        let authenticated = await faceIDService.authenticate()

        isAuthenticatingWithFaceID = false

        guard authenticated else {
            error = "Face ID was unavailable or authentication was cancelled. Sign in with your password instead."
            return
        }

        guard let accountEmail = FirebaseService.shared.currentUserEmail else {
            error = "Please sign in once with your email and password before using Face ID."
            return
        }

        let cleanEmail = accountEmail.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        let displayName: String
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = cleanEmail.components(separatedBy: "@").first ?? "User"
        } else {
            displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        do {
            try await FirebaseService.shared.saveCurrentUserProfile(
                displayName: displayName,
                role: role.rawValue.lowercased()
            )

            app.signIn(
                name: displayName,
                email: cleanEmail,
                role: role
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TMStyle.ink)
    }
}

struct TMFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(13)
            .background(.white, in: RoundedRectangle(cornerRadius: 13))
            .overlay(
                RoundedRectangle(cornerRadius: 13)
                    .stroke(TMStyle.line)
            )
    }
}

