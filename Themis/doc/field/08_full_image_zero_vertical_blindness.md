# 08 — Full-image 0%: vertical-text blindness (phone exonerated)

## Symptom

Single scan of the Yippie full pack shot scores **0.0% CriticalSevere** on the
phone — twice (26s and 56s for the identical file). Looks like a mobile
catastrophe; is not one.

## Proof it is not mobile-specific

CLI on the same file, same `mobile-v3` tier: **0.0%, 122 tokens**. CLI with the
27 MB server detector: **57.1%, 172 tokens** — but the same region missing.
Phone found 123. All three agree; the phone is exonerated.

## The picture (`assets/yippie_full_detector_boxes.jpg`)

All 122 CLI boxes drawn on the upright image: ingredients (left), nutrition
(center), QR/ITC/barcode/marketer (right) are boxed. The white statutory
strip at the bottom — `NET WEIGHT: 420 g`, `MRP Rs. 90.00 (Rs. 0.21/g)`,
`Mfd: 17JUL26`, `PKD./USE BY` — has **zero boxes**. Its text is printed
**vertically** (bottom-to-top reading direction). DBNet boxes horizontal text;
the rotation probe only fires on low overall quality, and 122 good tokens
keep quality high — so the vertical block is never attempted.

```bash
python3 -c "
import json
from PIL import Image, ImageDraw, ImageOps
d = json.load(open('/tmp/opencode/full_mobilev3.json'))
im = ImageOps.exif_transpose(Image.open('dataset/mine/yippie/fullimage/<f>.jpg'))
dr = ImageDraw.Draw(im)
for t in d['raw_ocr_tokens']:
    b = t['bbox']; dr.rectangle([b['x'], b['y'], b['x']+b['width'], b['y']+b['height']], outline=(255,0,0), width=6)
im.save('overlay.png')"
```

Consequence chain: no qty token → NetQuantity Violation; no MRP token →
MRP Violation; no date token → ManufactureDate Violation; 0 of 7 applicable
compliant → exactly 0.0%. The arithmetic is correct; the coverage is not.
(Halves score higher precisely because the photographer framed their text
horizontally.)

## Fix directions (engine side, `themis/src/ocr/`)

- Coverage-triggered rotation probe: if large image regions hold zero tokens,
  run the 90° detection pass and merge — gate on coverage, not just quality.
- `ppocr_cls.onnx` already ships in `themis/models/` but is **unused**; the
  standard det→cls→rec chain exists for exactly this.
- Cost note: a second full detection pass doubles detect time on affected
  panels only — acceptable if gated by the coverage check above.

## Side observation (timing)

Same file: 26s once, 56s once, same tier, same machine state class. That
variance (thermal vs probe-threshold borderline) is itself worth one TIMER
annotated run before any speed claim is made — see doc 06.
