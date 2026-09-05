# -*- coding: utf-8 -*-
"""批量生成 4 套清冷模板(按真实爆款重切)x4 姿势 = 16 张姿势参考图 (HAPI gpt-image-2 文生图，风格锚定真实爆款)。
用法: python gen_cool_poses.py <start> <end>
每个模板目录内记录 pose_images.json (pose name -> filename) 便于断点续跑。
"""
import codecs, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
SCRIPT = r"e:\Project\photo_post\scripts\gpt_image2.py"
KEY = "sk-8d0149c3e8dbf782ed1356b0be5e25579121eef8326c29db64884786bdf959df"
MODEL = "gpt-image-2"
SIZE = "3:4"

FOLDERS = ["18_cool_blue_queen","19_bookstore_cool","20_xinzhongshi_cool","22_jiangnan_water"]

# 风格前缀按小红书/抖音真实爆款方向锚定
STYLE = {
    "18_cool_blue_queen": "写实冷调高级灰棚拍人像，黑色吸光背景，一位年轻东亚女性穿冷灰/深蓝垂感衬衫或哑光黑，侧后方45-90度冷光仅照亮面部一半到三分之二，人物在画面中占比30%-50%其余大面积留黑，低饱和底妆保留原生肤质，情绪克制疏离，电影感高级灰，竖构图",
    "19_bookstore_cool": "写实冷调松弛街拍人像，清晨空旷街道或雨后漫射光，一位年轻东亚女性不直视镜头，自然背影半侧脸/行走中回头/手扶栏杆望远方，轻微欠曝带冷空气感，色调偏冷向蓝，松弛克制的叙事留白感，竖构图",
    "20_xinzhongshi_cool": "写实青花瓷新中式人像，一位年轻东亚女性穿白底蓝花吊带裙配白色蕾丝花边，黑长直秀发配额间蓝色花钿与长款水钻耳坠，咖啡馆落地窗或花园木窗作自然画框，窗外绿植朦胧虚化，明亮通透清素雅致，低饱和蓝白配色素净留白，竖构图",
    "22_jiangnan_water": "清冷江南水窗人像，一位年轻东亚女性穿冰蓝或奶白裙装，临水老木窗，窗外青瓷蓝水面小桥石墙，冷白漫射光把肤色衬得清透，眉眼含疏离，温婉清透有江南诗意，竖构图",
}

TASKS = []  # (folder, poseName, prompt)
for folder in FOLDERS:
    tpl = ROOT / folder / "template.pptpl"
    doc = json.load(open(tpl, encoding="utf-8"))
    style = STYLE[folder]
    for it in doc["pose"]:
        prompt = f"{style}。姿势动作：{it['description']}。竖构图半身或全身人像，画面干净有质感。"
        TASKS.append((folder, it["name"], prompt))

print(f"total {len(TASKS)} tasks", flush=True)

def index_of(folder, pose_name):
    rec = ROOT / folder / "pose_images.json"
    if rec.exists():
        try:
            m = json.load(codecs.open(rec, encoding="utf-8-sig"))
            if pose_name in m:
                f = ROOT / folder / m[pose_name]
                if f.exists():
                    return True
        except Exception:
            pass
    return False

start = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end = int(sys.argv[2]) if len(sys.argv) > 2 else len(TASKS)

for idx in range(start, min(end, len(TASKS))):
    folder, pose_name, prompt = TASKS[idx]
    outdir = ROOT / folder
    outdir.mkdir(exist_ok=True)
    if index_of(folder, pose_name):
        print(f"[{idx+1}/{len(TASKS)}] skip {folder} | {pose_name} (done)", flush=True)
        continue
    before = set(outdir.glob("*.png"))
    print(f"[{idx+1}/{len(TASKS)}] {folder} | {pose_name}", flush=True)
    r = subprocess.run(
        [sys.executable, SCRIPT, prompt, "--platform", "hapi", "--model", MODEL,
         "--size", SIZE, "--out", str(outdir), "--api-key", KEY],
        capture_output=True, text=True, encoding="utf-8", errors="replace")
    time.sleep(1)
    new = sorted(set(outdir.glob("*.png")) - before, key=lambda p: p.stat().st_mtime)
    mapped = new[0] if new else None
    if mapped:
        rec = outdir / "pose_images.json"
        m = {}
        if rec.exists():
            try:
                m = json.load(codecs.open(rec, encoding="utf-8-sig"))
            except Exception:
                m = {}
        m[pose_name] = mapped.name
        json.dump(m, open(rec, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
        print(f"   -> {mapped.name} | exit={r.returncode}", flush=True)
    else:
        print(f"   -> NO FILE | exit={r.returncode}", flush=True)
        print(f"   stderr: {r.stderr[-400:]}", flush=True)

print("batch done", flush=True)
