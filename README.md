# TutorMate

TutorMate is a SwiftUI iOS application for private tutors to manage student records, classes, attendance and fee records. It also includes a WidgetKit extension, biometric sign-in option, NFC attendance flow and local class reminders.

## Features and current status

- Firebase email/password registration and sign-in with tutor/student role profiles. A saved Firebase session is restored from the user's Firestore profile when the app launches.
- Tutor student CRUD and tutor-owned class CRUD use Firestore and stable UUID document IDs.
- Tutor attendance supports Present, Absent and Late. Its document ID is derived from student ID, class ID and date to make same-day writes idempotent.
- Tutor payment records are loaded from Firestore; create, edit and paid/unpaid status updates are supported. Payment deletion is denied by the current rules.
- Student accounts can read and update their own `users/{uid}` display profile. Student class, attendance, payment, assessment and assignment screens intentionally show access-unavailable states under the active rules; they do not display sample records.
- Face ID is an optional local biometric gate/setting; Firebase remains the account authentication authority.
- NFC scans require a physical supported iPhone and a text NDEF payload formatted `tutormate:v1:<class UUID>:<student UUID>`.
- Local reminders can be enabled in tutor settings. Reminders are scheduled 15 minutes before class time and keyed by class ID.
- The WidgetKit extension reads the app's shared App Group payload. It displays real tutor data when available; student assignment data is unavailable until secure assignments are implemented.

Student account linking, student-specific assigned class/attendance/payment reads, and payment-to-student ID relationships are not yet active. The current Firestore rules do not authorize those operations. Student account linking and tutor-role provisioning require a trusted backend; see `FIREBASE_STUDENT_ACCOUNT_LINKING_PLAN.md`. `FIRESTORE_RULES_PROPOSED.txt` is a review proposal only; it has not been deployed or approved. `FIRESTORE_MANUAL_REVIEW.md` is a manual/static checklist, not evidence that rules compile or pass automated tests. The active rules also let a user self-select the `tutor` profile role; this must be addressed by trusted role provisioning and an approved security-rule change before treating tutor authorization as robust.

## Technologies

Swift, SwiftUI, MVC-style separation, Firebase Authentication, Cloud Firestore, WidgetKit, App Groups, LocalAuthentication, Core NFC, UserNotifications, and XCTest.

## MVC structure

- `Models/`: typed student, class, attendance, payment and route models.
- `Views/`: authentication, tutor/student dashboards, feature screens and reusable UI components.
- `Controllers/`: app state and feature action coordination.
- `Services/`: Firebase, NFC, Face ID and notification integrations.
- `Widgets/TutorMateWidget/`: WidgetKit extension and shared payload storage model.
- `Tests/`: XCTest target and business-logic tests.

## Firebase setup

1. Open `TutorMate.xcodeproj` in Xcode and resolve the checked-in Swift Package Manager dependencies.
2. Register the app bundle identifier in your Firebase project and include the matching `GoogleService-Info.plist` in the TutorMate app target.
3. Enable Email/Password in Firebase Authentication and create a Cloud Firestore database.
4. Review `FIRESTORE_RULES.txt` carefully and deploy only the rules you have approved. Tutor CRUD and reads depend on a user profile with role `tutor` and records with matching `tutorId`.
5. Student-linked access requires a secure account-linking flow and approved rule changes. The app does not currently establish the link, so student-facing private records remain unavailable.

Collections currently used are `users`, `students`, `classes`, `attendance`, and `payments`. Tutor records are scoped by `tutorId`. Attendance documents also contain `studentId`, `classId`, date, status and record type. Current payment documents identify a student by display name only because the active rule schema does not permit a stable student ID field.

## NFC setup

Use an NFC-capable physical iPhone with NFC enabled and a compatible NDEF text tag. For the current tutor scan flow, encode `tutormate:v1:<class UUID>:<student UUID>` using IDs of records saved under that tutor. The scanner rejects mismatched payloads and reports success only after the Firestore attendance write returns. NFC cannot be validated in the iOS Simulator.

## Face ID

Use a device with Face ID/Touch ID enrolled and a device passcode enabled. The app includes the `NSFaceIDUsageDescription` privacy text. Biometric success does not create or replace a Firebase session.

## WidgetKit and App Groups

The app and extension share `group.com.example.tutormate`. Ensure that App Group is enabled for both signed targets in Xcode and registered for the Apple Developer team. Build and install the app, then add the TutorMate widget from the Home Screen widget gallery. iOS controls actual refresh timing.

## Local notifications

Class reminders are local notifications, not remote push. Enable Class Reminders in tutor settings and grant notification permission. Valid class times use a format such as `4:00 PM`. Updating or deleting a class reschedules or cancels its reminder. APNs/Firebase Cloud Messaging is not configured here.

## Run and test

Open `TutorMate.xcodeproj`, select the `TutorMate` scheme and a concrete iOS Simulator, then build/run. For command-line verification without signing:

```sh
xcodebuild -project TutorMate.xcodeproj -scheme TutorMate \
  -destination 'platform=iOS Simulator,id=<SIMULATOR-UDID>' \
  CODE_SIGNING_ALLOWED=NO build
```

Run tests by selecting the `TutorMateTests` scheme/target in Xcode or using the same concrete simulator destination with `test`. The suite uses XCTest because no coursework brief specifying another framework was present in the repository. Tests do not contact live Firebase.

## Known limitations and physical testing

- Current Firestore rules deny student reads of assigned classes, attendance and payments; they also deny payment deletion. Student assignment and student-ID payment linking need an approved secure rule/schema change and a trusted account-linking workflow.
- The student dashboard still contains sample presentation values and must not be represented as live student data.
- Verify Firebase account creation, tutor CRUD and data persistence with a test Firebase project and test accounts.
- Verify NFC scanning with a physical iPhone and correctly encoded NDEF tags.
- Verify biometric success/cancel/unavailable paths on a device or supported simulator configuration.
- Verify notification permission, delivery while backgrounded, rescheduling and cancellation on a device.
- Verify App Group entitlement and widget refresh on a signed installation.
- Accessibility should be reviewed with VoiceOver and larger text sizes on an iPhone before submission.

## Submission checklist

- Provide the official coursework brief and map components/learning outcomes to evidence; it is not included in this repository.
- Run the full test target on an installed concrete simulator and preserve the result.
- Complete Firebase Emulator/Console rule tests and obtain approval before deploying proposed security changes.
- Perform physical-device NFC, biometric, notification, widget and accessibility checks.
- Add screenshots, report, narrated demonstration and viva notes required by the actual coursework brief.
- Archive/zip only the project and required coursework materials; exclude DerivedData and private credentials.
