# Phase 3 runbook: KB, `diagnose()` and the M1 walking skeleton

## What exists
| Piece | Where | Check |
|---|---|---|
| KB sources, schema, validator, compiler | `kb/`, `tools/kb_build/` | `node --test tools/kb_build/test/*.test.js` |
| Dev seed KB (4 **draft** entries: rice, potato) | `kb/src/*.json` → `assets/kb/kb.json`, `functions/src/kb_index.json` | `node tools/kb_build/build.js --env dev --check` |
| `diagnose()` callable, quota, kill switch, classifier, general advice | `functions/src/` | `npm test --prefix functions` |
| Eval harness | `tools/eval/` | `tools/eval/README.md` |
| App: KB models/repository, cloud client, `DiagnosisService`, temporary result view | `lib/features/{kb,diagnosis}/` | `flutter test` |

Drafts exist only in **dev** builds: `kb_build --env stg|prod` drops them, and CI proves it. Until a named agronomist reviews entries and
they are published (`status: published`, with `source`, `reviewed_by`, `reviewed_at`), **`stg` and `prod` have an empty KB**, so the M1 demo below
runs against the `dev` environment. The app shows a "not reviewed" banner whenever the loaded KB contains drafts, and never shows medicine
placeholders.

## Rebuilding the KB
```bash
node tools/kb_build/build.js --env dev        # writes assets/kb/kb.json and functions/src/kb_index.json (commit both)
node tools/sync_functions_data.js             # districts.json into functions/src (commit)
```
Bump `kb/meta.json` `seq` for every content change. For release, `--env prod` and upload `kb.json` + SHA-256 per Design §5.

## M1 demo option A: local emulators (no Blaze plan needed)
```bash
cd functions && npm ci && npm run build && echo "ANTHROPIC_API_KEY=sk-ant-..." > .secret.local   # never commit
cd .. && npx firebase-tools emulators:start --only functions,auth,firestore --project krishi-dev-fdea4
# phone on the same Wi-Fi: use this machine's LAN IP (emulator: 10.0.2.2)
flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=<lan-ip>
```
Pick rice or potato, take a photo, tap "বিশ্লেষণ করুন": the result view shows the KB entry for the returned `disease_id`.
(The dev flavor allows cleartext HTTP so the app can reach the emulators.)

## M1 demo option B / task 3.10: deployed Functions (needs the Blaze plan)
```bash
firebase functions:secrets:set ANTHROPIC_API_KEY --project <project-id>
firebase deploy --only functions,firestore:rules,firestore:indexes --project <project-id>
# Firestore TTL for server-written collections
for c in quotas reports alerts reporters; do
  gcloud firestore fields ttls update expireAt --collection-group=$c --enable-ttl --project <project-id>
done
```
Optional per-environment settings go in `functions/.env.<project-id>`: `DAILY_CAP=30`, `VISION_MODEL=claude-haiku-4-5`,
`ENFORCE_APP_CHECK=true` (leave unset = monitor mode until the rejection rate is known, task 9.4).
Set the `config/runtime` Firestore document `{cloudEnabled: true}`; `false` is the server-side kill switch.

**Latency under a 3G-like profile** (task 3.10): on an emulator, `emulator -avd <name> -netspeed umts -netdelay umts`; run 20+ diagnoses and read
`diagnosis_completed.latency_ms` (Analytics) or the Functions logs; record p95 here. The app's client timeout is 8 s; a higher p95 means
shrinking the image or re-checking the region/`minInstances`.

## Model choice
`VISION_MODEL` defaults to `claude-haiku-4-5` (Design §7.2, cheapest). The request adapts to the model: forced tool use where supported,
`auto` + `strict` on newer models that reject forced `tool_choice`, and no sampling parameters on models that reject them.
Run `tools/eval` on real field photos before choosing a model (task 9.1).

## Verified locally (emulators, fake API key)
No auth → `UNAUTHENTICATED`; non-JPEG / bad crop → `INVALID_ARGUMENT`; valid request reaches the provider (`UNAVAILABLE` with a fake key);
31st call of the day → `RESOURCE_EXHAUSTED`; `config/runtime.cloudEnabled=false` → `UNAVAILABLE`. A real model call has **not** been exercised.

---

# Phase 5 notes: history, sync, rules

## Sync (task 5.4, 5.5)
`SyncService.flush()` pushes, per pending history row and in order: the history doc (`users/{uid}/history/{id}`, metadata only), then the
regional report (`reports/{uid}_{week}_{crop}_{disease}`). It runs at app start, when connectivity returns, and after each saved diagnosis,
never overlaps itself (a call during a run queues one more pass), never throws, and leaves failed rows pending. A repeat report in the same
week is denied by the create-only rules; that denial is treated as "already reported". Photo upload (backup/contribution) arrives with 8.2.

## Rules (task 5.6): run the emulator tests
```bash
npm install --prefix firebase
npm run test:emulated --prefix firebase     # starts the Firestore + Storage emulators (needs Java), 31 tests
```
Writing the tests found two gaps, both fixed: report docs only had a `hasOnly` field check (so a report missing `week` was accepted;
now `hasAll` too), and `contrib/` was not provably write-once (now `allow write: if resource == null && ...`).

Deploy to staging (manual, needs the Blaze plan and `firebase login`):
```bash
firebase deploy --only firestore:rules,firestore:indexes,storage --project <stg-project-id>
```
Then confirm in the console that **Firestore → Rules** and **Storage → Rules** show today's version.

## Failure handling and the 8 s budget (task 5.2, 5.3)
Sign-in plus the cloud call share one 8-second budget (`DiagnosisService.cloudBudget`), because "connected" is not "reachable". When it runs
out the result is a `CloudTimeout`, which falls back to the on-device model when one exists (Phase 6). Rejected-service problems and unexpected
errors are logged to Crashlytics through `ErrorReporter`; timeouts and the daily cap are expected and are not.

---

# Phase 6 notes: offline model

**No trained model exists yet, so the app is still cloud-only.** Everything around the model is built and tested; the model itself is
the open dependency (field dataset, M1-M7 in the plan). See `docs/model-handoff.md` for the file contract, how to validate a handoff,
and the device checklist.

What was verified here, without a model: the file contract and validators, crop-masked scoring on fixed vectors, preprocessing parity
against a Python reference (JPEG decode bit-identical to PIL; both resize modes within one 8-bit step), the classifier with a fake runner
(lazy and single-flight load, retry after a failed load, memory-pressure release), the fallback matrix with the real classifier, and the
offline label/caveat on the result screen. **Not verified:** the TFLite native library, real inference, latency, the 32-bit device, APK size.
`tflite_flutter` was added to `pubspec.yaml`; it has not been built for Android here, so a Gradle problem is possible.

## Phase 7 — alerts, weather, notifications

- Server: `aggregateReports` (Firestore trigger on `reports/*`, visible at >= `ALERT_THRESHOLD` distinct installs, default 3, one push per alert) and `refreshWeather` (scheduled 06:00 and 14:00 Asia/Dhaka).
- Emulator end-to-end: `npm run test:e2e --prefix firebase` (run with proxy env vars unset in restricted sandboxes).
- NOT verified: real FCM delivery, the live Open-Meteo API (host blocked in the dev sandbox; parser written from the documented shape), Android channel/permission changes on a device.
- Open: Open-Meteo free tier is non-commercial (plan O6, check terms or move to a paid plan). All shipped weather rules are `draft` with placeholder thresholds and stay inactive until the agronomist signs them off (K6).

## Phase 8 — settings, privacy, expert, share

- **Server:** `deleteMyData` (callable, erases `users/{uid}`, the caller's `reports/`, `backups/{uid}/`, `contrib/{uid}/`) and `onBackupDeleted` (clears `photoUrl` when a backup object is deleted). Both are deployed with the other functions.
- **Lifecycle (needs the real bucket, not verified here):** `gsutil lifecycle set firebase/lifecycle.json gs://<bucket>` for each of dev/stg/prod. Then confirm in `stg` that a lifecycle deletion fires `onBackupDeleted`. The emulator test deletes the object by API, which proves the handler, not that GCS lifecycle deletions emit the event. If they do not, add a daily scan (plan task 8.2).
- **Emulator end-to-end:** `npm run test:e2e:delete --prefix firebase` (same prerequisites as `test:e2e`: `npm run build --prefix functions` and a `functions/.secret.local`; run with the proxy variables unset in a restricted sandbox).
- **Remote Config to set before launch (plan O4):** `helpline_number`, `helpline_hours_text`, `helpline_note`, and `helpline_schedule` in the form `Sat,Sun,Mon,Tue,Wed,Thu 09:00-17:00` (Asia/Dhaka). With no schedule the open/closed badge is simply not shown. The press-reported 16123 / hours / charge are unverified; the baked-in default is the number only.
- **What leaves the device (Design §15.2), as implemented:** diagnosis photo → Function → AI (every online diagnosis); history metadata → Firestore; regional report fields (no photo/name) → `reports/` when the toggle is on (default on); photo → `backups/` only when backup is on, → `contrib/` only when contribution is on (both default off). Photos are uploaded only for diagnoses saved *after* the toggle was on; turning a toggle on never uploads older photos.
- **Deletion semantics:** the server is called first; if it fails the phone keeps its data and the farmer is told. Aggregated `alerts/` counts and their `reporters/{uid}` markers are not deleted (the markers expire by TTL after 30 days and hold no data beyond the id).
- **Unverified here:** share card Bangla glyph rendering on a real budget phone (tests use a placeholder font), the system share sheet, WhatsApp/SMS text, `tel:` on a device, and real Storage upload from the app.

## Gap audit after Phase 9: fixed and still open

Fixed: `min_app_version` soft-force update banner (never blocks); `daily_cap_display` Remote Config text; alerts, weather and the KB update now sign in before reading (the rules need it and sign-in is lazy; offline they stay quiet); `reports.expireAt` capped at 62 days ahead in the rules so a client cannot defeat the TTL.

Open, by choice or because it is external: no offline model is bundled (needs the trained model, Phase 6 external); the daily quota is spent before the AI call and not refunded when the provider fails (keeps spend bounded, but a provider outage burns farmers' counts, revisit with pilot data); the "KB updated" note on a result appears for any seq increase, not only when that disease changed; TTL policies and the Storage lifecycle are applied by hand (runbook commands), not by repo config; `deleteMyData` leaves `reporters/` markers and `quotas/` docs to expire by TTL; the "no Bangla voice" dialog is tested at controller level only.
