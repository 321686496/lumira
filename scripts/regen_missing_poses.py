# -*- coding: utf-8 -*-
"""修复 pose_images.json 中为 0 字节/缺失的姿势图（重生成，保持人物一致）。
用本文件夹内一个有效姿势图作为参考，图生图只改姿势 → 更新 pose_images.json。
用法: python regen_missing_poses.py   (处理所有模板中损坏的姿势图)
"""
import codecs, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
SCRIPT = r"e:\Project\photo_post\scripts\gpt_image2.py"
KEY = "sk-8d0149c3e8dbf782ed1356b0be5e25579121eef8326c29db64884786bdf959df"
MAX_TRY = 4
TIMEOUT = 420

def load_mapping(d):
    rec = d / "pose_images.json"
    return json.load(codecs.open(rec, encoding="utf-8-sig")) if rec.exists() else {}

def save_mapping(d, m):
    json.dump(m, open(d / "pose_images.json", "w", encoding="utf-8"),
              ensure_ascii=False, indent=2)

def valid_file(d, fn):
    if not fn:
        return None
    f = d / fn
    return f if (f.is_file() and f.stat().st_size > 0) else None

def newest_png(d, before):
    pngs = sorted(d.glob("*.png"), key=lambda p: p.stat().st_mtime)
    for p in reversed(pngs):
        if p not in before:
            return p
    return None

def regen(d, pose_name, desc, anchor):
    before = set(d.glob("*.png"))
    prompt = (f"保持参考图中同一位置同一套穿搭与发型、同一背景与光线不变, 只改变人物的姿势动作。"
              f"姿势动作：{desc}。竖构图。")
    cmd = [sys.executable, SCRIPT, prompt, "--image", str(anchor),
           "--platform", "hapi", "--model", "gpt-image-2", "--size", "3:4",
           "--once", "--out", str(d), "--api-key", KEY]
    for attempt in range(1, MAX_TRY + 1):
        print(f"[{d.name}/{pose_name}] 尝试 {attempt}/{MAX_TRY}", flush=True)
        try:
            r = subprocess.run(cmd, capture_output=True, text=True,
                               encoding="utf-8", errors="replace", timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            print("   超时,重试", flush=True); time.sleep(2); continue
        time.sleep(1)
        fn = newest_png(d, before)
        if fn:
            return fn.name
        err = (r.stderr or "")[-200:]
        print(f"   第{attempt}次失败 exit={r.returncode} {err}", flush=True)
        time.sleep(5)
    return None

def main():
    for d in sorted(ROOT.iterdir()):
        if not d.is_dir() or not (d / "template.pptpl").exists():
            continue
        doc = json.load(open(d / "template.pptpl", encoding="utf-8"))
        pose = doc.get("pose", [])
        poses = pose if isinstance(pose, list) else [pose]
        poses = [p for p in poses if isinstance(p, dict)]
        m = load_mapping(d)
        anchor = None
        for p in poses:
            anchor = valid_file(d, m.get(p.get("name"), ""))
            if anchor:
                break
        if anchor is None:
            print(f"!! {d.name} 无任何有效姿势图，跳过", flush=True); continue
        any_fixed = False
        for p in poses:
            if valid_file(d, m.get(p.get("name"), "")):
                continue
            fn = regen(d, p.get("name"), p.get("description", ""), anchor)
            if fn:
                m[p.get("name")] = fn
                save_mapping(d, m)
                print(f"   OK {p['name']} -> {fn}", flush=True); any_fixed = True
            else:
                print(f"   !! {p['name']} 生成失败", flush=True)
        if any_fixed:
            print(f"== {d.name} 已更新", flush=True)
    print("done", flush=True)

if __name__ == "__main__":
    main()