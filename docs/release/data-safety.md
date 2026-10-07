# Play "Data safety" answers (draft, task 9.6)

Derived from Design §15.2 and the code as built. Re-check against the final build and the AI provider's retention terms before submitting.

**Does the app collect or share user data?** Yes, collected. Shared with a third party: the diagnosis photo is sent to an AI service provider to process the request (declare as shared with a service provider acting on the developer's behalf, if Play's wording allows; otherwise declare as shared).

**Is data encrypted in transit?** Yes (HTTPS only; cleartext is disabled in the manifest).
**Can users request deletion?** Yes, in the app: Settings → "ইতিহাস মুছুন" deletes history, reports, backed-up and contributed photos from the server and the phone. Provide a web/e-mail route as well (Play requires a deletion URL when an account exists; the app uses anonymous sign-in, so confirm whether the account-deletion section applies).

| Play category | Data | Collected | Shared | Purpose | Optional? |
|---|---|---|---|---|---|
| Photos and videos | Leaf photo (EXIF removed, ≤ 300 KB) sent for each online diagnosis | Yes | Yes (AI provider processes it) | App functionality | Required for online diagnosis; offline model needs no upload |
| Photos and videos | Photo kept in cloud backup (30 days) | Yes, only if the backup toggle is on | No | App functionality | Optional, default off |
| Photos and videos | Photo contributed to improve the model | Yes, only if the contribution toggle is on | No | App functionality / model improvement | Optional, default off |
| App activity | Diagnosis history metadata and feedback | Yes | No | App functionality | Required for history sync |
| App activity | Regional report: district, upazila, crop, disease (no photo, no name) | Yes, if the toggle is on | No (shown only as aggregated counts to other farmers) | App functionality | Optional, default on |
| App info and performance | Crash logs, diagnostics | Yes | No | Analytics, app performance | Required |
| App activity | Analytics events (no personal data; see Design §16.2) | Yes | No | Analytics | Required (no opt-out built) |
| Device or other IDs | Anonymous Firebase user id, FCM token, Firebase installation id | Yes | No | App functionality, notifications, analytics | Required |
| Location | District/upazila the farmer **selects** (not GPS) | Yes | No | App functionality (alerts, weather) | Required to get local alerts |

Not collected: name, phone number, e-mail, precise location, contacts, financial info.
