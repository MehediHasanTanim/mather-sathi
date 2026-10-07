# Offline model handoff contract (Phase 6, task 6.1 / M7)

The app ships **cloud-only** until these files exist. When they are dropped into `assets/models/` and validate, offline diagnosis for the
launch crops switches on automatically; nothing else needs to change. If any file is missing or invalid the app stays cloud-only
(an invalid set is reported to Crashlytics, never half-loaded).

## Files (all in `assets/models/`)
| File | What |
|---|---|
| `crop_disease_v1.tflite` (any `*.tflite` name, set in the meta) | The classifier. Target: int8-quantised MobileNet-class, 25 MB or less (APK budget is about 60 MB total) |
| `labels.json` | `[{"disease_id": "rice_blast", "crop": "rice"}, ...]` in **output order**: position `i` is output `i` |
| `model_meta.json` | How to preprocess and read the model (below). Every field is required |

```json
{
  "version": "2026-11-01-r1",
  "file": "crop_disease_v1.tflite",
  "input_size": 224,
  "input_type": "float32",
  "resize": "bilinear",
  "normalization": "zero_one",
  "output": "probabilities",
  "labels": 41
}
```

## Preprocessing must match training exactly
The app: decodes the JPEG with the platform codec (bit-identical to PIL/OpenCV, verified), resizes the whole photo to
`input_size x input_size` (**squashed, no centre crop**), keeps RGB channel order, then normalises. Tensor layout is NHWC `[1, S, S, 3]`.

| Field | Values | Meaning |
|---|---|---|
| `resize` | `bilinear` | `tf.image.resize(method='bilinear', antialias=False)` / `tf.keras.layers.Resizing` (half-pixel centres, **no antialiasing**) |
| | `area` | `cv2.INTER_AREA` / PIL `Image.BOX` (box averaging) |
| `normalization` | `zero_one` | `v / 255` |
| | `minus_one_one` | `v / 127.5 - 1` |
| | `imagenet` | `(v/255 - mean) / std`, mean `[0.485, 0.456, 0.406]`, std `[0.229, 0.224, 0.225]` |
| | `none` | raw 0..255, only with `input_type: uint8` |
| `input_type` | `float32`, `uint8` | the model's input tensor type; `uint8` needs `normalization: none` |
| `output` | `probabilities`, `logits` | logits get a softmax in the app |

**Do not train with PIL `BILINEAR`/`BICUBIC`/`LANCZOS` or OpenCV `INTER_LINEAR` downscaling**: they antialias differently and none of them
matches either mode above exactly (measured: Dart's own `linear` resize differed from PIL by 0.02 mean per pixel on a textured photo).
If training already used one of those, re-export with a supported mode, or tell us and we add the mode.

The reference implementation of both modes is `tools/model_check/preprocess_reference.py`; the Dart code is tested against its
output on a fixture (`test/features/offline/scoring_and_contract_test.dart`, tolerance below one 8-bit step).

## Class list rules (checked by `kb_build`)
* Every `disease_id` in `labels.json` is a KB entry id, or `healthy`, or `unknown`.
* Every crop in the file has **both** a `healthy` and an `unknown` class.
* Every KB entry of a crop that appears in the file has a label.
* `model_meta.json` `labels` equals the number of labels, and the model's output length.
The app also refuses to start the model if the tensor shapes or types differ from the meta.

## Checking a handoff
```bash
node tools/model_check/check.js                          # meta + labels + file present, size
node tools/kb_build/build.js --env dev --validate        # labels vs the KB
python3 tools/model_check/export_model_outputs.py --images integration_test/parity --out integration_test/parity/expected.json
# temporarily list integration_test/parity/ under flutter: assets: in pubspec.yaml (do not ship it), then:
flutter test integration_test/parity_test.dart -d <device>   # task 6.5: top-1 equal; float probabilities within 0.02
```
Use about 20 representative images for the parity run (include one per crop and a non-plant).

## How a result is scored on device (task 6.3)
Only the chosen crop's classes compete. `mass` = their summed probability; below `min_crop_mass` the photo is reported as
"wrong crop / not a plant". Otherwise the best class is scored by `p / mass`: `>= conf_high` high, `>= conf_medium` medium, else low.
These three numbers are Remote Config values (defaults 0.80 / 0.60 / 0.50 are provisional): **set them from the held-out field set
in task 9.1**, never from the training data.

## Device checklist (task 6.6, manual)
- [ ] Runs on a 32-bit (`armeabi-v7a`) 2 GB Android 8-9 phone: `adb shell getprop ro.product.cpu.abilist`
- [ ] First offline classification does not freeze the UI; the model is not loaded at app start
- [ ] On-device latency 2 s or less on that phone (record in `docs/perf-baseline.md`)
- [ ] `flutter build appbundle --release` size within budget; both ABIs have the TFLite native libs
- [ ] Airplane mode: rice photo gives a result with the অফলাইন মোড label; the same result screen as online
- [ ] Opening the camera, backgrounding the app and returning still works with the model loaded (low-memory release)
