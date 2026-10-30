# Firestore Security Rules Review and Test Report

**Status: review draft only. No rules were deployed and `FIRESTORE_RULES.txt` was not modified.**

## Emulator test setup attempt (2026-10-30)

Created an isolated harness in `firestore-rules-tests/` using project ID `demo-tutormate-rules-test`, a Firestore-only emulator on `127.0.0.1:8080`, and a preparation script that copies the current proposal into the emulator rules path immediately before a test run. Added 14 Rules Unit Testing scenarios covering tutor ownership, student isolation, assignments, attendance, payments, malformed writes, and deletes.

Environment found: Node.js `v24.14.1`; npm `11.11.0`; no usable Java runtime (`java -version` reports “Unable to locate a Java Runtime”); Firebase CLI is not installed. The Firebase Emulator Suite requires Java JDK 11 or higher ([Firebase installation requirements](https://firebase.google.com/docs/emulator-suite/install_and_configure)).

Dependency installation was attempted, but requests to `https://registry.npmjs.org/` failed with `ECONNRESET`; the Firebase CLI and npm packages were not installed. Running `npm test` then stopped before emulator startup with `sh: firebase: command not found`. The rules preparation script did run and loaded the proposal file.

**Automated results: 0 passed, 0 failed, 14 not executed.** The test runner never started, so no test failures are attributed to the rules. The emulator did not start, and the proposal's Rules syntax has not been compiled. A Node syntax check of the JavaScript test files passed; this does not validate Firestore rules.

### Follow-up environment diagnosis

- Host: Apple Silicon macOS (`arm64`, macOS 26.5.1).
- Node/npm: Node.js `v24.14.1`, npm `11.11.0`.
- Java: no JDK registered in `/Library/Java/JavaVirtualMachines` or the user's Java directory; `/usr/libexec/java_home -V` and `java -version` report no runtime. `JAVA_HOME` is unset. Firebase documents JDK 11+ for the Emulator Suite.
- Package managers checked: Homebrew, MacPorts, mise, asdf, Nix, Conda/Mamba, and pkgx are absent. The account is not in the macOS `admin` group.
- Firebase CLI: absent. No dependencies were installed and no `package-lock.json` was generated.
- npm registry: configured to the official `https://registry.npmjs.org/`; proxy and HTTPS proxy are unset; TLS strict mode is enabled. System proxy configuration is empty. Normal `npm ping` failed with `ENOTFOUND registry.npmjs.org`; an unsandboxed permitted retry failed with `ECONNRESET`. This indicates registry DNS/network egress is unavailable/reset in this environment, not an incorrect npm registry or configured proxy. No mirror was used and TLS was not weakened.
- Emulator/tests: `npm test` ran the rules-copy preparation step and then stopped with `sh: firebase: command not found`. The emulator did not start. Results remain **0 passed, 0 failed, 14 not executed**. No proposed-rule test failure was observed because the test runner did not launch.

### Manual steps needed to resume

1. With an administrator or approved installer, install an Apple Silicon JDK 17 package from Eclipse Temurin (or another trusted JDK distributor). A user-local JDK archive can avoid changing system settings if the platform policy permits it. In the terminal used for tests, verify with `java -version` and set `JAVA_HOME` for that session using `/usr/libexec/java_home -v 17`.
2. Restore access to the official npm registry (or use the organization-approved proxy configuration). Do not use an untrusted registry mirror or disable TLS checks.
3. Run `cd /Users/student1/Downloads/TutorMate_Native_MVC/firestore-rules-tests`, then `npm install`, then `npm test`.
4. Provide the resulting test output if registry/JDK access must be performed by an administrator; until then the 14 tests remain unexecuted.

## Test environment and result

The app checkout has no Firebase Emulator configuration at its root. The isolated `firestore-rules-tests/` harness now contains its own `firebase.json`, `.firebaserc`, `package.json`, and test file. `GoogleService-Info.plist` identifies the app's configured Firebase project; it was not used for testing. The demo project ID is not a real Firebase project and no production Firebase operation was run.

**No automated Firestore rules scenario ran.** Therefore the proposed rules have not passed the security tests, and their Rules-language compilation is unverified. The scenario results below are all **Not run**; expected outcomes are the intended policy, not observed emulator results.

## Existing active-rule permissions

| Collection | Existing active permissions |
| --- | --- |
| `users/{uid}` | An authenticated user can read their own profile, create/update it with validated fields and immutable UID/email/role/createdAt, and cannot delete it. Profile creation currently lets the client choose `tutor` or `student`. |
| `students/{id}` | Tutor role is read from `users/{auth.uid}.role`; tutors can create/read/update/delete documents whose `tutorId` is their UID. Students cannot read these documents under the active rules. Updates preserve tutorId and document id, but do not preserve createdAt. |
| `classes/{id}` | Tutors can create/read/update/delete their own classes. Updates preserve tutorId, id, and createdAt. Students have no access. |
| `attendance/{id}` | Tutors can create validated manual records or the legacy NFC scan-event shape, read records with their tutorId, and update manual records. Deletes are denied. Students have no access. Manual writes verify the student and class tutorId ownership. |
| `payments/{id}` | Tutors can create/read/update records with their tutorId. Deletes are denied. There are no studentId or studentUserId fields in the active schema, so records are not securely linked to a student. Students have no access. |

Ownership checks use the authenticated UID and stored `tutorId`; `ownsStudent` and `ownsClass` read the referenced documents. Tutor authorization itself currently relies only on a client-writable profile role, so a user can self-create a tutor profile. This is an important privilege-escalation weakness in the current design and is corrected in the proposal by requiring a trusted Firebase Auth custom claim as well as a tutor profile.

## Proposed-rule changes made in this review

Only `FIRESTORE_RULES_PROPOSED.txt` was changed.

- Tutor authorization now requires both the profile role and an Admin-SDK-provisioned `request.auth.token.role == 'tutor'` claim. Client self-registration can create student profiles only; it cannot grant a tutor role or set `studentRecordId`.
- Replaced nested class assignment documents with a top-level `studentClassAssignments` collection. Its `studentUserId` allows the student's query to be constrained to their own assignments. Class reads remain per-document after fetching those assignment results.
- Assignment IDs are deterministic (`<student auth UID>_<class document ID>`), and assignment writes validate the tutor's ownership of the class and student record plus the trusted link between the student record and Auth UID.
- Attendance validation now checks that its assignment document belongs to the same student record and tutor, in addition to checking record ownership.
- Added nonnegative and bounded validation for student attendance rate, and nonnegative validation for class student count.
- Kept attendance deletion denied. Tutor payment deletion remains allowed by the proposal, unlike the active rules.

## Scenario matrix

| Scenario | Expected | Actual |
| --- | --- | --- |
| Tutor A reads/writes own students, classes, attendance, payments | Allow according to collection policy and validated fields | Not run; no emulator/test harness |
| Tutor A reads Tutor B records | Deny | Not run |
| Tutor A changes another tutor's owner fields | Deny | Not run |
| Student A reads own profile and linked student record | Allow after trusted link is provisioned | Not run |
| Student A reads Student B profile/records | Deny | Not run |
| Student reads only their assigned classes | Allow via own assignment query, then direct class gets | Not run |
| Student reads own attendance/payment history | Allow with query constrained by `studentUserId == auth.uid` and `studentId == users/{uid}.studentRecordId` | Not run |
| Student creates/updates/deletes attendance or payments | Deny | Not run |
| Unauthenticated protected reads/writes | Deny | Not run |
| Student self-assigns to class or changes either side of account link | Deny | Not run |
| Invalid tutor/student/class relationships | Deny | Not run |
| Student manipulates payment amount/status/ownership | Deny | Not run |
| Attendance deletion | Deny | Not run |
| Tutor payment deletion | Allow only for a payment owned by that tutor | Not run |

## Compatibility findings and required migration

The proposal does not match the current app payloads yet:

- `Student` and its Firebase writes have no `studentUserId`. The proposed student document requires that field (null for unlinked records); student update currently rebuilds fields and would need to preserve it. Tutor clients must never set or change a non-null link.
- `users/{uid}` currently has no `studentRecordId`; the profile save code cannot set it under the proposal. The trusted linking backend must write it.
- `Payment` has no student document ID. `savePayment`, `updatePayment`, and payment decoding currently use `studentName` only. The proposal requires both `studentId` and `studentUserId`; UI/controller/service/model changes are required.
- `saveAttendanceRecord` writes no `studentUserId` and has no assignment check. It must add the trusted linked UID and verify/require an assignment before writing. Its deterministic ID is consistent with the proposal's attendance ID field.
- The NFC scan-event method writes the active-rule `nfc_scan` event shape. The proposal intentionally permits only linked manual attendance records, so that legacy scan-event write will be denied. NFC should record attendance through the manual attendance payload after tutor-selected student/class validation, or the event logging schema must be separately reviewed and proposed.
- There is no `studentClassAssignments` read/write code. Add tutor assignment CRUD using stable IDs and filter student assignment reads by both `studentUserId == Auth.auth().currentUser.uid` and the linked `studentRecordId`. Student attendance/payment queries must filter by both `studentUserId` and the linked `studentId`. Fetch each resulting class by document ID; the class rule is a per-document assignment check, not a general student class-list query.
- Existing student, class, attendance, and payment reads query by `tutorId == current UID`, matching the tutor query conditions in the proposal. There are no student queries yet.
- Existing student/class/attendance/payment documents need a migration. Add nullable `studentUserId` to student records; link only after verified account linking. Add `studentId` and `studentUserId` to payments only after matching a stable student document ID. Backfill tutorId/document IDs and check timestamps/types before deploying strict validation. Existing attendance needs linked IDs and valid assignment documents before student access; never infer identity from names alone.
- The proposal uses a top-level assignment collection, so existing assignment data (if any) must be migrated to `studentClassAssignments` and checked for deterministic IDs and correct tutor ownership. No production records were inspected or modified as part of this review.
- Deleting a class does not cascade-delete assignment documents in Firestore. The app/backend must remove assignments first, and migration/testing should detect orphaned assignments.

## Trusted account and role linking

Yes, secure linking needs a trusted backend. Neither students nor ordinary tutor clients should be allowed to write `studentRecordId` or `studentUserId`. A suitable Cloud Function/Admin SDK flow should:

1. Let a tutor request an invitation for an existing student record. The backend creates a high-entropy, one-time, expiring invitation bound to that record, tutor UID, and expected email; store only a hash of its secret.
2. Require the student to authenticate and verify the expected email. A callable function verifies the invitation, authenticated UID, email verification, tutor ownership, unexpired/unused state, and that neither record is already linked.
3. In a Firestore transaction, consume the invitation and set both `users/{uid}.studentRecordId` and `students/{studentId}.studentUserId`; reject conflicts and retries that bind another account.
4. Provision tutor roles out of band, setting the tutor profile and Firebase Auth custom claim through Admin SDK. Refresh the user's ID token after a claim change.

Admin SDK bypasses Firestore rules, so the function must enforce these checks itself, be rate-limited, and be tested for replay, wrong-email, cross-tutor, and concurrent-link attempts. No such backend exists in the inspected project.

## Exact isolated Emulator test setup

Install a JDK 11 or higher and restore npm registry access. Then, from the isolated test folder, run:

```sh
cd /Users/student1/Downloads/TutorMate_Native_MVC/firestore-rules-tests
npm install
npm test
```

The harness is configured with demo project `demo-tutormate-rules-test`; `npm test` copies the current proposal into its configured rules path and runs `firebase emulators:exec --only firestore --project demo-tutormate-rules-test "node --test test/*.test.js"`. It does not invoke `firebase use` or reference the app project. Add allow/deny assertions for every row in the scenario matrix, plus assignment removal, unlinked student, and orphan assignment cases. First compile/load the rules in the emulator; do not treat static inspection as a substitute. Emulator tests do not verify production deployment behavior or the Admin SDK function.

## Before approval

1. Implement and test trusted tutor-role provisioning and student account linking.
2. Migrate/back up and validate existing documents in a non-production copy.
3. Update Swift models, FirebaseService queries/payloads, and assignment workflows to the new schema.
4. Run the isolated Emulator suite and resolve every failure; separately test Cloud Function authorization and replay protection.
5. Review the final complete rules and migration plan. Only then should the active rules be considered for approval/deployment.
