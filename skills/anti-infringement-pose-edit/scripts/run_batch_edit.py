#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""姿势图反侵权批量编辑编排器。

流程:
  1. 读取 N 张输入图(保持顺序);
  2. 按 `--max-per-call`(默认4)分批, 批次串行;
     - 第一批: 最多 `max_per_call` 张目标图(无锚点);
     - 后续批: 每批 `max_per_call-1` 张目标图 + 追加 1 张"衣着锚点"(第一批首张成片), 用于统一衣着;
  3. 每批把目标图(及锚点参考图)通过 gpt_image2.py 的 hapi 图生图接口一次发出,
     要求模型把每张的修改结果按 2x2 四宫格排成一张图;
  4. 用 crop_grid.py 识别裁剪四宫格 → 得到各单张成片;
  5. 裁不干净/空白的格 → 对该目标图单独跑一次单图编辑兜底;
  6. 输出与输入顺序对齐的单张成片到 --out。

运行前提: 环境变量 HAPI_API_KEY(或 --api-key) 已配置。
"""
from __future__ import annotations

import argparse
import base64
import mimetypes
import os
import shutil
import sys
import tempfile
import time

from PIL import Image

from crop_grid import crop_grid

# 让本项目 scripts/ 下的 gpt_image2 可导入
_SCRIPTS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                         os.pardir, os.pardir, os.pardir, "scripts"))
if _SCRIPTS not in sys.path:
    sys.path.insert(0, _SCRIPTS)

import gpt_image2  # noqa: E402

# 默认编辑提示词(用户给定)
BASE_PROMPT = (
    "修改一下这些图中人物的面部，变得更精致、更帅气美丽、有辨识度；"
    "优化衣着，使其更时髦有质感、贴合场景，同时风格统一、配色协调；"
    "仅修改人物面部与衣着，使其完全看不出与原图是同一个人，以避免侵权；"
    "并统一这几张图中人物的衣着。"
)
# 多图打包成 2x2 四宫格的指令
GRID_SUFFIX = (
    "请将每张输入图的修改结果，按2x2四宫格整齐排列为一张输出图"
    "（顺序：左上、右上、左下、右下，与输入顺序一致），四格之间留清晰边框/分隔线，便于拆分。"
    "人物保持原姿势与构图，仅修改面部与衣着。"
)
# 追加锚点参考图的说明(锚点放在图片列表末尾, 不渲染进网格)
ANCHOR_NOTE = (
    "注意：本次输入的最后一张图是「衣着锚点参考图」，仅用于参考其服饰的颜色/款式/整体风格，"
    "以便统一本批人物衣着；请勿把它作为待修改图渲染进网格，网格中只需输出本批次目标图的修改结果。"
)
# 单图(兜底重绘)提示词
SINGLE_PROMPT = (
    "修改一下这张图中人物的面部，变得更精致、更帅气美丽、有辨识度；"
    "优化衣着，使其更时髦有质感、贴合场景，同时风格统一、配色协调；"
    "仅修改人物面部与衣着，使其完全看不出与原图是同一个人，以避免侵权。"
    "直接输出这张修改后的单张人物照片，保持原姿势与构图。"
)


def parse_ratio(s: str) -> float:
    """解析比例描述为宽高比 w/h。支持 '3:4' / '3/4' / '3x4' / '0.75'。"""
    s = str(s).strip().lower()
    import re
    m = re.match(r"^([\d.]+)\s*[:/x]\s*([\d.]+)$", s)
    if m:
        return float(m.group(1)) / float(m.group(2))
    m = re.match(r"^([\d.]+)$", s)
    if m:
        return float(m.group(1))
    raise ValueError(f"无法识别的比例: {s} (可用 3:4 / 3/4 / 3x4 / 0.75)")


def infer_ratio(paths: list[str]) -> float | None:
    """从输入图推断目标比例: 全部一致→该比例; 不一致→占比最多的比例; 读不出→None。"""
    ratios: list[float] = []
    for p in paths:
        try:
            with Image.open(p) as im:
                w, h = im.size
            if w and h:
                ratios.append(w / h)
        except Exception:
            continue
    if not ratios:
        return None
    ref = ratios[0]
    if all(abs(r - ref) / max(ref, 1e-9) < 0.02 for r in ratios):
        return ref
    # 不一致: 取占比最多(round 到千分位)
    from collections import Counter
    best, bestn = None, -1
    for k, v in Counter(round(r, 3) for r in ratios).items():
        if v > bestn:
            best, bestn = k, v
    return float(best)


def ratio_to_grid_size(r: float, base: int = 1024) -> str:
    """按宽高比给出 2x2 宫格的输出尺寸(短边 ~base, 保持比例, 不强制方形)。"""
    r = max(r, 1e-6)
    if r >= 1:  # 横向
        w, h = base, max(1, int(round(base / r)))
    else:       # 竖向
        w, h = max(1, int(round(base * r))), base
    return f"{w}x{h}"


def _load_tuple(path: str) -> tuple[str, str, bytes]:
    with open(path, "rb") as f:
        data = f.read()
    ct = mimetypes.guess_type(path)[0] or "image/png"
    return (os.path.basename(path), ct, data)


def _decode_item(item: dict, tmpdir: str, prefix: str) -> str:
    """把 hapi 响应 data[] 的某一项落为本地文件, 返回路径。"""
    b64 = item.get("b64_json")
    if b64:
        p = os.path.join(tmpdir, f"{prefix}{int(time.time()*1000)}.png")
        with open(p, "wb") as f:
            f.write(base64.b64decode(b64))
        return p
    url = item.get("url")
    if url:
        path, _ = gpt_image2.download_to_local(url, tmpdir, prefix)
        return path
    raise RuntimeError("接口未返回 url/b64_json")


def make_client(cfg: argparse.Namespace):
    platform = cfg.platform
    pcfg = gpt_image2.PLATFORMS.get(platform, gpt_image2.PLATFORMS["hapi"])
    api_key = cfg.api_key or os.environ.get(pcfg["key_env"], "")
    if not api_key:
        raise RuntimeError(
            f"未配置 API Key: 请设置环境变量 {pcfg['key_env']} 或使用 --api-key")
    model = cfg.model or (pcfg["models"][0] if pcfg.get("models") else "gpt-image-2")
    return gpt_image2.make_client(platform, api_key, cfg.base_url or pcfg["base_url"]), model


def build_batches(total: int, max_per_call: int) -> list[list[int]]:
    """把 0..total-1 分成批次(索引列表)。

    第一批 ≤ max_per_call; 后续批 ≤ max_per_call-1(因为每晚 1 个槽给锚点)。
    例: total=9, max_per_call=4 -> [0..3], [4..6], [7,8]
    """
    batches: list[list[int]] = []
    first = min(max_per_call, total)
    batches.append(list(range(first)))
    rest = list(range(first, total))
    chunk = max_per_call - 1
    for i in range(0, len(rest), chunk):
        batches.append(rest[i:i + chunk])
    return [b for b in batches if b]


def run_single(client, model, target: str, out_dir: str, prefix: str,
               size_single: str, timeout: int) -> str | None:
    """单图编辑兜底: 直接产出一张成片。"""
    imgs = [_load_tuple(target)]
    size = gpt_image2.resolve_size(size_single, imgs[0][2])
    status, resp = client.edit(model, SINGLE_PROMPT, imgs, size=size, n=1, timeout=timeout)
    if status != 200 or not resp.get("data"):
        print(f"    [回退失败] HTTP {status}: {resp}", file=sys.stderr)
        return None
    with tempfile.TemporaryDirectory() as td:
        item = resp["data"][0]
        p = _decode_item(item, td, "s_")
        ext = os.path.splitext(p)[1]
        out = os.path.join(out_dir, f"{prefix}{ext or '.png'}")
        shutil.move(p, out)
    print(f"    [单图回退] {target} -> {out}")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="姿势图反侵权批量编辑")
    ap.add_argument("images", nargs="+", help="输入图片路径(≥1 张, 顺序即输出顺序)")
    ap.add_argument("--out", default="./anti_infringement_outputs", help="输出目录")
    ap.add_argument("--prompt", default=None, help="覆盖默认编辑提示词")
    ap.add_argument("--max-per-call", type=int, default=4, help="每批目标图上限(默认4)")
    ap.add_argument("--platform", default="hapi", choices=list(gpt_image2.PLATFORMS))
    ap.add_argument("--model", default=None)
    ap.add_argument("--api-key", default=None)
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--size-batch", default="1024x1024",
                    help="多图批次的输出尺寸(未指定 --ratio 且无法推断时生效, 默认方形)")
    ap.add_argument("--ratio", default=None,
                    help="宫格输出比例(如 3:4 / 3/4 / 0.75)。缺省时自动按原图比例推断(全部一致用该比例, 否则取多数)")
    ap.add_argument("--size-single", default="from-image", help="单图回退的输出尺寸")
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--keep-grids", action="store_true", help="保留中间四宫格到 out/_grids")
    ap.add_argument("--dry-run", action="store_true", help="只打印分批/锚点计划, 不调接口")
    args = ap.parse_args()

    batches = build_batches(len(args.images), args.max_per_call)

    # 宫格输出尺寸: 优先 --ratio, 其次自动按原图比例推断(全部一致→该比例/不一致→多数), 否则回退 --size-batch
    if args.ratio:
        ratio = parse_ratio(args.ratio)
    else:
        ratio = infer_ratio(args.images)
    if ratio:
        size_batch = ratio_to_grid_size(ratio)
        ratio_note = f"[尺寸] 宫格输出比例 w/h={ratio:.3f}, 尺寸 {size_batch} (跟随原图; 可用 --ratio 覆盖)"
    else:
        size_batch = args.size_batch
        ratio_note = f"[尺寸] 宫格输出尺寸 {size_batch} (方形, 无法推断原图比例)"

    if args.dry_run:
        print("[dry-run] 分批计划:")
        for bi, idxs in enumerate(batches, 1):
            anchor = "无(首批)" if bi == 1 else "上一批首张成片"
            print(f"  批次{bi}: 输入 {[args.images[i] for i in idxs]}  锚点={anchor}")
        print(ratio_note)
        print("[dry-run] 结束, 未调接口")
        return 0

    try:
        client, model = make_client(args)
    except RuntimeError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1

    os.makedirs(args.out, exist_ok=True)
    grids_dir = os.path.join(args.out, "_grids")
    os.makedirs(grids_dir, exist_ok=True)

    base_prompt = args.prompt or BASE_PROMPT

    outputs: list[str | None] = [None] * len(args.images)  # 与输入顺序对齐
    anchor_path: str | None = None  # 首批首张成片, 用作后续批次衣着锚点

    for bi, idxs in enumerate(batches, 1):
        targets = [args.images[i] for i in idxs]
        print(f"[批次 {bi}/{len(batches)}] 目标 {len(targets)} 张 -> {targets}")

        prompt = base_prompt + GRID_SUFFIX
        imgs = [_load_tuple(t) for t in targets]
        if anchor_path and not args.prompt:
            # 仅在使用默认提示词时注入锚点说明(自定义 prompt 时不叠加, 避免措辞冲突)
            prompt += ANCHOR_NOTE
            imgs.append(_load_tuple(anchor_path))
            print(f"    锚点参考图: {anchor_path}")

        size = gpt_image2.resolve_size(size_batch)
        status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=args.timeout)
        if status != 200 or not resp.get("data"):
            print(f"    [批次失败] HTTP {status}: {resp}", file=sys.stderr)
            # 逐张回退
            for t in targets:
                gi = args.images.index(t)
                outputs[gi] = run_single(client, model, t, args.out, f"r{gi+1}_",
                                         args.size_single, args.timeout)
            continue

        # 解码四宫格
        grid_path = os.path.join(grids_dir, f"batch{bi}.png")
        with tempfile.TemporaryDirectory() as td:
            decoded = _decode_item(resp["data"][0], td, f"g{bi}_")
            if args.keep_grids:
                shutil.move(decoded, grid_path)
            else:
                grid_path = decoded
            with Image.open(grid_path) as im:
                im = im.convert("RGB")
                cells, validity = crop_grid(im, 2, 2)

        # 把裁剪格按读取顺序映射到目标图
        for j, cell in enumerate(cells[:len(targets)]):
            gi = idxs[j]
            cell = cell.convert("RGB")
            out = os.path.join(args.out, f"out{gi+1}.png")
            cell.save(out)
            outputs[gi] = out
            print(f"    格{j+1} -> {out}  valid={validity[j]}")

        # 未覆盖/空白的: 单图回退
        for j, ok in enumerate(validity[:len(targets)]):
            if not ok:
                gi = idxs[j]
                print(f"    格{j+1} 空白/低质, 单图回退 {targets[j]}")
                outputs[gi] = run_single(client, model, targets[j], args.out,
                                         f"r{gi+1}_", args.size_single, args.timeout)

        # 记录锚点: 第一批的首张成片
        if bi == 1 and outputs[idxs[0]]:
            anchor_path = outputs[idxs[0]]

    print("\n==== 结果(按输入顺序) ====")
    for i, (src, out) in enumerate(zip(args.images, outputs), 1):
        print(f"  {i}. {os.path.abspath(src)} -> {out or '[失败]'}")
    failed = sum(1 for o in outputs if o is None)
    print(f"\n[完成] 出品 {len(outputs)-failed}/{len(outputs)} 张, 保存于 {os.path.abspath(args.out)}")
    return 0 if failed == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())