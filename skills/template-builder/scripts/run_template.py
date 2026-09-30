#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""模板制作全流程主编排脚本。

流程:
  1. 解析输入: 本地图片 / 网络图片 URL (/ 由 agent 用自带联网工具收集后指路径);
  2. 网格检测: 判断某张图是否为宫格拼图, 若是则拆成多张单图再进入下一步;
  3. 姿势图:
     a. 有真实参考图 -> 调用 反侵权技能(anti-infringement-pose-edit)加工成 N 张干净成片姿势图;
     b. 无参考图    -> 基于 config.poses 的姿势描述 用 hapi 文生图自动补姿势;
  4. 剪影: 对每张姿势图 单独一次 hapi 图生图(SIL_PROMPT) -> 阈值 245 二值化转透明底线稿;
  5. 结构: 产出 pose_images.json + template.pptpl(与后端在线模板同构);
  6. 输出: 全部写入 <parent>/<key>/ (默认 create_templates/<key>)。

运行前提: 环境变量 HAPI_API_KEY(或 --api-key)、config.json(模板结构+姿态描述)。
"""
from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

from PIL import Image

# 项目 scripts/ 提供 gpt_image2; 反侵权技能 scripts/ 提供 crop_grid 检测工具
_ROOT = Path(__file__).resolve().parents[3]                 # project root
_SCRIPTS = _ROOT / "scripts"
_AIE_SCRIPTS = _ROOT / "skills" / "anti-infringement-pose-edit" / "scripts"
for _p in (str(_SCRIPTS), str(_AIE_SCRIPTS)):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import gpt_image2  # noqa: E402

# ---------------------------------------------------------------- 图像工具

def _unipool(img, maxdim: int = 400):
    """按行/整列池化方差: 每行的方差=该行整宽像素方差, 每列=该列整高像素方差。
    网格线是跨全幅的低方差带, 用此信号可在任意 k×k 下可靠定位分割线。"""
    im = img.copy()
    im.thumbnail((maxdim, maxdim))
    gray = im.convert("L")
    w, h = gray.size
    px = gray.load()
    rowvar = [0.0] * h
    for y in range(h):
        vals = [px[x, y] for x in range(w)]
        m = sum(vals) / w
        rowvar[y] = sum((v - m) ** 2 for v in vals) / w
    colvar = [0.0] * w
    for x in range(w):
        vals = [px[x, y] for y in range(h)]
        m = sum(vals) / h
        colvar[x] = sum((v - m) ** 2 for v in vals) / h
    return rowvar, colvar, w, h


def _low_strips(var, scale: float, min_gap: int, length: int) -> list[int]:
    """找低方差条带并返回各自中心(映射到原图坐标)。忽略落到外缘 10% 的条带(外白边/留白)。"""
    mx = max(var) if var else 0.0
    if mx <= 1e-6:
        return []
    thr = mx * 0.15
    strips: list[list[int]] = []
    for i, v in enumerate(var):
        if v <= thr:
            if strips and i - strips[-1][1] <= min_gap:
                strips[-1][1] = i
            else:
                strips.append([i, i])
    lo, hi = 0.10 * length, 0.90 * length
    return [int(round((a + b + 1) / 2 * scale)) for a, b in strips
            if lo < (a + b + 1) / 2 * scale < hi]


def detect_grid_factor(img) -> int:
    """宫格阶数检测: 行/列内部低方差条带数一致且≥1 视为 k×k; 否则单图(1)。"""
    rowvar, colvar, w, h = _unipool(img)
    gap = max(2, min(w, h) // 80)
    col_cuts = _low_strips(colvar, img.width / w, gap, img.width)
    row_cuts = _low_strips(rowvar, img.height / h, gap, img.height)
    ncols, nrows = len(col_cuts) + 1, len(row_cuts) + 1
    if ncols == nrows and 2 <= ncols <= 4:
        return ncols
    return 1


def split_grid(img, factor: int) -> list:
    """按检测到的内部低方差条带把 k×k 宫格拆成单张(读取顺序)。"""
    rowvar, colvar, w, h = _unipool(img)
    gap = max(2, min(w, h) // 80)
    xs = [0] + _low_strips(colvar, img.width / w, gap, img.width) + [img.width]
    ys = [0] + _low_strips(rowvar, img.height / h, gap, img.height) + [img.height]
    cells = []
    for r in range(len(ys) - 1):
        for c in range(len(xs) - 1):
            cells.append(img.crop((xs[c], ys[r], xs[c + 1], ys[r + 1])))
    return cells

# 剪影口径(与后端 AI 一键建模一致)
SIL_PROMPT = (
    "纯白背景上的极简单色人物轮廓线稿插画，用少量平滑线条勾勒参考图中人物的整体姿势和四肢位置，"
    "保留姿势比例与画面位置；只画头、躯干、四肢的大轮廓，禁止绘制发型发丝、五官、眼睛、颈纹、"
    "手部细节、衣物褶皱和任何背景细节，无底色无文字"
)
SIL_THRESHOLD = 245
SIL_BBOX_RATIO = 0.3
SIL_PAD_RATIO = 0.05
SIZE = "768x1024"      # 竖构图(3:4), 与模板 aspectRatio 一致; hapi 需 WxH 像素格式
MAX_TRY = 3
TIMEOUT = 660

# 反侵权技能入口脚本(相对本文件)
ANTI_INFRINGE = _AIE_SCRIPTS / "run_batch_edit.py"


# ---------------------------------------------------------------- 图像工具

def load_tuple(path: str) -> tuple[str, str, bytes]:
    with open(path, "rb") as f:
        data = f.read()
    return (os.path.basename(path), mimetypes.guess_type(path)[0] or "image/png", data)


def decode_item(item: dict, tmp: Path, prefix: str) -> Path:
    b64 = item.get("b64_json")
    if b64:
        p = tmp / f"{prefix}{int(time.time()*1000)}.png"
        p.write_bytes(base64.b64decode(b64))
        return p
    url = item.get("url")
    if url:
        path, _ = gpt_image2.download_to_local(url, str(tmp), prefix)
        return Path(path)
    raise RuntimeError("接口未返回 url/b64_json")


# ---------------------------------------------------------------- 剪影

def binarize_to_transparent(img) -> object:
    gray = img.convert("L")
    alpha = gray.point(lambda v: 255 if v < SIL_THRESHOLD else 0)
    black = Image.new("RGB", img.size, (0, 0, 0))
    rgba = black.convert("RGBA")
    rgba.putalpha(alpha)
    return rgba


def crop_to_content(img, pad: float = SIL_PAD_RATIO) -> object:
    alpha = img.split()[3]
    bbox = alpha.getbbox()
    if not bbox:
        return img
    x0, y0, x1, y1 = bbox
    px = int(max(1, (x1 - x0) * pad))
    py = int(max(1, (y1 - y0) * pad))
    x0 = max(0, x0 - px); y0 = max(0, y0 - py)
    x1 = min(img.width, x1 + px); y1 = min(img.height, y1 + py)
    return img.crop((x0, y0, x1, y1))


# ---------------------------------------------------------------- 生成调用

def make_client(cfg_args) -> tuple:
    pcfg = gpt_image2.PLATFORMS.get(cfg_args.platform, gpt_image2.PLATFORMS["hapi"])
    key = cfg_args.api_key or os.environ.get(pcfg["key_env"], "")
    if not key:
        raise RuntimeError(f"未配置 API Key: 设置环境变量 {pcfg['key_env']} 或使用 --api-key")
    model = cfg_args.model or (pcfg["models"][0] if pcfg.get("models") else "gpt-image-2")
    return gpt_image2.make_client(cfg_args.platform, key, cfg_args.base_url or pcfg["base_url"]), model


def gen_hapi(client, model, prompt, out_dir: Path, label, ref: Path | None = None,
             size: str = SIZE) -> Path | None:
    for attempt in range(1, MAX_TRY + 1):
        tmp = out_dir / "_tmp" / f"{label}_{attempt}_{int(time.time()*1000)}"
        tmp.mkdir(parents=True, exist_ok=True)
        try:
            if ref is not None:
                imgs = [load_tuple(str(ref))]
                status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=TIMEOUT)
            else:
                status, resp = client.generate(model, prompt, size=size, n=1, timeout=TIMEOUT)
        except Exception as e:
            print(f"  [{label}] 尝试{attempt} 异常: {e}", flush=True)
            continue
        if status != 200 or not resp.get("data"):
            print(f"  [{label}] 尝试{attempt} HTTP {status}: {resp}", flush=True)
            time.sleep(2)
            continue
        out = decode_item(resp["data"][0], tmp, f"{label}_")
        final = out_dir / out.name
        shutil.move(str(out), final)
        print(f"  [{label}] -> {final.name}", flush=True)
        return final
    return None


def gen_silhouette(client, model, pose_path: Path, out_dir: Path) -> Path | None:
    from PIL import Image
    final = out_dir / f"{pose_path.stem}_sil.png"
    raw = gen_hapi(client, model, SIL_PROMPT, out_dir / "_sil_raw", "sil",
                   ref=pose_path, size=SIZE)
    if not raw:
        return None
    with Image.open(raw) as im:
        im = im.convert("RGB")
        sil = crop_to_content(binarize_to_transparent(im))
        sil.save(final)
        print(f"  剪影 -> {final.name} {final.stat().st_size//1024}KB", flush=True)
    return final


def run_anti_infringement(pose_sources: list[str], work: Path, api_key: str = "") -> list[Path] | None:
    """调用反侵权技能加工真实参考姿势图, 返回 N 张成片(按输入顺序)。"""
    tmp = work / "_anti_infringe"
    tmp.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, str(ANTI_INFRINGE), *pose_sources, "--out", str(tmp)]
    if api_key:
        cmd += ["--api-key", api_key]
    r = subprocess.run(cmd, capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=900)
    if r.returncode != 0:
        print(f"  [反侵权] 失败 exit={r.returncode}: {(r.stderr or r.stdout)[-400:]}", flush=True)
        return None
    outs = sorted(tmp.glob("out*.png"), key=lambda p: int(p.stem[3:]))
    if not outs:
        # 可能用 r 前缀(单图回退), 尝试宽松取值
        outs = sorted(tmp.glob("*.png"), key=lambda p: p.stat().st_mtime)
    print(f"  [反侵权] 得到 {len(outs)} 张成片", flush=True)
    return outs


# ---------------------------------------------------------------- 文档

def write_docs(cfg: dict, out_dir: Path, poses: list[dict]) -> None:
    mapping = {p["name"]: f"pose{i}.png" for i, p in enumerate(poses, 1)}
    (out_dir / "pose_images.json").write_text(json.dumps(mapping, ensure_ascii=False, indent=2),
                                              encoding="utf-8")
    pptpl = {
        "format": "pptpl", "version": "1.0.0",
        "_meta": {
            "name": cfg.get("name"), "author": "Lumira", "category": "portrait",
            "price": 0, "description": cfg.get("description"), "shortDesc": cfg.get("short_desc"),
            "tags": cfg.get("tags") or [],
            "referenceSource": cfg.get("reference_source", ""),
            "classification": cfg.get("classification", {}),
            "ambience": cfg.get("ambience", {}),
        },
        "composition": {"overlayType": "rule_of_thirds", "aspectRatio": "3:4", "opacity": 0.5,
                        "description": cfg.get("composition_description", "")},
        "pose": [
            {"name": p["name"], "silhouette": {"type": "image", "data": f"pose{i}_sil.png"},
             "position": {"x": 0.5, "y": 0.55}, "scale": 1.0, "rotation": 0,
             "description": p.get("description", ""), "cameraDirection": "back"}
            for i, p in enumerate(poses, 1)
        ],
        "camera": cfg.get("camera") or {
            "exposureCompensation": 0.3, "isoMode": "auto", "iso": 200, "shutterSpeed": "1/500",
            "whiteBalance": "daylight", "whiteBalanceK": 5600, "flashMode": "off",
            "focusMode": "auto", "lensType": "26mm", "lensSuggestion": "main"},
        "sceneGuide": cfg.get("scene_guide"),
        "postProcess": cfg.get("post_process"),
    }
    (out_dir / "template.pptpl").write_text(json.dumps(pptpl, ensure_ascii=False, indent=2),
                                            encoding="utf-8")


# ---------------------------------------------------------------- 主流程

def resolve_inputs(args, work: Path) -> list[Path]:
    """把输入(本地路径/URL)统一解析为本地图片文件, 并按顺序返回。"""
    out = []
    import requests
    for i, item in enumerate(args.inputs, 1):
        if item.startswith(("http://", "https://")):
            r = requests.get(item, timeout=60)
            r.raise_for_status()
            ct = (r.headers.get("content-type") or "image/png").split(";")[0].split("/")[-1]
            ext = ".png" if ct == "png" else ".jpg"
            p = work / "_refs" / f"in{i}{ext}"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(r.content)
            out.append(p)
            print(f"  下载 {item} -> {p.name}", flush=True)
        else:
            out.append(Path(item))
    return out


def _grid_split_all(paths: list[Path]) -> list[Path]:
    """对每张图做网格检测; 宫格则拆成多张单图, 单图原样。返回统一后的姿势图集合。"""
    from PIL import Image
    result: list[Path] = []
    for i, p in enumerate(paths, 1):
        with Image.open(p) as im:
            im = im.convert("RGB")
            factor = detect_grid_factor(im)
            if factor > 1:
                cells = split_grid(im, factor)
                print(f"  {p.name} 识别为 {factor}x{factor} 宫格, 拆成 {len(cells)} 张", flush=True)
                for j, cell in enumerate(cells, 1):
                    cell = cell.convert("RGB")
                    op = p.parent / f"panel_{i}_{j}.png"
                    cell.save(op)
                    result.append(op)
            else:
                print(f"  {p.name} 视为单图", flush=True)
                result.append(p)
    return result


def main() -> int:
    ap = argparse.ArgumentParser(description="模板制作全流程")
    ap.add_argument("--key", required=True, help="模板 slug, 用于输出目录 create_templates/<key>")
    ap.add_argument("--cfg", default=None, help="config.json(模板结构+姿势描述), dry-run 可省略")
    ap.add_argument("--inputs", nargs="*", default=[], help="本地图片路径或 http(s) 图片 URL")
    ap.add_argument("--count", type=int, default=0, help="指定姿势数量(仅自动补姿势时强制)")
    ap.add_argument("--auto-gen", action="store_true",
                    help="无参考图时用文生图自动补姿势(基于 cfg.poses 的姿势描述)")
    ap.add_argument("--skip-anti-infringement", action="store_true",
                    help="有参考图时不走反侵权加工(直接当最终成片)")
    ap.add_argument("--no-split", action="store_true",
                    help="跳过宫格检测(输入已是逐张单图时使用, 避免纯色单图被误判拆分)")
    ap.add_argument("--parent", default="create_templates", help="输出父目录(默认 create_templates)")
    ap.add_argument("--platform", default="hapi", choices=list(gpt_image2.PLATFORMS))
    ap.add_argument("--model", default=None)
    ap.add_argument("--api-key", default=None)
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if args.dry_run:
        print(f"[dry-run] key={args.key} 输出={Path(args.parent)/args.key} "
              f"count={args.count} inputs={len(args.inputs)} auto_gen={args.auto_gen}")
        return 0

    cfg = json.loads(Path(args.cfg).read_text(encoding="utf-8"))
    out_dir = Path(args.parent) / args.key
    pose_count = args.count
    if pose_count <= 0:
        pose_count = len(cfg.get("poses", []))
    if pose_count <= 0:
        print("[错误] --count 或 cfg.poses 为空", file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "_refs").mkdir(exist_ok=True)
    (out_dir / "_sil_raw").mkdir(exist_ok=True)

    try:
        client, model = make_client(args)
    except RuntimeError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1

    # 1) 输入
    refs = resolve_inputs(args, out_dir)
    if refs:
        if args.no_split:
            pose_sources = refs
            print(f"  [输入] 跳过宫格检测, {len(refs)} 张单图", flush=True)
        else:
            pose_sources = _grid_split_all(refs)
    else:
        pose_sources = []

    # 2) 姿势图: 有参考图->反侵权加工; 无参考图->文生图补
    final_poses: list[Path] = []
    if pose_sources:
        if args.skip_anti_infringement:
            final_poses = pose_sources[:pose_count]
            print(f"  [姿势] 跳过反侵权, 直接用 {len(final_poses)} 张", flush=True)
        else:
            print("  [姿势] 真实参考图 -> 反侵权加工…", flush=True)
            key = args.api_key or os.environ.get(
                gpt_image2.PLATFORMS.get(args.platform, gpt_image2.PLATFORMS["hapi"]).get("key_env", ""), "")
            done = run_anti_infringement([str(p) for p in pose_sources], out_dir, key)
            if done:
                final_poses = done[:pose_count]
            else:
                print("  !! 反侵权加工失败, 退回用原始图", flush=True)
                final_poses = pose_sources[:pose_count]
    elif args.auto_gen:
        print(f"  [姿势] 无参考图 -> 文生图自动补 {pose_count} 张…", flush=True)
        style = cfg.get("style_prompt", "")
        for i in range(pose_count):
            desc = cfg["poses"][i].get("description", "")
            prompt = f"{style}。姿势动作:{desc}。写实全身人像, 3:4竖构图, 保留皮肤毛孔与真实质感。"
            p = gen_hapi(client, model, prompt, out_dir, f"pose{i+1}")
            if p:
                final_poses.append(p)
    else:
        print("[错误] 无参考图且未开 --auto-gen", file=sys.stderr)
        return 1

    if not final_poses:
        print("[错误] 未得到任何姿势图", file=sys.stderr)
        return 1

    # 统一命名 pose1..poseN.png
    for i, src in enumerate(final_poses, 1):
        dst = out_dir / f"pose{i}.png"
        if src.resolve() != dst.resolve():
            shutil.move(str(src), str(dst))
        final_poses[i - 1] = dst

    n = len(final_poses)
    print(f"\n[姿势图] 共 {n} 张:", [p.name for p in final_poses], flush=True)

    # 3) 剪影(逐个生成, 保证质量与姿势一致)
    print("\n[剪影] 逐张生成…", flush=True)
    for i, pose in enumerate(final_poses, 1):
        gen_silhouette(client, model, pose, out_dir)

    # 4) 文档
    poses_cfg = cfg.get("poses", [])[:n]
    # 姿势名缺省用 poseN
    if len(poses_cfg) < n:
        poses_cfg = poses_cfg + [{"name": f"pose{i}", "description": ""} for i in
                                 range(len(poses_cfg) + 1, n + 1)]
    write_docs(cfg, out_dir, poses_cfg)
    print(f"\n[完成] 模板产物在 {out_dir.resolve()}", flush=True)
    for f in sorted(out_dir.glob("pose*.png")) + [out_dir / "pose_images.json",
                                                  out_dir / "template.pptpl"]:
        if f.exists():
            print(f"  - {f.name}", flush=True)
    return 0


if __name__ == "__main__":
    main()