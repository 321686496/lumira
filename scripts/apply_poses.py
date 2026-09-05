#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json, codecs, io
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
# json 文件是 utf-8 with BOM
with codecs.open(r"e:\Project\photo_post\scripts\poses_data.json", encoding="utf-8-sig") as f:
    POSES = json.load(f)

def write_utf8_no_bom(path, text):
    path.write_bytes(text.encode("utf-8"))

changed = []
for key, items in POSES.items():
    folder = ROOT / key
    tpl = folder / "template.pptpl"
    doc = json.load(open(tpl, encoding="utf-8"))
    poses = []
    for it in items:
        poses.append({
            "name": it["name"],
            "silhouette": {"type": "none"},
            "position": {"x": it["x"], "y": it["y"]},
            "scale": it["scale"],
            "rotation": it["rotation"],
            "description": it["description"],
        })
    doc["pose"] = poses
    json.dump(doc, open(tpl, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    changed.append(key)

print("updated:", ", ".join(changed))
print("total:", len(changed))
