# Final setup and validation checklist

## Required project-specific setup
- [ ] Open `TutorMate.xcodeproj` in Xcode on macOS and allow Swift Package Manager to resolve Firebase.
- [ ] Set unique bundle identifiers for the app and Widget Extension.
- [ ] Add `GoogleService-Info.plist` from your own Firebase project to the TutorMate app target.
- [ ] Enable Email/Password in Firebase Authentication. Create Firestore and configure restrictive security rules.
- [ ] In Apple Developer / Xcode Signing & Capabilities, enable App Groups for both targets and create/select `group.com.example.tutormate`; keep the identifier consistent in both entitlements and Swift files.
- [ ] Configure the NFC capability and Face ID usage description; use a supported physical iPhone for NFC and biometric tests.

## Test plan
- [ ] Build the TutorMate scheme for an iOS Simulator.
- [ ] Run the TutorMateTests test target.
- [ ] Sign in using a Firebase test account and confirm invalid credentials fail safely.
- [ ] Scan a valid NDEF tag on a compatible iPhone and confirm the correct signed-in student is recorded. Review the current demo identity handling before real-data use.
- [ ] Test Face ID success, cancellation, unavailable biometrics, and fallback sign-in.
- [ ] Add or change a class in the app; confirm the Home Screen widget updates after WidgetKit refresh.
- [ ] Build/archive with the intended signing team.

**Important:** source changes and project configuration are prepared, but this environment is not macOS and has no Xcode build tool. No successful Xcode build or physical-device test is claimed until the checklist is completed.
