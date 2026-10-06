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
