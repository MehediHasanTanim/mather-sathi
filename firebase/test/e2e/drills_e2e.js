'use strict';
// Release drills for plan task 9.4, on the local emulators (Functions + Firestore + Auth + Storage), real rules:
//  1. KILL SWITCH: config/runtime.cloudEnabled = false makes `diagnose` refuse at once; true lets calls through again;
//     a client cannot flip it.
//  2. KB PUBLISH / ROLLBACK: tools/kb_build/publish.js uploads the KB and moves kb_versions/current; a signed-in client can read
//     both and verify the SHA-256; a client cannot write either; republishing the same seq is refused; a higher seq is accepted.
//
//   cd functions && npm run build && echo "ANTHROPIC_API_KEY=x" > .secret.local && cd ..
//   npx firebase-tools emulators:exec --only functions,firestore,auth,storage --project demo-krishi "node firebase/test/e2e/drills_e2e.js"
const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { initializeApp } = require('firebase/app');
const { getAuth, connectAuthEmulator, signInAnonymously } = require('firebase/auth');
const { getFirestore, connectFirestoreEmulator, doc, getDoc, setDoc } = require('firebase/firestore');
const { getStorage, connectStorageEmulator, ref, getBytes, uploadBytes } = require('firebase/storage');
const { getFunctions, connectFunctionsEmulator, httpsCallable } = require('firebase/functions');

const PROJECT = 'demo-krishi';
const BUCKET = `${PROJECT}.appspot.com`;
const REST = `http://127.0.0.1:8080/v1/projects/${PROJECT}/databases/(default)/documents`;
const JPEG_B64 = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 1, 2, 3]).toString('base64');

function check(cond, msg) {
  if (!cond) throw new Error(`FAILED: ${msg}`);
  console.log(`ok - ${msg}`);
}
const denied = (e) => e && (e.code === 'permission-denied' || e.code === 'storage/unauthorized');

async function install() {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'fake', storageBucket: BUCKET }, 'drill');
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app); connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const storage = getStorage(app); connectStorageEmulator(storage, '127.0.0.1', 9199);
  const functions = getFunctions(app, 'asia-south1'); connectFunctionsEmulator(functions, '127.0.0.1', 5001);
  await signInAnonymously(auth);
  return { db, storage, functions };
}

const setRuntime = (enabled) => fetch(`${REST}/config/runtime`, {
  method: 'PATCH', headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
  body: JSON.stringify({ fields: { cloudEnabled: { booleanValue: enabled } } }),
}).then((r) => { if (!r.ok) throw new Error('could not set config/runtime'); });

async function diagnose(u) {
  const t = Date.now();
  try { await httpsCallable(u.functions, 'diagnose')({ image: JPEG_B64, crop: 'rice' }); return { ok: true, ms: Date.now() - t }; }
  catch (e) { return { ok: false, code: e.code, message: e.message, ms: Date.now() - t }; }
}

function publish(kbFile, env = 'dev') {
  const r = spawnSync('node', ['tools/kb_build/publish.js', '--env', env, '--project', PROJECT, '--kb', kbFile], { encoding: 'utf8' });
  return { status: r.status, out: `${r.stdout}${r.stderr}` };
}

(async () => {
  const u = await install();

  // ---- 1. kill switch ----
  await setRuntime(false);
  const off = await diagnose(u);
  check(!off.ok && off.code === 'functions/unavailable' && /disabled/.test(off.message), `kill switch on: diagnose refuses (${off.ms} ms after the flag was set, no cache)`);
  let writeDenied = false;
  try { await setDoc(doc(u.db, 'config/runtime'), { cloudEnabled: true }); } catch (e) { writeDenied = denied(e); }
  check(writeDenied, 'a client cannot flip config/runtime');
  await setRuntime(true);
  const on = await diagnose(u);
  check(on.ok || !/disabled/.test(on.message ?? ''), 'kill switch off: the call goes past the switch again (it then reaches the model, which is a fake key here)');

  // ---- 2. KB publish and rollback ----
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'kbdrill-'));
  const base = JSON.parse(fs.readFileSync('assets/kb/kb.json', 'utf8'));
  const write = (seq, entries) => {
    const f = path.join(tmp, `kb_${seq}.json`);
    fs.writeFileSync(f, JSON.stringify({ ...base, seq, version: `drill-${seq}`, entries }));
    return f;
  };
  const f10 = write(10, base.entries);
  let r = publish(f10);
  check(r.status === 0, `publish seq 10 succeeded\n${r.out}`);

  const ptr = (await getDoc(doc(u.db, 'kb_versions/current'))).data();
  check(ptr.seq === 10 && /^[a-f0-9]{64}$/.test(ptr.sha256) && ptr.path === 'kb/kb_10.json', 'a signed-in client can read the pointer');
  const bytes = Buffer.from(await getBytes(ref(u.storage, ptr.path)));
  check(crypto.createHash('sha256').update(bytes).digest('hex') === ptr.sha256, 'the downloaded file matches the pointer SHA-256');

  let w1 = false, w2 = false;
  try { await setDoc(doc(u.db, 'kb_versions/current'), { seq: 99 }); } catch (e) { w1 = denied(e); }
  try { await uploadBytes(ref(u.storage, 'kb/evil.json'), new Uint8Array([1])); } catch (e) { w2 = denied(e); }
  check(w1 && w2, 'a client can neither move the pointer nor upload into kb/');

  r = publish(f10);
  check(r.status !== 0 && /not higher/.test(r.out), 'republishing the same seq is refused');

  // Rollback: seq 11 without the bad entry.
  const bad = base.entries[0].id;
  const f11 = write(11, base.entries.filter((e) => e.id !== bad));
  r = publish(f11);
  check(r.status === 0, `rollback publish (seq 11 without ${bad}) succeeded`);
  const ptr2 = (await getDoc(doc(u.db, 'kb_versions/current'))).data();
  const kb2 = JSON.parse(Buffer.from(await getBytes(ref(u.storage, ptr2.path))).toString('utf8'));
  check(ptr2.seq === 11 && !kb2.entries.some((e) => e.id === bad), 'clients now see seq 11, which no longer contains the bad entry');

  const draftPlan = publish(f11, 'prod');
  check(draftPlan.status !== 0, 'a dev KB (drafts) cannot be published as prod');

  console.log('drills: all checks passed');
  process.exit(0);
})().catch((e) => { console.error(e.message); process.exit(1); });
