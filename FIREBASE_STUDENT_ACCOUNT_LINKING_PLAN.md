# TutorMate Student Account Linking and Role Provisioning Plan

**Design only. No Cloud Functions, credentials, or production data have been created or changed.** The client must not be allowed to set `users/{uid}.studentRecordId`, `students/{studentId}.studentUserId`, a tutor custom claim, or invitation state.

## Target records

- `users/{uid}`: Firebase UID, display name, verified email, immutable role; for a linked student, `studentRecordId`.
- `students/{studentId}`: tutor-owned student record; after a verified link, `studentUserId`.
- `studentInvitations/{tokenHash}`: private, one-use backend record with student record ID, tutor UID, normalized invite email, expiry, creation time, and redeemed state. Store only the hash of the random secret.

The link is valid only when both sides agree: `users/{uid}.studentRecordId == studentId` and `students/{studentId}.studentUserId == uid`. These fields are set together by trusted Admin SDK code. Do not match or authorize accounts by display name alone.

## Invitation creation

1. An authenticated tutor requests an invitation for a student record they own. The backend independently checks the caller's tutor custom claim/profile and reads the record to confirm `tutorId == caller UID`.
2. Generate at least 32 bytes of cryptographically secure random token material. Email a link containing the secret to the address already on the tutor-owned student record. Avoid putting student PII in the URL.
3. Store only a cryptographic hash of the token as the invitation document ID. Bind the invitation to `tutorId`, `studentRecordId`, normalized expected email, `expiresAt` (short lifetime, e.g. 24 hours), `createdAt`, and `redeemedAt: null`.
4. Rate-limit invitations per tutor/record/email, avoid revealing whether arbitrary email addresses have accounts, and log only non-secret audit metadata. Resending should revoke prior active invitations for the same record.

## Student redemption

1. Student creates or signs into Firebase Authentication, then completes Firebase email verification. A callable Function must use the verified Firebase ID token, not an email/UID supplied by the client.
2. Client sends the invitation secret to the callable over authenticated TLS. The Function hashes it and looks up the invitation; compare expected email to the authenticated user's verified email using normalized addresses.
3. In a Firestore transaction, read invitation, user profile, and student record. Require: invitation exists, is unexpired and unused; record still belongs to the invitation tutor; student record email still matches; profile role is student; neither side is linked to a different UID/record; caller has no conflicting link.
4. In the same transaction, set `users/{auth.uid}.studentRecordId`, set `students/{studentId}.studentUserId`, and mark the invitation redeemed with `redeemedAt` and `redeemedByUid`. Admin SDK bypasses rules, so every precondition must be checked in function code. Firestore transaction retries ensure two concurrent redeems cannot both succeed.
5. Return a generic success or safe failure. The client then refreshes its own profile from `/users/{uid}`. Never return a list of records, other student IDs, invitation hashes, or tutor data.

An expired or redeemed token is rejected. Replaying the same token, using it from a different email/UID, redeeming a record owned by another tutor, or relinking either side must fail. Provide an Admin-only unlink/recovery workflow with audit logging rather than allowing a student/tutor client to overwrite a link.

## Tutor role provisioning

Tutor role is privileged. Do not let onboarding choose `role: tutor` and thereby grant access. A trusted operator or controlled backend admin process should:

1. Verify the tutor identity and authorization outside the ordinary client.
2. Use Firebase Admin SDK to set the profile role to `tutor` and the Auth custom claim `role: tutor` for the same UID.
3. Ensure no public callable accepts an arbitrary UID or lets a tutor grant claims to another account. Admin operations should be IAM-protected or require an existing, separately provisioned administrator claim.
4. Ask the user to refresh their ID token after provisioning; test both profile and token claim checks.

The proposed rules require both the user profile role and the Auth custom claim. Current iOS onboarding writes profile roles from the client and has no claim provisioning. It will need a reviewed signup/invitation flow before those proposed rules can be used.

## Cloud Functions layout (not implemented)

- `createStudentInvitation`: callable, requires tutor authorization; verifies student ownership; creates/replaces one-use invitation and sends email through an approved provider.
- `redeemStudentInvitation`: callable, requires authenticated, email-verified student; performs the transaction above.
- `provisionTutor`: Admin-only operator procedure or privileged administrative backend action; sets role profile and Auth custom claim.
- Optional scheduled cleanup: remove expired invitation documents; TTL is cleanup only and must not replace expiry validation in redemption.

## Required backend tests before deployment

Use Firebase Emulator Suite plus Functions/Auth emulators in a separate demo project. Test valid redemption, wrong email, unverified email, wrong UID, expired/redeemed/replayed token, simultaneous redemption, tutor A linking tutor B's student, already-linked records, student attempting tutor provisioning, ordinary tutor attempting custom-claim provisioning, and retry/error recovery. Verify logs and email content do not expose tokens or unrelated student data. Review App Check/rate limits and IAM before any production rollout.
