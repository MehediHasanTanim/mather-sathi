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
