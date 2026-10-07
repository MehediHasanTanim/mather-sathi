# Cloud eval harness (task 3.9)

Runs a labelled field-photo set through the exact `classifyImage()` the `diagnose` Function uses and writes a JSON report:
per-crop and per-disease top-1, confusion matrix, **calibration table** (confidence bucket to observed accuracy), latency (mean/p50/p95)
and cost per call. Re-run it whenever the model, the prompt, or the KB candidate list changes; it sets the Remote Config
thresholds and chooses the cloud model (task 9.1).

```bash
cd tools/eval && npm install
export ANTHROPIC_API_KEY=...            # costs real money: start with --limit 5
npx ts-node cloud_eval.ts --data ./testset --crops rice,potato --limit 5 --out reports/cloud_v0.json
npx ts-node cloud_eval.ts --data ./testset --dry-run            # dataset/wiring check, no API calls
VISION_MODEL=claude-sonnet-5-5 npx ts-node cloud_eval.ts ...    # compare candidate models
```

Dataset: `testset/{crop}/{disease_id}/*.jpg`, `disease_id` may be `healthy`. Use JPEGs prepared like the app's (short side about 1024 px,
at most 300 KB); larger files are reported as errors rather than uploaded. Photos must be **real field photos not used for training**
and the KB candidate list must be the one under test (`functions/src/kb_index.json`, built by `tools/kb_build`).
The seed KB is draft content: numbers from it measure the plumbing, not launch readiness.

## Calibration (task 9.1)

```bash
npx ts-node calibrate.ts --reports reports/haiku.json reports/sonnet.json \
    [--samples reports/ondevice_samples.json] [--quality reports/quality.json] [--out reports/calibration]
```
Reads eval reports (one per candidate cloud model), and optionally on-device samples and photo-quality measurements, and writes
`calibration.md` (for the agronomist review) and `calibration.json`: the chosen model, a launch / beta / drop verdict per crop, whether the
confidence buckets are trustworthy, and **only the Remote Config values that were actually measured**
(`conf_high`, `conf_medium`, `min_crop_mass`, `blur_threshold`, `dark_threshold`). The default bar (`functions/src/calibration.ts`,
`DRAFT_BAR`) is the plan's draft: top-1 >= 80% per crop, high bucket >= 90%, medium >= 70%, at least 30 photos per number. Agree the real
bar with the agronomist; a crop below it leaves the launch list, the bar does not move.

- `--samples`: `[{ "crop", "expected", "predicted", "share" }]`, from the on-device model on the same held-out **field** photos (`share` = the winner's share of the chosen crop's probability mass, see `lib/features/offline/crop_scoring.dart`).
- `--quality`: `{ "blur": {"good": [...], "bad": [...]}, "dark": {...}, "cropMass": {...} }`. For blur and dark, produce the numbers with
  `QUALITY_DIR=<dir with blur|dark / good|bad / *.jpg> QUALITY_OUT=reports/quality.json flutter test test/tools/quality_stats_test.dart`
  (thumbnail made with the `image` package: confirm the final thresholds on a real phone).
