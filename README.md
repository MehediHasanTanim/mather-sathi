# কৃষি সহায় (Krishi Sahay)

AI crop-disease diagnosis for Bangladeshi farmers: photo → disease → Bangla treatment from a reviewed knowledge base.
Specs live in `docs/` (feature spec, technical design, implementation plan).

## Layout
`lib/` Flutter app · `functions/` Firebase Cloud Functions (TS) · `kb/` knowledge-base sources ·
`tools/` kb_build and eval · `firebase/` rules, indexes, rules tests · `assets/` bundled data.

## Local setup
- Flutter app: `flutter pub get && flutter test`. Run a flavor: `flutter run --flavor dev -t lib/main_dev.dart`
  (needs the per-flavor Firebase files from `flutterfire configure`, see below).
- Functions: `npm ci --prefix functions && npm test --prefix functions`
- KB: `node tools/kb_build/build.js --validate --env stg`
- Rules: `npm ci --prefix firebase && npm test --prefix firebase`

## Manual Phase 0 steps (need cloud accounts)
0.2 create Firebase projects dev/stg/prod (Blaze on stg/prod, Firestore in `asia-south1`, budget alerts) ·
0.4 `flutterfire configure` per flavor · 0.5 set `ANTHROPIC_API_KEY` secret, create keystore, Play Console record.

## Task 0.4: FlutterFire per flavor
Enable Anonymous sign-in in each Firebase project, then run (use the real project ids):
```bash
flutterfire configure --project=krishi-dev  --platforms=android --android-package-name=com.nextgenai.mather_sathi.dev --out=lib/firebase/options_dev.dart  --android-out=android/app/src/dev/google-services.json  --yes
flutterfire configure --project=krishi-stg  --platforms=android --android-package-name=com.nextgenai.mather_sathi.stg --out=lib/firebase/options_stg.dart  --android-out=android/app/src/stg/google-services.json  --yes
flutterfire configure --project=krishi-prod --platforms=android --android-package-name=com.nextgenai.mather_sathi     --out=lib/firebase/options_prod.dart --android-out=android/app/src/prod/google-services.json --yes
```
Commit the generated files (public client config, not secrets). The `lib/firebase/options_*.dart` files in the repo are placeholders until then.
Run the dev flavor, copy the App Check debug token from `adb logcat`, and register it under App Check > Apps > Manage debug tokens.
The home screen shows the anonymous uid; it should appear under Authentication > Users.
