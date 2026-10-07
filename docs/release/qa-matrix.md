# Budget-phone QA matrix (task 9.2)

Nothing here has been run: it needs real phones and the real internal-track build. Fill the table in; P1 failures block the release.
Mark results `P` (pass), `F` (fail, link the defect) or `n/a`.

| Device | Spec | Phone (model, Android, build) |
|---|---|---|
| D1 | Android 8–9, 2 GB RAM, 32-bit (`armeabi-v7a`), low free storage | |
| D2 | Android 11–12, 3 GB, mid-range | |
| D3 | Android 13+, 4 GB | |
| Emu | Network profiles for 3G-like conditions; airplane mode | |

| ID | Case | Pri | Automated coverage already in the repo | D1 | D2 | D3 |
|---|---|---|---|---|---|---|
| QA-01 | Fresh install, airplane mode, complete onboarding | P1 | onboarding widget tests | | | |
| QA-02 | Bangla conjuncts, digits and line height on all screens | P1 | Bangla sample on Settings (debug) | | | |
| QA-03 | Camera: kill the app while the system camera is open; resume | P1 | lost-photo recovery tests | | | |
| QA-04 | Blurry, dark, not-a-plant and wrong-crop photos give the right tips | P1 | image-prep fixtures (synthetic) | | | |
| QA-05 | Cloud diagnosis on 3G-like network meets the latency target (8 s budget) | P1 | none | | | |
| QA-06 | Cloud timeout falls back to on-device (if model shipped) or shows a clear failure | P1 | service fallback matrix | | | |
| QA-07 | Every result state: high, medium, low, healthy, unknown, general advice | P1 | result screen tests | | | |
| QA-08 | TTS plays, pauses, resumes; missing-voice dialog | P1 | controller tests with a fake engine | | | |
| QA-09 | History: 51st entry evicts the oldest; KB drift messages | P2 | DAO/retention tests | | | |
| QA-10 | Large system font does not break layouts | P2 | text-scale clamp | | | |
| QA-11 | Uploaded photos contain no EXIF/location (inspect a `backups/` object) | P1 | stripMetadata tests | | | |
| QA-12 | Toggles off: nothing uploaded (watch Storage and Firestore while diagnosing) | P1 | sync tests ("both off uploads nothing") | | | |
| QA-13 | "ইতিহাস মুছুন" removes local and cloud data | P1 | emulator delete e2e | | | |
| QA-14 | Helpline: dialer opens; hours text correct | P2 | expert screen tests | | | |
| QA-15 | Share card and text in WhatsApp and SMS; Bangla renders correctly | P2 | card renders to PNG (placeholder font) | | | |
| QA-16 | Alerts and weather push per the end-to-end script | P2 | alerts emulator e2e (no real FCM) | | | |
| QA-17 | Low memory: open camera, background app, return | P1 | none | | | |
| QA-18 | Cold start within the Phase 1 baseline | P2 | none | | | |
| QA-19 | KB update: publish a higher seq on `stg`, open the app, new content appears; rollback seq hides an entry | P1 | updater tests, drills e2e | | | |
| QA-20 | Obfuscated release build: crash a test button → readable stack in Crashlytics after symbol upload | P1 | none | | | |

Defect log: `| id | case | device | what happened | severity | owner | status |`
