# -*- coding: utf-8 -*-
"""将 online_templates/<key> 目录的模板产物上传到后端。

后端 POST /api/v1/admin/templates (AdminAuthGuard, Bearer token):
- meta  (JSON): name/category/price/poses/classification...
- cover + images[] : 姿势效果图(images[0]=封面)
- silhouette 文件   : 首个姿势剪影(后端注入 poses[0])
- 其余姿势剪影       : 以 base64 data URL 内嵌 meta.poses[i].silhouette.data
"""
import argparse
import base64
import json
import mimetypes
import os
import re
import sys

import requests

B64_STYLE = os.environ.get("UPLOAD_SIL_B64", "1") == "1"


def b64_data_url(path: str) -> str:
    with open(path, "rb") as f:
        raw = f.read()
    mime = mimetypes.guess_type(path)[0] or "image/png"
    return f"data:{mime};base64," + base64.b64encode(raw).decode()


def build_meta(base_dir: str):
    with open(os.path.join(base_dir, "template.pptpl"), encoding="utf-8") as f:
        pptpl = json.load(f)
    meta = pptpl.get("_meta", {})
    name = meta.get("name", "")
    category = meta.get("category", "portrait")
    classification = meta.get("classification", {})
    ambience = meta.get("ambience", {})

    meta_payload = {
        "name": name,
        "category": category,
        "price": int(meta.get("price", 0)),
        "description": meta.get("description", ""),
        "shortDesc": meta.get("shortDesc", ""),
        "gender": meta.get("gender", "unisex"),
        "ambience": ambience,
        "author": meta.get("author", "Lumira"),
        "referenceSource": meta.get("referenceSource", ""),
        "tags": meta.get("tags", []),
        "tagIds": [],
        "classification": {
            "type": classification.get("type", category),
            "majorStyle": classification.get("majorStyle", ""),
            "style": classification.get("style", ""),
            "subStyle": classification.get("subStyle", ""),
            "method": classification.get("method", ""),
        },
        "sortOrder": 0,
        "isActive": True,
        "composition": pptpl.get("composition", {}),
        "camera": pptpl.get("camera", {}),
        "sceneGuide": pptpl.get("sceneGuide", {}),
        "postProcess": pptpl.get("postProcess", {}),
    }

    raw_poses = pptpl.get("pose", [])
    if isinstance(raw_poses, dict):
        raw_poses = [raw_poses]
    poses = []
    sil_files = []
    for i, p in enumerate(raw_poses):
        sp = p.get("silhouette", {}) if isinstance(p.get("silhouette"), dict) else {}
        sp_type = sp.get("type", "builtin") if sp else "builtin"
        sp_data = sp.get("data", "") if sp else ""
        sil_file = None
        cand = os.path.join(base_dir, sp_data) if sp_data and not sp_data.startswith("data:") else ""
        if cand and os.path.exists(cand):
            sil_file = cand
        item = {
            "name": p.get("name", f"pose{i + 1}"),
            "position": p.get("position", {"x": 0.5, "y": 0.55}),
            "scale": p.get("scale", 1.0),
            "rotation": p.get("rotation", 0),
            "description": p.get("description", ""),
            "cameraDirection": p.get("cameraDirection", "back"),
        }
        if sil_file:
            if i == 0:
                item["silhouette"] = {"type": "image"}  # 文件字段注入
            else:
                item["silhouette"] = {"type": "image", "data": b64_data_url(sil_file)}
        else:
            item["silhouette"] = {"type": sp_type if sp_type else "builtin", "data": sp_data}
        poses.append(item)
        sil_files.append(sil_file)

    meta_payload["pose"] = poses[0] if poses else {}
    meta_payload["poses"] = poses
    return meta_payload, sil_files


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True, help="模板目录(含 template.pptpl / pose*.png / pose*_sil.png)")
    ap.add_argument("--base", default="https://lumira.iwtle.top/api/v1")
    ap.add_argument("--token", required=True)
    args = ap.parse_args()

    meta, sil_files = build_meta(args.dir)

    def pose_key(fn):
        m = re.match(r"^pose(\d+)(?!_sil)", fn, re.IGNORECASE)
        return int(m.group(1)) if m else 10 ** 9

    pose_images = sorted(
        [os.path.join(args.dir, f) for f in os.listdir(args.dir)
         if os.path.isfile(os.path.join(args.dir, f))
         and re.match(r"^pose\d+\.(png|jpe?g|webp)$", f, re.IGNORECASE)],
        key=lambda p: pose_key(os.path.basename(p)),
    )
    if not pose_images:
        print("[错误] 未找到 pose*.png 效果图", file=sys.stderr)
        sys.exit(1)

    first_sil = sil_files[0] if sil_files and sil_files[0] else None

    # multipart: meta 作为纯表单字段，文件走 files 列表（同名字段支持多个 images）
    data = {"meta": json.dumps(meta, ensure_ascii=False)}
    files = []
    for p in pose_images:
        files.append(("images", (os.path.basename(p), open(p, "rb"),
                                 mimetypes.guess_type(p)[0] or "image/png")))
    if first_sil:
        files.append(("silhouette", (os.path.basename(first_sil), open(first_sil, "rb"),
                                     mimetypes.guess_type(first_sil)[0] or "image/png")))

    headers = {"Authorization": f"Bearer {args.token}"}
    url = f"{args.base}/admin/templates"
    print(f"[上传] POST {url}")
    print(f"  模板名: {meta['name']} | 分类: {meta['category']} | 姿势数: {len(meta['poses'])}")
    print(f"  images: {[os.path.basename(p) for p in pose_images]} | silhouette: {os.path.basename(first_sil) if first_sil else '—(已内嵌)'}")

    resp = requests.post(url, headers=headers, data=data, files=files, timeout=300)
    print(f"[响应] HTTP {resp.status_code}")
    print(resp.text[:2500])
    if resp.status_code in (200, 201):
        try:
            j = resp.json()
            print(f"\n[成功] 模板 ID: {j.get('id', '')}  name: {j.get('name', '')}")
        except Exception:
            pass
        sys.exit(0)
    sys.exit(1)


if __name__ == "__main__":
    main()