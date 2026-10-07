# Operations runbook (Phase 9)

What is **automated and tested** is marked ✅ (with the command). What only a person with the real projects can do is marked 🔧.

## 1. Kill switch (stops AI spend)

- Turn off: set `config/runtime` → `cloudEnabled = false` in Firestore (console, or Admin SDK). `diagnose` reads it on **every call**, so it takes effect on the next request, not after a cache expires. The app then shows its offline/failure path (and falls back to the on-device model where it exists).
- Turn on: set it back to `true`.
- Clients cannot write `config/` (rules). ✅ `npm run test:e2e:drills --prefix firebase` (flips the switch, checks refusal, checks a client cannot flip it).
- Client-side companion: Remote Config `cloud_diagnosis_enabled = false` stops the app even trying (takes up to 12 h to reach phones; the server switch is the fast one).
- 🔧 Rehearse once on `stg` and write down who can do it at 2 a.m.

## 2. KB publish and rollback (no app release)

Publish: `node tools/kb_build/build.js --env prod && node tools/kb_build/publish.js --env prod --project <prod-id>`
(uploads `kb/kb_<seq>.json`, then moves `kb_versions/current`). Phones check at app start, verify the SHA-256 and schema, and swap the file atomically; open screens reload.

**Rollback of a bad entry** (wrong dose, wrong disease text): set that entry's `status` to `draft` (or delete it) in `kb/src`, bump `seq` in `kb/meta.json`, build for prod (drafts are excluded), publish. Phones move *forward* to the new seq; old history rows for that disease show the "entry removed" message instead of advice.
- ✅ `npm run test:e2e:drills --prefix firebase` runs publish → client reads pointer and verifies SHA-256 → republish of the same seq is refused → rollback publish → dev KB cannot go to prod. App side: `flutter test test/features/kb/kb_updater_test.dart` (tampered file, wrong hash, too-new schema, draft KB, hostile path, offline all refused with the live file untouched).
- Not covered by a KB rollback: the **Functions' candidate list** (`functions/src/kb_index.json`) still offers the hidden disease to the AI until the Functions are redeployed. The app shows such an id as "unknown", never as advice, so this is safe but redeploy soon after: `node tools/sync_functions_data.js && firebase deploy --only functions:diagnose`.
- Phones that never open the app, or are offline, keep the old KB until they connect. 🔧 Say so in the incident note.

## 3. Rotating the AI key (no downtime)

1. `firebase functions:secrets:set ANTHROPIC_API_KEY --project <id>` (creates a new secret version).
2. `firebase deploy --only functions:diagnose --project <id>`: a new revision binds the new version; traffic moves over when it is healthy, the old revision keeps serving until then.
3. Check one call succeeds; then revoke the old key at the provider and disable the old secret version.
🔧 Rehearse on `stg`. Not run from the dev sandbox.

## 4. App Check: monitor → enforce

- Today: `enforceAppCheck` is off unless `ENFORCE_APP_CHECK=true` is set at deploy (monitor mode). Stg/prod builds use Play Integrity, dev uses the debug provider.
- Plan: ship the internal-track build in monitor mode; for a week watch Firebase Console → App Check → *Functions* metrics: share of requests with a valid token. If ≥ ~95% of real users are verified, set `ENFORCE_APP_CHECK=true` in `functions/.env.<project>` and redeploy `diagnose` and `deleteMyData`. If a meaningful share is rejected (sideloaded APKs, rooted phones), decide **before launch**: distribute via Play only, or leave enforcement off and keep the daily cap and budget alerts tight (plan "Risk-driven Contingencies").
- The per-install daily cap (`DAILY_CAP`, default 30) and the kill switch bound spend either way.
- 🔧 Needs real Play-distributed installs; cannot be measured from the sandbox.

## 5. Rules and data review (checked in code)

| Area | Rule | Test |
|---|---|---|
| `users/{uid}/history` | owner only | `firebase/test/firestore.test.js` |
| `reports` | create-only, exact field list, `createdAt == request.time`, id starts with the caller's uid | same |
| `alerts`, `weather`, `kb_versions` | signed-in read, never write | same |
| `config`, `quotas`, `alerts/*/reporters` | denied to clients entirely (default deny) | same |
| Storage `backups/{uid}` | owner read/write, JPEG ≤ 1 MB | `firebase/test/storage.test.js` |
| Storage `contrib/{uid}` | write-once, no read, no delete | same |
| Storage `kb/` | signed-in read, no client write | same + drills e2e |
| App | `usesCleartextTraffic=false`, `allowBackup=false` (history stays out of Android auto-backup), obfuscated release build via `tools/release/build_aab.sh` | manifest |

Run: `npm run test:emulated --prefix firebase`.

## 6. Alerts and budget

`ops/setup_alerts.sh <project> <email> [billing-account] [budget]` creates log-based metrics (`diagnose_errors`, `diagnose_latency_ms`), two alert policies (errors > 5 in 5 min; p95 > 6 s for 10 min) and 50/90/100% budget alerts. `diagnose` writes one structured log line per call (`functions/src/diagnose.ts`, tested: no image, no uid, no free text). Expected refusals (bad input, daily cap, kill switch) are logged as INFO so they do not page anyone.
🔧 **Not run** (no GCP access here). Drill after running it: on `stg`, temporarily set a wrong `ANTHROPIC_API_KEY`, make a few calls, confirm the email arrives, restore the key. Also confirm budget emails by lowering the budget to a trivial amount for a day.

## 7. Analytics

Events (Design §16.2) are logged through `lib/core/analytics/analytics.dart`; tests assert names, parameters, and that no free text or image data is ever a parameter. 🔧 Verify in Firebase **DebugView** on a real device: `adb shell setprop debug.firebase.analytics.app com.nextgenai.mather_sathi.stg`. An opt-out switch is *not* built (Design says "consider"); decide with the privacy policy.

## 8. Incident procedure (from the plan)

1. Suspected unsafe advice: systemic → kill switch (§1); one disease → KB rollback (§2).
2. Tell the agronomist and affected pilot users through the support channel.
3. Root-cause (KB text, misclassification, UI), add a regression fixture, then re-enable.
