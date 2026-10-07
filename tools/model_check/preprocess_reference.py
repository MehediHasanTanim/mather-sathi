#!/usr/bin/env python3
"""Reference preprocessing for the offline model (docs/model-handoff.md), used to generate the parity fixtures
and to check the app's Dart preprocessing against the training pipeline.

  python3 tools/model_check/preprocess_reference.py IMAGE.jpg --size 16 --resize area --norm zero_one --out ref.json

--resize area      : PIL Image.BOX (same as cv2.INTER_AREA)
--resize bilinear  : TensorFlow/Keras bilinear, half-pixel centres, NO antialiasing (numpy implementation of
                     tf.image.resize(method='bilinear', antialias=False))
Writes a flat NHWC float list (RGB) as JSON.
"""
import argparse, json
import numpy as np
from PIL import Image

MEAN = np.array([0.485, 0.456, 0.406], dtype=np.float64)
STD = np.array([0.229, 0.224, 0.225], dtype=np.float64)


def bilinear_half_pixel(a: np.ndarray, size: int) -> np.ndarray:
    h, w, _ = a.shape
    ys = (np.arange(size) + 0.5) * h / size - 0.5
    xs = (np.arange(size) + 0.5) * w / size - 0.5
    y0 = np.clip(np.floor(ys).astype(int), 0, h - 1)
    x0 = np.clip(np.floor(xs).astype(int), 0, w - 1)
    y1, x1 = np.clip(y0 + 1, 0, h - 1), np.clip(x0 + 1, 0, w - 1)
    wy = np.clip(ys - np.floor(ys), 0, 1)[:, None, None]
    wx = np.clip(xs - np.floor(xs), 0, 1)[None, :, None]
    top = a[y0][:, x0] * (1 - wx) + a[y0][:, x1] * wx
    bot = a[y1][:, x0] * (1 - wx) + a[y1][:, x1] * wx
    return top * (1 - wy) + bot * wy


def preprocess(path: str, size: int, resize: str, norm: str) -> np.ndarray:
    im = Image.open(path).convert("RGB")
    if resize == "area":
        a = np.asarray(im.resize((size, size), Image.BOX), dtype=np.float64)
    else:
        a = bilinear_half_pixel(np.asarray(im, dtype=np.float64), size)
    if norm == "zero_one":
        a = a / 255.0
    elif norm == "minus_one_one":
        a = a / 127.5 - 1.0
    elif norm == "imagenet":
        a = (a / 255.0 - MEAN) / STD
    elif norm != "none":
        raise SystemExit(f"unknown normalization {norm}")
    return a


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("image")
    ap.add_argument("--size", type=int, default=224)
    ap.add_argument("--resize", choices=["area", "bilinear"], required=True)
    ap.add_argument("--norm", choices=["zero_one", "minus_one_one", "imagenet", "none"], required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    out = preprocess(args.image, args.size, args.resize, args.norm)
    json.dump([round(float(v), 6) for v in out.reshape(-1)], open(args.out, "w"))
