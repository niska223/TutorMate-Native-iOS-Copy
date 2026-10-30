
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject private var app: AppController

    let role: UserRole

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var error = ""
    @State private var info = ""
    @State private var isSigningIn = false
    @State private var isAuthenticatingWithFaceID = false
    @State private var isSendingPasswordReset = false

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

                            HStack {
                                Spacer()
                                Button {
                                    Task { @MainActor in
                                        await sendPasswordReset()
                                    }
                                } label: {
                                    if isSendingPasswordReset {
                                        ProgressView("Sending reset link…")
                                    } else {
                                        Text("Forgot password?")
                                    }
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TMStyle.blue)
                                .disabled(isSendingPasswordReset || isSigningIn || isAuthenticatingWithFaceID)
                            }

                            if !info.isEmpty {
                                Text(info)
                                    .font(.caption)
                                    .foregroundStyle(TMStyle.blue)
                            }

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

                            if app.faceIDEnabled {
                                let hasSavedSession = FirebaseService.shared.currentUserEmail != nil
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

                                        Text(hasSavedSession ? "Unlock saved account with Face ID" : "Face ID requires a saved sign-in")
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TMStyle.blue)
                                    .frame(maxWidth: .infinity)
                                }
                                .disabled(isSigningIn || isAuthenticatingWithFaceID || !hasSavedSession)
                                if !hasSavedSession {
                                    Text("Sign in successfully with your password, then use Lock with Face ID before returning here.")
                                        .font(.caption2)
                                        .foregroundStyle(TMStyle.muted)
                                        .multilineTextAlignment(.center)
                                        .frame(maxWidth: .infinity)
                                }
                            }

                            Button("Create an account") {
                                error = ""
                                app.route = role == .tutor
                                    ? .tutorOnboarding
                                    : .studentOnboarding
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TMStyle.blue)
                            .frame(maxWidth: .infinity)

                            Text("Sign in successfully once, enable Face ID in Settings, then choose Lock with Face ID instead of Sign out to use Face ID next time.")
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
        info = ""

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

            guard let profile = try await FirebaseService.shared.restoredProfile(),
                  profile.role == role else {
                throw FirebaseSetupError.roleMismatch
            }

            app.signIn(
                name: profile.name,
                email: profile.email,
                role: profile.role
            )
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func sendPasswordReset() async {
        error = ""
        info = ""
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleanEmail.contains("@"), cleanEmail.contains(".") else {
            error = "Enter the email address for your account, then select Forgot password."
            return
        }

        isSendingPasswordReset = true
        defer { isSendingPasswordReset = false }
        do {
            try await FirebaseService.shared.sendPasswordResetEmail(to: cleanEmail)
            info = "If an account uses this email, Firebase will send a password reset link. Check your inbox and spam folder."
        } catch {
            self.error = error.localizedDescription
        }
    }

    @MainActor
    private func signInWithFaceID() async {
        error = ""
        info = ""

        guard FirebaseService.shared.isConfigured else {
            error = "Firebase is not configured. Check GoogleService-Info.plist and restart the app."
            return
        }

        // Face ID confirms the identity of the account already signed in to
        // Firebase on this device. It cannot replace the first password sign-in
        // or recover a Firebase session after the user has signed out.
        guard let accountEmail = FirebaseService.shared.currentUserEmail else {
            error = "Sign in once with your email and password on this device before using Face ID."
            return
        }

        guard faceIDService.isAvailable else {
            error = faceIDService.unavailableMessage
                ?? "Face ID is unavailable. Set it up in device settings, then try again."
            return
        }

        isAuthenticatingWithFaceID = true

        let authenticated = await faceIDService.authenticate()

        isAuthenticatingWithFaceID = false

        guard authenticated else {
            error = "Face ID was cancelled or did not recognize you. Sign in with your password instead."
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

            guard let profile = try await FirebaseService.shared.restoredProfile(),
                  profile.role == role else {
                throw FirebaseSetupError.roleMismatch
            }

            app.signIn(
                name: profile.name,
                email: profile.email,
                role: profile.role
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

