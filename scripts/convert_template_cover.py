#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Convert raw Seedream cover (1680x2240, watermark at bottom-right) to:
- cover.jpg  1545x2060 JPEG q88 (crop from top-left, removes right 135px + bottom 180px)
- gen_{ts}_1.png  full-size original archive (PNG)
Usage: python convert_template_cover.py <raw_img> <template_dir>
"""
import sys
import time
from pathlib import Path

from PIL import Image

W, H = 1545, 2060
QUALITY = 88


def main() -> None:
    raw_path = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])

    img = Image.open(raw_path).convert("RGB")
    if img.size != (1680, 2240):
        print(f"warn: unexpected size {img.size}")

    # Crop top-left window 1545x2060: cuts right 135px + bottom 180px (watermark zone)
    cover = img.crop((0, 0, W, H))
    cover_path = out_dir / "cover.jpg"
    cover.save(cover_path, "JPEG", quality=QUALITY, optimize=True)

    # Archive original as gen_{ts}_1.png
    ts = int(time.time() * 1000)
    gen_path = out_dir / f"gen_{ts}_1.png"
    img.save(gen_path, "PNG", optimize=True)

    raw_path.unlink(missing_ok=True)
    print(f"cover: {cover_path} ({W}x{H}) | gen: {gen_path.name} | raw removed")


if __name__ == "__main__":
    main()
