# -*- coding: utf-8 -*-
"""用真实爆款照片做 img2img 参考，重新生成 5 套清冷模板 x4 姿势 = 20 张姿势参考图 (HAPI gpt-image-2)。
每张以该模板的爆款参考图(风格/色调/人物)为底，改为对应姿势。记录 pose_images.json 便于断点。
用法: python gen_cool_refs.py <start> <end>
"""
import codecs, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
REFS = Path(r"e:\Project\photo_post\refs\cool")
SCRIPT = r"e:\Project\photo_post\scripts\gpt_image2.py"
KEY = "sk-8d0149c3e8dbf782ed1356b0be5e25579121eef8326c29db64884786bdf959df"
MODEL = "gpt-image-2"
SIZE = "3:4"

FOLDERS = ["18_cool_blue_queen","19_bookstore_cool","20_xinzhongshi_cool","21_cinematic_light","22_jiangnan_water"]

REFIMG = {
    "18_cool_blue_queen": "18_blue1.jpg",
    "19_bookstore_cool":  "19_book1.jpg",
    "20_xinzhongshi_cool":"20_xzs1.jpg",
    "21_cinematic_light": "21_film1.jpg",
    "22_jiangnan_water":  "22_js1.jpg",
}

STYLE = {
    "18_cool_blue_queen": "冷蓝灰色低饱和，年轻女性，深沉克制御姐气质，夜晚街道/霓虹侧逆光勾亮发丝，金属配饰冷光反光，电影感氛围",
    "19_bookstore_cool": "老书店木质书架背景，素色棉麻穿搭，克制窗边自然光，书卷气，眼神安静游离，低饱和",
    "20_xinzhongshi_cool": "新中式清冷，米白/雾蓝素色改良旗袍配珍珠耳饰，古窗/回廊/园林背景，逆光发丝柔光轮廓，眉目疏离温婉",
    "21_cinematic_light": "电影感清冷，深色背景，侧逆光塑形大面积暗部，头纱或薄纱朦胧发光，情绪克制安静",
    "22_jiangnan_water": "江南水窗清透清冷，临水老木窗，青瓷蓝水面小桥石墙，冰蓝与奶白穿搭，窗外冷白漫射光，清透温婉",
}

TASKS = []
for folder in FOLDERS:
    ref = REFS / REFIMG[folder]
    if not ref.exists():
        raise SystemExit(f"缺参考图 {ref}")
    doc = json.load(open(ROOT / folder / "template.pptpl", encoding="utf-8"))
    style = STYLE[folder]
    for it in doc["pose"]:
        prompt = f"保持参考图中人物的发型妆容与整体氛围色调风格，把姿势改为：{it['description']}。{style}。竖构图半身或全身人像，画面干净有质感。"
        TASKS.append((folder, it["name"], str(ref), prompt))

print(f"total {len(TASKS)} tasks", flush=True)

done_idx = set()
for i, (folder, pose_name, _, _) in enumerate(TASKS):
    rec = ROOT / folder / "pose_images.json"
    if rec.exists():
        try:
            m = json.load(codecs.open(rec, encoding="utf-8-sig"))
            if pose_name in m and (ROOT / folder / m[pose_name]).exists():
                done_idx.add(i)
        except Exception:
            pass

start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end = int(sys.argv[2]) if len(sys.argv) > 2 else len(TASKS)

for idx in range(start, min(end, len(TASKS))):
    folder, pose_name, ref, prompt = TASKS[idx]
    outdir = ROOT / folder
    if idx in done_idx:
        print(f"[{idx+1}/{len(TASKS)}] skip {folder} | {pose_name} (done)", flush=True)
        continue
    before = set(outdir.glob("*.png"))
    print(f"[{idx+1}/{len(TASKS)}] {folder} | {pose_name} (ref={Path(ref).name})", flush=True)
    r = subprocess.run(
        [sys.executable, SCRIPT, prompt, "--platform", "hapi", "--model", MODEL,
         "--image", str(ref), "--size", SIZE, "--out", str(outdir), "--api-key", KEY],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    time.sleep(1)
    new = sorted(set(outdir.glob("*.png")) - before, key=lambda p: p.stat().st_mtime)
    mapped = new[0] if new else None
    if mapped:
        rec = outdir / "pose_images.json"
        m = {}
        if rec.exists():
            try: m = json.load(codecs.open(rec, encoding="utf-8-sig"))
            except Exception: m = {}
        m[pose_name] = mapped.name
        json.dump(m, open(rec, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print(f"   -> {mapped.name} | exit={r.returncode}", flush=True)
    else:
        print(f"   -> NO FILE | exit={r.returncode}", flush=True)
        print(f"   stderr: {r.stderr[-400:]}", flush=True)

print("batch done", flush=True)