'use strict';
// End-to-end check for plan task 7.7, on the local emulators (Functions + Firestore + Auth), with the REAL security rules:
// three anonymous installs report the same disease in the same upazila -> one alert becomes visible and exactly one push
// is "sent" (recorded in _emulator_outbox, since nothing can be delivered from an emulator). A repeat and a fourth report
// change nothing about the push.
//
//   cd functions && npm run build && echo "ANTHROPIC_API_KEY=x" > .secret.local && cd ..
//   npx firebase-tools emulators:exec --only functions,firestore,auth --project demo-krishi "node firebase/test/e2e/alerts_e2e.js"
const { initializeApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, setDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
const districts = require('../../../assets/data/districts.json');

const PROJECT = 'demo-krishi';
const dhaka = districts.find((d) => d.slug === 'dhaka');
const upazila = `${dhaka.upazilas[0].id}`;
const WEEK = '2026-W41';
const REST = 'http://127.0.0.1:8080/v1/projects/demo-krishi/databases/(default)/documents';

let n = 0;
async function install() {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake' }, `install-${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const { user } = await signInAnonymously(auth);
  return { db, uid: user.uid };
}

const report = (uid) => ({
  uid, district: 'dhaka', upazila, crop: 'rice', diseaseId: 'rice_blast', week: WEEK,
  createdAt: serverTimestamp(), expireAt: Timestamp.fromMillis(Date.now() + 30 * 864e5),
});
const reportId = (uid) => `${uid}_${WEEK}_rice_rice_blast`;

async function admin(path) {
  const r = await fetch(`${REST}/${path}`, { headers: { Authorization: 'Bearer owner' } });
  return r.json();
}
const num = (d, f) => Number(d?.fields?.[f]?.integerValue ?? 0);
const bool = (d, f) => d?.fields?.[f]?.booleanValue;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitFor(fn, what, ms = 20000) {
  const end = Date.now() + ms;
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() > end) throw new Error(`timed out waiting for ${what}`);
    await sleep(300);
  }
}
function check(cond, msg) {
  if (!cond) throw new Error(`FAILED: ${msg}`);
  console.log(`ok - ${msg}`);
}
const outbox = async () => ((await admin('_emulator_outbox')).documents ?? []);

(async () => {
  const alertDoc = `alerts/dhaka_${upazila}_rice_rice_blast_${WEEK}`;
  const users = [await install(), await install(), await install()];
  check(new Set(users.map((u) => u.uid)).size === 3, 'three distinct anonymous installs');

  for (const u of users) await setDoc(doc(u.db, `reports/${reportId(u.uid)}`), report(u.uid));
  check(true, 'three reports accepted by the security rules');

  const alert = await waitFor(async () => {
    const d = await admin(alertDoc);
    return num(d, 'count') === 3 ? d : null;
  }, 'alert count = 3');
  check(bool(alert, 'visible') === true, 'alert is visible at the third distinct install');

  const pushes = await waitFor(async () => {
    const o = await outbox();
    return o.length >= 1 ? o : null;
  }, 'the push');
  check(pushes.length === 1, 'exactly one push for the alert');
  check(pushes[0].fields.topic.stringValue === 'd_dhaka', 'push goes to the district topic d_dhaka');
  check(pushes[0].fields.route.stringValue === '/alerts', 'push deep-links to /alerts');

  let denied = false;
  try { await setDoc(doc(users[0].db, `reports/${reportId(users[0].uid)}`), report(users[0].uid)); } catch (e) { denied = e.code === 'permission-denied'; }
  check(denied, 'a repeat report from the same install in the same week is denied by the rules');

  const fourth = await install();
  await setDoc(doc(fourth.db, `reports/${reportId(fourth.uid)}`), report(fourth.uid));
  const after = await waitFor(async () => {
    const d = await admin(alertDoc);
    return num(d, 'count') === 4 ? d : null;
  }, 'alert count = 4');
  check(bool(after, 'visible') === true, 'still visible after a fourth report');
  await sleep(1500);
  check((await outbox()).length === 1, 'a fourth report does not send a second push');
  console.log('alert end-to-end: all checks passed');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
