#!/usr/bin/env python3
"""Field eval harness: single-panel scan of every dataset image at phone
parity (mobile-v3 tier, deterministic), one markdown table out.

Usage (from repo root):
    python3 scripts/eval_field.py [--dirs dataset/mine] [--tier mobile-v3]

Output: doc/field/eval/EVAL_<stamp>.md + EVAL_<stamp>.jsonl (raw per-image).
A run takes ~1s of Python per image plus inference (~7-20s desktop).
"""
import argparse
import datetime
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CLI = ROOT / "themis" / "target" / "release" / "themis"
IMG_EXTS = {".jpg", ".jpeg", ".png", ".webp"}

FIELD_ORDER = [
    "ManufacturerDetails",
    "NetQuantity",
    "MaximumRetailPrice",
    "ManufactureDate",
    "CountryOfOrigin",
    "ConsumerCare",
    "UnitSalePrice",
    "Rule7NumeralHeight",
]
STATUS_GLYPH = {"Compliant": "C", "Warning": "W", "Violation": "V", "NotApplicable": "-"}


def scan(cli: Path, models: Path, tier: str, img: Path) -> dict:
    t0 = time.time()
    p = subprocess.run(
        [str(cli), "--models-dir", str(models), "--model-tier", tier,
         "--deterministic", "--scan", str(img), "--json"],
        capture_output=True, text=True, timeout=600,
    )
    wall_ms = int((time.time() - t0) * 1000)
    try:
        rep = json.loads(p.stdout[p.stdout.index("{"):])
    except (ValueError, json.JSONDecodeError):
        return {"image": str(img), "error": (p.stderr or p.stdout)[-300:]}
    evals = {e["field"]: e["status"] for e in rep.get("evaluations", [])}
    return {
        "image": str(img.relative_to(ROOT)),
        "tokens": len(rep.get("raw_ocr_tokens", [])),
        "score": round(rep.get("compliance_score_pct", 0.0), 1),
        "tier": rep.get("risk_tier", "?"),
        "ms": wall_ms,
        "fields": {f: evals.get(f, "?") for f in FIELD_ORDER},
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--dirs", nargs="+",
                    default=["dataset/mine", "dataset/real_products"])
    ap.add_argument("--tier", default="mobile-v3")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    if not CLI.exists():
        sys.exit(f"build the CLI first: (cd themis && cargo build --release). Missing {CLI}")
    models = ROOT / "themis" / "models"

    imgs: list[Path] = []
    for d in args.dirs:
        imgs += sorted(
            p for p in (ROOT / d).rglob("*")
            if p.suffix.lower() in IMG_EXTS
        )
    if args.limit:
        imgs = imgs[: args.limit]
    print(f"{len(imgs)} images @ {args.tier} (deterministic)", flush=True)

    outdir = ROOT / "doc" / "field" / "eval"
    outdir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    rows: list[dict] = []
    with open(outdir / f"EVAL_{stamp}.jsonl", "w") as jf:
        for i, img in enumerate(imgs):
            try:
                r = scan(CLI, models, args.tier, img)
            except subprocess.TimeoutExpired:
                r = {"image": str(img.relative_to(ROOT)), "error": "timeout>600s"}
            rows.append(r)
            jf.write(json.dumps(r) + "\n")
            jf.flush()
            if "error" in r:
                print(f"[{i+1}/{len(imgs)}] {r['image']}: ERROR", flush=True)
            else:
                print(f"[{i+1}/{len(imgs)}] {r['image']}: {r['score']}% "
                      f"{r['tier']} t={r['tokens']} {r['ms']}ms", flush=True)

    ok = [r for r in rows if "error" not in r]
    head = ("| image | tokens | score% | tier | ms | " +
            " | ".join(FIELD_ORDER) + " |")
    sep = "|" + "---|" * (5 + len(FIELD_ORDER))
    lines = [f"# Field eval {stamp} — {args.tier}, deterministic, single-panel",
             f"", f"{len(ok)}/{len(rows)} images scored, "
             f"mean {sum(r['score'] for r in ok)/max(len(ok),1):.1f}% "
             f"(C=Compliant W=Warning V=Violation -=N/A)",
             f"", head, sep]
    for r in rows:
        if "error" in r:
            lines.append(f"| {r['image']} | ERROR | {r['error']} |||||")
            continue
        glyphs = " | ".join(STATUS_GLYPH.get(r["fields"][f], "?") for f in FIELD_ORDER)
        lines.append(f"| {r['image']} | {r['tokens']} | {r['score']} | "
                     f"{r['tier']} | {r['ms']} | {glyphs} |")
    (outdir / f"EVAL_{stamp}.md").write_text("\n".join(lines) + "\n")
    print(f"wrote doc/field/eval/EVAL_{stamp}.md")


if __name__ == "__main__":
    main()
