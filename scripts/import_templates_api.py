#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""通过后端 Admin API 批量导入 selfie_templates/*/template.pptpl
契约: POST {BASE}/api/v1/admin/templates multipart
  meta=<JSON>, images[0]...images[N] 文件
  Authorization: Bearer <ADMIN_TOKEN>
  Flutter 端 images[i] <-> poses[i] 一一对应; images[0]=封面=pose[0]
用法:
  python import_templates_api.py [folder] | --skill-test
  python import_templates_api.py --rebuild   # 压缩源图为 JPEG q85 重建，再删除旧模板
"""
import io, json, sys, time, uuid
import urllib.request, urllib.error
from pathlib import Path
from PIL import Image

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
BASE = "https://lumira.iwtle.top"
TOKEN = "46c3850364b14d20da48c31cfc7d233031b94f4c2fc76c8b32de527fb4c03043"
SKIP = {"37_skincare_morning"}
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

def classif(c):
    c = c or {}
    style = c.get("style", "") or ""
    return {"type": "portrait", "majorStyle": c.get("majorStyle","") or "",
            "style": style, "subStyle": c.get("subStyle","") or style,
            "method": c.get("method","") or ""}

def build_meta(doc):
    meta = doc.get("_meta", {})
    amb = meta.get("ambience") or {}
    return {"name": meta.get("name", "模板"), "author": "Lumira",
            "version": doc.get("version", "1.0.0"), "category": "portrait",
            "price": 0, "description": meta.get("description",""),
            "shortDesc": meta.get("shortDesc",""), "tags": meta.get("tags",[]),
            "referenceSource": meta.get("referenceSource","原创"),
            "classification": classif(meta.get("classification")),
            "ambience": {"seasons": amb.get("seasons",[]),
                         "weathers": amb.get("weathers",[]),
                         "timeTones": amb.get("timeTones",[])},
            "sortOrder": 0, "isActive": True,
            "composition": doc.get("composition",{}),
            "poses": [p for p in doc.get("pose",[]) if isinstance(p,dict)],
            "camera": doc.get("camera",{}),
            "sceneGuide": doc.get("sceneGuide",{}),
            "postProcess": doc.get("postProcess",{})}

def alignment(folder):
    d = ROOT / folder
    doc = json.load(io.open(d/"template.pptpl", encoding="utf-8"))
    poses = [p for p in doc.get("pose",[]) if isinstance(p,dict)]
    rec = d/"pose_images.json"
    mp = json.load(io.open(rec, encoding="utf-8-sig")) if rec.exists() else {}
    aligned = []
    for p in poses:
        fn = mp.get(p.get("name"), "")
        f = ROOT/folder/fn if fn else None
        aligned.append((p.get("name"), f if (f and f.is_file()) else None))
    return doc, poses, aligned

def to_jpeg(fp, q=85):
    """把效果图源 PNG 在内存中转为 JPEG q85（效果图是不透明照片，无需 alpha）"""
    im = Image.open(fp)
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
    b = "----lum"+uuid.uuid4().hex
    body = io.BytesIO()
    for k,v in fields.items():
        body.write(f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n'.encode())
        body.write(v if isinstance(v,bytes) else v.encode("utf-8")); body.write(b"\r\n")
    for k,(fn,data,ct) in files.items():
        body.write(f'--{b}\r\nContent-Disposition: form-data; name="{k}"; filename="{fn}"\r\nContent-Type: {ct}\r\n\r\n'.encode())
        body.write(data); body.write(b"\r\n")
    body.write(f"--{b}--\r\n".encode())
    return b, body.getvalue()

def post_one(folder, compress=False):
    doc, poses, aligned = alignment(folder)
    miss = [(p,f) for p,f in aligned if f is None]
    if miss:
        return f"SKIP {folder}: {len(miss)} 姿势缺图", False, None, None
    meta = build_meta(doc)
    try:
        files = {}
        for i,(pname,fp) in enumerate(aligned):
            # 空文件/损坏文件直接跳过该模板（不中断整批）
            if fp.stat().st_size == 0:
                return f"SKIP {folder}: {pname} 图片为空(0字节)", False, None, None
            if compress:
                files[f"images[{i}]"] = (f"image_{i}.jpg", to_jpeg(fp), "image/jpeg")
            else:
                files[f"images[{i}]"] = (fp.name, fp.read_bytes(), "image/png")
        b, body = multipart({"meta": json.dumps(meta, ensure_ascii=False)}, files)
        req = urllib.request.Request(f"{BASE}/api/v1/admin/templates", data=body,
            method="POST", headers={"Authorization": f"Bearer {TOKEN}",
            "Content-Type": f"multipart/form-data; boundary={b}"})
        with _opener.open(req, timeout=180) as resp:
            out = json.loads(resp.read().decode("utf-8"))
        return f"OK   {folder} -> {out.get('name','')} ({out.get('id','')}) poses={len(aligned)}", True, out.get('name'), out.get('id')
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")[:300]
        return f"ERR  {folder} HTTP {e.code}: {raw}", False, None, None
    except Exception as e:
        return f"ERR  {folder}: {e}", False, None, None

def delete_template(tid):
    req = urllib.request.Request(f"{BASE}/api/v1/admin/templates/{tid}",
        method="DELETE", headers={"Authorization": f"Bearer {TOKEN}"})
    with _opener.open(req, timeout=60) as resp:
        resp.read()
    return True

def main():
    only = None
    if len(sys.argv)>1 and not sys.argv[1].startswith("-"): only = sys.argv[1]
    if "--skill-test" in sys.argv:
        for d in sorted(ROOT.iterdir()):
            if not d.is_dir(): continue
            doc, poses, aligned = alignment(d.name)
            miss = [(p,f) for p,f in aligned if f is None]
            print(("OK " if not miss else f"缺{len(miss)}"), d.name,
                  f"poses={len(poses)} img={len([a for a in aligned if a[1]])}")
        return
    todo = sorted(d.name for d in ROOT.iterdir()
                  if d.is_dir() and (d/"template.pptpl").exists() and d.name not in SKIP)
    if only: todo = [t for t in todo if t.startswith(only) or t==only]

    if "--rebuild" in sys.argv:
        # 压缩源图重建模板：POST 新模板(全新 id) -> 按名字删除脚本运行前已存在的旧模板。
        # 每次实时拉取最新列表，保证重复运行也不产生重复 id（幂等）。
        req = urllib.request.Request(f"{BASE}/api/v1/admin/templates?page=1&pageSize=500",
            headers={"Authorization": f"Bearer {TOKEN}"})
        with _opener.open(req, timeout=30) as resp:
            snap = json.loads(resp.read().decode("utf-8"))["data"]
        old_by_name = {}
        for r in snap: old_by_name.setdefault(r.get("name",""), []).append(r.get("id"))
        ok = 0; created = {}   # name -> new id
        for t in todo:
            msg,succ,name,nid = post_one(t, compress=True)
            print(msg, flush=True)
            if succ and nid: created[name]=nid; ok+=1
            time.sleep(0.6)
        print(f"IMPORTED {ok}/{len(todo)}")
        # 删除与被重建模板同名的旧模板（含其存储的原始大图）
        to_delete = []
        for name,nid in created.items():
            to_delete += old_by_name.get(name, [])
        to_delete = list(dict.fromkeys(x for x in to_delete if x))
        del_ok = 0
        for oid in to_delete:
            try:
                delete_template(oid); del_ok+=1
                print(f"DEL  {oid}", flush=True)
            except Exception as e:
                print(f"DEL-ERR {oid} {e}", flush=True)
            time.sleep(0.3)
        print(f"DELETED {del_ok}/{len(to_delete)}")
        return

    ok=0
    for t in todo:
        msg,succ,_,_ = post_one(t); print(msg, flush=True); ok+=succ; time.sleep(0.6)
    print(f"DONE {ok}/{len(todo)}")

if __name__ == "__main__": main()
