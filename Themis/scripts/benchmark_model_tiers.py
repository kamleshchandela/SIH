#!/usr/bin/env python3
"""
Systematic Benchmark Harness for OCR Model Configurations Across 3 Datasets.
Evaluates:
- Token counts
- Mean confidence
- Compliance score % & Risk Tier
- Statutory clause correctness (Net Qty, MRP, Mfg, Date)
- Latency (ms)
"""

import json
import os
import subprocess
import time
from pathlib import Path

BINARY_PATH = Path("./themis/target/release/themis")

CONFIGS = [
    {
        "id": "Mobile_INT8_Base",
        "name": "Mobile INT8 (Current Edge)",
        "det_model": "themis/models/ppocr_det_int8.onnx",
        "rec_model": "themis/models/en_ppocr_v4_rec_int8.onnx",
        "det_size_mb": 0.76,
        "rec_size_mb": 2.00,
    },
    {
        "id": "ResNet_v2_Det_INT8",
        "name": "ResNet Server v2 Det INT8",
        "det_model": "themis/models/candidates/ch_ppocr_server_v2_det_int8.onnx",
        "rec_model": "themis/models/en_ppocr_v4_rec_int8.onnx",
        "det_size_mb": 11.82,
        "rec_size_mb": 2.00,
    },
    {
        "id": "PPOCRv4_Std_Det_INT8",
        "name": "PP-OCRv4 Std Det INT8",
        "det_model": "themis/models/candidates/ch_ppocr_v4_det_std_int8.onnx",
        "rec_model": "themis/models/en_ppocr_v4_rec_int8.onnx",
        "det_size_mb": 1.27,
        "rec_size_mb": 2.00,
    },
    {
        "id": "PPOCRv3_Rec_INT8",
        "name": "PP-OCRv3 Rec INT8",
        "det_model": "themis/models/ppocr_det_int8.onnx",
        "rec_model": "themis/models/candidates/en_ppocr_v3_rec_int8.onnx",
        "det_size_mb": 0.76,
        "rec_size_mb": 2.30,
    },
    {
        "id": "ResNet_Det_PPv3_Rec",
        "name": "ResNet Det + PP-OCRv3 Rec",
        "det_model": "themis/models/candidates/ch_ppocr_server_v2_det_int8.onnx",
        "rec_model": "themis/models/candidates/en_ppocr_v3_rec_int8.onnx",
        "det_size_mb": 11.82,
        "rec_size_mb": 2.30,
    },
    {
        "id": "Server_INT8_Ref",
        "name": "Server INT8 (Reference)",
        "det_model": "themis/models/ppocr_det_server_int8.onnx",
        "rec_model": "themis/models/en_ppocr_v4_rec_int8.onnx",
        "det_size_mb": 27.35,
        "rec_size_mb": 2.00,
    },
]

DATASETS = [
    {
        "id": "oats",
        "name": "Saffola Rolled Oats",
        "path": "dataset/mine/oats",
        "desc": "2 panels, rotated smartphone photos, decimal MRP vs weight"
    },
    {
        "id": "dishwasher",
        "name": "SaveMore Dishwash Liquid",
        "path": "dataset/mine/dishwasher",
        "desc": "1 panel macro, cylindrical curve, 2-column interleaved"
    },
    {
        "id": "yippie",
        "name": "Yippie Noodles",
        "path": "dataset/mine/yippie/halfimage",
        "desc": "5 panels macro pool, flexible folds, CIJ dot-matrix date"
    }
]

def run_evaluation(config, dataset):
    env = os.environ.copy()
    env["THEMIS_DET_MODEL"] = config["det_model"]
    env["THEMIS_REC_MODEL"] = config["rec_model"]
    env["THEMIS_DETERMINISTIC"] = "1"
    
    cmd = [
        str(BINARY_PATH),
        "--scan-product",
        dataset["path"],
        "--json"
    ]
    
    t0 = time.perf_counter()
    res = subprocess.run(cmd, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    latency_sec = time.perf_counter() - t0
    
    if res.returncode != 0:
        print(f"    [!] Error running {config['id']} on {dataset['id']}: {res.stderr[:200]}")
        return None
        
    try:
        data = json.loads(res.stdout)
        tokens = data.get("raw_ocr_tokens", [])
        token_count = len(tokens)
        mean_conf = (sum(t.get("confidence", 0.0) for t in tokens) / max(1, token_count))
        score = data.get("compliance_score_pct", 0.0)
        risk = data.get("risk_tier", "Unknown")
        
        eval_map = {e["field"]: e for e in data.get("evaluations", [])}
        mfg = eval_map.get("ManufacturerDetails", {}).get("status", "N/A")
        net_qty = eval_map.get("NetQuantity", {}).get("status", "N/A")
        net_qty_rem = eval_map.get("NetQuantity", {}).get("remarks", "")
        mrp = eval_map.get("MaximumRetailPrice", {}).get("status", "N/A")
        mrp_rem = eval_map.get("MaximumRetailPrice", {}).get("remarks", "")
        date = eval_map.get("ManufactureDate", {}).get("status", "N/A")
        care = eval_map.get("ConsumerCare", {}).get("status", "N/A")
        rule7 = eval_map.get("Rule7NumeralHeight", {}).get("status", "N/A")
        
        return {
            "config_id": config["id"],
            "config_name": config["name"],
            "total_size_mb": config["det_size_mb"] + config["rec_size_mb"],
            "dataset_id": dataset["id"],
            "latency_sec": latency_sec,
            "token_count": token_count,
            "mean_conf": mean_conf,
            "score": score,
            "risk": risk,
            "mfg": mfg,
            "net_qty": net_qty,
            "net_qty_rem": net_qty_rem,
            "mrp": mrp,
            "mrp_rem": mrp_rem,
            "date": date,
            "care": care,
            "rule7": rule7
        }
    except Exception as e:
        print(f"    [!] Failed to parse JSON: {e}")
        return None

def main():
    print("=" * 80)
    print("THEMIS OCR MODEL TIER BATTLE TEST (3 Real-World Datasets)")
    print("=" * 80)
    
    all_results = []
    
    for ds in DATASETS:
        print(f"\n==================================================")
        print(f"DATASET: {ds['name']} ({ds['path']})")
        print(f"Context: {ds['desc']}")
        print(f"==================================================")
        
        for cfg in CONFIGS:
            print(f"[>] Testing {cfg['name']} (Size: {cfg['det_size_mb'] + cfg['rec_size_mb']:.2f} MB)...", end="", flush=True)
            res = run_evaluation(cfg, ds)
            if res:
                all_results.append(res)
                print(f" Done in {res['latency_sec']:.2f}s | Tokens: {res['token_count']} | Score: {res['score']:.1f}% ({res['risk']})")
                print(f"     Net Qty: {res['net_qty']} ({res['net_qty_rem'][:35]}...) | MRP: {res['mrp']} | Date: {res['date']}")
            else:
                print(" FAILED")
                
    # Save results as JSON
    out_json = Path("./tmp/benchmark_results.json")
    out_json.parent.mkdir(parents=True, exist_ok=True)
    with open(out_json, "w") as f:
        json.dump(all_results, f, indent=2)
    print(f"\n[✓] Raw results saved to {out_json}")

if __name__ == "__main__":
    main()
