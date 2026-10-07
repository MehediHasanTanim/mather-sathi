# Real photo fixtures (task 2.6)

Put 30+ real phone photos here, a few per folder, each folder named for what the photo *is*:
`photos/sharp` (good leaf close-ups in daylight), `photos/blurry`, `photos/dark`, `photos/not_a_plant`.
Keep them small (resize to about 1600 px, strip EXIF/location) so the repo stays light.

`flutter test test/features/capture/real_photos_test.dart` then reports the catch rate (blurry and dark found) and the
false-reject rate (sharp wrongly rejected) with the current `RemoteFlags` defaults, and fails if they miss the provisional
targets (>= 90% caught, <= 10% false rejects). Use the printed `ImageStats` to pick `blur_threshold` and `dark_threshold`
for Remote Config. The test skips itself while the folders are empty.

On-device prep timing is measured separately on a 2 GB phone and recorded in `docs/perf-baseline.md`.
