#!/usr/bin/env bash
# Builds the obfuscated release bundle for one flavor (Design §15.1, plan tasks 9.4 and 9.6).
#   tools/release/build_aab.sh stg|prod
# Refuses to build without the upload key, because Play rejects a debug-signed bundle.
set -euo pipefail
cd "$(dirname "$0")/../.."
flavor="${1:?usage: build_aab.sh stg|prod}"
case "$flavor" in stg|prod) ;; *) echo "flavor must be stg or prod" >&2; exit 2;; esac

[ -f android/key.properties ] || { echo "android/key.properties is missing: no upload key, not building." >&2; exit 1; }
if grep -q "PLACEHOLDER" "lib/firebase/options_${flavor}.dart"; then
  echo "lib/firebase/options_${flavor}.dart is still the placeholder: run flutterfire configure for the ${flavor} project." >&2; exit 1
fi
[ -f "android/app/src/${flavor}/google-services.json" ] || { echo "android/app/src/${flavor}/google-services.json is missing for ${flavor}." >&2; exit 1; }

echo "== checks =="
node tools/kb_build/build.js --env "$flavor" --validate
node tools/kb_build/build.js --env "$flavor" --check || { echo "assets/kb/kb.json is for another env: rebuild with --env $flavor before bundling" >&2; exit 1; }
flutter analyze
flutter test

echo "== build =="
flutter build appbundle --release --flavor "$flavor" -t "lib/main_${flavor}.dart" \
  --obfuscate --split-debug-info=build/symbols --build-number "${BUILD_NUMBER:-1}"

aab="build/app/outputs/bundle/${flavor}Release/app-${flavor}-release.aab"
ls -l "$aab"
echo
echo "Next: upload symbols so Crashlytics can de-obfuscate crashes:"
echo "  firebase crashlytics:symbols:upload --app=<firebase android app id> build/symbols"
echo "Then test this exact bundle on the three QA devices (docs/release/qa-matrix.md) before promoting it."
