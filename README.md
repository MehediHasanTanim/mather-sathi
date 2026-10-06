# কৃষি সহায় (Krishi Sahay)

AI crop-disease diagnosis for Bangladeshi farmers: photo → disease → Bangla treatment from a reviewed knowledge base.
Specs live in `docs/` (feature spec, technical design, implementation plan).

## Layout
`lib/` Flutter app · `functions/` Firebase Cloud Functions (TS) · `kb/` knowledge-base sources ·
`tools/` kb_build and eval · `firebase/` rules, indexes, rules tests · `assets/` bundled data.

## Local setup
- Flutter app: install Flutter, then run `flutter create . --platforms=android --org com.nextgenai --project-name mather_sathi`
  once to generate `android/`, then add the flavors from the plan (Phase 0, task 0.3). `flutter pub get && flutter test`.
- Functions: `npm ci --prefix functions && npm test --prefix functions`
- KB: `node tools/kb_build/build.js --validate --env stg`
- Rules: `npm ci --prefix firebase && npm test --prefix firebase`

## Manual Phase 0 steps (need cloud accounts)
0.2 create Firebase projects dev/stg/prod (Blaze on stg/prod, Firestore in `asia-south1`, budget alerts) ·
0.4 `flutterfire configure` per flavor · 0.5 set `ANTHROPIC_API_KEY` secret, create keystore, Play Console record.
