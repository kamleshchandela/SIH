#!/usr/bin/env python3
"""
Model Acquisition & INT8 Quantization Script for Candidate OCR Models.
Downloads FP32 candidate models from HuggingFace, performs graph surgery,
and quantizes them to INT8 for mobile benchmarking.
"""

import os
import sys
import urllib.request
from pathlib import Path
import onnx
from onnxruntime.quantization import quantize_dynamic, QuantType

CACHE_DIR = Path("./tmp/models_cache")
OUTPUT_DIR = Path("./themis/models/candidates")

MODELS_TO_DOWNLOAD = [
    {
        "name": "ch_ppocr_server_v2_det.onnx",
        "url": "https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv1/ch_ppocr_server_v2.0_det_infer.onnx",
        "type": "det",
        "description": "PP-OCRv2 ResNet Server Detection (46.6 MB FP32)"
    },
    {
        "name": "db_mobilenet_v3_large.onnx",
        "url": "https://huggingface.co/Felix92/onnxtr-db-mobilenet-v3-large/resolve/main/model.onnx",
        "type": "det",
        "description": "docTR DBNet MobileNetV3-Large (15.3 MB FP32)"
    },
    {
        "name": "ch_ppocr_v4_det_std.onnx",
        "url": "https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv4/ch_PP-OCRv4_det_infer.onnx",
        "type": "det",
        "description": "PP-OCRv4 Standard Mobile Detection (4.5 MB FP32)"
    },
    {
        "name": "en_ppocr_v3_rec.onnx",
        "url": "https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv3/en_PP-OCRv3_rec_infer.onnx",
        "type": "rec",
        "description": "PP-OCRv3 English Recognition (8.6 MB FP32)"
    },
    {
        "name": "ch_ppocr_v4_rec.onnx",
        "url": "https://huggingface.co/SWHL/RapidOCR/resolve/main/PP-OCRv4/ch_PP-OCRv4_rec_infer.onnx",
        "type": "rec",
        "description": "PP-OCRv4 Standard Recognition (10.4 MB FP32)"
    }
]

def download_file(url: str, dest_path: Path):
    if dest_path.exists() and dest_path.stat().st_size > 0:
        print(f"[*] Found cached: {dest_path} ({dest_path.stat().st_size / (1024*1024):.2f} MB)")
        return
    print(f"[+] Downloading {url} -> {dest_path}...")
    dest_path.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req) as resp, open(dest_path, "wb") as f:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        chunk_size = 64 * 1024
        while True:
            chunk = resp.read(chunk_size)
            if not chunk:
                break
            f.write(chunk)
            downloaded += len(chunk)
            if total > 0:
                pct = downloaded / total * 100
                sys.stdout.write(f"\r    {downloaded / (1024*1024):.1f}/{total / (1024*1024):.1f} MB ({pct:.1f}%)")
                sys.stdout.flush()
    print("\n    Download complete.")

def convert_constants_to_initializers(model_path: Path, temp_path: Path):
    """
    Performs graph surgery to convert Constant nodes to Graph Initializers.
    Required for models exported from Paddle2ONNX to prevent quantization crashes.
    """
    print(f"    Running graph surgery on {model_path.name}...")
    model = onnx.load(str(model_path))
    initializers = {init.name for init in model.graph.initializer}
    
    nodes_to_remove = []
    for node in model.graph.node:
        if node.op_type == "Constant":
            for attr in node.attribute:
                if attr.name == "value" and attr.t:
                    tensor = attr.t
                    tensor.name = node.output[0]
                    if tensor.name not in initializers:
                        model.graph.initializer.append(tensor)
                        initializers.add(tensor.name)
                    nodes_to_remove.append(node)
                    break
    
    for node in nodes_to_remove:
        model.graph.node.remove(node)
        
    onnx.save(model, str(temp_path))
    print(f"    Converted {len(nodes_to_remove)} constant nodes to graph initializers.")

def quantize_model(input_path: Path, output_path: Path):
    print(f"    Applying INT8 dynamic quantization -> {output_path.name}...")
    temp_surgery_path = input_path.with_suffix(".surgery.onnx")
    try:
        convert_constants_to_initializers(input_path, temp_surgery_path)
        quantize_dynamic(
            model_input=str(temp_surgery_path),
            model_output=str(output_path),
            weight_type=QuantType.QInt8,
            per_channel=True
        )
    except Exception as e:
        print(f"    [!] Graph surgery error: {e}. Trying direct quantization...")
        quantize_dynamic(
            model_input=str(input_path),
            model_output=str(output_path),
            weight_type=QuantType.QInt8,
            per_channel=True
        )
    finally:
        if temp_surgery_path.exists():
            temp_surgery_path.unlink()

def main():
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    print("=" * 70)
    print("Phase 1: Downloading & Quantizing Candidate OCR Models")
    print("=" * 70)
    
    results = []
    for m in MODELS_TO_DOWNLOAD:
        print(f"\n--- Processing: {m['description']} ---")
        raw_path = CACHE_DIR / m["name"]
        int8_name = m["name"].replace(".onnx", "_int8.onnx")
        int8_path = OUTPUT_DIR / int8_name
        
        try:
            download_file(m["url"], raw_path)
            raw_sz = raw_path.stat().st_size / (1024 * 1024)
            
            if not int8_path.exists() or int8_path.stat().st_size == 0:
                quantize_model(raw_path, int8_path)
            else:
                print(f"[*] Found existing quantized model: {int8_path}")
                
            int8_sz = int8_path.stat().st_size / (1024 * 1024)
            reduction = (1.0 - int8_sz / raw_sz) * 100
            print(f"[✓] {int8_name}: {raw_sz:.2f} MB (FP32) -> {int8_sz:.2f} MB (INT8) [-{reduction:.1f}%]")
            results.append({
                "name": int8_name,
                "type": m["type"],
                "fp32_mb": raw_sz,
                "int8_mb": int8_sz,
                "reduction_pct": reduction,
                "path": str(int8_path)
            })
        except Exception as e:
            print(f"[!] Error processing {m['name']}: {e}")
            
    print("\n" + "=" * 70)
    print("Summary of Quantized Candidate Models in themis/models/candidates/:")
    print("=" * 70)
    for r in results:
        print(f"• {r['name']:32}: {r['int8_mb']:5.2f} MB (from {r['fp32_mb']:5.2f} MB, -{r['reduction_pct']:.1f}%)")

if __name__ == "__main__":
    main()
