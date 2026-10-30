import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import test, { before, beforeEach, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where
} from 'firebase/firestore';

const here = path.dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(path.resolve(here, '..', 'firestore.rules'), 'utf8');
const projectId = 'demo-tutormate-rules-test';
let env;

const ids = {
  tutorA: 'tutor-a', tutorB: 'tutor-b', studentA: 'student-a', studentB: 'student-b',
  recordA: 'record-a', recordB: 'record-b', classA: 'class-a', classAUnassigned: 'class-a-unassigned',
  classB: 'class-b', paymentA: 'payment-a', paymentB: 'payment-b', attendanceA: 'attendance-a', attendanceB: 'attendance-b'
};
const assignmentId = (uid, classId) => `${uid}_${classId}`;
const stamp = new Date('2026-01-15T10:00:00.000Z');

function tutorDb(uid = ids.tutorA) {
  return env.authenticatedContext(uid, { role: 'tutor', email: `${uid}@example.test` }).firestore();
}
function studentDb(uid = ids.studentA) {
  return env.authenticatedContext(uid, { email: `${uid}@example.test` }).firestore();
}
function pathRef(db, collectionName, id) { return doc(db, collectionName, id); }

function user(uid, role, studentRecordId) {
  return { uid, displayName: uid, email: `${uid}@example.test`, role, createdAt: stamp,
    ...(studentRecordId ? { studentRecordId } : {}) };
}
function student(id, tutorId, studentUserId) {
  return { id, name: id, email: `${id}@example.test`, grade: 'Year 10', phone: '',
    attendanceRate: 90, score: 80, paid: false, tutorId, createdAt: stamp, studentUserId };
}
function classRecord(id, tutorId) {
  return { id, title: id, subject: 'Maths', date: stamp, time: '10:00', duration: '1 hour',
    location: 'Room 1', students: 1, tutorId, createdAt: stamp };
}
function assignment(uid, recordId, tutorId, classId) {
  return { studentUserId: uid, studentRecordId: recordId, tutorId, classId, createdAt: stamp };
}
function attendance(id, recordId, uid, tutorId, classId) {
  return { id, studentId: recordId, studentUserId: uid, studentName: recordId, classId,
    className: classId, date: stamp, status: 'Present', tutorId, recordType: 'manual',
    createdAt: stamp, updatedAt: stamp };
}
function payment(id, recordId, uid, tutorId, amount = 25) {
  return { id, studentId: recordId, studentUserId: uid, studentName: recordId,
    description: 'Tuition', amount, date: stamp, isPaid: false, tutorId,
    createdAt: stamp, updatedAt: stamp };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId,
    firestore: { rules, host: '127.0.0.1', port: 8080 }
  });
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async context => {
    const db = context.firestore();
    const fixtures = [
      ['users', ids.tutorA, user(ids.tutorA, 'tutor')],
      ['users', ids.tutorB, user(ids.tutorB, 'tutor')],
      ['users', ids.studentA, user(ids.studentA, 'student', ids.recordA)],
      ['users', ids.studentB, user(ids.studentB, 'student', ids.recordB)],
      ['students', ids.recordA, student(ids.recordA, ids.tutorA, ids.studentA)],
      ['students', ids.recordB, student(ids.recordB, ids.tutorB, ids.studentB)],
      ['classes', ids.classA, classRecord(ids.classA, ids.tutorA)],
      ['classes', ids.classAUnassigned, classRecord(ids.classAUnassigned, ids.tutorA)],
      ['classes', ids.classB, classRecord(ids.classB, ids.tutorB)],
      ['studentClassAssignments', assignmentId(ids.studentA, ids.classA), assignment(ids.studentA, ids.recordA, ids.tutorA, ids.classA)],
      ['studentClassAssignments', assignmentId(ids.studentB, ids.classB), assignment(ids.studentB, ids.recordB, ids.tutorB, ids.classB)],
      ['attendance', ids.attendanceA, attendance(ids.attendanceA, ids.recordA, ids.studentA, ids.tutorA, ids.classA)],
      ['attendance', ids.attendanceB, attendance(ids.attendanceB, ids.recordB, ids.studentB, ids.tutorB, ids.classB)],
      ['payments', ids.paymentA, payment(ids.paymentA, ids.recordA, ids.studentA, ids.tutorA)],
      ['payments', ids.paymentB, payment(ids.paymentB, ids.recordB, ids.studentB, ids.tutorB)]
    ];
    for (const [name, id, data] of fixtures) await setDoc(doc(db, name, id), data);
  });
});

after(async () => { await env?.cleanup(); });

test('Tutor can read own records and list by tutorId', async () => {
  const db = tutorDb();
  for (const [name, id] of [['students', ids.recordA], ['classes', ids.classA],
    ['attendance', ids.attendanceA], ['payments', ids.paymentA]]) {
    await assertSucceeds(getDoc(pathRef(db, name, id)));
    const ownQuery = query(collection(db, name), where('tutorId', '==', ids.tutorA));
    const results = await assertSucceeds(getDocs(ownQuery));
    assert.ok(results.docs.every(item => item.data().tutorId === ids.tutorA));
  }
});

test('Tutor cannot read another tutor profile, student, class, attendance, or payment', async () => {
  const db = tutorDb();
  for (const [name, id] of [['users', ids.tutorB], ['students', ids.recordB], ['classes', ids.classB],
    ['attendance', ids.attendanceB], ['payments', ids.paymentB]]) {
    await assertFails(getDoc(pathRef(db, name, id)));
  }
});

test('Tutor cannot change ownership fields or mutate another tutor records', async () => {
  const db = tutorDb();
  await assertFails(updateDoc(pathRef(db, 'students', ids.recordA), { tutorId: ids.tutorB }));
  await assertFails(updateDoc(pathRef(db, 'students', ids.recordA), { studentUserId: ids.studentB }));
  await assertFails(updateDoc(pathRef(db, 'classes', ids.classA), { tutorId: ids.tutorB }));
  await assertFails(updateDoc(pathRef(db, 'attendance', ids.attendanceA), { tutorId: ids.tutorB }));
  await assertFails(updateDoc(pathRef(db, 'payments', ids.paymentA), { tutorId: ids.tutorB }));
  await assertFails(updateDoc(pathRef(db, 'students', ids.recordB), { name: 'stolen' }));
  await assertFails(updateDoc(pathRef(db, 'payments', ids.paymentB), { amount: 0.01 }));
});

test('Tutor can create valid owned student, class, assignment, attendance, and payment records', async () => {
  const db = tutorDb();
  await assertSucceeds(setDoc(pathRef(db, 'students', 'record-new'), student('record-new', ids.tutorA, null)));
  await assertSucceeds(setDoc(pathRef(db, 'classes', 'class-new'), classRecord('class-new', ids.tutorA)));
  const assigned = assignment(ids.studentA, ids.recordA, ids.tutorA, ids.classAUnassigned);
  await assertSucceeds(setDoc(pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classAUnassigned)), assigned));
  await assertSucceeds(setDoc(pathRef(db, 'attendance', 'attendance-new'), attendance('attendance-new', ids.recordA, ids.studentA, ids.tutorA, ids.classA)));
  await assertSucceeds(setDoc(pathRef(db, 'payments', 'payment-new'), payment('payment-new', ids.recordA, ids.studentA, ids.tutorA)));
});

test('Student can read own profile and linked student record only', async () => {
  const db = studentDb();
  await assertSucceeds(getDoc(pathRef(db, 'users', ids.studentA)));
  await assertSucceeds(getDoc(pathRef(db, 'students', ids.recordA)));
  await assertFails(getDoc(pathRef(db, 'users', ids.studentB)));
  await assertFails(getDoc(pathRef(db, 'students', ids.recordB)));
});

test('Student can read an assigned class but not another or an unassigned class', async () => {
  const db = studentDb();
  await assertSucceeds(getDoc(pathRef(db, 'classes', ids.classA)));
  await assertFails(getDoc(pathRef(db, 'classes', ids.classAUnassigned)));
  await assertFails(getDoc(pathRef(db, 'classes', ids.classB)));
});

test('Student can list only own assignments, attendance, and payments', async () => {
  const db = studentDb();
  const assignments = await assertSucceeds(getDocs(query(collection(db, 'studentClassAssignments'),
    where('studentUserId', '==', ids.studentA), where('studentRecordId', '==', ids.recordA))));
  assert.equal(assignments.size, 1);
  const attendanceRecords = await assertSucceeds(getDocs(query(collection(db, 'attendance'),
    where('studentUserId', '==', ids.studentA), where('studentId', '==', ids.recordA))));
  assert.equal(attendanceRecords.size, 1);
  const payments = await assertSucceeds(getDocs(query(collection(db, 'payments'),
    where('studentUserId', '==', ids.studentA), where('studentId', '==', ids.recordA))));
  assert.equal(payments.size, 1);
  await assertFails(getDoc(pathRef(db, 'attendance', ids.attendanceB)));
  await assertFails(getDoc(pathRef(db, 'payments', ids.paymentB)));
});

test('Student cannot modify or delete attendance, payments, students, or assignments', async () => {
  const db = studentDb();
  await assertFails(updateDoc(pathRef(db, 'students', ids.recordA), { name: 'Changed' }));
  await assertFails(updateDoc(pathRef(db, 'attendance', ids.attendanceA), { status: 'Absent' }));
  await assertFails(deleteDoc(pathRef(db, 'attendance', ids.attendanceA)));
  await assertFails(updateDoc(pathRef(db, 'payments', ids.paymentA), { amount: 1 }));
  await assertFails(deleteDoc(pathRef(db, 'payments', ids.paymentA)));
  await assertFails(setDoc(pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classAUnassigned)),
    assignment(ids.studentA, ids.recordA, ids.tutorA, ids.classAUnassigned)));
  await assertFails(deleteDoc(pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classA))));
});

test('Student cannot change their profile role or student record link', async () => {
  const db = studentDb();
  await assertFails(updateDoc(pathRef(db, 'users', ids.studentA), { role: 'tutor' }));
  await assertFails(updateDoc(pathRef(db, 'users', ids.studentA), { studentRecordId: ids.recordB }));
  await assertFails(setDoc(pathRef(db, 'users', 'self-promoted'), user('self-promoted', 'tutor')));
});

test('Unauthenticated reads and writes to protected collections are denied', async () => {
  const db = env.unauthenticatedContext().firestore();
  await assertFails(getDoc(pathRef(db, 'students', ids.recordA)));
  await assertFails(getDoc(pathRef(db, 'classes', ids.classA)));
  await assertFails(getDoc(pathRef(db, 'attendance', ids.attendanceA)));
  await assertFails(getDoc(pathRef(db, 'payments', ids.paymentA)));
  await assertFails(setDoc(pathRef(db, 'students', 'anonymous'), student('anonymous', ids.tutorA, null)));
});

test('Invalid assignment ownership and student-to-tutor relationships are rejected', async () => {
  const db = tutorDb();
  const invalid = assignment(ids.studentA, ids.recordB, ids.tutorA, ids.classA);
  await assertFails(setDoc(pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classA)), invalid));
  const wrongTutor = assignment(ids.studentA, ids.recordA, ids.tutorB, ids.classA);
  await assertFails(setDoc(pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classA)), wrongTutor));
  const wrongKey = assignment(ids.studentA, ids.recordA, ids.tutorA, ids.classA);
  await assertFails(setDoc(pathRef(db, 'studentClassAssignments', 'arbitrary-id'), wrongKey));
});

test('Invalid field sets and data types are rejected', async () => {
  const db = tutorDb();
  await assertFails(setDoc(pathRef(db, 'students', 'bad-student'), { ...student('bad-student', ids.tutorA, null), attendanceRate: '90' }));
  await assertFails(setDoc(pathRef(db, 'students', 'extra-field'), { ...student('extra-field', ids.tutorA, null), private: true }));
  await assertFails(setDoc(pathRef(db, 'classes', 'bad-class'), { ...classRecord('bad-class', ids.tutorA), students: -1 }));
  await assertFails(setDoc(pathRef(db, 'payments', 'bad-amount'), payment('bad-amount', ids.recordA, ids.studentA, ids.tutorA, -2)));
  await assertFails(setDoc(pathRef(db, 'payments', 'bad-type'), { ...payment('bad-type', ids.recordA, ids.studentA, ids.tutorA), amount: '25' }));
  await assertFails(setDoc(pathRef(db, 'attendance', 'bad-status'), { ...attendance('bad-status', ids.recordA, ids.studentA, ids.tutorA, ids.classA), status: 'Excused' }));
});

test('Deletes follow proposal: attendance denied, linked student denied, own tutor payment allowed', async () => {
  const db = tutorDb();
  await assertFails(deleteDoc(pathRef(db, 'attendance', ids.attendanceA)));
  await assertFails(deleteDoc(pathRef(db, 'students', ids.recordA)));
  await assertFails(deleteDoc(pathRef(db, 'payments', ids.paymentB)));
  await assertSucceeds(deleteDoc(pathRef(db, 'payments', ids.paymentA)));
});

test('Tutor cannot change assignment student, class, or ownership fields', async () => {
  const db = tutorDb();
  const ref = pathRef(db, 'studentClassAssignments', assignmentId(ids.studentA, ids.classA));
  await assertFails(updateDoc(ref, { studentUserId: ids.studentB }));
  await assertFails(updateDoc(ref, { studentRecordId: ids.recordB }));
  await assertFails(updateDoc(ref, { classId: ids.classB }));
  await assertFails(updateDoc(ref, { tutorId: ids.tutorB }));
});
