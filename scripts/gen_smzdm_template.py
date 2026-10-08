#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""线上模板生产：多场景万能氛围人像（源自 什么值得买帖子「显身材的万能拍照姿势」）。

防侵权处理：
  - 姿势演示图（pose*.png）以帖子原张为 i2i 底图（MaaS qwen-image-3.0-pro 图生图），
    锁定"姿势/身体比例/场景/光线/机位/构图 "，但提示词显式要求换一张通用亚洲女性面容，
    并把外套/裙装的颜色与版型微调为接近但不同的款式（防侵权，不复刻原脸/原衣服）。
  - 剪影图（pose*_sil.png）由姿势图经"白底黑线稿图生图 + 本地二值化"生成，仅保留动作轮廓。

流程：panels -> poses(9) -> sil(9) -> doc；断点续跑（已存在即跳过）。
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
KEY = "05_fashion_vibe_portrait"
OUT_DIR = ROOT / "online_templates" / KEY
MASS_SCRIPT = SCRIPT_DIR / "gen_image.py"

MASS_MODEL = "qwen-image-3.0-pro"
P_SIZE = "3:4"
MAX_TRY = 3
CALL_TIMEOUT = 660
N_POSES = 9

SIL_PROMPT = (
    "纯白背景上的极简单色人物轮廓线稿插画，用少量平滑线条勾勒参考图中人物的整体姿势和四肢位置，"
    "保留姿势比例与画面位置；只画头、躯干、四肢的大轮廓，禁止绘制发型发丝、五官、眼睛、颈纹、"
    "手部细节、衣物褶皱和任何背景细节，无底色无文字"
)
SIL_THRESHOLD = 245
SIL_BBOX_THRESHOLD = 0.3
SIL_BBOX_PAD_RATIO = 0.05

# 源图面板映射：index -> (源文件, 姿势名, 朝向, 场景句子)
POSES = [
    (img, name, camera_direction, scene_zh, pose_detail_zh)
    for img, name, camera_direction, scene_zh, pose_detail_zh in [
        ("img2.jpg", "坐姿托腮", "front",
         "奢华酒店客房：右侧粉色丝绒软包长凳、左边深色木柜，落地窗夜景，暖米色墙面",
         "人物侧坐于软包长凳上，双腿一上一下交叉翘二郎腿，右手肘撑面托腮，左手向后撑凳面，面朝镜头"),
        ("img3.jpg", "靠墙低头拎包", "three_quarter",
         "高端酒店走廊：左侧抛光黑色大理石镜面墙、深棕木纹护墙板、黑白几何拼花地面",
         "人物重心在右腿，左腿前伸点地微屈，右手轻触身侧大理石墙，左手自然下垂拎包，头微低目视下方"),
        ("img4.jpg", "优雅蹲姿", "front",
         "高端酒店大堂：深棕木护墙板、近黑大理石墙、黑白几何拼花地面、顶部射灯",
         "人物并拢屈膝优雅下蹲，重心下沉，左手搭在左膝，右手向下轻触地面上的手提包，上身挺直抬头看镜头"),
        ("img5.jpg", "镜前翘腿站姿", "front",
         "高端酒店电梯厅：整面抛光镜面墙、深色花岗岩与白色大理石几何拼花地面、暖色吊灯",
         "人物左腿直立支撑，右腿屈膝抬起脚尖轻点左小腿后侧，左手自然垂拎包，右手向后轻扶镜面墙，面朝镜头"),
        ("img6.jpg", "咖啡厅托腮", "front",
         "法式轻奢咖啡厅：黑色古典立柱与黑色护墙板配金线、白色大理石圆桌金边、藤编黑白纹椅、背景糕点展示柜、水晶吊灯",
         "人物侧坐于藤编椅上，双腿大腿交叠翘二郎腿，右手抬起轻托腮，左手自然放腿侧，面朝镜头"),
        ("img7.jpg", "倚台歪头", "three_quarter",
         "黑金色调轻奢餐厅大堂：黑色墙面配金色装饰线与大型金色'&'符号、水晶吊灯、黑色台面金边",
         "人物侧身倚靠黑色台面，右手自然搭在台沿、左手微抬贴于胸前，身体微侧，头微歪面朝镜头"),
        ("img8.jpg", "站立双手交叠", "front",
         "法式复古轻奢店堂：黑白Art Deco植物纹样墙纸、黑色立体字母装饰、白色大理石小圆桌、藤编座椅、右侧镜面墙、黑金氛围",
         "人物站立，身体微侧，双手交叠轻拢于身前，头微歪、下巴轻收，直视角镜头"),
        ("img10.jpg", "居酒屋跪坐搭盘", "front",
         "日式居酒屋：木格酒柜摆满清酒瓶与达摩摆件、木招牌、播放动画的电视、暖黄灯光与红白灯笼、矮桌上有餐盘",
         "人物跪坐于木质餐位前，双腿并拢斜放，右手自然伸展轻触矮桌上的餐盘，面朝镜头"),
        ("img12.jpg", "台阶举手机眨眼", "front",
         "日式居酒屋掘式下沉座位：木质台阶座，红白灯笼与暖黄灯笼、木格酒架、日文书法木牌、播放动画的电视",
         "人物坐于木质台阶，双腿并拢微收，右手举起持手机、左手轻搭腿侧，面带微笑右眼眨眼"),
    ]
]

# 每套服装的防侵权颜色/版型微调指令（颜色变化 + 装饰细节重排，但风格调性保留）
OUTFIT_CHANGE = {
    "蓝绿": "把外套与短裙的主色由蓝绿微调为偏墨绿/雾蓝青的近似色系，黑色羽毛流苏边改为同色系短穗装饰，整体小香风粗花呢质感保留",
    "香槟金": "把外套与百褶裙的主色由香槟金光感微调为偏月光银/雾金色的近似色系，亮闪改为细密金银丝线，蕾丝内搭保留，整体轻奢小香风保留",
    "白绒": "把白色毛绒大衣微调为偏燕麦米驼色的近似浅色，黑白波点丝袜保留波点但调小圆点密度，珍珠发饰保留，整体名媛度假感保留",
}

REFINE_PROMPT = (
    "以参考图为基准重绘这张时尚人像：严格保持参考图中人物的姿势动作与四肢位置、身体比例、"
    "同一场景（{scene}）、同一光线方向与同一机位与构图，以上任何一项都不得改变。"
    "本姿势关键动作务必如实还原：{detail}。"
    "防侵权处理：把参考图中的人脸替换为一张不同的、非本参考图的亚洲女性通用面容，五官、脸型、发型"
    "完全重新生成一张普通年轻女生样貌，禁止复刻参考图人物的五官长相，禁止出现与原图同一张脸；"
    "同时{outfit_change}（防侵权地微调服装颜色与版型，但不改变服装风格类型与场景搭配）。"
    "把它变成真实相机直出的高清人像写真：3:4竖构图，室内暖调氛围光，皮肤保留真实毛孔纹理"
    "（禁止磨皮与塑料感），服装面料保留真实物理质感，轻微胶片颗粒。"
    "禁止CG或3D渲染感，禁止插画感，禁止过度锐化，禁止完美对称的网红脸，禁止改变人物姿势、场景与构图，"
    "禁止添加文字水印。"
)

META = {
    "name": "多场景万能氛围人像",
    "short_desc": "三套小香风穿搭，藏进光影里松弛出片",
    "description": (
        "氛围感人像万能模板，跨三套轻奢造型与三种空间：蓝绿粗花呢小香风套装配奢华酒店走廊/客房，"
        "香槟金亮闪粗花呢叠蕾丝内搭配黑金法式餐吧，燕麦白绒大衣搭波点丝袜配暖黄日式居酒屋。"
        "姿势覆盖坐姿托腮、靠墙低头、优雅蹲姿、镜前翘腿、倚台歪头、跪坐搭盘、举机眨眼等各类出片动作，"
        "室内暖光氛围、简约高级构图。适合约会下午茶、酒店打卡、餐厅氛围感写真，穿搭贴场景即可松弛出片。"
    ),
    "tags": "人像, 小香风, 氛围感, 咖啡厅, 居酒屋, 都市, 写真",
    "reference_source": "什么值得买帖子「显身材的万能拍照姿势」（源自公众号：学点拍照姿势）",
    "classification": {
        "majorStyle": "scene_portrait",
        "style": "elegant_lady",
        "method": "",
    },
    "ambience": {
        "seasons": ["autumn", "winter"],
        "weathers": ["sunny", "cloudy"],
        "timeTones": ["night", "warm"],
    },
}


def tdir():
    d = OUT_DIR / "_refs" / "_tmp" / str(int(time.time() * 1000))
    d.mkdir(parents=True, exist_ok=True)
    return d


def valid(p: Path) -> bool:
    return p.is_file() and p.stat().st_size > 0


def run_cmd(cmd, out_dir: Path, label: str):
    before = set(out_dir.glob("*.png"))
    try:
        r = subprocess.run(cmd, capture_output=True, text=True,
                           encoding="utf-8", errors="replace", timeout=CALL_TIMEOUT)
    except subprocess.TimeoutExpired:
        print(f"   [{label}] 超时({CALL_TIMEOUT}s)", flush=True)
        return None
    time.sleep(0.5)
    for p in sorted(out_dir.glob("*.png"), key=lambda p: p.stat().st_mtime, reverse=True):
        if p not in before:
            return p
    err = (r.stderr or r.stdout or "")[-400:]
    print(f"   [{label}] 失败 exit={r.returncode} {err}", flush=True)
    return None


def gen_maas(prompt: str, out_dir: Path, label: str, ref: Path = None):
    for attempt in range(1, MAX_TRY + 1):
        tmp = tdir()
        cmd = [sys.executable, str(MASS_SCRIPT), prompt,
               "--model", MASS_MODEL, "--size", P_SIZE, "--out", str(tmp)]
        if ref is not None:
            cmd += ["--image-file", str(ref)]
        print(f"   [{label}] maas 尝试 {attempt}/{MAX_TRY}", flush=True)
        f = run_cmd(cmd, tmp, label)
        if f:
            return f
        time.sleep(3)
    return None


def binarize_to_transparent(raw_path: Path) -> Image.Image:
    gray = Image.open(raw_path).convert("L")
    arr = np.asarray(gray)
    alpha = np.where(arr < SIL_THRESHOLD, 255, 0).astype(np.uint8)
    rgb = np.zeros(arr.shape + (3,), dtype=np.uint8)
    return Image.fromarray(np.dstack([rgb, alpha]), "RGBA")


def crop_to_content(img: Image.Image) -> Image.Image:
    alpha = np.asarray(img)[:, :, 3]
    ys, xs = np.where(alpha >= int(SIL_BBOX_THRESHOLD * 255))
    if len(xs) == 0:
        return img
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    pad_x = int(round((x1 - x0 + 1) * SIL_BBOX_PAD_RATIO))
    pad_y = int(round((y1 - y0 + 1) * SIL_BBOX_PAD_RATIO))
    w, h = img.size
    box = (max(0, x0 - pad_x), max(0, y0 - pad_y),
           min(w, x1 + pad_x + 1), min(h, y1 + pad_y + 1))
    return img.crop(box)


def outfit_key_for(i: int) -> str:
    return ["蓝绿", "蓝绿", "蓝绿", "蓝绿", "香槟金", "香槟金", "香槟金", "白绒", "白绒"][i - 1]


def step_panels(source_dir: Path, force: bool = False):
    refs = OUT_DIR / "_refs"
    refs.mkdir(parents=True, exist_ok=True)
    src_imgs = ["img2.jpg", "img3.jpg", "img4.jpg", "img5.jpg",
                "img6.jpg", "img7.jpg", "img8.jpg", "img10.jpg", "img12.jpg"]
    for i, fn in enumerate(src_imgs, 1):
        target = refs / f"panel{i}.png"
        if valid(target) and not force:
            continue
        im = Image.open(source_dir / fn).convert("RGB")
        im.save(target)
        print(f"panel{i} <- {fn} {target.stat().st_size // 1024}KB", flush=True)
    return True


def pose_prompt(i: int):
    fn, name, cam, scene, detail = POSES[i - 1]
    outfit = outfit_key_for(i)
    return REFINE_PROMPT.format(
        scene=scene, detail=detail, outfit_change=OUTFIT_CHANGE[outfit])


def step_pose(idx: int, force: bool) -> bool:
    target = OUT_DIR / f"pose{idx}.png"
    if valid(target) and not force:
        print(f"跳过 pose{idx}（已存在）", flush=True)
        return True
    ref = OUT_DIR / "_refs" / f"panel{idx}.png"
    if not valid(ref):
        print(f"!! panel{idx}.png 缺失", flush=True)
        return False
    fn, name, cam, scene, detail = POSES[idx - 1]
    print(f"生成 pose{idx} · {name}（{MASS_MODEL} 图生图+防侵权）…", flush=True)
    f = gen_maas(pose_prompt(idx), OUT_DIR, f"pose{idx} {name}", ref=ref)
    if not f:
        return False
    f.replace(target)
    print(f"pose{idx} -> {target.name}", flush=True)
    return True


def step_sil(idx: int, force: bool) -> bool:
    target = OUT_DIR / f"pose{idx}_sil.png"
    if valid(target) and not force:
        print(f"跳过 pose{idx} 剪影（已存在）", flush=True)
        return True
    src = OUT_DIR / f"pose{idx}.png"
    if not valid(src):
        print(f"!! pose{idx}.png 缺失", flush=True)
        return False
    print(f"生成 pose{idx} 剪影（{MASS_MODEL} 白底黑线稿 + 本地二值化）…", flush=True)
    raw = gen_maas(SIL_PROMPT, OUT_DIR, f"pose{idx} 剪影", ref=src)
    if not raw:
        return False
    keep = OUT_DIR / "_refs" / "sil_raw"
    keep.mkdir(parents=True, exist_ok=True)
    raw.replace(keep / f"pose{idx}_sil_raw.png")
    img = crop_to_content(binarize_to_transparent(keep / f"pose{idx}_sil_raw.png"))
    img.save(target)
    print(f"pose{idx} 剪影 -> {target.name} {img.size}", flush=True)
    return True


def write_docs():
    mapping = {POSES[i - 1][1]: f"pose{i}.png" for i in range(1, N_POSES + 1)}
    (OUT_DIR / "pose_images.json").write_text(
        json.dumps(mapping, ensure_ascii=False, indent=2), encoding="utf-8")
    pptpl = {
        "format": "pptpl",
        "version": "1.0.0",
        "_meta": {
            "name": META["name"],
            "author": "Lumira",
            "category": "portrait",
            "price": 0,
            "description": META["description"],
            "shortDesc": META["short_desc"],
            "tags": [t.strip() for t in META["tags"].split(",") if t.strip()],
            "referenceSource": META["reference_source"],
            "classification": {
                "type": "portrait",
                "majorStyle": META["classification"]["majorStyle"],
                "style": META["classification"]["style"],
                "subStyle": META["classification"]["style"],
                "method": META["classification"]["method"],
            },
            "ambience": META["ambience"],
        },
        "composition": {
            "overlayType": "rule_of_thirds",
            "aspectRatio": "3:4",
            "opacity": 0.5,
            "description": (
                "竖版 3:4，三分法构图。人物多集中于中下部，不同姿势按其在原场景中的位置自然分布，"
                "空间纵深与暖光氛围作为背景留白，人物作为清晰前景主体。"
            ),
        },
        "pose": [
            {
                "name": POSES[i - 1][1],
                "silhouette": {"type": "image", "data": f"pose{i}_sil.png"},
                "position": {"x": 0.5, "y": 0.55},
                "scale": 1.0,
                "rotation": 0,
                "description": POSES[i - 1][4],
                "cameraDirection": POSES[i - 1][2],
            }
            for i in range(1, N_POSES + 1)
        ],
        "camera": {
            "exposureCompensation": 0.3,
            "isoMode": "auto",
            "iso": 200,
            "shutterSpeed": "1/250",
            "whiteBalance": "shade",
            "whiteBalanceK": 6500,
            "flashMode": "off",
            "focusMode": "auto",
            "lensType": "35mm",
            "lensSuggestion": "main",
        },
        "sceneGuide": {
            "lightDirection": "室内暖调氛围光，暖黄灯源为主光，画面柔和包裹人物，皮肤透亮",
            "shootingDistance": "1.2-2.5m",
            "background": "奢华酒店走廊/客房、黑金法式餐吧、暖黄日式居酒屋三种场景，按姿势分布",
            "props": ["迷你手提包", "手机", "咖啡/餐盘", "陶杯"],
            "bestTime": "室内任意时段（餐厅/酒店/居酒屋夜间氛围更佳）",
            "tips": [
                "穿搭贴场景：小香风配餐吧、毛绒大衣配居酒屋，风格适配才出氛围。",
                "姿势别僵：轻靠墙面、手搭桌沿、拎包抬腿，松弛小动作更自然。",
                "角度随场景：餐吧微俯拍显精致，开阔空间稍低机位衬身形。",
                "暖光下多露穿搭细节与外套质感更出片。",
            ],
        },
        "postProcess": {
            "cropRatio": "3:4",
            "color": {
                "brightness": 3,
                "contrast": 5,
                "saturation": 3,
                "temperature": 4,
                "tint": 4,
                "highlights": -6,
                "shadows": 6,
            },
            "smoothStrength": 12,
            "sharpen": 14,
            "vignette": 8,
            "grain": 12,
            "lut": "warm_film",
        },
    }
    (OUT_DIR / "template.pptpl").write_text(
        json.dumps(pptpl, ensure_ascii=False, indent=2), encoding="utf-8")
    print("已产出 pose_images.json 与 template.pptpl", flush=True)


def main():
    ap = argparse.ArgumentParser(description="多场景万能氛围人像模板生成（防侵权去识别化）")
    ap.add_argument("step", choices=["panels", "poses", "sil", "doc", "all"])
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--source", default="online_templates/_fetch/SMZDM",
                    help="帖子参考图目录")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source_dir = (ROOT / args.source).resolve()

    if args.step == "panels":
        step_panels(source_dir, args.force)
    elif args.step == "poses":
        if step_panels(source_dir, args.force):
            for i in range(1, N_POSES + 1):
                step_pose(i, args.force)
    elif args.step == "sil":
        for i in range(1, N_POSES + 1):
            step_sil(i, args.force)
    elif args.step == "doc":
        write_docs()
    else:  # all
        if step_panels(source_dir, args.force):
            for i in range(1, N_POSES + 1):
                step_pose(i, args.force)
            for i in range(1, N_POSES + 1):
                step_sil(i, args.force)
            write_docs()
    print(f"输出目录: {OUT_DIR}", flush=True)


if __name__ == "__main__":
    main()