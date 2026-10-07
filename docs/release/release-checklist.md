# Release checklist (task 9.6) with honest status

✅ = done in the repo and tested here. 🔧 = needs a person, a real project, a real phone or a third party. Nothing below marked 🔧 has been done.

## Gate G9 / M4

| Item | Status |
|---|---|
| KB signed off (K7) and published (`kb_versions/current` has the latest seq and SHA-256) | 🔧 No agronomist reviewer yet (decisions.md). The seed KB is draft content: **never ship it**. ✅ `publish.js` refuses drafts for stg/prod, the app refuses draft KBs outside dev. |
| Calibration done (9.1) | 🔧 Needs the held-out **field** photo set and the agronomist. ✅ Tooling ready: `tools/eval/calibrate.ts` (see `tools/eval/README.md`). |
| QA matrix green on 3 devices (9.2) | 🔧 `docs/release/qa-matrix.md` |
| Kill-switch and KB rollback drills | ✅ rehearsed on the emulators (`npm run test:e2e:drills --prefix firebase`); 🔧 rehearse once on `stg` |
| Internal-track build live | 🔧 needs Play account (O1), upload key, prod Firebase project |

## Before building

- 🔧 `flutterfire configure` for stg and prod (`lib/firebase/options_*.dart` are placeholders, and `android/app/src/<flavor>/google-services.json`). `build_aab.sh` refuses to run while they are placeholders.
- 🔧 Create the upload keystore and `android/key.properties` (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`); keep the keystore out of git (ignored) and in a password manager. Enrol in Play App Signing.
- ✅ `tools/release/build_aab.sh stg|prod`: checks KB build matches the env, analyze, tests, then `flutter build appbundle --obfuscate --split-debug-info`. 🔧 Never run here (no Android toolchain in the sandbox): expect to fix Gradle/R8 issues on the first real build, especially keep rules for `tflite_flutter` and Firebase.
- 🔧 Upload `build/symbols` to Crashlytics (command printed by the script).

## Backend (per project)

- 🔧 `config/runtime.cloudEnabled = true`; `DAILY_CAP` set; `ANTHROPIC_API_KEY` set; billing budget alerts active (`ops/setup_alerts.sh`).
- 🔧 Deploy: Firestore rules + indexes, Storage rules, Functions (`diagnose`, `aggregateReports`, `refreshWeather`, `deleteMyData`, `onBackupDeleted`), Firestore TTL policies on `expireAt` (collections `quotas`, `reports`, `alerts`, `alerts/*/reporters`), Storage lifecycle `gsutil lifecycle set firebase/lifecycle.json gs://<bucket>`.
- 🔧 Confirm in `stg` that a lifecycle deletion fires `onBackupDeleted` (if not, add a daily scan).
- 🔧 App Check decision (ops-runbook §4).
- 🔧 Remote Config: thresholds from 9.1, `helpline_*` values from DAE (O4), TTS rates tuned on the QA phones.
- 🔧 Open-Meteo terms for commercial use (O6) or swap provider; weather rules need agronomist sign-off (K6), they ship as `draft` (inactive).

## Play listing

- ✅ Drafts: `store-listing.md` (Bangla and English), `privacy-policy-draft.md`, `data-safety.md` (answers mapped to Design §15.2).
- 🔧 Legal review of the privacy policy (Bangladesh data-protection requirements, AI provider retention terms), host it at a public URL and put that URL in the listing and the Data safety form.
- 🔧 Screenshots from a real build (Bangla UI), feature graphic, content rating questionnaire, target audience (not directed at children).
- Distribution: Play only; no sponsored content (decisions.md).

## Pilot

- ✅ Kit drafts in `docs/pilot/`. 🔧 Print the guide, test the support channel with a real call and message, agree the incident contact with the agronomist.
