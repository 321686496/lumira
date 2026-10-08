#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过后端 Admin API 导入 online_templates/<folder>/ 下的模板。

契约: POST {BASE}/api/v1/admin/templates multipart
  meta=<JSON>, images[0..N] 效果图文件, silhouette=<poses[0] 剪影文件>
  其余姿势(poses[1..])的剪影以 data URL(base64) 内嵌进 meta.poses[i].silhouette.data，
  与 admin 前端 template-form 提交行为一致（后端仅对 poses[0] 落盘剪影文件）。
  Authorization: Bearer <ADMIN_TOKEN>
  Flutter 端 images[i] <-> poses[i] 一一对应；images[0]=封面=pos[0]

用法:
  python import_template_folder.py 06_lazy_lounge [--base URL] [--token TK] [--dry-run]
"""
import base64, io, json, sys, uuid
import urllib.request, urllib.error
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "online_templates"
BASE = "https://lumira.iwtle.top"
TOKEN = ""  # 命令行 --token 或环境变量 ADMIN_TOKEN 提供
DRY = "--dry-run" in sys.argv
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))


def classif(c):
    c = c or {}
    style = c.get("style", "") or ""
    return {"type": "portrait", "majorStyle": c.get("majorStyle", "") or "",
            "style": style, "subStyle": c.get("subStyle", "") or style,
            "method": c.get("method", "") or ""}


def read_sil_png(path, max_side=256):
    """剪影压缩为小尺寸透明 PNG 再转 base64 data URL(显著减小 meta 体积)。"""
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    scale = max_side / max(w, h)
    if scale < 1:
        im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()


def build_meta(doc, folder, sil_data_urls):
    meta = doc.get("_meta", {})
    amb = meta.get("ambience") or {}
    poses = []
    for i, p in enumerate([x for x in doc.get("pose", []) if isinstance(x, dict)]):
        # 剪影：所有姿势统一用 data URL 内嵌（poses[0] 的剪影文件同时走 silhouette 字段落盘，
        # 与 admin 前端 template-form 提交行为一致，后端对 poses[0] 落盘、其余内嵌）。
        pts = {**p}
        pts["silhouette"] = {"type": "image", "data": sil_data_urls.get(i, "")}
        poses.append(pts)
    return {
        "name": meta.get("name", folder), "author": "Lumira",
        "version": doc.get("version", "1.0.0"), "category": "portrait",
        "price": 0, "description": meta.get("description", ""),
        "shortDesc": meta.get("shortDesc", ""), "tags": meta.get("tags", []),
        "referenceSource": meta.get("referenceSource", "原创"),
        "classification": classif(meta.get("classification")),
        "ambience": {"seasons": amb.get("seasons", []),
                     "weathers": amb.get("weathers", []),
                     "timeTones": amb.get("timeTones", [])},
        "sortOrder": 0, "isActive": True,
        "composition": doc.get("composition", {}),
        "poses": poses,
        "camera": doc.get("camera", {}),
        "sceneGuide": doc.get("sceneGuide", {}),
        "postProcess": doc.get("postProcess", {}),
    }


def to_jpeg(fp, q=85, max_side=1280):
    im = Image.open(fp)
    # 限制最长边，降低后端落盘/处理耗时，避免 Nginx 反代 504
    w, h = im.size
    scale = max_side / max(w, h)
    if scale < 1:
        im = im.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
    if im.mode in ("RGBA", "P", "LA"):
        im = im.convert("RGBA")
        bg = Image.new("RGB", im.size, (255, 255, 255))
        bg.paste(im, mask=im.split()[-1])
        im = bg
    else:
        im = im.convert("RGB")
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=q, optimize=True)
    return buf.getvalue()


def multipart(fields, files):
    b = "----lum" + uuid.uuid4().hex
    body = io.BytesIO()
    for k, v in fields.items():
        body.write(f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n'.encode())
        body.write(v if isinstance(v, bytes) else v.encode("utf-8")); body.write(b"\r\n")
    for k, (fn, data, ct) in files.items():
        body.write(f'--{b}\r\nContent-Disposition: form-data; name="{k}"; filename="{fn}"\r\nContent-Type: {ct}\r\n\r\n'.encode())
        body.write(data); body.write(b"\r\n")
    body.write(f"--{b}--\r\n".encode())
    return b, body.getvalue()


def main():
    global BASE, TOKEN
    if len(sys.argv) < 2 or sys.argv[1].startswith("-"):
        print("用法: python import_template_folder.py <folder> [--base URL] [--token TK] [--dry-run]")
        return 1
    folder = sys.argv[1]
    for i, a in enumerate(sys.argv):
        if a == "--base" and i + 1 < len(sys.argv): BASE = sys.argv[i + 1]
        if a == "--token" and i + 1 < len(sys.argv): TOKEN = sys.argv[i + 1]
    import os
    TOKEN = TOKEN or os.environ.get("ADMIN_TOKEN", "")
    if not TOKEN:
        print("[错误] 缺少 ADMIN_TOKEN: 用 --token 或环境变量 ADMIN_TOKEN 提供")
        return 2

    d = ROOT / folder
    doc = json.load(io.open(d / "template.pptpl", encoding="utf-8"))
    poses = [p for p in doc.get("pose", []) if isinstance(p, dict)]
    mp = json.load(io.open(d / "pose_images.json", encoding="utf-8-sig")) if (d / "pose_images.json").exists() else {}

    aligned = []
    for p in poses:
        fn = mp.get(p.get("name"), "")
        f = d / fn if fn else None
        aligned.append((p.get("name"), f if (f and f.is_file()) else None))

    miss = [(p, f) for p, f in aligned if f is None]
    if miss:
        print(f"SKIP {folder}: {len(miss)} 姿势缺效果图 -> {[p for p, _ in miss]}")
        return 1

    sil_files = [d / f"pose{i+1}_sil.png" for i in range(len(poses))]
    sil_urls = {}
    for i, sf in enumerate(sil_files):
        if sf and sf.is_file():
            sil_urls[i] = read_sil_png(sf)
        else:
            # 找不到剪影文件：本姿势剪影留空(后端可后续补)
            sil_urls[i] = ""
    # 首姿势剪影文件单独上传(silhouette 字段)
    first_sil = sil_files[0] if sil_files and sil_files[0].is_file() else None

    meta = build_meta(doc, folder, sil_urls)

    if DRY:
        print(f"[dry-run] folder={folder} poses={len(poses)}")
        for i, (pname, f) in enumerate(aligned):
            print(f"  images[{i}] {pname} <- {f.name}  sil={'pose' + str(i+1) + '_sil.png' if (sil_files[i] and sil_files[i].is_file()) else 'MISSING'}")
        print(f"  silhouette(poses[0]) = {first_sil.name if first_sil else 'MISSING'}")
        print(f"  meta.poses 剪影类型: ", [p.get('silhouette', {}).get('type') or p.get('silhouette') for p in meta['poses']])
        return 0

    # 剪影全部走 data URL 内嵌(meta.poses[].silhouette.data)，不单独上传文件，
    # 避免触发后端 multipart 的 files 数量上限(默认 10)，9 张 images 已接近该限制。
    files = {}
    for i, (pname, fp) in enumerate(aligned):
        if fp.stat().st_size == 0:
            print(f"SKIP {folder}: {pname} 图片为空")
            return 1
        files[f"images[{i}]"] = (f"image_{i}.jpg", to_jpeg(fp), "image/jpeg")

    b, body = multipart({"meta": json.dumps(meta, ensure_ascii=False)}, files)
    req = urllib.request.Request(f"{BASE}/api/v1/admin/templates", data=body,
        method="POST", headers={"Authorization": f"Bearer {TOKEN}",
        "Content-Type": f"multipart/form-data; boundary={b}"})
    try:
        with _opener.open(req, timeout=180) as resp:
            out = json.loads(resp.read().decode("utf-8"))
        print(f"OK {folder} -> {out.get('name', '')} ({out.get('id', '')}) poses={len(aligned)}")
        print(f"  coverUrl={out.get('coverUrl', '')}")
        return 0
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")[:500]
        print(f"ERR {folder} HTTP {e.code}: {raw}")
        return 1
    except Exception as e:
        print(f"ERR {folder}: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())