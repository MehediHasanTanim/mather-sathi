# Pilot kit (task 9.7): drafts

Plan: 20–30 farmers, 2–3 upazilas, 2 weeks, at least four launch crops, an agronomist or local agriculture officer on call (plan "Field Pilot Plan"). Do not start before: KB signed off (K7), calibration (9.1), QA matrix green (9.2), drills passed (9.4). The seed KB must never reach a pilot build.

| File | What |
|---|---|
| `farmer-guide.md` | one-page Bangla guide to print |
| `feedback-form.md` | questions for the end-of-pilot interview and a short form |
| `agronomist-review-sheet.md` | blind review template for the 100+ diagnoses sample |
| `support.md` | support channel, incident contacts, how to test it |

Measure (all from existing events and fields): accuracy vs agronomist truth, 👍/👎 vs truth, `latency_ms` p95 by `source`, `fallback_to_on_device` / `diagnosis_completed`, `retake_prompted` / photos, crash-free sessions (Crashlytics), comprehension (interview), safety (zero wrong-dose incidents: every medicine-bearing output reviewed).
