# TutorMate Firestore Manual Security Review

**Review type: manual/static review only.** This is not automated rules validation. The proposed rules have not been compiled by Firebase or run in Emulator tests. Do not publish them on the basis of this checklist. `FIRESTORE_RULES.txt` is the active file and must remain separate.

## Collections and proposed permissions

| Path | Tutor | Student | Unauthenticated |
| --- | --- | --- | --- |
| `users/{uid}` | Tutor profiles and the tutor Auth custom claim must be provisioned by trusted Admin SDK code. A user reads/updates their own profile; no delete. | Can self-create a `student` profile and read/update only their own profile. UID, email, role, creation time and link are immutable from the client. | Denied. |
| `students/{studentId}` | Create/read/update records where `tutorId` is the signed-in tutor. Delete only while unlinked. IDs, tutor ownership, creation time and student account link cannot be changed by ordinary client updates. | Read only the student record linked on both sides to the signed-in UID; no writes. | Denied. |
| `classes/{classId}` | CRUD own classes, preserving owner and identity on updates. | Read a class only when a valid assignment for their linked account exists. | Denied. |
| `studentClassAssignments/{uid_classId}` | Create/read/update/delete assignments only for their own class and student records and matching trusted account link. | Read only assignments whose UID and student record match their own link. No writes. | Denied. |
| `attendance/{attendanceId}` | Create/read/update validated manual attendance for owned student/class and valid assignment. Delete denied. | Read own linked attendance only. Cannot write or delete. | Denied. |
| `payments/{paymentId}` | Create/read/update/delete validated payment records belonging to their tutor and student. | Read own linked payment only. Cannot write or delete. | Denied. |

The rules have no broad catch-all grant; unmatched paths are denied by Firestore. Tutor list queries need `tutorId == auth.uid`. Student assignment queries need both `studentUserId == auth.uid` and the linked `studentRecordId`; attendance/payment queries need `studentUserId == auth.uid` and `studentId == the linked record ID`. The client obtains class IDs from its own assignment results and fetches those class documents individually.

## Access scenarios to review

### Tutors

- Tutor A reads and writes Tutor A's students/classes/attendance/payments: allow only with profile role and trusted tutor custom claim, matching `tutorId`, valid fields, and valid relationships.
- Tutor A reads or changes Tutor B data: deny.
- Tutor A changes a document ID, tutor owner, linked student UID, student ID, class ID, or immutable creation timestamp: deny.
- Tutor A deletes their own payment: allowed by this proposal. Deleting another tutor's payment: denied. Tutor attendance deletion: denied.

### Students

- Student A reads their own `/users/{uid}` profile and linked student record: allow after trusted two-sided linking.
- Student A reads Student B profile/record, an unassigned class, or another student's assignment/attendance/payment: deny.
- Student A reads their assigned class, own assignment, own attendance and own payments: intended to allow with the required query filters and a verified link.
- Student A creates or changes assignments, attendance, payment amounts/status, or ownership/link fields: deny.

### Unauthenticated

All protected reads and writes should be denied. Check `get`, `list`, `create`, `update` and `delete`; do not infer write protection from a denied read.

## Ownership, validation, and privacy concerns

- The draft requires a tutor profile role and `request.auth.token.role == 'tutor'`; profile role alone cannot grant tutor access. Trusted backend provisioning is required.
- Account linking is a two-sided relation (`users.studentRecordId` and `students.studentUserId`); normal clients cannot set either field. The planned trusted linking design is in [FIREBASE_STUDENT_ACCOUNT_LINKING_PLAN.md](FIREBASE_STUDENT_ACCOUNT_LINKING_PLAN.md).
- Assignment, attendance and payment rules verify tutor ownership and linked student IDs. Check ID equality and each relationship independently in manual scenarios.
- Student document reads return the entire document. Firestore rules cannot hide selected fields. Enabling a student read would expose that student's `phone`, score, attendance rate and paid flag; separate tutor-only fields before granting student document reads if any should remain private.
- Class deletion does not cascade to top-level assignment documents. App/backend deletion must remove assignments first and should detect orphaned assignments.
- The active rules still rely on a profile's `role` for tutor authorization and let a user create their own profile with either role. This is a privilege-escalation risk in the active rules. A client-only fix cannot secure it; backend role provisioning and an approved rules change are required.
- Current Student, Payment and Attendance Swift models/payloads do not fully carry the proposal's linked IDs/assignment schema. The proposal is not ready to apply without code and data migration.

## Manual Firebase Console checks

These steps are for a **separate disposable Firebase project** only. Never use the TutorMate production project for a manual review. Do not publish rules during this checklist.

1. In Firebase Console, create/select a dedicated test project. Confirm its project ID in Project settings. Do not use the project configured by the app or `tutor-mate-b7556`.
2. Enable Authentication and Firestore only in the test project. Create test-only tutor A/B and student A/B accounts. Student accounts should be linked only through the trusted backend design; do not fake a trusted link from the app client.
3. Create synthetic Firestore fixtures with distinct owner UIDs and IDs: `users`, `students`, `classes`, `studentClassAssignments`, `attendance`, and `payments`. Use the fields/types in the proposal and do not copy production data.
4. Open Firestore Database → Rules and inspect the proposal in a scratch/test project. If using Rules Playground/Simulator, first confirm it evaluates the unsaved draft. If it only simulates currently published rules, do not publish the draft just to test it; stop and use Emulator tests instead.
5. For unauthenticated context, simulate read/list/create/update/delete on each collection; expect denial.
6. For Tutor A, simulate own-document reads/writes and Tutor B cross-owner reads/writes. Expect only owned, valid operations to succeed. Try changing each owner and immutable ID field; expect denial.
7. For student A, simulate own profile and linked record reads; then Student B and unassigned record reads. Expect only own records to be readable. Try own assigned class, another class, and own/other assignments.
8. Simulate student attendance/payment list requests with both required UID and record-ID filters; try a query missing either filter. Expect the constrained query to be allowed and the under-constrained query to be denied. The Console simulator may not prove query behavior reliably; confirm with Emulator unit tests before approval.
9. Attempt student assignment/attendance/payment writes and deletes; expect denial. Attempt tutor attendance deletion (deny), deletion of a linked student (deny), deletion of another tutor's payment (deny), and deletion of own tutor payment (allowed by proposal).
10. Try missing required fields, extra fields, string payment amount, zero/negative amount, invalid status, bad timestamp, negative class count, and out-of-range attendance rate. Expect denial.
11. Close without publishing. Recheck the project ID before deleting test fixtures. Record each attempted operation and observed result, including simulator limitations.

The Console simulator is a manual spot-check, not a substitute for Rules Unit Testing. It does not establish transaction safety for account linking, invitation replay protection, concurrency behavior, or reliable query-proof coverage. Do not mark a scenario passed unless it was actually performed and observed.

## Current disposition

Static review only. No Firebase Console checks, emulator runs, rules compilation, live Firebase operations, or production changes were performed for this document. Before approval, complete isolated emulator tests, backend account-link tests, Swift schema/query work, migration planning, and a review of the final complete rule set.
