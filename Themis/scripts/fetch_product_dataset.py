#!/usr/bin/env python3
"""
fetch_product_dataset.py
Extracts real Indian packaged commodity images and metadata from Open Food Facts India.
Uses only Python 3 standard library (no external pip dependencies).
"""

import os
import sys
import json
import time
import argparse
import urllib.request
import urllib.error
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

API_SEARCH_URL = "https://world.openfoodfacts.net/api/v2/search"
HEADERS = {
    "User-Agent": "SIH-LegalMetrology-Compliance/1.0 (Testing Legal Metrology Compliance OCR)"
}

def sanitize_filename(name: str) -> str:
    keep = ("-", "_", " ")
    clean = "".join(c for c in name if c.isalnum() or c in keep).strip()
    return clean.replace(" ", "_")[:50]

def download_file(url: str, dest_path: Path, timeout: int = 15) -> bool:
    if dest_path.exists() and dest_path.stat().st_size > 0:
        return True
    try:
        req = urllib.request.Request(url, headers=HEADERS)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            content = resp.read()
            if len(content) > 0:
                dest_path.parent.mkdir(parents=True, exist_ok=True)
                dest_path.write_bytes(content)
                return True
    except Exception as e:
        print(f"    [!] Error downloading {url}: {e}", file=sys.stderr)
    return False

def search_products(page: int = 1, page_size: int = 24):
    params = {
        "countries_tags_en": "india",
        "page_size": page_size,
        "page": page,
        "fields": "code,product_name,brands,quantity,categories,image_front_url,image_packaging_url,image_ingredients_url,image_nutrition_url,images"
    }
    query_str = "&".join(f"{k}={v}" for k, v in params.items())
    url = f"{API_SEARCH_URL}?{query_str}"
    
    req = urllib.request.Request(url, headers=HEADERS)
    with urllib.request.urlopen(req, timeout=20) as resp:
        data = json.loads(resp.read().decode("utf-8"))
        return data.get("products", [])

def build_raw_image_url(barcode: str, img_id: str) -> str:
    # Construct high-resolution Open Food Facts image URL
    # e.g. barcode 8901058000290 -> 890/105/800/0290/{id}.jpg
    code_str = str(barcode).zfill(13)
    p1 = code_str[:3]
    p2 = code_str[3:6]
    p3 = code_str[6:9]
    p4 = code_str[9:]
    return f"https://images.openfoodfacts.net/images/products/{p1}/{p2}/{p3}/{p4}/{img_id}.jpg"

def process_product(p: dict, out_dir: Path):
    barcode = p.get("code") or "unknown"
    raw_name = p.get("product_name") or p.get("brands") or "unnamed"
    safe_name = sanitize_filename(raw_name)
    folder_name = f"{barcode}_{safe_name}"
    prod_dir = out_dir / folder_name
    prod_dir.mkdir(parents=True, exist_ok=True)
    
    # Save metadata
    meta_path = prod_dir / "metadata.json"
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(p, f, indent=2, ensure_ascii=False)
        
    download_tasks = []
    
    # Standard designated images
    image_fields = {
        "front": p.get("image_front_url"),
        "packaging": p.get("image_packaging_url"),
        "ingredients": p.get("image_ingredients_url"),
        "nutrition": p.get("image_nutrition_url"),
    }
    
    for tag, url in image_fields.items():
        if url:
            # Upgrade thumbnail .400.jpg to full resolution if possible
            full_url = url.replace(".400.jpg", ".full.jpg")
            ext = ".jpg"
            dest = prod_dir / f"{tag}{ext}"
            download_tasks.append((full_url, dest))
            
    # Also grab raw photos if packaging panel isn't explicitly tagged
    images_dict = p.get("images", {})
    if isinstance(images_dict, dict):
        raw_ids = [k for k in images_dict.keys() if k.isdigit()]
        # Grab first 3 raw high-res shots (often back panel / side panel with MRP)
        for rid in sorted(raw_ids, key=int)[:3]:
            raw_url = build_raw_image_url(barcode, rid)
            dest = prod_dir / f"panel_raw_{rid}.jpg"
            download_tasks.append((raw_url, dest))
            
    downloaded_count = 0
    for url, dest in download_tasks:
        if download_file(url, dest):
            downloaded_count += 1
            
    return barcode, raw_name, downloaded_count

def main():
    parser = argparse.ArgumentParser(description="Download real Indian product images for OCR compliance testing.")
    parser.add_argument("--count", type=int, default=25, help="Number of products to download (default: 25)")
    parser.add_argument("--out-dir", type=str, default="./dataset/real_products", help="Output directory")
    parser.add_argument("--workers", type=int, default=4, help="Parallel download workers")
    args = parser.parse_args()
    
    out_path = Path(args.out_dir).resolve()
    out_path.mkdir(parents=True, exist_ok=True)
    
    print(f"[*] Target: {args.count} Indian packaged products")
    print(f"[*] Saving to: {out_path}")
    
    products = []
    page = 1
    while len(products) < args.count:
        needed = min(24, args.count - len(products))
        print(f"[*] Fetching product index page {page}...")
        try:
            batch = search_products(page=page, page_size=24)
        except Exception as e:
            print(f"[!] Failed to fetch page {page}: {e}")
            break
        if not batch:
            break
        products.extend(batch)
        page += 1
        time.sleep(0.5)
        
    products = products[:args.count]
    print(f"[*] Found {len(products)} products. Starting download with {args.workers} workers...")
    
    total_imgs = 0
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(process_product, p, out_path): p for p in products}
        for future in as_completed(futures):
            try:
                barcode, name, count = future.result()
                total_imgs += count
                print(f"  [+] Downloaded {count} images for [{barcode}] {name}")
            except Exception as e:
                print(f"  [!] Failed processing: {e}")
                
    print(f"\n[✓] Done! Downloaded {total_imgs} images across {len(products)} products into {out_path}")

if __name__ == "__main__":
    main()
