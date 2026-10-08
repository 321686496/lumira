#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""人物一致性姿势图生成。

用途: 让一组姿势参考图中的人物保持「同一张脸 + 同一套衣服」。
做法:
  1) 锚点图: 取一张参考图做单图编辑 -> 换成全新面孔(防侵权), 衣着沿用原图, 作为「角色锚点」;
  2) 每张姿势: 用 [姿势参考图, 角色锚点图] 双图编辑 -> 保留图1的姿势/机位/构图/场景,
     人物的脸与全身衣着完全照搬图2。

复用 scripts/gpt_image2.py 的图生图接口(HAPI: image[] 多图编辑)。
"""
from __future__ import annotations

import argparse
import base64
import io
import os
import shutil
import sys
import time
from pathlib import Path

from PIL import Image

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT / "scripts") not in sys.path:
    sys.path.insert(0, str(_ROOT / "scripts"))

import gpt_image2  # noqa: E402

MAX_TRY = 3
TIMEOUT = 660
REF_Q = 82


def load_tuple(path: str, box=(768, 1024)) -> tuple:
    """参考图统一缩放并压成 JPEG(避免大体积 base64 触发上游超时)。"""
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail(box)
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=REF_Q)
    return (os.path.basename(path), "image/jpeg", buf.getvalue())


def decode_item(item: dict, out_dir: Path, prefix: str) -> Path:
    b64 = item.get("b64_json")
    if b64:
        p = out_dir / f"{prefix}.png"
        p.write_bytes(base64.b64decode(b64))
        return p
    url = item.get("url")
    if url:
        path, _ = gpt_image2.download_to_local(url, str(out_dir), prefix)
        return Path(path)
    raise RuntimeError("接口未返回 url/b64_json")


def edit(client, model, prompt, imgs, out_path: Path, size: str):
    raw_dir = out_path.parent / "_raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    for attempt in range(1, MAX_TRY + 1):
        try:
            status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=TIMEOUT)
        except Exception as e:  # noqa: BLE001
            print(f"  [{out_path.stem}] 尝试{attempt} 异常: {e}", flush=True)
            continue
        if status != 200 or not resp.get("data"):
            print(f"  [{out_path.stem}] 尝试{attempt} HTTP {status}: {str(resp)[:300]}", flush=True)
            time.sleep(2)
            continue
        p = decode_item(resp["data"][0], raw_dir, f"{out_path.stem}_{int(time.time()*1000)}")
        shutil.move(str(p), str(out_path))
        print(f"  [{out_path.stem}] -> {out_path.name} {out_path.stat().st_size//1024}KB", flush=True)
        return out_path
    print(f"  [{out_path.stem}] 全部尝试失败", flush=True)
    return None


def anchor_prompt(face: str) -> str:
    return (
        "这是一张人物照片。请严格保留原图中的姿势动作、机位、构图、场景、光线与整套衣着，"
        f"只把人物的面孔替换成一张全新的脸：{face}，使其完全看不出与原图是同一个人，以避免侵权。"
        "除面部与发型外，姿势、衣着、场景、构图、光线必须与原图保持一致。"
        "输出写实全身人像照片，3:4 竖构图，画面中不要出现任何文字、水印、贴纸或字幕。"
    )


def consist_prompt(outfit: str) -> str:
    return (
        "图1是姿势与场景参考图，图2是人物身份参考图。"
        "请以图1为准：严格保留图1中人物的姿势动作、机位、构图、场景、道具、光线与画面比例。"
        "同时以图2为准：输出中人物的面部特征、发型、身材比例与全身衣着必须与图2完全一致，"
        f"衣着为：{outfit}。"
        "最终画面必须是「图2的同一张脸、同一套衣服」出现在「图1的姿势与场景」中。"
        "写实全身人像照片，3:4 竖构图，画面中不要出现任何文字、水印、贴纸或字幕。"
    )


def main() -> int:
    ap = argparse.ArgumentParser(description="人物一致性姿势图生成")
    ap.add_argument("--poses", nargs="+", required=True, help="姿势参考图(按输出顺序)")
    ap.add_argument("--out", required=True, help="输出目录")
    ap.add_argument("--anchor-name", default="anchor", help="锚点图文件名(不含扩展名)")
    ap.add_argument("--anchor-index", type=int, default=0, help="用第几张参考图生成锚点(0 基)")
    ap.add_argument("--face", default="一位五官精致、有辨识度的亚洲男性，二十多岁，短黑发",
                    help="新面孔描述")
    ap.add_argument("--outfit", default="", help="统一衣着描述(透传给双图编辑提示词)")
    ap.add_argument("--engine", default="gpt2k", choices=list(gpt_image2.ENGINES))
    ap.add_argument("--size", default="768x1024")
    ap.add_argument("--only", type=int, default=0, help="只处理第 N 张(1 基), 复用已有锚点, 便于验证")
    ap.add_argument("--skip-anchor", action="store_true", help="复用已存在的锚点图")
    ap.add_argument("--api-key", default=None)
    args = ap.parse_args()

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    eng = gpt_image2.resolve_engine(args.engine)
    pcfg = gpt_image2.PLATFORMS[eng["platform"]]
    key = args.api_key or os.environ.get(pcfg["key_env"], "")
    if not key:
        print(f"[错误] 未配置 {pcfg['key_env']}", file=sys.stderr)
        return 1
    client = gpt_image2.make_client(eng["platform"], key, pcfg["base_url"])
    model = eng["model"]
    print(f"[引擎] {eng['platform']}/{model}  size={args.size}", flush=True)

    poses = [Path(p) for p in args.poses]
    anchor_path = out_dir / f"{args.anchor_name}.png"

    # 1) 锚点
    if args.skip_anchor and anchor_path.exists():
        print(f"[锚点] 复用 {anchor_path.name}", flush=True)
    else:
        src = poses[args.anchor_index]
        print(f"[锚点] 由 {src.name} 生成…", flush=True)
        r = edit(client, model, anchor_prompt(args.face),
                 [load_tuple(str(src))], anchor_path, args.size)
        if not r:
            print("[错误] 锚点生成失败", file=sys.stderr)
            return 1

    # 2) 逐张姿势
    anchor_img = load_tuple(str(anchor_path))
    proc = [args.only - 1] if args.only else range(len(poses))
    ok, fail = 0, []
    for i in proc:
        dst = out_dir / f"pose{i+1}.png"
        print(f"[姿势 {i+1}/{len(poses)}] {poses[i].name} …", flush=True)
        r = edit(client, model, consist_prompt(args.outfit),
                 [load_tuple(str(poses[i])), anchor_img], dst, args.size)
        if r:
            ok += 1
            with Image.open(r) as im:
                print(f"    size={im.size[0]}x{im.size[1]}", flush=True)
        else:
            fail.append(i + 1)

    print(f"\n[完成] 成功 {ok} 张, 失败 {fail}", flush=True)
    return 0 if not fail else 2


if __name__ == "__main__":
    raise SystemExit(main())