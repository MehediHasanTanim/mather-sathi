#!/usr/bin/env bash
# Observability for plan task 9.5: log-based metrics and alert policies for the `diagnose` Function, plus a billing budget.
# NOT RUN from the dev sandbox (no GCP access): run it once per project (stg, prod) and then do the drill in
# docs/release/ops-runbook.md ("force an error, see the alert"). Needs: gcloud authenticated, Cloud Monitoring and Billing APIs.
#   ops/setup_alerts.sh <project-id> <notification-email> [billing-account-id] [monthly-budget-usd]
set -euo pipefail
project="${1:?project id}"; email="${2:?notification email}"; billing="${3:-}"; budget="${4:-100}"

gcloud config set project "$project" >/dev/null

# Structured lines come from functions/src/diagnose.ts: {event:"diagnose", ok, code, latency_ms}. Severity ERROR is only used
# for unexpected failures (not for bad input, the daily cap, or the kill switch).
gcloud logging metrics create diagnose_errors \
  --description="Unexpected diagnose failures" \
  --log-filter='resource.type="cloud_run_revision" AND jsonPayload.event="diagnose" AND severity>=ERROR' || true

gcloud logging metrics create diagnose_latency_ms \
  --description="diagnose latency" \
  --log-filter='resource.type="cloud_run_revision" AND jsonPayload.event="diagnose" AND jsonPayload.ok=true' \
  --value-extractor='EXTRACT(jsonPayload.latency_ms)' \
  --config-from-file=<(cat <<'JSON'
{ "metricDescriptor": { "metricKind": "DELTA", "valueType": "DISTRIBUTION", "unit": "ms" },
  "valueExtractor": "EXTRACT(jsonPayload.latency_ms)",
  "bucketOptions": { "exponentialBuckets": { "numFiniteBuckets": 40, "growthFactor": 1.4, "scale": 100 } } }
JSON
) || true

channel=$(gcloud beta monitoring channels create --display-name="Krishi on-call" --type=email \
  --channel-labels="email_address=$email" --format='value(name)')

policy() { gcloud alpha monitoring policies create --policy-from-file=<(printf '%s' "$1") --notification-channels="$channel"; }

# More than 5 unexpected errors in 5 minutes.
policy '{
  "displayName": "diagnose: unexpected errors",
  "combiner": "OR",
  "conditions": [{ "displayName": "errors > 5 / 5 min",
    "conditionThreshold": { "filter": "metric.type=\"logging.googleapis.com/user/diagnose_errors\" resource.type=\"cloud_run_revision\"",
      "comparison": "COMPARISON_GT", "thresholdValue": 5, "duration": "0s",
      "aggregations": [{ "alignmentPeriod": "300s", "perSeriesAligner": "ALIGN_SUM" }] } }]
}'

# p95 latency above 6 s for 10 minutes (the app gives up at 8 s and falls back).
policy '{
  "displayName": "diagnose: p95 latency > 6 s",
  "combiner": "OR",
  "conditions": [{ "displayName": "p95 > 6000 ms",
    "conditionThreshold": { "filter": "metric.type=\"logging.googleapis.com/user/diagnose_latency_ms\" resource.type=\"cloud_run_revision\"",
      "comparison": "COMPARISON_GT", "thresholdValue": 6000, "duration": "600s",
      "aggregations": [{ "alignmentPeriod": "300s", "perSeriesAligner": "ALIGN_PERCENTILE_95" }] } }]
}'

if [ -n "$billing" ]; then
  gcloud billing budgets create --billing-account="$billing" --display-name="krishi-$project" \
    --budget-amount="${budget}USD" \
    --threshold-rule=percent=0.5 --threshold-rule=percent=0.9 --threshold-rule=percent=1.0 \
    --filter-projects="projects/$project"
else
  echo "No billing account given: create the budget alerts (50/90/100%) by hand in the console." >&2
fi
echo "Done. Now run the drill in docs/release/ops-runbook.md to prove the alert fires."
