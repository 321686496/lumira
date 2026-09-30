#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""线上模板生产：樱花和服扇影人像（由小红书「和服 - KIKI」笔记整理，6 姿势）。

防侵权处理：
  - 姿势演示图（pose*.png）以原图整格为 i2i 底图，锁定"姿势/和服装扮/场景/光线/机位"，
    但提示词显式要求把人脸替换为"一张不同的、非本参考图的亚洲女性通用面容"，
    不复刻原图人物五官与身份（去识别化，规避肖像权）。
  - 剪影图（pose*_sil.png）由姿势图经"白底黑线稿+本地二值化"生成，仅保留通用动作轮廓，
    天然不包含肖像细节，用于覆盖用户照片。

平台分工：
  - 姿势演示图 / 剪影图 → HAPI (gpt_image2.py, gpt-image-2)
  - （本模板无边锚点/无关图片，故无需 MaaS；预留 MASS_SCRIPT 供后续扩展）

流程：
  panels -> poses(6) -> sil(6) -> doc
  断点续跑：目标文件存在且非空即跳过；--force 强制重生成。
"""
import argparse
import io
import json
import subprocess
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

SCRIPT_DIR = Path(__file__).resolve().parent
ROOT = SCRIPT_DIR.parent
KEY = "04_kimono_kiki"
OUT_DIR = ROOT / "online_templates" / KEY
HAPI_SCRIPT = SCRIPT_DIR / "gpt_image2.py"
MASS_SCRIPT = SCRIPT_DIR / "gen_image.py"

BACKEND = "maas"            # hapi 额尽, 用 MaaS；可用 "hapi"/"maas"
HAPI_KEY = "sk-8d0149c3e8dbf782ed1356b0be5e25579121eef8326c29db64884786bdf959df"
HAPI_MODEL = "gpt-image-2"
MASS_MODEL = "qwen-image-3.0-pro"
P_SIZE = "3:4"          # 与模板 aspectRatio 一致
MAX_TRY = 3
CALL_TIMEOUT = 660

N_POSES = 6

SIL_PROMPT = (
    "纯白背景上的极简单色人物轮廓线稿插画，用少量平滑线条勾勒参考图中人物的整体姿势和四肢位置，"
    "保留姿势比例与画面位置；只画头、躯干、四肢的大轮廓，禁止绘制发型发丝、五官、眼睛、颈纹、"
    "手部细节、衣物褶皱和任何背景细节，无底色无文字"
)
SIL_THRESHOLD = 245
SIL_BBOX_THRESHOLD = 0.3
SIL_BBOX_PAD_RATIO = 0.05

# 以原图整格为底图的「提质+去识别化」提示词：锁定姿势/服装/场景，换一张通用面容防侵权
REFINE_PROMPT = (
    "以参考图为准重绘这张和服人像：严格保持参考图中人物的姿势动作、同一套和服"
    "（浅粉色樱花仙鹤纹和服、粉意腰带/白色太鼓结、发髻与粉色花卉发饰）、同一日式和风室内场景"
    "（榻榻米、障子门、仿真樱花树、灯笼）、同一光线方向与同一机位与构图，以上任何一项都不得改变。"
    "此外必须把参考图中的人脸替换为一张不同的、非本参考图的亚洲女性通用面容：五官、脸型、发型"
    "完全重新生成一张普通年轻女生样貌，禁止复刻参考图人物的五官与长相，禁止出现与原图同一张脸。"
    "把它变成真实相机直出的高清和服写真：3:4竖构图，室内暖调柔光，和服面料保留真实物理质感"
    "（丝绸光泽、樱花与仙鹤纹样清晰、腰带褶皱、发饰细节），皮肤保留真实纹理，轻微胶片颗粒。"
    "禁止磨皮与塑料感，禁止CG或3D渲染感，禁止插画感与过度锐化，禁止完美对称的网红脸，"
    "禁止改变人物姿势、和服、场景与构图，禁止添加文字水印。"
)

POSES = [
    {
        "name": "封面·扇遮面斜坐",
        "description": (
            "人物侧身斜坐在榻榻米上，身体朝向屏幕左侧约四分之三角度、背部稍对镜头，双腿向左侧斜伸"
            "其中一腿伸直一腿屈膝收起，左手撑在身后榻榻米上微微后仰支撑，右手举到面前持一把展开的"
            "粉紫渐变折扇半遮面，扇面靠近一侧脸颊与眼睛，另一侧眼睛与眉目露于扇外，视线含蓄地下垂，"
            "发髻高挽配粉色花卉发饰"
        ),
    },
    {
        "name": "跪坐执扇弈棋",
        "description": (
            "人物跪坐(双腿并拢跪在榻榻米上、脚背贴地)于围棋矮盘前，上身挺直微侧、背部稍对镜头，"
            "左手举到侧脸旁持一把半开的粉紫渐变折扇半掩侧脸，右手轻轻抬起悬于棋盘上方做落子前的"
            "停顿动作，发髻高挽插粉色花朵发饰，姿态端庄含蓄"
        ),
    },
    {
        "name": "背坐赏樱",
        "description": (
            "人物完全背对镜头跪坐在榻榻米上，双膝并拢脚背贴地、上身挺直，头部微仰朝向右上方的"
            "樱花树枝，双手自然放于大腿前或身前，发髻高挽插白色百合与粉色小花发饰，背景是仿真樱花树、"
            "障子门与茶具，呈现宁静的赏花姿态"
        ),
    },
    {
        "name": "背坐攀枝",
        "description": (
            "人物背对镜头跪坐在榻榻米上，上身微微侧转向画面左侧，右臂向上高高举起、右手轻触攀折几枝"
            "探入画面的樱花枝，左臂自然垂落或扶在膝上，头微转向侧上方望向右手与花朵，发髻高挽配花卉发饰"
        ),
    },
    {
        "name": "持机自拍",
        "description": (
            "人物半侧面站立/坐姿，手持一部手机举到面前做近距自拍姿势，头部微低并向画面一侧侧转约30度，"
            "视线向下看向手机屏幕，肩部自然放松，发髻高挽配粉色花卉发饰，身穿樱花纹浅粉和服"
        ),
    },
    {
        "name": "背坐横刀",
        "description": (
            "人物背对镜头跪坐，双膝并拢脚背贴地、上身挺直微侧，双臂向身体两侧平伸、双手握持一柄"
            "长刀横架于肩后，刀身横过肩背，头部微低视线朝下，和服肩部滑落露出后颈与部分肩背，"
            "腰间系白色太鼓结，发髻插白色百合与粉色垂坠花饰，呈现蓄势安静的姬武者姿态"
        ),
    },
]

# ---------------- 元信息 ----------------
META = {
    "name": "樱花和服扇影人像",
    "short_desc": "一扇一花，把春日樱花季穿在身上",
    "description": (
        "写实日式和风樱花季人像。暖调室内和风空间，榻榻米铺地，仿真樱花树缀满粉白瓣朵、"
        "障子门透出暖光、点缀灯笼与茶具，浅粉樱花仙鹤纹和服、粉意腰带与白色太鼓结，发髻高挽插花簪。"
        "人物或执扇遮面、或跪坐弈棋、或背坐赏樱攀枝、或横刀架肩，姿态端庄含蓄、含情脉脉，"
        "画面暖粉柔和、电影质感。适合和风写真、樱花季体验、室内古风等场景，人物肢体与情绪"
        "入画自然，氛围治愈唯美。"
    ),
    "tags": "人像, 和服, 樱花, 和风, 写真, 春季",
    "reference_source": "小红书「和服 - KIKI」和风樱花写真姿势合集",
    "classification": {
        "majorStyle": "hanfu_kimono",
        "style": "sakura_kimono",
        "method": "",
    },
    "ambience": {
        "seasons": ["spring"],
        "weathers": ["sunny", "cloudy"],
        "timeTones": ["day", "warm"],
    },
}


# ---------------- 工具 ----------------
def tdir():
    d = OUT_DIR / "_refs" / "_tmp" / str(int(time.time() * 1000))
    d.mkdir(parents=True, exist_ok=True)
    return d


def newest_png(d: Path):
    pngs = sorted(d.glob("*.png"), key=lambda p: p.stat().st_mtime)
    return pngs[-1] if pngs else None


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


def gen_hapi(prompt: str, out_dir: Path, label: str, ref: Path = None, fidelity: str = None):
    variants = [["--input-fidelity", fidelity] if fidelity else [], []]
    if not fidelity:
        variants = [[]]
    for extra in variants:
        for attempt in range(1, MAX_TRY + 1):
            tmp = tdir()
            cmd = [sys.executable, str(HAPI_SCRIPT), prompt,
                   "--platform", "hapi", "--model", HAPI_MODEL, "--size", P_SIZE,
                   "--out", str(tmp), "--api-key", HAPI_KEY, "--timeout", str(CALL_TIMEOUT)]
            cmd += extra
            if ref is not None:
                cmd += ["--image", str(ref), "--once"]
            print(f"   [{label}] hapi 尝试 {attempt}/{MAX_TRY}"
                  f"{' fidelity=' + str(fidelity) if extra else ''}", flush=True)
            f = run_cmd(cmd, tmp, label)
            if f:
                return f
            time.sleep(3)
    return None


def gen_maas(prompt: str, out_dir: Path, label: str, ref: Path = None):
    """MaaS 图生图（本地参考图转 data URL），支持 asynchronously poll"""
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


def gen_image(prompt: str, out_dir: Path, label: str, ref: Path = None, fidelity: str = None):
    """按 BACKEND 分流的统一生成入口"""
    if BACKEND == "hapi":
        return gen_hapi(prompt, out_dir, label, ref, fidelity)
    return gen_maas(prompt, out_dir, label, ref)


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


# ---------------- 步骤 ----------------
def step_panels(source_dir: Path, force: bool = False):
    """把下载的 6 张小红书原图复制为 panel1..6，作为 6 个姿势的 i2i 底图"""
    refs = OUT_DIR / "_refs"
    refs.mkdir(parents=True, exist_ok=True)
    imgs = sorted(source_dir.glob("*.webp")) + sorted(source_dir.glob("*.png"))
    imgs = [p for p in imgs if p.suffix.lower() in (".webp", ".png")]
    if len(imgs) < N_POSES:
        print(f"!! 参考图不足: 需要 {N_POSES} 张, 找到 {len(imgs)}", flush=True)
        return False
    for i in range(1, N_POSES + 1):
        target = refs / f"panel{i}.png"
        if valid(target) and not force:
            continue
        im = Image.open(imgs[i - 1]).convert("RGB")
        im.save(target)
        print(f"panel{i} -> {target.name} {target.stat().st_size // 1024}KB", flush=True)
    return True


def pose_prompt(pose: dict) -> str:
    """通用提质+去识别化提示词，并追加该姿势的关键道具/动作，弥补 MaaS 姿势保持精度。"""
    return (
        "以参考图为基准重绘这张和服人像：严格保持参考图中人物的姿势动作与四肢位置、同一套和服"
        "（浅粉色樱花仙鹤纹和服、粉意腰带、白色太鼓结、发髻配粉色花卉发饰）、同一日式和风室内场景"
        "（榻榻米、障子门、仿真樱花树、纸灯笼）、同一光线方向与同一机位与构图，以上任何一项都不得改变。"
        f"本姿势关键动作与道具，务必如实还原：{pose['description']}"
        "此外必须把参考图中的人脸替换为一张不同的、非本参考图的亚洲女性通用面容：五官、脸型、发型"
        "完全重新生成一张普通年轻女生样貌，禁止复刻参考图人物的五官与长相，禁止出现与原图同一张脸。"
        "把它变成真实相机直出的高清和服写真：3:4竖构图，室内暖调柔光，和服面料保留真实物理质感"
        "（丝绸光泽、樱花与仙鹤纹样清晰、腰带褶皱、发饰细节），皮肤保留真实纹理，轻微胶片颗粒。"
        "禁止磨皮与塑料感，禁止CG或3D渲染感，禁止插画感与过度锐化，禁止完美对称的网红脸，"
        "禁止改变人物姿势、和服、场景与构图，禁止添加文字水印。"
    )


def step_pose(idx: int, force: bool) -> bool:
    target = OUT_DIR / f"pose{idx}.png"
    if valid(target) and not force:
        print(f"跳过 pose{idx}（已存在）", flush=True)
        return True
    ref = OUT_DIR / "_refs" / f"panel{idx}.png"
    if not valid(ref):
        print(f"!! panel{idx}.png 缺失", flush=True)
        return False
    p = POSES[idx - 1]
    print(f"生成 pose{idx} · {p['name']}（{BACKEND} 提质+去识别化）…", flush=True)
    f = gen_image(pose_prompt(p), OUT_DIR, f"pose{idx} {p['name']}",
                  ref=ref, fidelity="high")
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
    print(f"生成 pose{idx} 剪影（{BACKEND} 白底黑线稿 + 本地二值化）…", flush=True)
    raw = gen_image(SIL_PROMPT, OUT_DIR, f"pose{idx} 剪影", ref=src, fidelity="high")
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
    mapping = {p["name"]: f"pose{i}.png" for i, p in enumerate(POSES, 1)}
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
                "竖版 3:4，三分法构图。人物全身/半身置于画面中下部，top 部保留樱花树与障子门的留白；"
                "榻榻米水平线放在画面下 1/3 处，人物作为前景与和风道具形成前后景层次。"
            ),
        },
        "pose": [
            {
                "name": p["name"],
                "silhouette": {"type": "image", "data": f"pose{i}_sil.png"},
                "position": {"x": 0.5, "y": 0.55},
                "scale": 1.0,
                "rotation": 0,
                "description": p["description"],
                "cameraDirection": "back",
            }
            for i, p in enumerate(POSES, 1)
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
            "lensType": "26mm",
            "lensSuggestion": "main",
        },
        "sceneGuide": {
            "lightDirection": "室内暖调柔光，主光来自画面前上方，经障子门与纸灯柔化，人物面部与和服受光均匀，光比约 2:1，整体暖粉色调、皮肤透亮",
            "shootingDistance": "1.5-2.5m",
            "background": "榻榻米地面、障子木格纸门、仿真樱花树、暖色纸灯笼与茶具/围棋盘等和风道具；避免杂乱杂物与人群",
            "props": ["粉紫折扇", "樱花枝", "围棋盘", "长刀", "茶具"],
            "bestTime": "日间室内自然光（阴天/室内布灯均可）",
            "tips": [
                "用暖光（低色温）让和服樱粉色调更温润柔和。",
                "人物落到榻榻米中线并留出身后樱花树，避免与盆栽轮廓重叠。",
                "扇遮面时对焦眼睛一侧，保证露出的眉眼清晰锐利。",
                "跪坐/正坐时稍微侧身，让和服腰带与太鼓结形成好看的立体层次。",
                "发簪花簇与樱花树同向摆放，让人与景的'花'遥相呼应更出片。",
            ],
        },
        "postProcess": {
            "cropRatio": "3:4",
            "color": {
                "brightness": 5,
                "contrast": 6,
                "saturation": 4,
                "temperature": 4,
                "tint": 6,
                "highlights": -10,
                "shadows": 8,
            },
            "smoothStrength": 14,
            "sharpen": 16,
            "vignette": 10,
            "grain": 12,
            "lut": "warm_film",
        },
    }
    (OUT_DIR / "template.pptpl").write_text(
        json.dumps(pptpl, ensure_ascii=False, indent=2), encoding="utf-8")
    print("已产出 pose_images.json 与 template.pptpl", flush=True)


def main():
    ap = argparse.ArgumentParser(description="樱花和服扇影人像模板生成（防侵权去识别化）")
    ap.add_argument("step", choices=["panels", "poses", "sil", "doc", "all"])
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--source", default="online_templates/_fetch/KIKI",
                    help="参考图目录，内含 img1..6.webp")
    args = ap.parse_args()

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    source_dir = Path(args.source)

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