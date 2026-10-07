#!/usr/bin/env node
'use strict';
// Publishes the built KB for over-the-air update (Design §5.4):
//   node tools/kb_build/build.js --env prod          # build (drafts excluded)
//   node tools/kb_build/publish.js --env prod --project <firebase-project-id> [--dry-run]
// Needs admin credentials (GOOGLE_APPLICATION_CREDENTIALS or `gcloud auth application-default login`), or the emulator
// env vars (FIRESTORE_EMULATOR_HOST, FIREBASE_STORAGE_EMULATOR_HOST). Uploads kb/kb_<seq>.json, then moves the pointer
// `kb_versions/current`. Clients verify the SHA-256 and the schema before using it.
// ROLLBACK: remove or unpublish the entry in kb/src, bump `seq` in kb/meta.json, build, publish. Clients move forward to the new seq.
const fs = require('node:fs');
const path = require('node:path');
const { planPublish } = require('./publish_lib');

const args = process.argv.slice(2);
const opt = (n, d) => { const i = args.indexOf(`--${n}`); return i >= 0 ? args[i + 1] : d; };
const env = opt('env', 'dev');
const project = opt('project');
const kbFile = path.resolve(opt('kb', path.join(__dirname, '../../assets/kb/kb.json')));

(async () => {
  if (!project) throw new Error('--project <firebase project id> is required');
  const fromFunctions = (m) => require(require.resolve(m, { paths: [path.join(__dirname, '../../functions')] })); // firebase-admin lives with the Functions
  const { initializeApp } = fromFunctions('firebase-admin/app');
  const { getFirestore } = fromFunctions('firebase-admin/firestore');
  const { getStorage } = fromFunctions('firebase-admin/storage');
  initializeApp({ projectId: project, storageBucket: opt('bucket', `${project}.appspot.com`) });
  const db = getFirestore();

  const kbJson = fs.readFileSync(kbFile, 'utf8');
  const cur = (await db.doc('kb_versions/current').get()).data();
  const plan = planPublish({ kbJson, env, current: cur ? { seq: cur.seq } : null });
  if (plan.errors.length) {
    for (const e of plan.errors) console.error(`publish: ${e}`);
    process.exit(1);
  }
  console.log(`publish: ${project} seq ${cur?.seq ?? '-'} -> ${plan.pointer.seq}, sha256 ${plan.pointer.sha256}`);
  if (args.includes('--dry-run')) return console.log('publish: dry run, nothing written');

  await getStorage().bucket().file(plan.object.path).save(kbJson, { contentType: plan.object.contentType, resumable: false });
  await db.doc('kb_versions/current').set(plan.pointer); // last: clients only see the new pointer once the file exists
  console.log('publish: done');
})().catch((e) => { console.error(`publish: ${e.message}`); process.exit(1); });
