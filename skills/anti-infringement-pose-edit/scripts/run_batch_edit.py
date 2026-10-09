#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""姿势图反侵权批量编辑编排器。

流程:
  1. 读取 N 张输入图(保持顺序);
  2. 按引擎预设的单次上限分批(--engine qwen3pro 上限3 / gpt2k 上限4; --max-per-call 可覆盖):
     - 第一批: 最多 `上限` 张目标图(无锚点);
     - 后续批: 每批 `上限-1` 张目标图 + 追加 1 张"衣着锚点"(第一批首张成片), 用于统一衣着;
     - 批内只剩 1 张时不走宫格, 直接单图编辑(仍附锚点);
  3. 每批按批内张数与模板比例选布局(1x2 / 1x3 / 2x2 / 竖排镜像), 一次发出,
     要求模型把每张的修改结果按该布局排成一张图;
  4. 用 crop_grid.py 按布局裁剪 → 归一化到统一的目标单格像素(短边 768, 比例=模板比例);
  5. 裁不干净/空白的格 → 对该目标图单独跑一次单图编辑兜底;
  6. 输出与输入顺序对齐、尺寸完全一致的单张成片到 --out。

运行前提: 环境变量 MASS_API_KEY(默认引擎 qwen3pro) 或 HAPI_API_KEY(gpt2k) 已配置。
"""
from __future__ import annotations

import argparse
import base64
import io
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

# 构图保持硬约束(拼进默认提示词, 单图/宫格共用): 防止生图模型把原图重绘成紧凑特写
COMPOSE_KEEP = (
    "严格保持每张原图的构图与取景：景别（全身/半身/特写）、人物在画面中的位置与大小占比、"
    "头顶与脚下及四周的环境留白，都必须与原图完全一致；"
    "禁止推近变焦、禁止裁切为特写、禁止改变留白与人物位置。"
)
# 默认编辑提示词(用户给定)
BASE_PROMPT = (
    "修改一下这些图中人物的面部，变得更精致、更帅气美丽、有辨识度；"
    "优化衣着，使其更时髦有质感、贴合场景，同时风格统一、配色协调；"
    "仅修改人物面部与衣着，使其完全看不出与原图是同一个人，以避免侵权；"
    "并统一这几张图中人物的衣着。" + COMPOSE_KEEP
)
# 多图打包成宫格的指令(布局在运行时按批内张数生成)
def grid_suffix(rows: int, cols: int) -> str:
    return (f"请将每张输入图的修改结果，按{rows}行{cols}列整齐排列为一张输出图"
            f"（顺序：从左到右、从上到下，与输入顺序一致），"
            f"格与格之间留清晰边框/分隔线，便于拆分。"
            f"人物保持原姿势与构图，仅修改面部与衣着。")
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
    + COMPOSE_KEEP +
    "直接输出这张修改后的单张人物照片，保持原姿势与构图。"
)


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


def _load_tuple(path: str) -> tuple[str, str, bytes]:
    """上传前统一缩放并压成 JPEG: 部分渠道(MaaS/qwen-image)对大体积 base64 输入会上游超时。"""
    with Image.open(path) as im:
        im = im.convert("RGB")
        im.thumbnail((1024, 1024))
        buf = io.BytesIO()
        im.save(buf, "JPEG", quality=88)
    return ("ref.jpg", "image/jpeg", buf.getvalue())


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


def make_client(eng: dict, api_key: str = "", base_url: str = ""):
    """按解析结果构造客户端, 返回 (client, model)。"""
    pcfg = gpt_image2.PLATFORMS[eng["platform"]]
    key = api_key or os.environ.get(pcfg["key_env"], "")
    if not key:
        raise RuntimeError(
            f"未配置 API Key: 请设置环境变量 {pcfg['key_env']} 或使用 --api-key")
    return gpt_image2.make_client(eng["platform"], key,
                                  base_url or pcfg["base_url"]), eng["model"]


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


def pick_layout(n: int, ratio: float) -> tuple:
    """按本批目标数 n 与模板比例 r 选宫格布局 (rows, cols)。

    n==4 用 2x2; n 为 2/3 时: 竖构图(r<=1)横排、横构图(r>1)竖排,
    使画布长宽比 = n*r 或 r/n 不超过 gpt_image2.MAX_RATIO(3:1)。
    """
    if n <= 1:
        return (1, 1)
    if n >= 4:
        return (2, 2)
    return (1, n) if ratio <= 1 else (n, 1)


def canvas_size(ratio: float, rows: int, cols: int) -> str:
    """宫格画布尺寸 = 单格目标尺寸 × 布局。

    单格尺寸已由 gpt_image2.cell_size 满足既有尺寸约束, 合法比例域内画布亦落在约束内
    (如 16:9 三格 → 1360x2304)。
    """
    cw, ch = gpt_image2.cell_size(ratio)
    return gpt_image2.resolve_size(f"{cw * cols}x{ch * rows}")


def normalize_image(im, target: tuple):
    """居中裁剪到目标比例并缩放到目标像素, 保证所有单张尺寸完全一致。"""
    from PIL import Image
    tw, th = target
    w, h = im.size
    if (w, h) == (tw, th):
        return im
    if w / h > tw / th:          # 过宽 -> 裁左右
        nw = min(w, max(1, int(round(h * tw / th))))
        x = (w - nw) // 2
        im = im.crop((x, 0, x + nw, h))
    else:                        # 过高 -> 裁上下
        nh = min(h, max(1, int(round(w * th / tw))))
        y = (h - nh) // 2
        im = im.crop((0, y, w, y + nh))
    return im.resize((tw, th), Image.LANCZOS)


def split_and_normalize(grid_img, n: int, ratio: float) -> tuple:
    """按 n 对应的布局裁剪宫格, 并把每格归一化到统一的单格目标像素。

    返回 (cells, validity), 长度均为 n。
    """
    rows, cols = pick_layout(n, ratio)
    cells, validity = crop_grid(grid_img, rows, cols)
    target = gpt_image2.cell_size(ratio)
    return [normalize_image(c, target) for c in cells[:n]], validity[:n]


def run_single(client, model, target: str, out_dir: str, prefix: str,
               size_single: str, timeout: int, ratio: float,
               anchor: str | None = None, custom_prompt: bool = False,
               hint: str = "", input_fidelity: str | None = None) -> str | None:
    """单图编辑: 直接产出一张成片(附锚点参考以统一衣着), 并归一化到目标尺寸。"""
    imgs = [_load_tuple(target)]
    prompt = SINGLE_PROMPT + gpt_image2.ratio_note(ratio)
    if hint and not custom_prompt:
        prompt += f"构图要求：{hint}。"
    if anchor and not custom_prompt:
        prompt += ANCHOR_NOTE
        imgs.append(_load_tuple(anchor))
    size = gpt_image2.resolve_size(size_single, imgs[0][2])
    status, resp = client.edit(model, prompt, imgs, size=size, n=1, timeout=timeout,
                               input_fidelity=input_fidelity)
    if status != 200 or not resp.get("data"):
        print(f"    [回退失败] HTTP {status}: {resp}", file=sys.stderr)
        return None
    with tempfile.TemporaryDirectory() as td:
        item = resp["data"][0]
        p = _decode_item(item, td, "s_")
        out = os.path.join(out_dir, f"{prefix}.png")
        with Image.open(p) as im:
            normalize_image(im.convert("RGB"), gpt_image2.cell_size(ratio)).save(out)
    print(f"    [单图] {target} -> {out} {gpt_image2.cell_size_str(ratio)}")
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description="姿势图反侵权批量编辑")
    ap.add_argument("images", nargs="+", help="输入图片路径(≥1 张, 顺序即输出顺序)")
    ap.add_argument("--out", default="./anti_infringement_outputs", help="输出目录")
    ap.add_argument("--prompt", default=None, help="覆盖默认编辑提示词")
    ap.add_argument("--engine", default=gpt_image2.DEFAULT_ENGINE,
                    choices=list(gpt_image2.ENGINES),
                    help="生图引擎预设(默认 qwen3pro: mass/qwen-image-3.0-pro, 单次上限 3 张)")
    ap.add_argument("--platform", default=None, choices=list(gpt_image2.PLATFORMS),
                    help="覆盖引擎预设的平台")
    ap.add_argument("--model", default=None, help="覆盖引擎预设的模型")
    ap.add_argument("--max-per-call", type=int, default=None,
                    help="每批图片上限(默认按引擎推导: qwen3pro=3 / gpt2k=4)")
    ap.add_argument("--api-key", default=None)
    ap.add_argument("--base-url", default=None)
    ap.add_argument("--ratio", default=None,
                    help="模板宽高比(如 3:4 / 3/4 / 0.75)。缺省按输入图比例推断(全部一致用该比例, 否则取多数), 再缺省 3:4")
    ap.add_argument("--size-single", default="from-image", help="单图路径的输出尺寸")
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--no-grid", action="store_true",
                    help="不做宫格打包, 每张图单独跑一次单图编辑(部分渠道对多图输入会上游超时时使用)")
    ap.add_argument("--no-keep-grids", dest="keep_grids", action="store_false",
                    help="不保留中间宫格拼图(默认保留到 out/_grids)")
    ap.add_argument("--anchor", default=None,
                    help="显式指定衣着锚点图(单张/纠错重编辑时维持衣着统一)")
    ap.add_argument("--hints", default=None,
                    help="按输入顺序的构图提示, 用 ';;' 分隔与图片一一对应; "
                         "默认提示词下宫格按格序拼入、单图编辑附带对应提示")
    ap.add_argument("--dry-run", action="store_true", help="只打印分批/锚点计划, 不调接口")
    args = ap.parse_args()

    try:
        eng = gpt_image2.resolve_engine(args.engine, args.platform, args.model,
                                        args.max_per_call)
    except ValueError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1

    # 模板宽高比: --ratio 必须属合法域; 未给则按输入图推断并吸附到最近合法域; 再兜底 3:4
    if args.ratio:
        r = gpt_image2.aspect_ratio_ok(args.ratio)
        if r is None:
            legal = "/".join(lbl for lbl, _ in gpt_image2.ASPECT_RATIOS)
            print(f"[错误] --ratio 必须是 {legal} 之一: {args.ratio}", file=sys.stderr)
            return 1
        ratio = r
    else:
        ratio = gpt_image2.nearest_aspect_ratio(infer_ratio(args.images))[0]
    ratio_label = gpt_image2.ratio_label(ratio)
    batches = build_batches(len(args.images), eng["max_input_images"])

    if args.dry_run:
        print(f"[dry-run] 引擎 {eng['engine']}: platform={eng['platform']} "
              f"model={eng['model']} 单次上限={eng['max_input_images']} 张")
        print(f"[比例] {ratio_label}  单格 {gpt_image2.cell_size_str(ratio)}")
        print("[dry-run] 分批计划:")
        for bi, idxs in enumerate(batches, 1):
            layout = "单图编辑" if len(idxs) == 1 else "%d行%d列" % pick_layout(len(idxs), ratio)
            anchor = "无(首批)" if bi == 1 else "上一批首张成片"
            print(f"  批次{bi}: 目标 {len(idxs)} 张  布局 {layout}  锚点={anchor}")
            print(f"          输入 {[args.images[i] for i in idxs]}")
        print("[dry-run] 结束, 未调接口")
        return 0

    try:
        client, model = make_client(eng, args.api_key or "", args.base_url or "")
    except RuntimeError as e:
        print(f"[错误] {e}", file=sys.stderr)
        return 1

    os.makedirs(args.out, exist_ok=True)

    base_prompt = (args.prompt or BASE_PROMPT) + gpt_image2.ratio_note(ratio)
    # 构图提示(与输入顺序对齐) + hapi 通道启用 input_fidelity=high(提高对输入构图的保真)
    hints = [h.strip() for h in (args.hints or "").split(";;")] if args.hints else []

    def hint_for(idx: int) -> str:
        return hints[idx] if 0 <= idx < len(hints) else ""

    fidelity = "high" if eng["platform"] == "hapi" else None

    outputs: list[str | None] = [None] * len(args.images)  # 与输入顺序对齐

    # --no-grid: 每张图单独一次单图编辑, 不做宫格打包/裁剪
    if args.no_grid:
        for i, src in enumerate(args.images):
            print(f"[单图 {i+1}/{len(args.images)}] {src}")
            outputs[i] = run_single(client, model, src, args.out, f"out{i+1}",
                                    args.size_single, args.timeout, ratio,
                                    None, bool(args.prompt),
                                    hint=hint_for(i), input_fidelity=fidelity)
        print("\n==== 结果(按输入顺序) ====")
        for i, (src, out) in enumerate(zip(args.images, outputs), 1):
            print(f"  {i}. {os.path.abspath(src)} -> {out or '[失败]'}")
        failed = sum(1 for o in outputs if o is None)
        print(f"\n[完成] 出品 {len(outputs)-failed}/{len(outputs)} 张, 保存于 {os.path.abspath(args.out)}")
        return 0 if failed == 0 else 2

    grids_dir = os.path.join(args.out, "_grids")
    os.makedirs(grids_dir, exist_ok=True)

    anchor_path: str | None = args.anchor  # 显式锚点优先; 否则首批首张成片用作后续批次衣着锚点

    for bi, idxs in enumerate(batches, 1):
        targets = [args.images[i] for i in idxs]
        rows, cols = pick_layout(len(targets), ratio)
        print(f"[批次 {bi}/{len(batches)}] 目标 {len(targets)} 张 "
              f"{rows}行{cols}列 -> {targets}")

        # 单张批次: 不走宫格, 直接单图编辑(仍附锚点)
        if len(targets) == 1:
            gi = idxs[0]
            outputs[gi] = run_single(client, model, targets[0], args.out,
                                     f"out{gi+1}", args.size_single, args.timeout,
                                     ratio, anchor_path, bool(args.prompt),
                                     hint=hint_for(gi), input_fidelity=fidelity)
            continue

        prompt = base_prompt + grid_suffix(rows, cols)
        cell_hints = [hint_for(gi) for gi in idxs]
        if not args.prompt and any(cell_hints):
            # 构图提示按输出格序拼入(与输入顺序一一对应)
            prompt += "各格构图要求（与输出格序一一对应）：" + \
                      "; ".join(f"格{k+1}：{h}" for k, h in enumerate(cell_hints) if h) + "。"
        imgs = [_load_tuple(t) for t in targets]
        if anchor_path and not args.prompt:
            # 仅在使用默认提示词时注入锚点说明(自定义 prompt 时不叠加, 避免措辞冲突)
            prompt += ANCHOR_NOTE
            imgs.append(_load_tuple(anchor_path))
            print(f"    锚点参考图: {anchor_path}")

        size_arg = canvas_size(ratio, rows, cols)
        size = gpt_image2.resolve_size(size_arg)
        print(f"    画布 {size_arg}")
        status, resp = client.edit(model, prompt, imgs, size=size, n=1,
                                   timeout=args.timeout, input_fidelity=fidelity)
        if status != 200 or not resp.get("data"):
            print(f"    [批次失败] HTTP {status}: {resp}", file=sys.stderr)
            # 逐张回退
            for t in targets:
                gi = args.images.index(t)
                outputs[gi] = run_single(client, model, t, args.out, f"out{gi+1}",
                                         args.size_single, args.timeout, ratio,
                                         anchor_path, bool(args.prompt))
            continue

        # 解码宫格 -> 按布局裁剪 -> 归一化
        grid_path = os.path.join(grids_dir, f"batch{bi}.png")
        with tempfile.TemporaryDirectory() as td:
            decoded = _decode_item(resp["data"][0], td, f"g{bi}_")
            if args.keep_grids:
                shutil.move(decoded, grid_path)
            else:
                grid_path = decoded
            with Image.open(grid_path) as im:
                cells, validity = split_and_normalize(im.convert("RGB"), len(targets), ratio)

        # 把裁剪格按读取顺序映射到目标图
        for j, cell in enumerate(cells):
            gi = idxs[j]
            out = os.path.join(args.out, f"out{gi+1}.png")
            cell.convert("RGB").save(out)
            outputs[gi] = out
            print(f"    格{j+1} -> {out}  {cell.size[0]}x{cell.size[1]}  valid={validity[j]}")

        # 未覆盖/空白的: 单图回退
        for j, ok in enumerate(validity):
            if not ok:
                gi = idxs[j]
                print(f"    格{j+1} 空白/低质, 单图回退 {targets[j]}")
                outputs[gi] = run_single(client, model, targets[j], args.out,
                                         f"out{gi+1}", args.size_single, args.timeout,
                                         ratio, anchor_path, bool(args.prompt),
                                         hint=hint_for(gi), input_fidelity=fidelity)

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