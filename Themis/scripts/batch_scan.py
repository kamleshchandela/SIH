#!/usr/bin/env python3
"""
batch_scan.py
Interactive, multi-threaded batch compliance scanner for Themis Legal Metrology Engine.
Supports SKU Multi-Panel Pooling (pools all packaging panels for each product),
dynamic worker profiles (Full, 5/6, 3/4, 1/2, Custom), live progress dashboard,
statistical violation summaries, and JSON audit export.
"""

import os
import sys
import json
import time
import argparse
import threading
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from typing import List, Dict, Any, Tuple

# ANSI Colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
MAGENTA = "\033[95m"
BOLD = "\033[1m"
DIM = "\033[2m"
RESET = "\033[0m"

def find_themis_binary() -> Path:
    candidates = [
        Path("./themis/target/release/themis"),
        Path("../themis/target/release/themis"),
        Path("./target/release/themis"),
        Path("/home/arch/Projects/backbone/themis/target/release/themis"),
    ]
    for c in candidates:
        if c.is_file() and os.access(c, os.X_OK):
            return c.resolve()
    print(f"{RED}[!] Error: 'themis' binary not found. Run 'cargo build --release' inside themis/ first.{RESET}", file=sys.stderr)
    sys.exit(1)

def discover_targets(target_dir: Path) -> Tuple[List[Path], bool]:
    """
    Returns (targets, is_product_dir_mode).
    If target_dir contains subdirectories with images, treats each subdirectory as a distinct SKU product.
    Otherwise, returns flat list of individual image files.
    """
    subdirs = [d for d in target_dir.iterdir() if d.is_dir() and not d.name.startswith(".")]
    valid_product_dirs = []
    extensions = {".jpg", ".jpeg", ".png", ".webp"}

    for d in subdirs:
        has_imgs = any(p.suffix.lower() in extensions for p in d.iterdir() if p.is_file())
        if has_imgs:
            valid_product_dirs.append(d)

    if valid_product_dirs:
        return sorted(valid_product_dirs), True

    # Flat image list fallback
    images = []
    for root, _, files in os.walk(target_dir):
        for f in files:
            p = Path(root) / f
            if p.suffix.lower() in extensions:
                images.append(p)
    return sorted(images), False

def run_themis_scan(themis_bin: Path, target_path: Path, is_product_mode: bool) -> Dict[str, Any]:
    models_dir = themis_bin.parent.parent.parent / "themis" / "models"
    if not models_dir.exists():
        models_dir = Path("/home/arch/Projects/backbone/themis/models")

    cmd = [
        str(themis_bin),
        "--models-dir", str(models_dir),
    ]

    if is_product_mode:
        cmd.extend(["--scan-product", str(target_path)])
    else:
        cmd.extend(["--scan", str(target_path)])

    cmd.append("--json")

    try:
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=60)
        if proc.returncode == 0 and proc.stdout.strip():
            raw = proc.stdout
            idx = raw.find("{")
            if idx != -1:
                return json.loads(raw[idx:])
    except Exception as e:
        return {"error": str(e)}
    return {"error": "Scan failed", "stderr": proc.stderr}

def select_worker_profile(total_cpus: int) -> Tuple[int, str]:
    w_full = total_cpus
    w_5_6 = max(1, int(total_cpus * 5 / 6))
    w_3_4 = max(1, int(total_cpus * 3 / 4))
    w_1_2 = max(1, int(total_cpus / 2))

    print(f"\n{BOLD}Detected System Hardware: {total_cpus} Logical CPU Cores{RESET}")
    print(f"{BOLD}Select Concurrency Profile (CPU Multi-threading):{RESET}")
    print(f"  {CYAN}1){RESET} {BOLD}5/6 Threads (~83%){RESET} — {w_5_6} workers {GREEN}[Recommended: Maximum throughput + system headroom]{RESET}")
    print(f"  {CYAN}2){RESET} Full Power (100%) — {w_full} workers [All CPU cores saturated]")
    print(f"  {CYAN}3){RESET} 3/4 Threads (75%) — {w_3_4} workers [Balanced multi-tasking]")
    print(f"  {CYAN}4){RESET} 1/2 Threads (50%) — {w_1_2} workers [Eco mode / Low thermal budget]")
    print(f"  {CYAN}5){RESET} Single Thread (1 worker) — 1 worker [Sequential debug]")
    print(f"  {CYAN}6){RESET} Custom number of workers")

    try:
        choice = input(f"\nEnter choice [1-6, default: {BOLD}1{RESET}]: ").strip()
    except (EOFError, KeyboardInterrupt):
        choice = "1"

    if choice == "2":
        return w_full, "Full (100%)"
    elif choice == "3":
        return w_3_4, "3/4 (75%)"
    elif choice == "4":
        return w_1_2, "1/2 (50%)"
    elif choice == "5":
        return 1, "Single (1 worker)"
    elif choice == "6":
        try:
            val = int(input("Enter custom worker count: ").strip())
            return max(1, val), f"Custom ({val} workers)"
        except ValueError:
            return w_5_6, "5/6 (83%) [Fallback]"
    else:
        return w_5_6, "5/6 (83%) [Recommended]"

def main():
    parser = argparse.ArgumentParser(description="Themis Interactive Multi-threaded Batch Compliance Scanner")
    parser.add_argument("path", nargs="?", default=None, help="Directory to scan")
    parser.add_argument("--workers", type=int, default=None, help="Force specific worker count")
    parser.add_argument("--profile", choices=["full", "5/6", "3/4", "1/2", "single"], default=None, help="Pre-select concurrency profile")
    parser.add_argument("--out", type=str, default=None, help="Output JSON path")
    args = parser.parse_args()

    print(f"\n{BOLD}{CYAN}{'='*80}{RESET}")
    print(f"{BOLD}{CYAN}      THEMIS — MULTI-THREADED LEGAL METROLOGY BATCH COMPLIANCE SCANNER{RESET}")
    print(f"{BOLD}{CYAN}          (Multi-Panel SKU Pooling & LMPC 2011 Regulatory Audit){RESET}")
    print(f"{BOLD}{CYAN}{'='*80}{RESET}")

    themis_bin = find_themis_binary()
    print(f"{DIM}[*] Binary Engine: {themis_bin}{RESET}")

    # Resolve target directory
    if args.path:
        target_dir = Path(args.path).resolve()
    else:
        default_dir = "./dataset/real_products"
        try:
            user_input = input(f"\nEnter folder path to scan [{BOLD}{default_dir}{RESET}]: ").strip()
        except (EOFError, KeyboardInterrupt):
            user_input = ""
        target_dir = Path(user_input if user_input else default_dir).resolve()

    if not target_dir.exists() or not target_dir.is_dir():
        print(f"{RED}[!] Directory does not exist: {target_dir}{RESET}")
        sys.exit(1)

    targets, is_product_mode = discover_targets(target_dir)
    if not targets:
        print(f"{YELLOW}[!] No targets found in {target_dir}{RESET}")
        sys.exit(0)

    total_cpus = os.cpu_count() or 4

    # Resolve worker concurrency
    if args.workers is not None:
        num_workers = max(1, args.workers)
        profile_name = f"CLI forced ({num_workers} workers)"
    elif args.profile:
        mapping = {
            "full": (total_cpus, "Full (100%)"),
            "5/6": (max(1, int(total_cpus * 5 / 6)), "5/6 (83%)"),
            "3/4": (max(1, int(total_cpus * 3 / 4)), "3/4 (75%)"),
            "1/2": (max(1, int(total_cpus / 2)), "1/2 (50%)"),
            "single": (1, "Single (1 worker)"),
        }
        num_workers, profile_name = mapping[args.profile]
    else:
        num_workers, profile_name = select_worker_profile(total_cpus)

    mode_desc = f"{len(targets)} Complete Products (Pooling all panels per product)" if is_product_mode else f"{len(targets)} Isolated Images"
    print(f"\n{GREEN}[✓] Discovered: {BOLD}{mode_desc}{RESET} in {target_dir}")
    print(f"{GREEN}[✓] Concurrency: {BOLD}{num_workers} parallel workers{RESET} ({profile_name})")

    try:
        confirm = input(f"\nProceed with batch compliance scan of {len(targets)} targets? [Y/n]: ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        confirm = "y"

    if confirm not in ("", "y", "yes"):
        print("Aborted by user.")
        sys.exit(0)

    col_title = "PRODUCT SKU (POOLED PANELS)" if is_product_mode else "PACKAGING IMAGE"
    print(f"\n{BOLD}{'PROGRESS':<12} | {'STATUS':<6} | {'SCORE':<7} | {col_title:<34} | {'VIOLATIONS':<18}{RESET}")
    print(f"{'-'*86}")

    # Shared thread-safe state
    print_lock = threading.Lock()
    progress_count = 0
    total_compliant = 0
    total_violations = 0
    total_penalties = 0
    violation_types_count = {}
    collected_results = []

    start_time = time.time()

    def process_item(item_idx: int, t_path: Path):
        nonlocal progress_count, total_compliant, total_violations, total_penalties
        scan_res = run_themis_scan(themis_bin, t_path, is_product_mode)

        with print_lock:
            progress_count += 1
            pct = (progress_count / len(targets)) * 100
            display_name = t_path.name[:32]

            if "error" in scan_res:
                print(f"[{progress_count:>3}/{len(targets):<3}] {pct:>4.0f}% | {RED}ERROR {RESET} | {'0.0%':<7} | {display_name:<34} | {scan_res.get('error')[:18]}")
                collected_results.append({"target": str(t_path), "error": scan_res.get("error")})
                return

            is_compliant = scan_res.get("overall_compliant", False)
            score = scan_res.get("compliance_score_pct", 0.0)
            v_summary = scan_res.get("violations", {})
            v_count = v_summary.get("total_violations", 0)
            missing = v_summary.get("mandatory_missing", [])
            non_std = v_summary.get("non_standard_units", [])
            
            penalties = v_summary.get("statutory_penalties", [])
            fine = sum(p.get("compoundable_fine_inr", 0) for p in penalties)

            if is_compliant:
                status_tag = f"{GREEN}PASS  {RESET}"
                total_compliant += 1
            else:
                status_tag = f"{RED}FAIL  {RESET}"
                total_violations += 1
                total_penalties += fine

            for m in missing:
                violation_types_count[m] = violation_types_count.get(m, 0) + 1
            for u in non_std:
                k = f"Non-std unit: {u}"
                violation_types_count[k] = violation_types_count.get(k, 0) + 1

            v_preview = f"{v_count} issues" if v_count > 0 else "Compliant"
            if missing:
                v_preview += f" ({missing[0]})"

            score_color = GREEN if score >= 80 else (YELLOW if score >= 50 else RED)
            print(f"[{progress_count:>3}/{len(targets):<3}] {pct:>4.0f}% | {status_tag} | {score_color}{score:>5.1f}%{RESET} | {display_name:<34} | {v_preview:<18}")

            collected_results.append({
                "target": str(t_path),
                "report": scan_res,
            })

    # Execute in parallel with chosen worker count
    with ThreadPoolExecutor(max_workers=num_workers) as executor:
        futures = [executor.submit(process_item, i, path) for i, path in enumerate(targets)]
        for f in as_completed(futures):
            f.result()

    elapsed = time.time() - start_time
    avg_per_target = (elapsed / len(targets)) * 1000 if targets else 0
    throughput = len(targets) / elapsed if elapsed > 0 else 0

    print(f"\n{BOLD}{CYAN}{'='*80}{RESET}")
    print(f"{BOLD}                    LEGAL METROLOGY BATCH AUDIT REPORT{RESET}")
    print(f"{BOLD}{CYAN}{'='*80}{RESET}")
    print(f"Evaluation Mode         : {BOLD}{'Product-Level (Pooled Panels)' if is_product_mode else 'Isolated Image Mode'}{RESET}")
    print(f"Total Targets Audited   : {len(targets)}")
    print(f"Parallel Worker Threads : {num_workers} ({profile_name})")
    print(f"Total Wall-Clock Time   : {BOLD}{elapsed:.2f} seconds{RESET}")
    print(f"Processing Throughput   : {BOLD}{throughput:.1f} targets/sec{RESET} ({avg_per_target:.1f} ms wall-latency/product)")
    print(f"Compliant Products      : {GREEN}{total_compliant}{RESET}")
    print(f"Non-Compliant Products  : {RED}{total_violations}{RESET}")
    print(f"Total Assessed Fines    : {YELLOW}₹{total_penalties:,} INR{RESET} (under Jan Vishwas Act compounding)")

    if violation_types_count:
        print(f"\n{BOLD}Top Frequent Missing Declarations / Violations Across Products:{RESET}")
        sorted_v = sorted(violation_types_count.items(), key=lambda x: x[1], reverse=True)
        for v_name, count in sorted_v[:6]:
            bar = "█" * min(25, int(count / len(targets) * 40))
            print(f"  • {v_name:<25} : {count:>3} products {CYAN}{bar}{RESET}")

    # Output JSON export
    out_json = Path(args.out) if args.out else (target_dir.parent / "batch_scan_results.json")
    with open(out_json, "w", encoding="utf-8") as f:
        json.dump({
            "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "evaluation_mode": "product_level_pooled" if is_product_mode else "isolated_image",
            "concurrency_profile": profile_name,
            "worker_threads": num_workers,
            "total_targets": len(targets),
            "wall_time_seconds": elapsed,
            "throughput_fps": throughput,
            "total_compliant": total_compliant,
            "total_violations": total_violations,
            "total_penalties_inr": total_penalties,
            "results": collected_results,
        }, f, indent=2)

    print(f"\n{GREEN}[✓] Full structured audit report saved to: {out_json}{RESET}\n")

if __name__ == "__main__":
    main()
