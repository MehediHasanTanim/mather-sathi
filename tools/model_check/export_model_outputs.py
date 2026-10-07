#!/usr/bin/env python3
"""Runs the TFLite model on a folder of JPEGs with the reference preprocessing and writes the outputs the app must reproduce
(plan task 6.5). Needs ONE of: tensorflow, ai-edge-litert, tflite-runtime.

  python3 tools/model_check/export_model_outputs.py --images integration_test/parity --out integration_test/parity/expected.json
  # optional: --models-dir assets/models (default)

Output: {"<image file name>": [probabilities...]}; logits models are softmaxed here, like the app does.
"""
import argparse, json, os, sys
import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from preprocess_reference import preprocess  # noqa: E402


def load_interpreter(path):
    for mod, attr in (("ai_edge_litert.interpreter", "Interpreter"), ("tflite_runtime.interpreter", "Interpreter")):
        try:
            return getattr(__import__(mod, fromlist=[attr]), attr)(model_path=path)
        except ImportError:
            continue
    try:
        import tensorflow as tf
        return tf.lite.Interpreter(model_path=path)
    except ImportError:
        raise SystemExit("install one of: tensorflow, ai-edge-litert, tflite-runtime")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--models-dir", default=os.path.join(os.path.dirname(__file__), "../../assets/models"))
    a = ap.parse_args()

    meta = json.load(open(os.path.join(a.models_dir, "model_meta.json")))
    interp = load_interpreter(os.path.join(a.models_dir, meta["file"]))
    interp.allocate_tensors()
    inp, out = interp.get_input_details()[0], interp.get_output_details()[0]
    result = {}
    for name in sorted(os.listdir(a.images)):
        if not name.lower().endswith((".jpg", ".jpeg")):
            continue
        x = preprocess(os.path.join(a.images, name), meta["input_size"], meta["resize"], meta["normalization"])
        if meta["input_type"] == "uint8":
            x = np.round(x).clip(0, 255).astype(np.uint8)
        else:
            x = x.astype(np.float32)
        interp.set_tensor(inp["index"], x[None, ...])
        interp.invoke()
        y = interp.get_tensor(out["index"])[0].astype(np.float64)
        if out["dtype"] != np.float32:  # quantised output: dequantise
            scale, zero = out["quantization"]
            y = (y - zero) * scale
        if meta["output"] == "logits":
            e = np.exp(y - y.max())
            y = e / e.sum()
        result[name] = [round(float(v), 6) for v in y]
    json.dump(result, open(a.out, "w"), indent=1)
    print(f"wrote {len(result)} outputs to {a.out}")


if __name__ == "__main__":
    main()
