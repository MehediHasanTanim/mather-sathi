'use strict';
// Run with: npm run test:emulated  (starts the Firestore and Storage emulators)
const test = require('node:test');
const { before, after, beforeEach } = test;
const { assertSucceeds, assertFails } = require('@firebase/rules-unit-testing');
const { doc, getDoc, setDoc, updateDoc, deleteDoc, serverTimestamp, Timestamp, collection, getDocs } = require('firebase/firestore');
const { newEnv } = require('./helpers');

let env;
before(async () => { env = await newEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const asUser = (uid) => env.authenticatedContext(uid).firestore();
const anon = () => env.unauthenticatedContext().firestore();
const seed = (fn) => env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore()));

const weekAhead = () => Timestamp.fromMillis(Date.now() + 30 * 864e5);
const report = (uid, over = {}) => ({
  uid, district: 'dhaka', upazila: '5', crop: 'rice', diseaseId: 'rice_blast', week: '2026-W41',
  createdAt: serverTimestamp(), expireAt: weekAhead(), ...over,
});
const reportId = (uid) => `${uid}_2026-W41_rice_rice_blast`;

test.describe('users/{uid}/history', () => {
  test('the owner can read and write their own history', async () => {
    const db = asUser('alice');
    await assertSucceeds(setDoc(doc(db, 'users/alice/history/h1'), { disease_id: 'rice_blast' }));
    await assertSucceeds(getDoc(doc(db, 'users/alice/history/h1')));
    await assertSucceeds(updateDoc(doc(db, 'users/alice/history/h1'), { feedback: 'correct' }));
    await assertSucceeds(deleteDoc(doc(db, 'users/alice/history/h1')));
  });

  test('another user cannot read, write or list it', async () => {
    await seed((db) => setDoc(doc(db, 'users/alice/history/h1'), { disease_id: 'rice_blast' }));
    const bob = asUser('bob');
    await assertFails(getDoc(doc(bob, 'users/alice/history/h1')));
    await assertFails(setDoc(doc(bob, 'users/alice/history/h2'), { disease_id: 'x' }));
    await assertFails(updateDoc(doc(bob, 'users/alice/history/h1'), { feedback: 'incorrect' }));
    await assertFails(deleteDoc(doc(bob, 'users/alice/history/h1')));
    await assertFails(getDocs(collection(bob, 'users/alice/history')));
  });

  test('signed-out clients cannot touch history', async () => {
    await assertFails(getDoc(doc(anon(), 'users/alice/history/h1')));
    await assertFails(setDoc(doc(anon(), 'users/alice/history/h1'), { a: 1 }));
  });

  test('nothing else under users/{uid} is open (default deny)', async () => {
    await assertFails(setDoc(doc(asUser('alice'), 'users/alice'), { a: 1 }));
    await assertFails(setDoc(doc(asUser('alice'), 'users/alice/secrets/s1'), { a: 1 }));
  });
});

test.describe('reports: create-once, never readable', () => {
  test('a valid report can be created', async () => {
    await assertSucceeds(setDoc(doc(asUser('alice'), `reports/${reportId('alice')}`), report('alice')));
  });

  test('expireAt is capped: a far-future TTL is denied, a normal or slightly fast-clock one is allowed', async () => {
    const db = asUser('alice');
    await assertFails(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice', { expireAt: Timestamp.fromMillis(Date.now() + 365 * 864e5) })));
    await assertFails(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice', { expireAt: 'never' })));
    await assertSucceeds(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice', { expireAt: Timestamp.fromMillis(Date.now() + 45 * 864e5) })));
  });

  test('a second report for the same install, week, crop and disease is denied (the dedupe)', async () => {
    const db = asUser('alice');
    await assertSucceeds(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice')));
    await assertFails(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice')));
  });

  test('the doc id must start with the caller uid', async () => {
    await assertFails(setDoc(doc(asUser('alice'), `reports/${reportId('bob')}`), report('alice')));
    await assertFails(setDoc(doc(asUser('alice'), 'reports/random-id'), report('alice')));
  });

  test('the uid field must be the caller', async () => {
    await assertFails(setDoc(doc(asUser('alice'), `reports/${reportId('alice')}`), report('bob')));
  });

  test('createdAt must be the server time', async () => {
    await assertFails(setDoc(doc(asUser('alice'), `reports/${reportId('alice')}`), report('alice', { createdAt: Timestamp.fromMillis(1) })));
  });

  test('extra fields (e.g. a photo, a name) are rejected; missing fields too', async () => {
    await assertFails(setDoc(doc(asUser('alice'), `reports/${reportId('alice')}`), report('alice', { photoUrl: 'http://x', name: 'Alice' })));
    const { week, ...missing } = report('alice');
    await assertFails(setDoc(doc(asUser('alice'), `reports/${reportId('alice')}`), missing));
  });

  test('signed-out clients cannot report', async () => {
    await assertFails(setDoc(doc(anon(), `reports/${reportId('alice')}`), report('alice')));
  });

  test('nobody can read, update or delete a report, not even its author', async () => {
    const db = asUser('alice');
    await assertSucceeds(setDoc(doc(db, `reports/${reportId('alice')}`), report('alice')));
    await assertFails(getDoc(doc(db, `reports/${reportId('alice')}`)));
    await assertFails(getDocs(collection(db, 'reports')));
    await assertFails(updateDoc(doc(db, `reports/${reportId('alice')}`), { district: 'khulna' }));
    await assertFails(deleteDoc(doc(db, `reports/${reportId('alice')}`)));
  });
});

test.describe('server-written collections are read-only for signed-in clients', () => {
  for (const path of ['alerts/a1', 'weather/dhaka', 'kb_versions/current']) {
    test(`${path}: signed-in read ok, signed-out read denied, no client writes`, async () => {
      await seed((db) => setDoc(doc(db, path), { x: 1 }));
      await assertSucceeds(getDoc(doc(asUser('alice'), path)));
      await assertFails(getDoc(doc(anon(), path)));
      await assertFails(setDoc(doc(asUser('alice'), path), { x: 2 }));
      await assertFails(updateDoc(doc(asUser('alice'), path), { x: 2 }));
      await assertFails(deleteDoc(doc(asUser('alice'), path)));
    });
  }

  test('alerts can be listed by a signed-in client (the feed query)', async () => {
    await seed((db) => setDoc(doc(db, 'alerts/a1'), { district: 'dhaka', visible: true }));
    await assertSucceeds(getDocs(collection(asUser('alice'), 'alerts')));
  });
});

test.describe('everything else is denied by default', () => {
  for (const path of ['quotas/alice_2026-10-06', 'config/runtime', 'alerts/a1/reporters/alice', 'feedback/f1', 'anything/else']) {
    test(`${path}: no client read or write`, async () => {
      await seed((db) => setDoc(doc(db, path), { count: 1 }));
      await assertFails(getDoc(doc(asUser('alice'), path)));
      await assertFails(setDoc(doc(asUser('alice'), path), { count: 99 }));
      await assertFails(deleteDoc(doc(asUser('alice'), path)));
    });
  }

  test('a client cannot lift its own daily cap or flip the kill switch', async () => {
    await assertFails(setDoc(doc(asUser('alice'), 'quotas/alice_2026-10-06'), { count: 0, uid: 'alice' }));
    await assertFails(setDoc(doc(asUser('alice'), 'config/runtime'), { cloudEnabled: true }));
  });
});
