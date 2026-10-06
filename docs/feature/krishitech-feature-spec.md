# কৃষি সহায় (Krishi Sahay) — Feature Specification

**App Concept:** AI-powered crop disease diagnosis for Bangladeshi farmers  
**Version:** MVP 1.1 (revised after requirements audit)  
**Platform:** Flutter (Android-first; low-end device optimized)  
**Core Flow:** Farmer takes photo → AI identifies disease → Bangla treatment advice  
**Last Updated:** October 2026

---

## 0. Requirements Traceability

Your stated requirement: *"Farmer takes a photo of an affected crop; AI identifies the disease and suggests treatment in Bangla."*

| Requirement | Where it is specified |
|---|---|
| Farmer takes a photo of an affected crop | F1 (camera, gallery, guidance, quality check, crop selection, compression) |
| AI identifies the disease | F2.1–2.3 (cloud path + on-device path), F2.5 confidence, F2.6 no-disease / wrong-crop handling |
| Suggests treatment | F2.4 result screen; treatment text comes from the curated Disease Knowledge Base (§ Knowledge Base) |
| In Bangla | Principles, KB content (`*_bn` fields), UI strings, F3 TTS readout, Localization Notes |

Features 3–9 (TTS, history, expert routing, regional alerts, weather risk, onboarding, settings) are supporting features added around that core. They are not part of the one-line requirement and can be cut if scope must shrink. Cut order, last to first: F7 weather, F6 alerts, F4 history sync.

---

## Core Design Principles

- **Bangla-first** — entire UI and all treatment output in Bangla; no English required
- **Works on low-end phones** — 2GB RAM, Android 8+, 4G or even 3G
- **Offline-capable core** — bundled lite model covers the 8 launch crops without internet
- **No literacy barrier** — every diagnosis can be read aloud via TTS
- **Treatment is curated, not improvised** — the AI *identifies* the disease; pesticide names and doses come only from a vetted knowledge base (see below). The AI never invents doses.
- **No sponsored treatment advice** — if agri-input partners are ever added, they must be visually separate from the diagnosis and never influence which product is recommended
- **Zero cost to farmer** — app is free; images are compressed to limit mobile data use
- **Trust through simplicity** — avoid jargon; advice must be actionable within 24 hours

---

## Architecture Summary

```
Flutter App (Android-first)
├── Camera / Gallery              → Capture affected crop photo
├── Image compress                → Resize/JPEG before upload (3G-friendly)
├── On-device lite model (TFLite) → Offline classification → disease_id
├── Bundled Knowledge Base (JSON) → disease_id → Bangla treatment content
├── Firebase Cloud Functions      → Proxy to vision AI (API keys never in the app)
│     ├── diagnose()              → Vision model classifies image into KB disease IDs
│     ├── aggregateReports()      → Builds regional alert counters
│     └── refreshWeather()        → Scheduled per-district weather fetch (cached)
├── Firebase App Check            → Blocks non-genuine clients from calling Functions
├── Firebase Firestore            → History sync, reports, alerts, weather cache
├── Firebase Storage (opt-in)     → Photo backup if farmer consents
├── Firebase Auth (anonymous)     → Install identity, no signup required
├── flutter_tts                   → Read diagnosis aloud in Bangla
└── shared_preferences            → Selected crop, district, settings
```

> **Why a Cloud Function proxy:** calling a vision-AI API directly from the app would embed the API key in the APK, where it can be extracted and abused. Cloud Functions require the Firebase **Blaze** (pay-as-you-go) plan; it has free monthly quotas but needs a billing account.

---

## Knowledge Base (KB) — Source of Treatment Content

The KB is the single source of truth for everything the farmer reads or hears about a disease. Both the cloud path and the offline path return a `disease_id`; the app looks up the KB entry and renders the same result screen.

**Entry schema (bundled JSON, updatable via Firestore/Remote Config):**

```json
{
  "id": "rice_blast",
  "crop": "rice",
  "name_bn": "ধানের ব্লাস্ট রোগ",
  "description_bn": "<২-৩ বাক্যের বিবরণ>",
  "symptoms_bn": ["<লক্ষণ ১>", "<লক্ষণ ২>", "<লক্ষণ ৩>"],
  "cause_bn": "<১-২ বাক্য>",
  "urgency": "high",
  "immediate_bn": ["<এখনই করণীয় ১>", "<এখনই করণীয় ২>"],
  "medicine": [
    {
      "name_bn": "<অনুমোদিত ওষুধের নাম>",
      "active_ingredient": "<verified>",
      "dose_bn": "<verified dose>",
      "interval_bn": "<verified interval>",
      "pre_harvest_interval_days": "<verified>"
    }
  ],
  "prevention_bn": ["<প্রতিরোধ ১>", "<প্রতিরোধ ২>"],
  "see_expert": false,
  "source": "<DAE / BRRI / BARI document reference>",
  "reviewed_by": "<agronomist name>",
  "reviewed_at": "<date>"
}
```

**Rules**
- Every `medicine` entry must be reviewed by a qualified agronomist/plant pathologist against DAE, BRRI or BARI guidance before release. No entry ships with unverified doses.
- Fields in angle brackets above are placeholders: this spec deliberately does not state real doses.
- Scope: 8 crops × ~5 diseases = ~40 entries at launch.
- Each entry carries `source`, `reviewed_by`, `reviewed_at` for auditability.
- KB version is stored in the app; a newer KB is pulled when online.

**Crops outside the KB ("অন্যান্য ফসল"):** the cloud model gives a general description and prevention advice only, with **no medicine names or doses**, plus a prominent "see expert" prompt.

---

## Feature List

---

### Feature 1: Crop Photo Capture

**Purpose:** Farmer captures or selects an image of the diseased crop part.

#### 1.1 Photo Input Methods

| Method | Description |
|---|---|
| Camera (live) | Opens device camera; farmer photographs affected leaf/stem/fruit |
| Gallery picker | Selects existing photo from phone gallery |
| Retake | After preview, option to retake before submitting |

#### 1.2 Photo Guidance UX

Before capture, app shows a visual guide overlay:

```
┌─────────────────────────────┐
│   📸 ছবি তুলুন              │
│                             │
│   ✅ পাতার কাছ থেকে তুলুন  │
│   ✅ আলো যেন ভালো থাকে     │
│   ✅ রোগাক্রান্ত অংশ         │
│      ফ্রেমে রাখুন            │
│   ❌ ঝাপসা ছবি দেবেন না     │
└─────────────────────────────┘
```

Displayed as a bottom sheet for 3 seconds before camera opens. Dismissable.

#### 1.3 Photo Quality Check

After capture, before sending to AI:
- Minimum resolution check: 480×480 px
- Blur detection (Laplacian variance < threshold → warn user)
- If too blurry: show "ছবিটি একটু ঝাপসা — আবার চেষ্টা করুন" with Retake button
- Blur threshold is tuned on real field photos during QA, not fixed in advance

#### 1.4 Image Preparation (before upload)

- Resize longest edge to **1024 px**, JPEG quality ~80, strip EXIF/location metadata
- Target payload ≤ ~300 KB so the cloud call is feasible on 3G
- The original stays on the device only; the compressed copy is what is sent

#### 1.5 Crop Selection (Pre-Capture)

Farmer selects their crop type before taking the photo. This improves accuracy significantly.

**Supported crops at MVP launch (8 crops):**

| Crop (Bangla) | Crop (English) | Icon |
|---|---|---|
| ধান | Rice | 🌾 |
| পাট | Jute | 🪴 |
| আলু | Potato | 🥔 |
| টমেটো | Tomato | 🍅 |
| বেগুন | Brinjal/Eggplant | 🍆 |
| মরিচ | Chili | 🌶️ |
| পেঁয়াজ | Onion | 🧅 |
| সরিষা | Mustard | 🌻 |

Displayed as a 2×4 icon grid. Last selected crop is remembered across sessions.

**"অন্যান্য ফসল" (Other crop)** — text input fallback; cloud-only path with the restricted output described in the KB section. If offline, show "এই ফসলের জন্য ইন্টারনেট দরকার".

---

### Feature 2: AI Disease Diagnosis

**Purpose:** Core feature. Identifies the disease from the photo and returns Bangla treatment advice.

#### 2.1 Diagnosis Pipeline

```
User submits photo + crop type
          │
   compress + quality check
          │
   ┌──── Internet? ────┐
   │ No                │ Yes
   ▼                   ▼
On-device          Cloud Function diagnose()
TFLite model       (App Check verified)
   │                   │ vision model classifies into
   │                   │ the KB disease IDs for that crop
   │                   │ (or "unknown")
   └────────┬──────────┘
            ▼
   { disease_id, confidence bucket }
            │
            ▼
   KB lookup → Bangla content
            │
            ▼
   Result screen + TTS + history save
```

If the cloud call fails or times out (8 s), the app falls back to the on-device model automatically for the 8 launch crops (see 2.8).

#### 2.2 On-device Lite Model (Offline Mode)

- TFLite classifier bundled in APK (target ≤ ~25 MB)
- Covers 8 crops × ~5 diseases ≈ 40 classes, plus a "healthy / unknown" class per crop
- Output: `disease_id` + softmax score, mapped to the confidence buckets in 2.5
- Low-confidence offline result shows the caveat "ইন্টারনেট চালু করে আরও নিখুঁত ফলাফল পান"

**Example classes (Rice / ধান):**

| Class | Disease (Bangla) |
|---|---|
| rice_blast | ধানের ব্লাস্ট রোগ |
| brown_spot | বাদামি দাগ রোগ |
| bacterial_blight | ব্যাকটেরিয়াল ব্লাইট |
| neck_rot | নেক রট |
| sheath_blight | শিথ ব্লাইট |

> **Dependency:** this model needs a labelled field-image dataset. See *Model & Data Plan*. Without it, ship cloud-only first and add offline in v1.1.

#### 2.3 Cloud Path (Online Mode)

The app calls the `diagnose` Cloud Function with `{image, crop_id}`. The function sends the image to a vision model (Claude Haiku-class or a Gemini Flash-class model; chosen by accuracy on the QA set) and asks it to **classify**, not to write treatment.

**Classification prompt (inside the Function, KB IDs injected per crop):**
```
You are a plant pathology assistant for Bangladeshi crops.
Crop: {crop_id}
Candidate diseases: {list of KB ids + short Bangla/English descriptors for this crop}

Look at the image and choose the single best match from the candidate list.
If the image shows no visible disease, return "healthy".
If it does not clearly match any candidate, or the image is not this crop,
or the image is not a plant, return "unknown".
Do not invent diseases outside the list.

Return JSON only:
{
  "disease_id": "<id | healthy | unknown>",
  "confidence": "high|medium|low",
  "image_issue": "none|blurry|not_a_plant|wrong_crop|too_dark",
  "visible_symptoms": ["<short English note>", "..."]
}
```

**Free-text path for "other crops" (Bangla, no medicines):**
```
তুমি একজন অভিজ্ঞ বাংলাদেশি কৃষি বিশেষজ্ঞ। ছবিতে ফসলের যে সমস্যা দেখা যাচ্ছে তা সহজ বাংলায় ২-৩ বাক্যে বলো।
ওষুধের নাম বা মাত্রা কখনো বলবে না। সাধারণ প্রতিরোধমূলক পরামর্শ দাও এবং কৃষি কর্মকর্তার সাথে যোগাযোগ করতে বলো।
```

The Function returns the classification; the app merges it with the KB entry. Because the model only picks from a closed list, the treatment text is always KB-reviewed content.

#### 2.4 Diagnosis Result Screen

```
┌─────────────────────────────────────────┐
│ 🔴 ধানের ব্লাস্ট রোগ             [শেয়ার]│
│ নিশ্চিতমাত্রা বেশি ✅                    │
├─────────────────────────────────────────┤
│ 📢 [শুনুন]   ⚠️ জরুরি চিকিৎসা দরকার   │
├─────────────────────────────────────────┤
│ 📋 রোগের বিবরণ        {description_bn}  │
├─────────────────────────────────────────┤
│ 🔬 লক্ষণসমূহ          {symptoms_bn[]}   │
├─────────────────────────────────────────┤
│ 💊 চিকিৎসা                              │
│ এখনই করুন:            {immediate_bn[]}  │
│ ওষুধ:                 {medicine.name_bn}│
│ মাত্রা:               {medicine.dose_bn}│
│ কতদিন পর পর:          {interval_bn}     │
│ ফসল তোলার আগে বিরতি:  {pre-harvest days}│
│ ⛑️ স্প্রের সময় মাস্ক ও গ্লাভস পরুন,    │
│    ওষুধের মোড়কের নির্দেশনা পড়ুন       │
├─────────────────────────────────────────┤
│ 🛡️ প্রতিরোধ           {prevention_bn[]} │
├─────────────────────────────────────────┤
│ 👨‍⚕️ কৃষি কর্মকর্তার পরামর্শ নিন         │
├─────────────────────────────────────────┤
│ ফলাফলটি কি সঠিক ছিল?   [👍 হ্যাঁ] [👎 না] │
│ ℹ️ এটি এআই-ভিত্তিক পরামর্শ; চূড়ান্ত      │
│   সিদ্ধান্তের আগে কৃষি কর্মকর্তার সাথে  │
│   কথা বলুন।                             │
└─────────────────────────────────────────┘
```

All `{...}` fields are filled from the KB entry. No percentage is shown: LLM and softmax scores are not reliable probabilities, so only the three buckets in 2.5 are displayed.

**Color coding by urgency (from KB `urgency`):**
- 🔴 High urgency — red header
- 🟡 Medium urgency — orange header
- 🟢 Low urgency / preventive — green header

#### 2.5 Confidence Buckets

Both paths are normalized to the same three buckets.

| Bucket | Cloud source | On-device source (provisional) | Display |
|---|---|---|---|
| high | model says `high` | softmax ≥ 0.80 | "নিশ্চিতমাত্রা বেশি ✅" |
| medium | model says `medium` | 0.60–0.79 | "সম্ভাব্য রোগ ⚠️ — বিশেষজ্ঞকে দেখান" |
| low | model says `low` | < 0.60 | "ছবি থেকে নিশ্চিত হওয়া যায়নি — আরও কাছ থেকে ছবি তুলুন" |

On-device thresholds are provisional and must be calibrated on the held-out field test set.

#### 2.6 Non-diagnosis States

| State | Trigger | Behavior |
|---|---|---|
| Healthy | `disease_id = healthy` | "আপনার ফসলে কোনো পরিচিত রোগ দেখা যায়নি 🌿" + prevention tips |
| Unknown | `disease_id = unknown` | "নিশ্চিত হওয়া যায়নি" + Retry + expert contact CTA |
| Wrong crop | `image_issue = wrong_crop` | "এটি {crop} বলে মনে হচ্ছে না — ফসল ঠিক আছে?" with crop re-select |
| Not a plant / blurry / dark | `image_issue` set | Specific Bangla tip + Retake |

Sub-text on Healthy/Unknown: "ছবিটি ভালো মানের হলে আবার চেষ্টা করুন, অথবা কৃষি কর্মকর্তার সাথে যোগাযোগ করুন". Two CTAs: **আবার চেষ্টা করুন** | **কর্মকর্তার নম্বর**.

#### 2.7 Farmer Feedback

- "ফলাফলটি কি সঠিক ছিল?" 👍/👎 on every result; 👎 optionally asks "আসল রোগ কী ছিল?" from the crop's disease list
- Stored locally on the history row; sent to Firestore `feedback/` (no photo unless photo-contribution consent is on)
- Purpose: measure real-world accuracy and build the next training set

#### 2.8 Error and Offline Handling

| Situation | Behavior |
|---|---|
| No internet, launch crop | On-device result with offline caveat |
| No internet, other crop | "এই ফসলের জন্য ইন্টারনেট দরকার" |
| Cloud timeout (8 s) / server error | Fall back to on-device; if unavailable, "আবার চেষ্টা করুন" |
| Rate limit / App Check rejected | Friendly Bangla message; do not retry in a loop |
| Per-install daily cap | e.g. 30 cloud diagnoses/day/install to bound cost; message when reached |
| Slow upload | Progress indicator + cancel button |

---

### Feature 3: Text-to-Speech (TTS) Diagnosis Readout

**Purpose:** Farmers who struggle to read can hear the full diagnosis in Bangla.

#### 3.1 TTS Behavior

- Powered by `flutter_tts` (uses the device's built-in Bangla TTS engine)
- Tapping 📢 **[শুনুন]** starts playback of the diagnosis
- Reads: disease name → description → immediate actions → medicine name + dose + interval → safety line
- Playback speed: 0.85× default (slower for clarity); setting in Settings
- Pause/resume button shown during playback
- If device has no Bangla TTS voice: dialog guiding the farmer to install Google TTS Bangla voice data
- Quality of Bangla TTS varies by device; QA must test on the target budget phones

#### 3.2 TTS Script Template

```
রোগের নাম: {name_bn}।
{description_bn}।
এখনই যা করবেন: {immediate_bn[0]}। {immediate_bn[1]}।
ওষুধ: {medicine[0].name_bn}। মাত্রা: {medicine[0].dose_bn}।
{medicine[0].interval_bn}।
স্প্রের সময় মাস্ক ও গ্লাভস পরুন।
```

---

### Feature 4: Diagnosis History

**Purpose:** Farmer can revisit past diagnoses without re-scanning.

#### 4.1 History List Screen

- Sorted by most recent
- Each entry shows: thumbnail, crop type, disease name, date, urgency badge
- Stored locally in SQLite (source of truth); optionally synced to Firestore

#### 4.2 History Entry Detail

Tapping an entry reopens the result screen (read-only), rendered from the stored `disease_id` and the **current** KB. A "KB updated since" note appears if the KB entry changed after the diagnosis date.

#### 4.3 Data Model

See *SQLite Schema* below (single definition).

#### 4.4 Retention

- Local SQLite: keep last 50 diagnoses (auto-delete oldest, including local photo file)
- Firebase Storage photos (only if backup consent is on): deleted after 30 days; the matching Firestore `photo_url` is then cleared by a scheduled Function so no dead links remain
- Firestore history records (no photo): kept until the farmer deletes history or the account is purged
- "ইতিহাস মুছুন" deletes local rows and the farmer's Firestore/Storage data

> **Limitation:** anonymous Firebase Auth ties history to the install. If the app is uninstalled or data is cleared, cloud history cannot be recovered. Phone-number linking is a post-MVP option.

---

### Feature 5: Expert Contact & Extension Worker Routing

**Purpose:** For serious or unidentified diseases, connect the farmer to the government agriculture helpline or a local officer.

#### 5.1 "কর্মকর্তার সাথে যোগাযোগ করুন" CTA

Shown on:
- Any diagnosis with KB `see_expert: true`
- Confidence bucket `low` (and recommended for `medium`)
- Healthy/Unknown states and "other crop" results

#### 5.2 Contact Options

```
┌──────────────────────────────────┐
│ 👨‍🌾 কৃষি সহায়তা                 │
├──────────────────────────────────┤
│ 📞 কৃষি কল সেন্টার              │
│    ১৬১২৩ (কৃষি সম্প্রসারণ অধিদপ্তর) │
│    [কল করুন]                     │
├──────────────────────────────────┤
│ 📱 ছবি ও ফলাফল শেয়ার করুন        │
│    (আপনার পছন্দের যেকোনো অ্যাপে)  │
│    [শেয়ার করুন]                  │
└──────────────────────────────────┘
```

**Helpline:** 16123, Krishi Call Centre run by the Department of Agricultural Extension (DAE). A Dhaka Tribune feature confirms the number and operator, but it is a dated press report. It also states operating hours (about 9 am–5 pm, closed Fridays and government holidays) and a per-minute call charge. **Verify the current number, hours and charge with DAE before launch**, and show the hours in the UI so farmers do not call when it is closed.

**Share behavior:** uses the system share sheet so the farmer can send the diagnosis to a relative, input dealer or local agriculture officer. The app does not claim an official DAE WhatsApp/SMS number, since none has been verified.

#### 5.3 Share Diagnosis Feature

- **Image card** (PNG with disease name + treatment summary)
- **Text** (plain Bangla for SMS/WhatsApp)
- **PDF** — post-MVP

---

### Feature 6: Disease Alert Feed (Regional)

**Purpose:** Show recent disease reports from other farmers in the same district.

#### 6.1 How It Works

- After a diagnosis with confidence `high` or `medium`, and only if the farmer has location sharing on, the app writes an anonymized report `{district, upazila, crop, disease_id, week}` to Firestore `reports/`
- A Cloud Function (`aggregateReports`) dedupes by install (one report per install per disease per week) and updates `alerts/{district}_{upazila}_{crop}_{disease}_{week}` counters
- The app only reads `alerts/`; it never reads raw `reports/`

#### 6.2 Anti-abuse Rules

- An alert is shown only when **≥ 3 distinct installs** report the same crop + disease + upazila within 7 days
- Reports require an App Check–verified anonymous user
- Firestore rules: clients may create `reports/` docs but not read, update or delete them; `alerts/` is read-only for clients
- Alerts older than 14 days expire from the feed

#### 6.3 Alert Feed UI

```
┌──────────────────────────────────────┐
│ 🚨 আপনার এলাকায় সাম্প্রতিক রোগবালাই │
│ ময়মনসিংহ জেলা                       │
├──────────────────────────────────────┤
│ 🌾 ধান — ব্লাস্ট রোগ               │
│ ত্রিশাল উপজেলা • ২ দিন আগে         │
│ ৩ জন কৃষক রিপোর্ট করেছেন           │
├──────────────────────────────────────┤
│ 🥔 আলু — লেট ব্লাইট                │
│ ফুলপুর উপজেলা • ৫ দিন আগে          │
│ ৭ জন কৃষক রিপোর্ট করেছেন           │
└──────────────────────────────────────┘
```

#### 6.4 Privacy

- No GPS is collected or stored. District and upazila are chosen from dropdowns during onboarding
- Location-sharing consent screen shown once, in plain Bangla; opt-out any time in Settings
- Reports contain no photo, no name, no phone number

---

### Feature 7: Weather-Disease Risk Indicator

**Purpose:** When conditions favour disease, warn the farmer proactively.

#### 7.1 Data Flow

- A scheduled Cloud Function (`refreshWeather`) fetches a 3-day forecast once or twice a day for each district's reference coordinates and caches it in Firestore `weather/{district}`
- The app reads its own district's document. No weather API key lives in the app, and call volume does not grow with the user count
- Weather source: OpenWeatherMap or Open-Meteo. Check each provider's free-tier terms against the app's commercial use before choosing

#### 7.2 Risk Logic

Risk rules live in the KB as per-crop rules owned by an agronomist, for example "humidity above X% with rain forecast → fungal-disease risk for crops A, B". The thresholds are **placeholders to be set by a plant pathologist**, not fixed by this spec.

Banner on the home screen (dismissable):

```
⛅ আগামী ৩ দিনে বৃষ্টি ও আর্দ্রতা বেশি থাকবে।
ধান ও আলু ক্ষেত পর্যবেক্ষণে রাখুন।
```

#### 7.3 Weather Data Model

```dart
class WeatherRisk {
  final String district;
  final double humidity;          // %
  final double tempMin;           // °C
  final double tempMax;
  final bool rainExpected;
  final List<String> riskCrops;   // Crops at risk
  final String riskMessage;       // Bangla warning text
  final DateTime fetchedAt;
}
```

#### 7.4 Notifications

The Settings "নোটিফিকেশন" toggle controls FCM push for two things only: (a) a weather-risk warning for the farmer's district and primary crop, (b) a new regional alert in the farmer's district. The app subscribes to FCM topics per district (e.g. `district_mymensingh`) and unsubscribes when the toggle is off.

---

### Feature 8: App Onboarding

**Purpose:** First-launch experience for non-tech-savvy farmers.

#### 8.1 Onboarding Screens (4 slides)

| Slide | Illustration | Text |
|---|---|---|
| 1 | Farmer with phone | "স্বাগতম! ফসলের রোগ এখন ঘরে বসেই শনাক্ত করুন" |
| 2 | Photo being taken | "শুধু ছবি তুলুন — AI বাকি কাজ করবে" |
| 3 | Bangla diagnosis screen | "সহজ বাংলায় চিকিৎসার পরামর্শ পান" |
| 4 | District selection | "আপনার জেলা বেছে নিন" |

#### 8.2 Profile Setup and Consent

After the slides:
1. Select district (64 districts, Bangla)
2. Select upazila (filtered by district)
3. Select primary crop (from the 8 supported)
4. Consent screen with three separate toggles, all in plain Bangla:
   - এলাকার রোগ সতর্কতায় অংশ নিন (anonymous reports) — default on
   - ছবি ক্লাউডে ব্যাকআপ রাখুন — default **off**
   - অ্যাপ উন্নত করতে আমার ছবি ব্যবহারের অনুমতি — default **off**

These are pre-filled on every future diagnosis session. Check applicable Bangladeshi data-protection requirements before launch.

---

### Feature 9: App Settings

| Setting | Options | Default |
|---|---|---|
| ভাষা | বাংলা | বাংলা (locked at MVP) |
| TTS গতি | ধীর / স্বাভাবিক / দ্রুত | স্বাভাবিক |
| এলাকার রোগ সতর্কতায় অংশ নিন | চালু / বন্ধ | চালু |
| ছবি ক্লাউডে ব্যাকআপ | চালু / বন্ধ | বন্ধ |
| ছবি দিয়ে অ্যাপ উন্নত করুন | চালু / বন্ধ | বন্ধ |
| নোটিফিকেশন | চালু / বন্ধ | চালু |
| জেলা / উপজেলা / প্রধান ফসল | change | from onboarding |
| ইতিহাস মুছুন | বাটন | — |
| অ্যাপ সম্পর্কে | — | version, KB version, contact |

---

## Model & Data Plan (Critical Path)

The on-device model and the KB are the long poles. Neither is a coding task.

| Item | Detail | Owner |
|---|---|---|
| Knowledge Base authoring | ~40 entries in Bangla, each sourced to DAE/BRRI/BARI guidance and reviewed | Agronomist / plant pathologist (partner or hired) |
| Training images | Public datasets are mostly lab-condition images and do not cover every launch crop (jute, mustard and onion are likely thin). Plan to collect and label real field photos | Field team + agronomist labelling |
| Held-out test set | Real field photos not used in training; used for accuracy numbers and threshold calibration | Same |
| Model training | Fine-tune a small mobile-friendly classifier (e.g. MobileNet-class) and export to TFLite | ML engineer (you) |
| Cloud model evaluation | Run the same test set through candidate vision models; pick by accuracy and cost | ML engineer |

**Fallback if data is not ready:** launch cloud-only, with the on-device model and offline mode shipping in v1.1.

---

## Non-Functional Requirements and Acceptance Targets

Proposed targets, to be confirmed after the first field test:

| Area | Target |
|---|---|
| Cloud diagnosis latency | ≤ 8 s on 3G with ≤ 300 KB image |
| On-device latency | ≤ 2 s on a 2GB-RAM budget phone |
| Accuracy | Top-1 correct on the held-out field set; set the bar with the agronomist (a draft goal is ≥ 80% for launch crops) and report per crop |
| APK size | ≤ ~60 MB including model and KB |
| Min OS | Android 8.0 (API 26) |
| Cloud cost guard | Per-install daily cap + App Check |
| Safety | 100% of displayed medicines come from reviewed KB entries |
| Accessibility | Tap targets ≥ 48 dp, TTS available on result screen |

---

## SQLite Schema (Full)

```sql
CREATE TABLE diagnosis_history (
  id              TEXT PRIMARY KEY,
  crop_type       TEXT NOT NULL,
  disease_id      TEXT,                  -- KB id, or 'healthy' / 'unknown'
  kb_version      TEXT,                  -- KB version used at diagnosis time
  photo_path      TEXT,                  -- local file path
  photo_url       TEXT,                  -- Storage URL (only if backup consent)
  confidence      TEXT,                  -- 'high' | 'medium' | 'low'
  source          TEXT DEFAULT 'cloud',  -- 'cloud' | 'on_device'
  diagnosed_at    TEXT NOT NULL,
  district        TEXT,
  upazila         TEXT,
  feedback        TEXT,                  -- 'correct' | 'incorrect' | NULL
  feedback_actual TEXT,                  -- farmer-supplied disease_id if incorrect
  is_synced       INTEGER DEFAULT 0
);

CREATE TABLE user_profile (
  id                  INTEGER PRIMARY KEY DEFAULT 1,
  district            TEXT,
  upazila             TEXT,
  default_crop        TEXT,
  share_reports       INTEGER DEFAULT 1,
  photo_backup        INTEGER DEFAULT 0,
  photo_contribute    INTEGER DEFAULT 0,
  notifications       INTEGER DEFAULT 1,
  onboarding_done     INTEGER DEFAULT 0
);

CREATE INDEX idx_history_date ON diagnosis_history(diagnosed_at DESC);
CREATE INDEX idx_history_crop ON diagnosis_history(crop_type);
```

The full AI response is no longer stored: the result is rebuilt from `disease_id` and the KB.

---

## Firestore Rules (Sketch)

```
users/{uid}/history/{doc}   read, write: if request.auth.uid == uid
reports/{doc}               create: if request.auth != null; no read/update/delete
alerts/{doc}                read: if request.auth != null; no client writes
weather/{district}          read: if request.auth != null; no client writes
feedback/{doc}              create: if request.auth != null; no read
kb_versions/{doc}           read: if request.auth != null; no client writes
```

---

## Flutter Package Dependencies

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State management
  flutter_riverpod: ^2.5.1

  # Camera & image
  camera: ^0.11.0
  image_picker: ^1.1.2
  image: ^4.2.0                   # Blur detection (Laplacian)
  flutter_image_compress: ^2.3.0  # Resize/JPEG before upload

  # On-device ML
  tflite_flutter: ^0.10.4

  # Firebase
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.4
  cloud_firestore: ^5.2.1
  cloud_functions: ^5.1.0         # Calls diagnose() proxy
  firebase_app_check: ^0.3.0
  firebase_storage: ^12.1.3
  firebase_messaging: ^15.0.4

  # Connectivity
  connectivity_plus: ^6.0.5

  # TTS
  flutter_tts: ^4.0.2

  # Navigation
  go_router: ^14.2.7

  # Local DB
  sqflite: ^2.3.3+1
  path: ^1.9.0

  # Utilities
  shared_preferences: ^2.3.2
  uuid: ^4.4.2
  intl: ^0.19.0
  share_plus: ^9.0.0
  url_launcher: ^6.3.0            # tel: link to 16123

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.11
  riverpod_generator: ^2.4.3
  mockito: ^5.4.4
```

Removed from the first draft: `dart_openai` (the AI is called from the Function, not the app), `weather` and `geolocator` (weather is cached server-side and location comes from dropdowns, not GPS).

> Version numbers are indicative; run `flutter pub upgrade --major-versions` and pin at project start.

---

## AI Cost Estimate (Monthly, Rough)

Planning figures only. Re-check current model pricing before committing.

Per cloud call, a ~1024 px image plus the candidate list is roughly 2,000 input tokens, and the classification JSON is under ~100 output tokens. At Claude Haiku 4.5 list prices ($1 / $5 per million tokens) that is about **$0.0025 per call**. Gemini Flash–class models are typically cheaper per call, so verify the current price.

| Scenario (10,000 diagnoses/month) | Cloud calls | Approx. AI cost |
|---|---|---|
| 100% cloud | 10,000 | ~$25 |
| 60% on-device / 40% cloud | 4,000 | ~$10 |
| 100% on-device (offline) | 0 | $0 |

Other costs: Cloud Functions, Firestore and Storage are small at MVP volume but need the Blaze plan. The per-install daily cap and App Check keep a bad actor from running the bill up.

---

## MVP Build Sprint (10 Days)

**Parallel track, not in the 10 days:** KB authoring, field image collection, model training (see *Model & Data Plan*). Days 3–6 depend on at least a first KB batch.

| Day | Tasks | Deliverable |
|---|---|---|
| 1 | Project setup, Firebase, App Check, folder structure, onboarding (district/upazila/crop, consent) | App launches through onboarding |
| 2 | Crop selection, camera/gallery, quality check, image compression | Farmer can take/select a clean, compressed photo |
| 3 | `diagnose()` Cloud Function proxy, classification prompt, KB loader, daily cap | Image → `disease_id` from the cloud |
| 4 | Result screen from KB, confidence buckets, non-diagnosis states, TTS, disclaimer, feedback buttons | Full result with audio |
| 5 | SQLite history, offline/error handling, cloud-to-offline fallback logic | Past diagnoses; graceful failures |
| 6 | TFLite integration (needs trained model; otherwise skip to v1.1) | Offline diagnosis for launch crops |
| 7 | Reports + `aggregateReports()` + alert feed + Firestore rules | Regional alerts with ≥3-install threshold |
| 8 | `refreshWeather()` + banner + FCM topic notifications | Weather risk and push |
| 9 | Settings, expert contact (16123), share card, consent toggles | Feature-complete |
| 10 | QA with real field photos on budget phones, accuracy report, release APK | APK ready for field testing |

---

## Future Features (Post-MVP)

| Feature | Description |
|---|---|
| **বাজার দর (Market Prices)** | Live crop prices from a government or market data source |
| **সার পরামর্শ (Fertilizer Advice)** | Soil-based fertilizer recommendations |
| **ফসল ক্যালেন্ডার (Crop Calendar)** | Seasonal planting/harvesting schedule |
| **কৃষি ঋণ (Agri Credit)** | Links to BRDB/BKB loan application portals |
| **ভিডিও টিউটোরিয়াল** | Short Bangla videos on disease treatment |
| **Chatbot (কৃষি সহকারী)** | Free-text question answering in Bangla |
| **Multi-photo diagnosis** | 2–3 photos (leaf, whole plant, field) for higher accuracy |
| **Phone-number account linking** | Recover history after reinstall |
| **Tablet/Kiosk mode** | For Union Digital Centers (ইউনিয়ন ডিজিটাল সেন্টার) |

---

## Localization Notes

All strings must be in Bangla (bn-BD). Key UI strings:

| Key | Bangla |
|---|---|
| app_name | কৃষি সহায় |
| take_photo | ছবি তুলুন |
| select_crop | ফসল বেছে নিন |
| analyzing | বিশ্লেষণ করা হচ্ছে... |
| disease_found | রোগ শনাক্ত হয়েছে |
| no_disease | কোনো রোগ পাওয়া যায়নি |
| treatment | চিকিৎসা |
| prevention | প্রতিরোধ |
| listen | শুনুন |
| share | শেয়ার করুন |
| history | ইতিহাস |
| call_expert | বিশেষজ্ঞকে কল করুন |
| offline_mode | অফলাইন মোড |
| try_again | আবার চেষ্টা করুন |
| was_correct | ফলাফলটি কি সঠিক ছিল? |
| ai_disclaimer | এটি এআই-ভিত্তিক পরামর্শ; চূড়ান্ত সিদ্ধান্তের আগে কৃষি কর্মকর্তার সাথে কথা বলুন |
| safety_line | স্প্রের সময় মাস্ক ও গ্লাভস পরুন, ওষুধের মোড়কের নির্দেশনা পড়ুন |
| needs_internet | এই ফসলের জন্য ইন্টারনেট দরকার |

---

## Target User Profile

| Attribute | Detail |
|---|---|
| Primary user | Small/medium farmer, 30–55 years old |
| Location | Rural Bangladesh (64 districts) |
| Device | Budget Android (Samsung Galaxy A series, Walton) |
| Literacy | Basic Bangla literacy; may not read well |
| Connectivity | Spotty 4G; sometimes 3G or offline |
| Tech literacy | Can use WhatsApp and Facebook; unfamiliar with complex apps |
| Pain point | Travels to the Upazila office for a disease diagnosis; expensive and time-consuming |
| Motivation | Save the crop, reduce pesticide cost, increase yield |

---

## Open Decisions

1. **KB owner:** who reviews treatment content (DAE/BARI/BRRI partnership, university agronomist, or a hired consultant)? This gates launch.
2. **Offline at launch or v1.1?** Depends on whether labelled field images exist by about Day 6.
3. **Monetization stance:** confirm that treatment advice stays free of sponsored products.
4. **Photo use for model improvement:** confirm the consent wording and who may access contributed photos.
