#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成 17 模板 x 4 姿势 = 68 张姿势参考图, 用 MaaS qwen-image-3.0-pro.
用法: python gen_all_poses.py <start_index> <end_index> --dry
每张输出到对应模板目录 gen_{ts}_{poseN}.png
"""
import codecs, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
SCRIPT = r"e:\Project\photo_post\scripts\gen_image.py"
MODEL = "qwen-image-3.0-pro"

with codecs.open(r"e:\Project\photo_post\scripts\poses_data.json", encoding="utf-8-sig") as f:
    POSES = json.load(f)

# 每套模板的风格前缀 prompt（场景/服装/色调），与模板的 cover 保持一致
STYLE = {
    "01_mirror_selfie": "写实时尚人像摄影，年轻亚洲女孩室内对镜自拍，简约现代穿搭，干净洗手间/试衣间，自然光，高质感写真",
    "02_new_chinese_cold": "写实新中式人像摄影，年轻亚洲女孩，素色新中式裙装，白纱帘/素色墙面/竹林/白墙黛瓦背景，清冷低饱和色调，电影质感",
    "03_ccd_retro": "写实CCD复古风格自拍，年轻亚洲女孩，胶片颗粒感，闪光灯质感，卧室/夜晚街道/便利店背景，复古千禧风",
    "04_cream_healing": "写实奶油治愈系人像，年轻亚洲女孩，奶白/米色家居服，奶白床品与米色纱帘柔和室内，奶油色调，温暖梦幻，柔和光",
    "05_y2k_dark": "写实Y2K千禧暗调自拍，年轻亚洲女孩，猫眼墨镜，酷辣穿搭，弱光室内/夜晚街道，暗调高对比，霓虹点缀，酷感",
    "06_hk_noir": "写实港风复古人像，年轻亚洲女孩，红唇浓颜，复古着装，霓虹招牌/复古室内/夜晚街头，浓郁胶片色调，王家卫风格",
    "07_french_lazy": "写实法式慵懒人像，年轻亚洲女孩，简约法式穿搭，咖啡馆/街角/玻璃柜台角落，暖调日光，浪漫慵懒氛围，胶片感",
    "08_natural_bare": "写实原生素颜人像，年轻亚洲女孩，素颜裸妆，纯色墙面/天空/虚化背景，通透自然光，清透干净，高级特写",
    "09_south_france": "写实南法度假人像，年轻亚洲女孩，碎花连衣裙+草帽+草编包，田野/花园/草坪/海边，明媚阳光，度假胶片感",
    "10_bw_studio": "写实黑白影室肖像，年轻亚洲女孩，老式木椅，纯色背景布，黑白摄影，经典光影层次，优雅复古",
    "11_japanese_fresh": "写实日系清新人像，年轻亚洲女孩，简约清新穿搭，安静街道/公园/天台，通透自然光，清新胶片色调，青春感",
    "12_mint_mambo_window": "写实时尚人像摄影，年轻亚洲女孩穿薄荷绿针织配奶白下装，薄荷绿墙+白纱帘漫射柔光，低饱和薄荷绿调，肤色白皙，高级写真",
    "13_mint_forest": "写实森系人像摄影，年轻亚洲女孩穿薄荷绿碎花裙配麻花辫，森林斜射光斑，低饱和清冷薄荷绿调，胶片颗粒，清透",
    "14_mint_seaside": "写实海边人像摄影，年轻亚洲女孩穿薄荷绿一字肩垂坠长裙，蓝绿渐变海面浅白沙滩，低饱和清爽冷调，肤白通透，治愈",
    "15_mint_soda_street": "写实夏日街头人像自拍，年轻亚洲女孩穿薄荷绿短袖，薄荷绿墙背景，举冰镇薄荷汽水，低饱和清透色调，俏皮街头",
    "16_mint_home_lounge": "写实居家人像自拍，年轻亚洲女孩穿奶白家居服躺薄荷绿纯色床单，窗边漫射柔光，低饱和奶雾薄荷调，慵懒治愈",
    "17_mint_picnic": "写实草地野餐人像，年轻亚洲女孩穿薄荷绿亚麻裙戴草帽，公园草坪米白野餐垫，藤编篮柠檬水，午后柔光，清新薄荷调",
}

FOLDER_ORDER = ["01_mirror_selfie","02_new_chinese_cold","03_ccd_retro","04_cream_healing","05_y2k_dark","06_hk_noir","07_french_lazy","08_natural_bare","09_south_france","10_bw_studio","11_japanese_fresh","12_mint_mambo_window","13_mint_forest","14_mint_seaside","15_mint_soda_street","16_mint_home_lounge","17_mint_picnic"]

# 构造 68 个 prompt 扁平列表
TASKS = []  # (folder, poseName, prompt)
for folder in FOLDER_ORDER:
    if folder not in POSES: 
        continue
    style = STYLE.get(folder, "写实人像摄影")
    for it in POSES[folder]:
        prompt = f"{style}。姿势动作：{it['description']}。竖构图，全身或半身人像，画面干净有质感。"
        TASKS.append((folder, it["name"], prompt))

print(f"total {len(TASKS)} tasks")

start = int(sys.argv[1]) if len(sys.argv)>1 else 0
end = int(sys.argv[2]) if len(sys.argv)>2 else len(TASKS)

for idx in range(start, min(end, len(TASKS))):
    folder, pose_name, prompt = TASKS[idx]
    outdir = ROOT / folder
    outdir.mkdir(exist_ok=True)
    ts = int(time.time()*1000)
    print(f"[{idx+1}/{len(TASKS)}] {folder} | {pose_name}", flush=True)
    # 调用 gen_image.py 串行
    r = subprocess.run([sys.executable, SCRIPT, prompt, "--model", MODEL, "--out", str(outdir)],
                       capture_output=True, text=True, encoding="utf-8", errors="replace")
    # 找到生成的文件（最新 png）
    time.sleep(1)
    pngs = sorted(outdir.glob("*.png"), key=lambda p: p.stat().st_mtime)
    last = pngs[-1] if pngs else None
    print(f"   -> {last.name if last else 'NONE'} | exit={r.returncode}", flush=True)
    if r.returncode != 0:
        print(f"   stderr: {r.stderr[-300:]}", flush=True)

print("batch done", flush=True)
