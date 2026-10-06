# কৃষি সহায় (Krishi Sahay) — Phase-wise Technical Implementation Plan

**Version:** 1.0  
**Based on:** Feature Spec v1.1 · Technical Design v1.0  
**Platform:** Flutter (Android-first) + Firebase Cloud Functions (TypeScript)  
**State management:** Riverpod  
**Last Updated:** October 2026

---

## Table of Contents

0. [How to Read This Plan](#0-how-to-read-this-plan)
1. [Plan at a Glance](#1-plan-at-a-glance)
2. [Parallel Tracks (KB, Model/Data, Ops)](#2-parallel-tracks-kb-modeldata-ops)
3. [Phase 0 — Foundations](#phase-0--foundations)
4. [Phase 1 — App Shell, Onboarding, Profile](#phase-1--app-shell-onboarding-profile)
5. [Phase 2 — Capture and Image Preparation](#phase-2--capture-and-image-preparation)
6. [Phase 3 — Knowledge Base and Cloud Diagnosis](#phase-3--knowledge-base-and-cloud-diagnosis)
7. [Phase 4 — Result Experience](#phase-4--result-experience)
8. [Phase 5 — History, Sync, Resilience](#phase-5--history-sync-resilience)
9. [Phase 6 — Offline Model](#phase-6--offline-model)
10. [Phase 7 — Alerts, Weather, Notifications](#phase-7--alerts-weather-notifications)
11. [Phase 8 — Settings, Privacy, Expert, Share](#phase-8--settings-privacy-expert-share)
12. [Phase 9 — Hardening, Calibration, Release](#phase-9--hardening-calibration-release)
13. [Milestones and Demo Scripts](#milestones-and-demo-scripts)
14. [Field Pilot Plan](#field-pilot-plan)
15. [Risk-driven Contingencies](#risk-driven-contingencies)
16. [Templates and Checklists](#templates-and-checklists)
17. [Estimate Summary and Scope Cut Order](#estimate-summary-and-scope-cut-order)

---

## 0. How to Read This Plan

### Assumptions

- One full-stack engineer (Flutter + TypeScript) working with AI coding tools. Estimates are **focused engineering hours, ±30%**, and include writing the tests listed in each acceptance column.
- An agronomist or plant pathologist is reachable part-time for KB review (Track K). This is the single biggest external dependency.
- The design decisions in Technical Design v1.0 are accepted. Where the plan differs from the spec (§20 of the design), the design wins.

### Reality check on the spec's "10-day sprint"

The spec's 10-day table is a **build order**, not a duration a single engineer can hit. Summing the tasks below gives about **204 engineering hours** for everything, **159 h** for a cloud-only core (Tier 1). Section 1 converts that into calendar time for different weekly capacities. Plan on weeks, not days, unless two engineers work in parallel.

### Conventions

| Item | Meaning |
|---|---|
| **ID** | `phase.task`, e.g. `3.5`. Parallel-track tasks use `K`, `M`, `O` prefixes |
| **Stream** | `A` app (Flutter) · `B` backend (Functions, rules, Firebase) · `K` KB content · `M` ML/data · `O` ops/legal/partners · `Q` QA |
| **Tier** | `T1` cloud-only core · `T2` adds offline model · `T3` adds community features and photo backup |
| **h** | Estimated focused hours |
| **Depends** | Task IDs that must be done (or at least usable) first |

### Definition of Done (every task)

1. Acceptance column met and demonstrated on a budget Android phone (not just an emulator) when UI-visible.
2. Unit/widget/emulator tests for the listed behavior pass in CI.
3. All user-visible strings are in `app_bn.arb`; no hard-coded Bangla in widgets.
4. No secret, API key or personal data in code, logs or analytics.
5. Analytics events from Design §16 added where the task touches them.
6. PR reviewed; KB or `weather_rules.json` changes also approved by the agronomist.

### Working agreements

Trunk-based development with short PRs. CI must be green to merge. Every Firebase change (rules, indexes, functions) is deployed to `stg` first, never straight to `prod`.

---

## 1. Plan at a Glance

| Phase | Goal | Hours | Tier | Milestone |
|---|---|---|---|---|
| 0 | Foundations: projects, repo, CI, secrets, decisions | 14.0 | T1 | — |
| 1 | App shell, Bangla rendering, SQLite, onboarding, profile | 18.0 | T1 | — |
| 2 | Photo capture, compression, quality checks | 17.0 | T1 | — |
| 3 | KB pipeline, `diagnose()` Function, cloud client, eval v0 | 31.5 | T1 | **M1** walking skeleton |
| 4 | Result screen, TTS, feedback, non-diagnosis states | 23.5 | T1 | — |
| 5 | History, failure handling, history sync, rules | 20.5 | T1 + T3 | **M2** cloud-only core, internal test |
| 6 | Offline TFLite model | 16.0 | T2 | **M3** offline works |
| 7 | Alerts, weather, notifications | 21.5 | T3 | — |
| 8 | Settings, consent plumbing, expert, share, data deletion | 17.5 | T1 + T3 | — |
| 9 | Calibration, QA, security drills, release | 25.0 | T1 | **M4** pilot-ready |
| | **Total** | **204.5** | | |

### Scope tiers

| Tier | Contents | Hours (cumulative) |
|---|---|---|
| **T1** Cloud-only core | Phases 0–4, 5 (minus report push), 8 (minus photo upload), 9 | **159** |
| **T2** + offline model | + Phase 6 | **175** |
| **T3** + community | + Phase 7, report push (5.5), photo backup/contribution (8.2) | **204.5** |

T1 is the user's stated requirement: photo → AI identifies disease → Bangla treatment. T2 and T3 are additive and can ship in later releases.

### Calendar time by weekly capacity (no buffer)

| Capacity | T1 | T1 + T2 | Full (T1–T3) |
|---|---|---|---|
| 15 h/week (side project) | 10.6 wk | 11.7 wk | 13.6 wk |
| 30 h/week | 5.3 wk | 5.8 wk | 6.8 wk |
| 60 h/week (two engineers) | 2.7 wk | 2.9 wk | 3.4 wk |

Add roughly 20% contingency. These figures cover engineering only; Tracks K and M often set the real launch date (next section).

### Critical path

```
0.1 decision: KB reviewer named ─► K2 first KB batch ─► real content into 3.x ─► pilot
O1 Play account (lead time)    ────────────────────────────────► 9.6 internal test track
M1–M7 dataset → model          ─► 6.1 handoff ─► Phase 6 ─► 9.1 calibration ─► offline in pilot
3.9 eval harness v0            ─► choose cloud model ─► 9.1 calibration ─► thresholds
```

Engineering tasks are rarely the bottleneck. Waiting on KB review, field photos, or a Play account is.

### Work-stream split for two engineers

| Engineer | Phases / tasks |
|---|---|
| **A (app)** | 0.3, 0.4, 0.6, all of Phases 1, 2, 4, 5.1–5.4, 6.2–6.4, 8.1, 8.4, 8.5, 7.2, 7.4 |
| **B (backend/ML)** | 0.2, 0.5, Phase 3 B-tasks, 3.9, 5.5, 5.6, 6.1, 6.5, 7.1, 7.3, 7.5–7.7, 8.2, 8.3, KB tooling, Tracks K/M coordination |

---

## 2. Parallel Tracks (KB, Model/Data, Ops)

These start on Day 0 and run alongside the engineering phases. They are not in the 204.5 h.

### Track K — Knowledge Base content

| ID | Task | Owner | Effort (rough) | Needed by |
|---|---|---|---|---|
| K1 | KB style guide and review checklist (plain Bangla, units, how to state doses, safety line, sources) | PM + agronomist | 3 h | Before K2 |
| K2 | **Batch 1:** rice + potato, about 10 entries, reviewed | Agronomist + editor | ~20 h | Start of Phase 3 testing (week 1–2) |
| K3 | Batch 2: tomato, brinjal, chili, about 15 entries | same | ~30 h | Before pilot |
| K4 | Batch 3: jute, onion, mustard, about 15 entries | same | ~30 h | Before pilot |
| K5 | `ai_hint_en` for every entry (short visual description used by the classifier prompt), reviewed | same | ~8 h | With each batch |
| K6 | Weather rules v1 (`weather_rules.json`) | Plant pathologist | ~4 h | Before Phase 7 |
| K7 | KB sign-off before pilot: every medicine entry re-read against its cited source | Agronomist | ~6 h | Before M4 |

Effort assumes about 2 h per entry across drafting, source checking, Bangla edit and review. Treat as a planning figure.

### Track M — Dataset and offline model (gates Phase 6)

| ID | Task | Notes | Effort / duration |
|---|---|---|---|
| M1 | Freeze class list with the agronomist (8 crops × ~5 diseases + healthy/unknown) | Must match KB ids; changes later are expensive | 4 h |
| M2 | Photo collection protocol: framing, lighting, background, one disease per folder, naming, metadata (crop, upazila, date, field id) | Include field/farm id in metadata | 4 h |
| M3 | Collect field photos | Fine-tuning a pretrained mobile classifier typically starts at 100+ images per class (rule of thumb, not a guarantee). With ~40 classes that is thousands of photos, so plan **weeks** | Weeks |
| M4 | Expert label review of a sample (about 10% plus all disputed images) | Label noise caps accuracy | Ongoing |
| M5 | Split train/val/test **by field or farm and date**, never random by image | Photos of the same plant in train and test inflate accuracy | 3 h |
| M6 | Train a MobileNet-class model, int8 quantize, export TFLite | Public datasets may help pretraining but are mostly lab-condition images | ~20 h |
| M7 | Handoff package: `.tflite`, `labels.json`, preprocessing spec (size, dtype, normalization), version | Feeds task 6.1 | 2 h |
| M8 | Model card: data sources, counts per class, per-crop metrics | Needed for the pilot review | 3 h |

**If M3 is not progressing by the end of Phase 4, ship T1 and move Phase 6 to a later release** (see contingencies).

### Track O — Operations, legal, partners

| ID | Task | Why now | Effort |
|---|---|---|---|
| O1 | Google Play developer account (verification can take days). Check current policies for new accounts, which have included mandatory closed testing before production access | Lead time | 2 h + wait |
| O2 | Compile `districts.json`: 64 districts, upazilas, URL-safe slugs, reference lat/lon, from an official administrative list | Needed in task 1.4 | ~6 h |
| O3 | Partner outreach: DAE/BARI/BRRI or a university for KB review and field data | Gates K and M | ongoing |
| O4 | Verify the 16123 helpline: number, hours, charge, with DAE | Spec relies on a dated press report | 1 h |
| O5 | Privacy policy and consent wording (Bangla), AI provider data-retention check | Play listing and onboarding | ~6 h |
| O6 | Weather provider terms check against commercial use | Before 7.3 | 1 h |
| O7 | Recruit 20–30 pilot farmers and a local agriculture officer contact | Pilot | ~8 h |

---

## Phase 0 — Foundations

**Goal:** Everything needed to start coding safely: decisions made, three Firebase projects, secrets, repo, CI.  
**Duration:** about 14 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 0.1 | Decision record: KB reviewer named with a start date; offline in v1.0 or v1.1; distribution (Play only vs sideload); sponsored-content stance | O | T1 | 2 | — | `docs/decisions.md` exists and is signed off. **No later phase starts without a named KB reviewer** |
| 0.2 | Create Firebase projects `dev`, `stg`, `prod`; Blaze on `stg`/`prod`; Firestore in `asia-south1`; billing budget alerts | B | T1 | 2 | — | Three projects exist; Firestore location set; budget alerts email the owner |
| 0.3 | Repo scaffold: Flutter app, `functions/`, `kb/`, `tools/`, `firebase/`; flavors; lint rules | A | T1 | 3 | — | `flutter run --flavor dev` shows a themed blank app on a device; `npm test` runs in `functions/` |
| 0.4 | FlutterFire per flavor; App Check (debug provider in dev); anonymous sign-in smoke test | A | T1 | 2 | 0.2, 0.3 | Dev app signs in anonymously; user visible in the Auth console |
| 0.5 | Secrets and signing: `ANTHROPIC_API_KEY` in Secret Manager (`stg`, `prod`); upload keystore generated and backed up; Play Console app record created | B | T1 | 1.5 | 0.2, O1 | Only the Functions service account can read the secret; keystore stored in a secrets vault, not the repo |
| 0.6 | CI skeleton with four jobs: `dart`, `functions`, `kb`, `rules` (stubs allowed) | A | T1 | 2 | 0.3 | A PR shows four green checks |
| 0.7 | Compliance prep: provider retention terms, data-protection checklist, consent text v0 | O | T1 | 1.5 | O5 | One-page note and Bangla consent draft ready for review |

```bash
# Projects and local tooling
firebase use --add                                  # aliases: dev, stg, prod
firebase firestore:databases:create '(default)' --location=asia-south1   # irreversible; the console also works
firebase init functions firestore storage emulators # TypeScript functions
firebase functions:secrets:set ANTHROPIC_API_KEY --project krishi-stg

# FlutterFire, one run per flavor
dart pub global activate flutterfire_cli
flutterfire configure --project=krishi-dev --platforms=android \
  --android-package-name=bd.krishisahay.app.dev --out=lib/firebase/options_dev.dart
```

```groovy
// android/app/build.gradle — flavors
flavorDimensions "env"
productFlavors {
  dev  { dimension "env"; applicationIdSuffix ".dev"; resValue "string", "app_name", "Krishi Dev" }
  stg  { dimension "env"; applicationIdSuffix ".stg"; resValue "string", "app_name", "Krishi Stg" }
  prod { dimension "env"; resValue "string", "app_name", "কৃষি সহায়" }
}
```

**Gate G0:** KB reviewer named; three projects; CI green on an empty change; secret set on `stg`.

---

## Phase 1 — App Shell, Onboarding, Profile

**Goal:** App launches fast, renders Bangla correctly, works offline from the first launch, and completes onboarding.  
**Duration:** about 18 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 1.1 | `bootstrap.dart`: Firebase init, DB open, `ProviderContainer` preload (profile, KB placeholder), `UncontrolledProviderScope` | A | T1 | 2 | 0.4 | No onboarding flicker on launch; cold-start time logged and recorded as a baseline |
| 1.2 | Theme and Bangla: bundle Noto Sans Bengali (Regular, Bold), line height 1.4+, `textScaler` clamp 1.0–1.3, ARB skeleton, Bangla digits via `intl` | A | T1 | 2.5 | 0.3 | A sample screen with conjuncts, matras and digits renders correctly on Android 8 and a recent Android |
| 1.3 | SQLite helper, schema v1 (Design §9), DAOs for history and profile, migration skeleton | A | T1 | 4 | 0.3 | DAO tests pass with `sqflite_common_ffi`; retention query deletes beyond 50 rows and returns file paths to delete |
| 1.4 | `districts.json` integration; district → upazila pickers with Bangla search | A | T1 | 2 | O2 | Picker filters upazilas by district; selecting a district clears a stale upazila |
| 1.5 | Onboarding: 4 slides, profile setup (district, upazila, primary crop), consent screen with 3 toggles plus the AI-processing disclosure line | A | T1 | 4 | 1.2, 1.3, 1.4 | Completes in airplane mode; defaults are reports on, photo backup off, contribution off; disclosure text is visible and not a toggle |
| 1.6 | Router: `StatefulShellRoute` (4 tabs), onboarding redirect, placeholder tabs | A | T1 | 2 | 1.5 | Fresh install → onboarding; after completion → home; relaunch skips onboarding |
| 1.7 | `RemoteFlags` wrapper: defaults baked in, background fetch, dev override | A | T1 | 1.5 | 0.4 | App behaves correctly with Remote Config unreachable (uses defaults) |

```yaml
# pubspec.yaml — fonts
flutter:
  fonts:
    - family: NotoSansBengali
      fonts:
        - asset: assets/fonts/NotoSansBengali-Regular.ttf
        - asset: assets/fonts/NotoSansBengali-Bold.ttf
          weight: 700
```

**Checkpoint:** On a budget phone, a first launch in airplane mode reaches the home screen after onboarding with correct Bangla text.

---

## Phase 2 — Capture and Image Preparation

**Goal:** A farmer picks a crop, takes a photo, and the app produces a clean, small JPEG or tells them how to retake it.  
**Duration:** about 17 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 2.1 | Crop grid (8 crops) plus "অন্যান্য ফসল" text input; default crop from profile | A | T1 | 3 | 1.6 | Last crop is remembered; "other" needs a non-empty label of at most 40 characters |
| 2.2 | Guidance bottom sheet (3 s, dismissable) → `image_picker` camera or gallery; `retrieveLostData()` handling | A | T1 | 3 | 2.1 | Killing the app while the system camera is open and returning resumes the flow with the photo |
| 2.3 | `ImagePrepService`: native compress, size loop (q80 → q70 → q60), EXIF stripped, orientation corrected | A | T1 | 3 | 2.2 | A 12 MP photo becomes a typical ≤ 300 KB JPEG, upright, with no EXIF/GPS (checked with an EXIF tool) |
| 2.4 | Quality analysis in an isolate: mean luminance + Laplacian variance on a 256-px thumbnail; thresholds from `RemoteFlags`; unit tests on fixtures | A | T1 | 3.5 | 2.3, 1.7 | On the fixture set, most blurry and dark images are flagged and few good ones rejected (provisional targets: ≥ 90% caught, ≤ 10% false rejects) |
| 2.5 | Preview/retake screen with a specific Bangla tip per `ImageIssue` | A | T1 | 2.5 | 2.4 | Each issue shows its own tip; retake keeps the selected crop |
| 2.6 | Fixture photo set: 30+ real photos (sharp, blurry, dark, not-a-plant) and prep timing on a budget phone | Q | T1 | 2 | — | Small fixtures committed; prep time recorded on a 2 GB device and compared with the design target |

**Threshold tuning procedure (feeds 9.1):**
1. Run the analysis over fixtures and plot luminance and Laplacian variance per label.
2. Choose initial thresholds separating the clusters; store them as Remote Config values.
3. Re-tune with real field photos from the pilot. Close-up leaves are textured, so thresholds from desktop-style photos will be wrong.

**Checkpoint:** Camera or gallery → preview shows either a ready image or a clear retake instruction, on a budget phone.

---

## Phase 3 — Knowledge Base and Cloud Diagnosis

**Goal:** A real photo goes through the proxy Function to a `disease_id`, which is rendered from KB data. This phase ends with **M1 (walking skeleton)**.  
**Duration:** about 31.5 h. This is the largest phase; split it across weeks.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 3.1 | KB JSON schema, validator and `kb_build` (outputs `kb.json` and `kb_index.json`) | B | T1 | 5 | 0.3 | Every rule in Design §5.3 has a failing-fixture test; identical input yields an identical SHA-256; CI `kb` job blocks bad entries |
| 3.2 | Dev seed KB: rice and potato, 2+ entries each; `status: draft` allowed in dev only | K | T1 | 1.5 | 3.1 | Draft entries are excluded from `stg`/`prod` builds, proven by a CI check |
| 3.3 | Dart KB models, `KbRepository.load()` (file, else bundled asset), `kbProvider` | A | T1 | 3 | 3.1 | A corrupt local file falls back to the bundled asset; parse errors reach Crashlytics |
| 3.4 | Functions scaffold: `kbIndex` loader, districts loader, lint and tests | B | T1 | 2 | 0.3, 3.1 | `npm test` green; emulators boot |
| 3.5 | `diagnose()`: auth required, `config/runtime` kill-switch, input validation, quota transaction, App Check; TTL on `quotas` | B | T1 | 4 | 3.4 | Tests: no auth → `unauthenticated`; 31st call in a day → `resource-exhausted`; oversize or non-JPEG → `invalid-argument`; kill-switch → `unavailable` |
| 3.6 | `classifyImage()`: forced tool call, per-crop enum, server-side validation | B | T1 | 4 | 3.4 | With a mocked client: an out-of-enum id → `unknown`; no tool call → `unknown`; the prompt lists only this crop's candidates |
| 3.7 | `generalAdvice()` for other crops: schema without medicine fields, Bangla prompt, dose-regex filter | B | T1 | 2.5 | 3.6 | Output containing a dose-like pattern is replaced by generic advice plus expert prompt |
| 3.8 | `CloudDiagnosisClient`, failure mapping, `DiagnosisService` cloud branch, lazy anonymous auth | A | T1 | 3.5 | 3.3, 3.5, 2.3 | Each `FirebaseFunctionsException` code maps per Design §6.5; a double submit is ignored |
| 3.9 | Eval harness v0 (cloud path): folder dataset in, JSON report out | M | T1 | 4 | 3.6 | Report has per-crop top-1, confusion matrix, calibration table (bucket → observed accuracy), latency, cost per call |
| 3.10 | Deploy to `stg`; device smoke test; latency under a throttled network | B | T1 | 2 | 3.5–3.8 | A real photo from a real device returns a `disease_id` from `stg`; p95 latency recorded under a 3G-like profile |

```bash
# Firestore TTL for server-written collections
gcloud firestore fields ttls update expireAt --collection-group=quotas  --enable-ttl --project krishi-stg
gcloud firestore fields ttls update expireAt --collection-group=reports --enable-ttl --project krishi-stg
gcloud firestore fields ttls update expireAt --collection-group=alerts  --enable-ttl --project krishi-stg
gcloud firestore fields ttls update expireAt --collection-group=reporters --enable-ttl --project krishi-stg

# KB build (CI and local)
node tools/kb_build/build.js --validate --env stg   # drafts excluded; fails on any §5.3 rule
```

```dart
// dev flavor: run against the local emulators (10.0.2.2 is the host from an Android emulator;
// use the machine's LAN IP for a physical device)
if (flavor == Flavor.dev && useEmulators) {
  FirebaseFunctions.instanceFor(region: 'asia-south1').useFunctionsEmulator('10.0.2.2', 5001);
  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
  await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
}
```

```bash
# Eval harness v0 — dataset layout: testset/{crop}/{disease_id}/*.jpg
npx ts-node tools/eval/cloud_eval.ts --data ./testset --crops rice,potato --out reports/cloud_v0.json
# Network throttling for the latency check on an emulator
emulator -avd Pixel_API_33 -netspeed umts -netdelay umts
```

**Build-order note:** do 3.9 right after 3.6, before the app-side work in 3.8. Knowing the cloud model's real accuracy on Bangladeshi field photos early is the cheapest insurance against a bad surprise.

**Gate G3 / M1 demo:** on a real device in `stg`, a rice or potato photo becomes a disease name rendered from a KB entry (even a temporary result view), and the eval report for the first KB batch exists.

---

## Phase 4 — Result Experience

**Goal:** The farmer sees a clear Bangla result, can hear it, and can say whether it was right.  
**Duration:** about 23.5 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 4.6 | `HistoryNotifier.saveOutcome`: store the prepared JPEG, snapshot `disease_name_bn`, KB seq, retention | A | T1 | 3 | 1.3 | After 51 saves only 50 rows and files remain; the original photo is never stored |
| 4.1 | `DiagnosisFlowNotifier` and Analyzing screen (stages, cancel) | A | T1 | 3 | 3.8, 4.6 | State machine per Design §8.2; back or cancel during analysis is safe; a double tap does not start two runs |
| 4.2 | `ResultScreen` from the KB: sections, urgency color + icon, confidence bucket text, disclaimer, safety line | A | T1 | 5 | 3.3, 4.1 | Matches the checklist below for a fixture entry |
| 4.3 | Non-diagnosis states (healthy, unknown, wrong crop, not-a-plant) and the general-advice view | A | T1 | 3 | 4.2 | Each state shows the spec's copy and CTAs; general advice shows no medicine section |
| 4.4 | TTS: `TtsController`, KB script builder, speed setting, unavailable-voice dialog | A | T1 | 4 | 4.2 | Pause then resume continues from the current chunk; rapid pause/resume never plays two streams; missing Bangla voice shows the install guidance |
| 4.5 | Feedback control (👍/👎 plus "what was it?" picker) writing to the history row | A | T1 | 2.5 | 4.6 | Feedback persists, sets `is_synced = 0`, and re-opening the entry shows the choice |
| 4.7 | Widget tests (result states from KB fixtures), TTS chunking tests | A | T1 | 3 | 4.2–4.6 | CI green; golden or widget tests cover high, medium and low confidence |

**Result screen checklist (spec §2.4 mapped to the KB):**

| Section | Source | Verified by |
|---|---|---|
| Header: disease name, urgency color and icon, confidence bucket text | KB `name_bn`, `urgency`; bucket | Widget test |
| 📢 listen button, "জরুরি" tag when urgency is high | KB | Widget test |
| Description, symptoms | KB | Widget test |
| Immediate actions | KB `immediate_bn` | Widget test |
| Medicine name, dose, interval, pre-harvest interval | KB `medicine[]` | Widget test; **absent when the entry has no medicine** |
| Safety line (mask, gloves, read the label) | ARB constant | Widget test; present whenever a medicine is shown |
| Prevention | KB | Widget test |
| Expert CTA | KB `see_expert`, bucket low, unknown | Widget test |
| Feedback row and AI disclaimer | ARB | Widget test |

**Checkpoint:** On a device: photo → result with Bangla treatment from the KB → audio plays → 👍 saved.

---

## Phase 5 — History, Sync, Resilience

**Goal:** Past diagnoses are reviewable, failures are handled gracefully, and data is backed up to Firestore.  
**Duration:** about 20.5 h. This phase ends with **M2 (cloud-only core, internal testing)**.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 5.1 | History list and detail; detail rebuilds from `disease_id` and the current KB; shows "তথ্য হালনাগাদ হয়েছে" or "তথ্য আর পাওয়া যাচ্ছে না" on KB drift | A | T1 | 4 | 4.6 | A removed KB entry shows the saved name and a message, never a crash |
| 5.2 | Failure UX per Design §6.5 (messages, retry, cap message) | A | T1 | 3 | 3.8 | Each `DiagnosisFailure` shows its Bangla message; no retry loop on `ServiceRejected` |
| 5.3 | `connectivityProvider`, 8 s timeout handling, fallback logic with the test matrix below | A | T1 | 3 | 3.8 | Matrix passes with fakes |
| 5.4 | `SyncService.flush()`: history push, `ensureSignedIn`, triggers at start, reconnect and after save | A | T1 | 4 | 4.6, 0.4 | Offline saves sync after reconnect; unsynced rows survive app restarts; duplicate pushes are harmless |
| 5.5 | Report eligibility and push with deterministic ID; `permission-denied` on repeat treated as sent | B | **T3** | 3.5 | 5.4 | Two pushes in one week produce one doc; the retry after a timeout is safe |
| 5.6 | Firestore rules, Storage rules, indexes; rules unit tests; deploy to `stg` | B | T1 | 3 | 0.2 | Tests: a user cannot read another user's history; `reports` create-once, no read; `alerts`, `weather` read-only; unknown collections denied |

**Fallback matrix (task 5.3):**

| Case | Online | Crop | Cloud result | On-device available | Expected |
|---|---|---|---|---|---|
| 1 | Yes | Launch | OK | any | Cloud result, `source = cloud` |
| 2 | Yes | Launch | Timeout / server error | Yes | On-device result, `source = on_device` |
| 3 | Yes | Launch | Timeout / server error | No | Failure message + retry |
| 4 | Yes | Launch | Daily cap | Yes | On-device result |
| 5 | Yes | Launch | Daily cap | No | Cap message |
| 6 | Yes | Launch | `ServiceRejected` | Yes | On-device result; error logged to Crashlytics |
| 7 | No | Launch | — | Yes | On-device result with the offline caveat |
| 8 | No | Launch | — | No | "ইন্টারনেট চালু করে আবার চেষ্টা করুন" |
| 9 | No | Other | — | any | `NeedsInternet` message |
| 10 | Yes | Other | Timeout / error | any | Failure message (no on-device path for other crops) |
| 11 | Yes (no data balance) | Launch | Timeout | Yes | Case 2 within about 8 s |

In a T1 build the "on-device available = Yes" rows are stubbed; they become live in Phase 6.

**Gate G5 / M2 demo:** with the dev KB (real KB batch 1 preferred), a tester on `stg` completes: onboarding → photo → result → audio → feedback → history → airplane-mode failure message. Share the build on the Play internal track once O1 is done.

---

## Phase 6 — Offline Model

**Goal:** Launch-crop diagnosis works without internet with the same result screen. **Gated on Track M (M7 handoff).**  
**Duration:** about 16 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 6.1 | Model contract: input shape and dtype, normalization, `labels.json` (`index → {disease_id, crop}`), versioning; the label-to-KB check added to `kb_build` | B | T2 | 2 | M7 | `kb_build` fails if a label id is missing from the KB or a crop lacks a `healthy` class |
| 6.2 | `TfliteClassifier`: lazy init, `IsolateInterpreter`, tensor preprocessing in an isolate | A | T2 | 4 | 6.1 | First offline classify completes without blocking the UI thread; model loads only when needed |
| 6.3 | Crop-masked scoring (probability mass outside the crop → `wrongCrop`/low), thresholds from Remote Config, unit tests with fixed output vectors | A | T2 | 3 | 6.2 | Fixed vectors produce the expected bucket and `unknown` cases |
| 6.4 | Wire into `DiagnosisService` fallback and offline entry; offline caveat UI | A | T2 | 2 | 6.3, 5.3 | Fallback matrix cases 2, 4, 6, 7 now pass with the real classifier |
| 6.5 | Parity check: Python eval and Dart app outputs on the same 20 fixture images | B | T2 | 3 | 6.2 | Float model: probabilities within a small tolerance; int8 model: same top-1 on every fixture. Differences mean preprocessing mismatch |
| 6.6 | 32-bit device test; APK size and ABI check | Q | T2 | 2 | 6.2 | Runs on an `armeabi-v7a` phone; size within the design target; native libs for both ABIs confirmed |

```bash
# Check the test phone's ABI
adb shell getprop ro.product.cpu.abilist     # e.g. armeabi-v7a,armeabi vs arm64-v8a,...

# Release builds
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
flutter build apk --release --split-per-abi   # only if you also distribute APKs directly
```

**Gate G6 / M3 demo:** airplane mode, rice photo, result in under the target latency on a 32-bit 2 GB phone, same screen as online.

---

## Phase 7 — Alerts, Weather, Notifications

**Goal:** Regional outbreak alerts and weather warnings, delivered without a custom server.  
**Duration:** about 21.5 h (Tier 3).

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 7.1 | `aggregateReports` with `reporters` idempotency, geo/KB validation, `suppressed` support; emulator tests | B | T3 | 4 | 5.5, 3.4 | Re-delivered trigger does not double count; alert becomes `visible` only at the third distinct install; garbage district/crop ignored |
| 7.2 | Alerts feed: provider, query, composite index, UI | A | T3 | 3 | 7.1 | Feed shows only visible alerts from the last 14 days for the user's district; empty state in Bangla |
| 7.3 | `refreshWeather`: provider interface, `weather_rules.json` loader, rule evaluation, tests | B | T3 | 5 | K6, O6 | Rules evaluated on a recorded forecast fixture; scheduled for 06:00 and 14:00 Asia/Dhaka |
| 7.4 | Weather banner on home: filtered by primary crop, dismissal remembered per fetch | A | T3 | 2 | 7.3 | Dismissed banner stays hidden until new data arrives |
| 7.5 | FCM: topic sync in `ProfileNotifier`, notification channels (`alerts`, `weather`), deep links | A | T3 | 3.5 | 1.6 | Changing district swaps topics; notifications toggle off unsubscribes; tapping a push opens `/alerts` |
| 7.6 | Notify helpers: district topic push when an alert becomes visible; weather push only when risk **increases** | B | T3 | 2 | 7.1, 7.3 | No repeat pushes for an unchanged risk level |
| 7.7 | End-to-end test on `stg`: three test installs report the same disease; alert appears and one push is sent | Q | T3 | 2 | 7.1–7.6 | Recorded test run; a fourth report does not send a second push |

**Alert end-to-end script:**
1. Install on three devices (or emulators) with different anonymous users, all in the same district and upazila.
2. Each completes a diagnosis for the same crop with a result of `high` or `medium` confidence and the same disease.
3. Check: `reports` has three docs, `alerts/{id}.count = 3`, `visible = true`, one push received per subscribed device.
4. A repeat by device 1 in the same week changes nothing (create denied, still count 3).

**Gate G7:** weather rules signed off by the agronomist; alert and weather paths verified on `stg`.

---

## Phase 8 — Settings, Privacy, Expert, Share

**Goal:** Everything the farmer controls, plus the deletion and sharing paths.  
**Duration:** about 17.5 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 8.1 | Settings screen: toggles, TTS speed, district/upazila/crop, about (app and KB version) | A | T1 | 4 | 1.5 | Each setting persists and takes effect immediately (topic sync, TTS rate) |
| 8.2 | Photo backup and contribution uploads in `SyncService`; Storage rules; 30-day lifecycle on `backups/`; `onBackupDeleted` clears `photoUrl` | B | **T3** | 4.5 | 5.4, 5.6 | Default off uploads nothing; backup on uploads once; after lifecycle deletion the history doc's `photoUrl` is cleared (verified in `stg`; use a scheduled scan if the event does not fire) |
| 8.3 | `deleteMyData` callable and client wiring ("ইতিহাস মুছুন") including a local wipe | B | T1 | 3 | 5.4 | After deletion: Firestore history, Storage objects, the user's reports and local rows are gone; the app returns to a clean state |
| 8.4 | Expert screen: number, hours and charge note from Remote Config, open/closed in Asia/Dhaka time, `tel:` launch | A | T1 | 2.5 | O4, 1.7 | Dialer opens with the number; "বন্ধ" shows outside hours; hours text updatable without a release |
| 8.5 | Share: off-screen share card to PNG plus text version; system share sheet | A | T1 | 3.5 | 4.2 | Card renders Bangla correctly on a budget phone; text share works in WhatsApp and SMS |

```json
// lifecycle.json — apply with: gsutil lifecycle set lifecycle.json gs://<bucket>
{ "rule": [ { "action": { "type": "Delete" },
              "condition": { "age": 30, "matchesPrefix": ["backups/"] } } ] }
```

**Gate G8:** privacy toggles verified against Design §15.2 (what leaves the device); deletion path demonstrated end to end.

---

## Phase 9 — Hardening, Calibration, Release

**Goal:** Prove accuracy, safety and performance on real devices and set thresholds from data. Ends with **M4 (pilot-ready)**.  
**Duration:** about 25 h.

| ID | Task | Str | Tier | h | Depends | Acceptance |
|---|---|---|---|---|---|---|
| 9.1 | Calibration run on the held-out **field** set (cloud and, if built, on-device); set Remote Config thresholds; choose the cloud model | M | T1 | 4 | 3.9, K2–K4 (6.5) | Report per crop; calibration table reviewed with the agronomist; thresholds set so the "high" bucket meets the agreed accuracy bar |
| 9.2 | Budget-phone QA matrix (see Templates) | Q | T1 | 5 | M2 | All P1 cases pass on three devices; defects triaged |
| 9.3 | Performance pass vs targets: cloud latency, on-device latency, memory, cold start, APK size | A | T1 | 3 | 9.2 | Numbers recorded against the Design targets; regressions filed |
| 9.4 | Security pass and drills: App Check monitor → enforce plan, rules review, key rotation, **kill-switch drill, KB rollback drill**, obfuscated build | B | T1 | 4 | 5.6, 3.5 | `cloudEnabled = false` stops spend within a minute; a bad KB entry is hidden via a new `seq` without an app release; rotating the AI key causes no downtime |
| 9.5 | Observability: analytics events, Crashlytics, Functions error and latency alerts, budget alerts verified | B | T1 | 3 | 3.10 | Events visible in DebugView; a forced Function error triggers an alert |
| 9.6 | Release: AAB, Play internal track, Bangla store listing, screenshots, privacy policy URL, Data safety form | O/A | T1 | 4 | O1, O5 | Internal-track build installable by testers; Data safety answers match Design §15.2 |
| 9.7 | Pilot kit: feedback form, support channel, one-page farmer guide, agronomist review sheet | O | T1 | 2 | 9.6 | Kit ready; support contact tested |

**Calibration procedure (9.1):**
1. Run `tools/eval` on the held-out set for each candidate cloud model and for the on-device model.
2. Compare per-crop top-1, then the calibration table: for each confidence bucket, observed accuracy.
3. Agree the bar with the agronomist (draft: ≥ 80% top-1 overall; the "high" bucket noticeably better than "medium"; "low" always triggers the expert CTA).
4. Set Remote Config values: `conf_high`, `conf_medium`, `min_crop_mass`, `blur_threshold`, `dark_threshold`.
5. If a crop does not meet the bar, **remove that crop from the launch list** or label it "beta" rather than lowering the bar.

**Gate G9 / M4:** KB signed off (K7); calibration done; QA matrix green; kill-switch and KB rollback drills passed; internal track build live.

---

## Milestones and Demo Scripts

| Milestone | After | Demo (what a stakeholder can see) |
|---|---|---|
| **M1** Walking skeleton | Phase 3 | Device on `stg`: photo → `disease_id` → KB-rendered result; eval report v0 on the first KB batch |
| **M2** Cloud-only core | Phase 5 | Full loop with TTS, feedback, history and failure handling; internal-track build |
| **M3** Offline | Phase 6 | Airplane mode: same result screen, fast, on a 32-bit 2 GB phone |
| **M4** Pilot-ready | Phase 9 | Calibrated thresholds, signed-off KB, drills passed, pilot kit ready |

---

## Field Pilot Plan

**Size and length (proposed):** 20–30 farmers across 2–3 upazilas, 2 weeks, covering at least four of the launch crops, with a local agriculture officer or agronomist on call.

**What to measure**

| Metric | How | Proposed pass line |
|---|---|---|
| Real accuracy | Agronomist reviews a sample of 100+ diagnoses blind to the app result and records the true disease | Meets the bar agreed in 9.1 |
| Farmer-reported correctness | 👍/👎 rate (compare with the expert review to see how reliable feedback is) | Reported alongside the expert numbers |
| Latency | Analytics `latency_ms`, split by source | p95 within the Design target on field networks |
| Fallback rate | `fallback_to_on_device` / total | Understand it; no fixed target |
| Retake rate | `retake_prompted` / photos | Falling over the pilot after tips are tuned |
| Stability | Crash-free sessions in Crashlytics | ≥ 99% (proposed) |
| Comprehension | Short interviews: can the farmer say what to do next after hearing the result? | Qualitative; capture quotes |
| Safety | Every medicine-bearing output class reviewed by the agronomist before and during the pilot | **Zero** wrong-dose incidents |

**Incident procedure**
1. Any suspected unsafe advice: set `config/runtime.cloudEnabled = false` if it is systemic, or publish a new KB `seq` with that entry's `status` changed to hide it.
2. Notify the agronomist and affected pilot users through the support channel.
3. Root-cause (KB text, misclassification, UI) and add a regression fixture before re-enabling.

**Exit decision:** go to broader release, fix-and-repeat, or narrow the launch crop list. The decision is made with the agronomist on the data above.

---

## Risk-driven Contingencies

| Trigger | Response |
|---|---|
| No KB reviewer named at G0 | Do not proceed past Phase 2. Only dev-seed content may be used, and **never in a pilot or production build** |
| KB batch 1 late at the start of Phase 3 testing | Continue with the dev seed; do not schedule the pilot until K2–K4 and K7 are done |
| Cloud accuracy below the bar for a crop (3.9 or 9.1) | Options, in order: change the cloud model, improve `ai_hint_en` with the agronomist, narrow candidate lists, add multi-photo (post-MVP), drop the crop from launch |
| Dataset not ready by the end of Phase 4 | Ship T1 cloud-only; move Phase 6 to the next release; communicate that offline is "coming" |
| App Check rejects a meaningful share of real users in monitor mode | Distribute via Play, or keep enforcement off with tighter caps and monitor spend; decide before launch, not after |
| Cloud p95 above the 8 s budget on field networks | Reduce image size, review region and `minInstances`, then revisit the timeout; the on-device fallback covers the remainder |
| Bangla TTS poor on target phones | Record human audio for the top diseases (post-MVP); keep TTS for the rest |
| Play account has a mandatory closed-testing period | Start O1 on Day 0 and start the closed test as soon as M2 exists |
| Weather provider terms disallow commercial use | Swap the provider behind the interface; no app change |
| Colluding installs create a fake alert | Set `suppressed = true` on the alert; raise the threshold via a Function parameter |
| Estimates overrun | Apply the cut order below |

---

## Templates and Checklists

### KB change pull request (agronomist approves)

```markdown
## KB change
- Entries added/changed: <ids>
- For every medicine entry:
  - [ ] Name, active ingredient, dose, interval, pre-harvest interval match the cited source
  - [ ] Source cited (document, edition, page/section)
  - [ ] Units are unambiguous in Bangla (গ্রাম/মিলি, প্রতি লিটার পানিতে)
- [ ] Symptoms and description are understandable to a farmer
- [ ] `ai_hint_en` is accurate and describes visual cues only
- [ ] `reviewed_by` and `reviewed_at` filled
- [ ] `tools/kb_build --validate` passes
- Reviewer: <name>   Date: <date>
```

### CI outline

```yaml
name: ci
on: [pull_request]
jobs:
  kb:
    steps: [checkout, setup-node, run: node tools/kb_build/build.js --validate --env stg]
  dart:
    steps: [checkout, setup-flutter, run: flutter pub get, run: flutter analyze, run: flutter test]
  functions:
    steps: [checkout, setup-node, run: npm ci --prefix functions, run: npm test --prefix functions]  # uses emulators
  rules:
    steps: [checkout, setup-node, run: npm ci --prefix firebase, run: npm test --prefix firebase]
  build:
    needs: [kb, dart, functions, rules]
    steps: [flutter build appbundle --release --flavor stg --obfuscate --split-debug-info=build/symbols]
```

### Budget-phone QA matrix (task 9.2)

| Device | Spec |
|---|---|
| D1 | Android 8–9, 2 GB RAM, 32-bit (`armeabi-v7a`), low free storage |
| D2 | Android 11–12, 3 GB, mid-range (e.g. a Galaxy A-series) |
| D3 | Android 13+, 4 GB (current baseline) |
| Emulator | Network profiles for 3G-like conditions; airplane mode |

| ID | Case | Priority |
|---|---|---|
| QA-01 | Fresh install, airplane mode, complete onboarding | P1 |
| QA-02 | Bangla conjuncts, digits and line height on all screens | P1 |
| QA-03 | Camera: kill the app while the system camera is open; resume | P1 |
| QA-04 | Blurry, dark, not-a-plant and wrong-crop photos give correct tips | P1 |
| QA-05 | Cloud diagnosis on 3G-like network meets the latency target | P1 |
| QA-06 | Cloud timeout fallback (T2) or clear failure message (T1) | P1 |
| QA-07 | Every result state: high, medium, low, healthy, unknown, general advice | P1 |
| QA-08 | TTS plays, pauses, resumes; missing-voice dialog | P1 |
| QA-09 | History: 51st entry evicts the oldest; KB drift messages | P2 |
| QA-10 | Large system font does not break layouts | P2 |
| QA-11 | Photo/EXIF check: no location data in uploaded images | P1 |
| QA-12 | Toggles: nothing uploaded when backup and contribution are off | P1 |
| QA-13 | "ইতিহাস মুছুন" removes local and cloud data | P1 |
| QA-14 | Helpline: dialer opens; hours text correct | P2 |
| QA-15 | Share card and text in WhatsApp and SMS | P2 |
| QA-16 | Alerts and weather push (T3) per the end-to-end script | P2 |
| QA-17 | Low memory: open camera, background app, return | P1 |
| QA-18 | Cold start time within the Phase 1 baseline | P2 |

### Release checklist

```
[ ] KB signed off (K7) and published (kb_versions/current has the latest seq and SHA-256)
[ ] config/runtime.cloudEnabled = true on prod; DAILY_CAP set
[ ] ANTHROPIC_API_KEY set on prod; billing budget alerts active
[ ] App Check enforcement decision made and applied
[ ] Firestore rules, Storage rules, indexes, TTL policies, lifecycle rule deployed to prod
[ ] Remote Config: thresholds from 9.1, helpline details from O4, TTS rates
[ ] Analytics events and Crashlytics symbols (build/symbols) uploaded
[ ] Play listing in Bangla, privacy policy URL, Data safety form consistent with Design §15.2
[ ] Obfuscated release build tested on D1, D2, D3
[ ] Kill-switch and KB rollback drills documented and rehearsed
[ ] Pilot kit and support channel ready
```

---

## Estimate Summary and Scope Cut Order

### Hours by phase and tier

| Phase | T1 | T2 | T3 | Total |
|---|---|---|---|---|
| 0 Foundations | 14.0 | | | 14.0 |
| 1 App shell | 18.0 | | | 18.0 |
| 2 Capture | 17.0 | | | 17.0 |
| 3 KB + cloud | 31.5 | | | 31.5 |
| 4 Result | 23.5 | | | 23.5 |
| 5 History/sync | 17.0 | | 3.5 | 20.5 |
| 6 Offline | | 16.0 | | 16.0 |
| 7 Community | | | 21.5 | 21.5 |
| 8 Settings etc. | 13.0 | | 4.5 | 17.5 |
| 9 Hardening | 25.0 | | | 25.0 |
| **Total** | **159.0** | **16.0** | **29.5** | **204.5** |

### Cut order when time is short

Cut from the top. Items higher in the list go first.

1. Phase 7 (alerts, weather, notifications) and task 5.5. Nothing else depends on them.
2. Task 8.2 (photo backup and contribution). Keep the toggles off and hidden, or omit them.
3. Phase 6 (offline model). Ship cloud-only and say so.
4. Image-card sharing in 8.5. Keep the text share.
5. History sync (5.4). SQLite already holds everything.

### Non-negotiable regardless of schedule

| Item | Why |
|---|---|
| 3.1 KB validator and the reviewed-KB rule | Prevents unreviewed treatment advice reaching farmers |
| 3.5 App Check, quota, kill-switch | Prevents uncontrolled AI spend |
| 3.7 Dose filter on general advice | Prevents invented doses for other crops |
| 4.2 Disclaimer and safety line | Safety and honesty about AI limits |
| 8.3 `deleteMyData` | Real control over personal data |
| 9.1 Calibration on field photos | Confidence labels must mean something |
| 9.4 Kill-switch and KB rollback drills | The way to stop harm quickly |
