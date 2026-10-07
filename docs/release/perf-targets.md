# Performance pass (task 9.3)

Targets are from Design §6, §14 and the plan; measurements need real phones and a release build, so the "measured" columns are empty.

| Metric | Target | How to measure | D1 | D2 | D3 |
|---|---|---|---|---|---|
| Cold start to first frame | within the Phase 1 baseline (`docs/perf-baseline.md`) | `adb shell am start -W`, `cold_start_first_frame_ms` in logcat | | | |
| Cloud diagnosis, photo to result | p95 inside the 8 s client budget on 3G-like; recorded as p50/p95 | analytics `diagnosis_completed.latency_ms` split by `source`; device on a throttled profile | | | |
| Cloud function latency | p95 < 6 s (alert threshold) | Cloud Monitoring `diagnose_latency_ms` | | | |
| On-device diagnosis (if the model ships) | recorded, no fixed target yet | same event, `source=on_device` | | | |
| Memory during diagnosis | no OOM on D1; never more than one decoded full-size image | Android Studio profiler, QA-17 | | | |
| APK/AAB size | ≤ ~60 MB per-ABI APK including model and KB | `bundletool build-apks`, size of the D1 split | | | |
| 32-bit libs | TFLite ships `armeabi-v7a` | unzip the AAB, look under `base/lib/` | | | |
| History screen | smooth scroll with 50 rows | profile mode | | | |

Regressions: file one defect per miss, with the number and the build.
