'use strict';
// End-to-end check for plan tasks 8.2/8.3 on the local emulators (Functions + Firestore + Auth + Storage), with the REAL
// rules: two installs upload history, a report and photos; one calls deleteMyData and ONLY their data disappears.
// Also: when a backup object is deleted (what the 30-day lifecycle rule does), onBackupDeleted clears `photoUrl`.
//
//   cd functions && npm run build && echo "ANTHROPIC_API_KEY=x" > .secret.local && cd ..
//   npx firebase-tools emulators:exec --only functions,firestore,auth,storage --project demo-krishi "node firebase/test/e2e/delete_e2e.js"
const { initializeApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, setDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
const { getStorage, connectStorageEmulator, ref, uploadBytes } = require('firebase/storage');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');
const districts = require('../../../assets/data/districts.json');

const PROJECT = 'demo-krishi';
const BUCKET = `${PROJECT}.appspot.com`;
const dhaka = districts.find((d) => d.slug === 'dhaka');
const upazila = `${dhaka.upazilas[0].id}`;
const WEEK = '2026-W41';
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function check(cond, msg) {
  if (!cond) throw new Error(`FAILED: ${msg}`);
  console.log(`ok - ${msg}`);
}
async function waitFor(fn, what, ms = 20000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`timed out waiting for ${what}`);
    await sleep(300);
  }
}

let n = 0;
async function install() {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake', storageBucket: BUCKET }, `install-${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const storage = getStorage(app);
  connectStorageEmulator(storage, '127.0.0.1', 9199);
  const functions = getFunctions(app, 'asia-south1');
  connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  const { user } = await signInAnonymously(auth);
  return { db, storage, functions, uid: user.uid };
}

async function populate(u) {
  await setDoc(doc(u.db, `users/${u.uid}/history/h1`), { crop_type: 'rice', disease_id: 'rice_blast', photoUrl: `backups/${u.uid}/h1.jpg` });
  await setDoc(doc(u.db, `reports/${u.uid}_${WEEK}_rice_rice_blast`), {
    uid: u.uid, district: 'dhaka', upazila, crop: 'rice', diseaseId: 'rice_blast', week: WEEK,
    createdAt: serverTimestamp(), expireAt: Timestamp.fromMillis(Date.now() + 30 * 864e5),
  });
  await uploadBytes(ref(u.storage, `backups/${u.uid}/h1.jpg`), JPEG, { contentType: 'image/jpeg' });
  await uploadBytes(ref(u.storage, `contrib/${u.uid}/h1.jpg`), JPEG, { contentType: 'image/jpeg' });
}
// Admin view (owner token bypasses the rules): reports are write-only for clients.
const REST = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const hasDoc = async (_u, path) => (await fetch(`${REST}/${path}`, { headers: { Authorization: 'Bearer owner' } })).status === 200;
const hasObject = async (_u, path) =>
  (await fetch(`http://127.0.0.1:9199/storage/v1/b/${BUCKET}/o/${encodeURIComponent(path)}`, { headers: { Authorization: 'Bearer owner' } })).status === 200;

(async () => {
  const [a, b] = [await install(), await install()];
  await populate(a);
  await populate(b);
  check(await hasDoc(a, `users/${a.uid}/history/h1`) && await hasObject(a, `backups/${a.uid}/h1.jpg`), 'both installs uploaded history, report and photos through the real rules');

  const anon = initializeApp({ projectId: PROJECT, apiKey: 'fake' }, 'anon');
  const anonFns = getFunctions(anon, 'asia-south1');
  connectFunctionsEmulator(anonFns, '127.0.0.1', 5001);
  let rejected = false;
  try { await httpsCallable(anonFns, 'deleteMyData')(); } catch (e) { rejected = e.code === 'functions/unauthenticated'; }
  check(rejected, 'an unauthenticated call is rejected');
  check(await hasDoc(b, `users/${b.uid}/history/h1`), 'and deletes nothing');

  const res = await httpsCallable(a.functions, 'deleteMyData')();
  check(res.data.ok === true && res.data.reports === 1, 'deleteMyData succeeded and counted the caller\'s report');

  check(!(await hasDoc(a, `users/${a.uid}/history/h1`)), 'caller history is gone');
  check(!(await hasDoc(a, `reports/${a.uid}_${WEEK}_rice_rice_blast`)), 'caller report is gone');
  check(!(await hasObject(a, `backups/${a.uid}/h1.jpg`)), 'caller backup photo is gone');
  check(!(await hasObject(a, `contrib/${a.uid}/h1.jpg`)), 'caller contributed photo is gone');

  check(await hasDoc(b, `users/${b.uid}/history/h1`), 'the other install\'s history is untouched');
  check(await hasDoc(b, `reports/${b.uid}_${WEEK}_rice_rice_blast`), 'the other install\'s report is untouched');
  check(await hasObject(b, `backups/${b.uid}/h1.jpg`) && await hasObject(b, `contrib/${b.uid}/h1.jpg`), 'the other install\'s photos are untouched');

  const again = await httpsCallable(a.functions, 'deleteMyData')();
  check(again.data.ok === true, 'deleting again (nothing left) is safe');

  // onBackupDeleted: what the lifecycle rule does after 30 days. Owner bearer token bypasses the rules in the emulator.
  const name = encodeURIComponent(`backups/${b.uid}/h1.jpg`);
  const del = await fetch(`http://127.0.0.1:9199/storage/v1/b/${BUCKET}/o/${name}`, { method: 'DELETE', headers: { Authorization: 'Bearer owner' } });
  check(del.ok, 'backup object deleted (simulating the 30-day lifecycle rule)');
  const cleared = await waitFor(async () => (await (await fetch(`${REST}/users/${b.uid}/history/h1`, { headers: { Authorization: 'Bearer owner' } })).json()).fields?.photoUrl === undefined, 'photoUrl to be cleared', 25000).catch(() => false);
  check(cleared, 'onBackupDeleted cleared photoUrl on the history doc');
  check(await hasDoc(b, `users/${b.uid}/history/h1`), 'and kept the history doc itself');

  console.log('delete end-to-end: all checks passed');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
