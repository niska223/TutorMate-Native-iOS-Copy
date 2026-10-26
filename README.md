# TutorMate Native iOS — SwiftUI + MVC

This is a native SwiftUI conversion starter based on the uploaded TutorMate web prototype.

## Screens represented
- Welcome / role selection
- Tutor sign-in and onboarding
- Student sign-in and onboarding
- Tutor dashboard, classes, students, attendance, payments, finance and settings
- Student home, classes, progress and profile
- NFC attendance demo flow
- WidgetKit-style in-app preview
- Separate sample WidgetKit extension source and XCTest examples

## Design
The UI uses the prototype's blue (`#2C73E8`), ink (`#172238`), pale canvas (`#F7F9FC`), rounded cards, soft accent colours and the two-role flow. The layouts are recreated in SwiftUI; some browser-specific CSS illustrations are approximated with SF Symbols and native SwiftUI shapes.

## Project-file repair status
The `.pbxproj` syntax was repaired after the Xcode parse error. The project file passes `plutil -lint`, and all Swift files pass a Swift parser check. These checks do **not** replace a build with Xcode; see `PROJECT_FILE_REPAIR.md` and complete the setup/test checklist below.

## Open in Xcode
1. Open `TutorMate.xcodeproj` on a Mac using Xcode 16 or later.
2. Select the `TutorMate` scheme, choose your iPhone/iPad simulator, then let Xcode resolve the Firebase Swift Package dependencies.
3. In **Signing & Capabilities**, choose your Apple development team and use a unique bundle identifier (the sample uses `com.example.TutorMate`).
4. For Firebase: create a project in the Firebase Console, register this iOS bundle ID, download `GoogleService-Info.plist`, and add it to the **TutorMate app target**. Enable **Email/Password** under Authentication. The sign-in screen uses Firebase Auth when the configuration file is present; otherwise it explicitly remains in demo mode.
5. Firestore attendance sync writes to the `attendance` collection. Create a Firestore database and configure secure rules before using real student data. The sample uses a demo identity for NFC attendance and must be replaced with the authenticated user's identity before production use.
6. For NFC, use a supported physical iPhone and an NDEF-formatted tag. Enable NFC Tag Reading capability if Xcode requests it. The app entitlement and usage description are included. NFC scans read the tag payload; attendance syncs to Firestore only when Firebase is configured.
7. Face ID is available from the sign-in screen. Add a device passcode/Face ID on the test device; simulator support can vary. Face ID verifies the device owner and is not a replacement for server authentication.
8. `TutorMateWidget` is a separate Widget Extension target. In Apple Developer / Xcode Signing & Capabilities, enable the App Groups capability for BOTH the app and widget and create/select `group.com.example.tutormate` (or change the same identifier in both entitlements and both Swift files). Build both targets, then add the widget from the iOS Home Screen. The app writes the next scheduled class to shared App Group storage and requests a WidgetKit timeline refresh whenever the sessions array changes.
9. Run the `TutorMateTests` test target. This package was generated in a non-macOS environment and **has not been compiled or tested in Xcode here**. You must open it on a Mac, resolve packages, configure signing/App Groups/Firebase, then build and run the app and test target before submission.

## Integration status and remaining setup
- **Xcode project:** `TutorMate.xcodeproj` is included, with app, Widget Extension, and unit-test targets.
- **Firebase:** Firebase SDK products are included and authentication/attendance service calls are wired. Your own `GoogleService-Info.plist`, Firebase Console setup, Firestore database and secure rules are required; those cannot be generated without access to your Firebase project. Without those, Firebase-backed sign-in and cloud attendance cannot be validated.
- **NFC:** real NDEF reader session is implemented, but requires supported physical hardware and a correctly formatted tag. It cannot be validated in this environment.
- **Face ID:** connected to the sign-in UI through LocalAuthentication; physical-device permission/device setup is required.
- **WidgetKit:** a separate extension target reads the next-class payload from shared App Group storage. The main app writes the payload and requests timeline reloads. App Groups must be enabled for both targets and WidgetKit refresh timing is still controlled by iOS.
- **Build verification:** not compiled or tested in Xcode. Please build and run the included test target on a Mac before treating it as submission-ready.

## MVC mapping
- Models: typed data structures for students, tutor, class sessions, attendance, payments, assessments and navigation
- Views: SwiftUI screen components and reusable visual components
- Controllers: app state and business actions, plus small feature controllers
- Services: integration boundaries for Firebase, notifications, NFC and Face ID

## Fixes for recent Xcode build errors

- `TutorRootView.swift`: removed the iOS-unavailable single-value `List(selection:)` initializer and changed the sidebar rows to buttons that update the selected section.
- `NFCService.swift`: marked NFC delegate callbacks `nonisolated`, moved service state updates onto `MainActor`, and applied `@preconcurrency` to the delegate conformance to accommodate SDK protocol isolation differences.
- `TutorMate.xcodeproj/project.pbxproj`: explicitly sets `ALWAYS_SEARCH_USER_PATHS = NO` and `USE_HEADERMAP = YES` for build configurations to avoid the legacy header-map setting warning.

These source/configuration fixes have been reviewed in this environment, but the project must still be built in Xcode to confirm compatibility with the installed Xcode and iOS SDK.
