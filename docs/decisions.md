# Decision Record (Task 0.1)

**Status: Recorded from product-owner answers, 2026-10-06.**

| # | Decision | Choice | Notes |
|---|---|---|---|
| 1 | KB reviewer (agronomist) | **Deferred for development** | Dev-seed KB (`status: draft`) only. Draft entries are excluded from `stg`/`prod` builds (task 3.2). **A named reviewer is still required before any pilot or production build.** |
| 2 | Offline model | **v1.0 if the field dataset is ready by end of Phase 4, else v1.1.** Dataset to be prepared in-house | See caveat below. |
| 3 | Distribution | **Google Play only** | App Check (Play Integrity) can be enforced after monitor mode. |
| 4 | Sponsored content | **None** | No sponsored advice in diagnosis. |
| 5 | Firestore location | `asia-south1` | Cannot be changed later. |
| 6 | Android package id | `com.nextgenai.mather_sathi` (+ `.dev`, `.stg` suffixes for flavors) | Requested `com.nextgenai.mather-sathi` is invalid: Android application IDs allow only letters, digits and underscores per segment, so the hyphen became an underscore. |

## Caveat on decision 2
The plan (Track M) needs real, expert-labelled **field** photos, split by field/farm and date. An in-house
dataset assembled from public or lab-condition images will not give trustworthy accuracy or confidence thresholds.
Until a labelled field set exists, ship cloud-only (v1.1 offline), as the contingency table already allows.

## Data provenance: `assets/data/districts.json` (task O2 / 1.4)
Generated from the open `nuhil/bangladesh-geocode` dataset (64 districts, 494 upazilas, Bangla and English names, reference lat/lon).
**Must be validated against the official Bangladesh administrative list before release** (the national total is about 495 upazilas;
names and spellings can lag official changes). Slugs are used for FCM topics (`d_<slug>`).
