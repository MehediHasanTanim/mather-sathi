# Cold-start baseline (task 1.1)

`ColdStart` logs `cold_start_first_frame_ms=<n>` (time from `main()` to the first frame; filter logcat with
`adb logcat | grep cold_start`). Process start to first frame is measured with:

```bash
adb shell am force-stop com.nextgenai.mather_sathi.dev
adb shell am start -W -n com.nextgenai.mather_sathi.dev/com.nextgenai.mather_sathi.MainActivity
```
Use `TotalTime` from the output. Record release-mode numbers (`flutter run --release --flavor dev -t lib/main_dev.dart`).

| Device | Android | Build | first_frame_ms | am start TotalTime | Date |
|---|---|---|---|---|---|
| _to be measured on a 2 GB budget phone_ | | | | | |
