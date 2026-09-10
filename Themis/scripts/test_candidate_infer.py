#!/usr/bin/env python3
import time
import numpy as np
from PIL import Image
import onnxruntime as ort
from pathlib import Path

def test_model_inference():
    test_img_path = Path("dataset/mine/dishwasher/PXL_20260906_162848337.jpg")
    img = Image.open(test_img_path).convert("RGB")
    print(f"Loaded test image: {test_img_path} ({img.size})")

    # Resize for detection test
    target_size = 960
    scale = target_size / max(img.size)
    new_w = int(np.ceil(img.width * scale / 32.0) * 32)
    new_h = int(np.ceil(img.height * scale / 32.0) * 32)
    resized = img.resize((new_w, new_h), Image.BILINEAR)

    # Normalize: ImageNet mean/std
    mean = np.array([0.485, 0.456, 0.406], dtype=np.float32).reshape(1, 3, 1, 1)
    std = np.array([0.229, 0.224, 0.225], dtype=np.float32).reshape(1, 3, 1, 1)
    arr = np.array(resized, dtype=np.float32) / 255.0
    arr = np.transpose(arr, (2, 0, 1))[np.newaxis, ...]
    arr = (arr - mean) / std

    print("\n--- Testing Detectors ---")
    det_candidates = [
        ("Mobile INT8 (Current)", "themis/models/ppocr_det_int8.onnx"),
        ("Server INT8 (Reference)", "themis/models/ppocr_det_server_int8.onnx"),
        ("ResNet Server v2 INT8", "themis/models/candidates/ch_ppocr_server_v2_det_int8.onnx"),
        ("PP-OCRv4 Std Det INT8", "themis/models/candidates/ch_ppocr_v4_det_std_int8.onnx"),
    ]

    for label, model_path in det_candidates:
        p = Path(model_path)
        if not p.exists():
            continue
        try:
            sess = ort.InferenceSession(str(p), providers=["CPUExecutionProvider"])
            input_name = sess.get_inputs()[0].name
            t0 = time.perf_counter()
            outputs = sess.run(None, {input_name: arr})
            lat = (time.perf_counter() - t0) * 1000
            out = outputs[0]
            print(f"[✓] {label:25} | Size: {p.stat().st_size / (1024*1024):5.2f} MB | Latency: {lat:6.1f} ms | Out shape: {out.shape} | Max prob: {out.max():.3f}")
        except Exception as e:
            print(f"[!] {label:25} | FAILED: {e}")

    print("\n--- Testing Recognizers ---")
    # Crop a small sample text patch
    crop = img.crop((100, 100, 400, 150))
    rec_h = 48
    aspect = crop.width / crop.height
    rec_w = int(np.clip(round(rec_h * aspect), 64, 960))
    crop_resized = crop.resize((rec_w, rec_h), Image.BILINEAR)
    crop_arr = (np.array(crop_resized, dtype=np.float32) / 255.0 - 0.5) / 0.5
    crop_arr = np.transpose(crop_arr, (2, 0, 1))[np.newaxis, ...]

    rec_candidates = [
        ("en_PP-OCRv4 Mobile INT8 (Current)", "themis/models/en_ppocr_v4_rec_int8.onnx", 97),
        ("en_PP-OCRv3 Mobile INT8", "themis/models/candidates/en_ppocr_v3_rec_int8.onnx", 97),
        ("ch_PP-OCRv4 Std INT8", "themis/models/candidates/ch_ppocr_v4_rec_int8.onnx", 6625),
    ]

    for label, model_path, expected_classes in rec_candidates:
        p = Path(model_path)
        if not p.exists():
            continue
        try:
            sess = ort.InferenceSession(str(p), providers=["CPUExecutionProvider"])
            input_name = sess.get_inputs()[0].name
            t0 = time.perf_counter()
            outputs = sess.run(None, {input_name: crop_arr})
            lat = (time.perf_counter() - t0) * 1000
            out = outputs[0]
            print(f"[✓] {label:32} | Size: {p.stat().st_size / (1024*1024):5.2f} MB | Latency: {lat:5.1f} ms | Out shape: {out.shape}")
        except Exception as e:
            print(f"[!] {label:32} | FAILED: {e}")

if __name__ == "__main__":
    test_model_inference()
