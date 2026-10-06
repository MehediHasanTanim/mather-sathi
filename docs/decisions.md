# Decision Record (Task 0.1)

**Status: DRAFT, not signed off.** Gate G0 requires a named KB reviewer. No work past Phase 2 starts without one.
Only dev-seed KB content may be used until then, and never in a pilot or production build.

| # | Decision | Options | Choice | Owner / date |
|---|---|---|---|---|
| 1 | KB reviewer (agronomist) and start date | DAE/BARI/BRRI, university, consultant | **OPEN** | |
| 2 | Offline model in v1.0 or v1.1 | v1.0 if field dataset ready by end of Phase 4, else v1.1 | **OPEN** (default: v1.1, cloud-only first) | |
| 3 | Distribution | Play only / also sideload (App Check caveat, Design §15.1) | **OPEN** (default: Play) | |
| 4 | Sponsored content | None in diagnosis (spec principle) | No sponsored advice | |
| 5 | Firestore location | `asia-south1`; cannot be changed later | `asia-south1` (confirm latency) | |
| 6 | Android package id | `bd.krishisahay.app` (+ `.dev`, `.stg`) | proposed | |

Sign-off: ____________  Date: ________
