#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""四宫格（2x2）智能识别与裁剪。

用法:
    python crop_grid.py <grid.png> [--rows 2] [--cols 2] [--out ./cells] [--prefix cell_]

被 run_batch_edit.py 复用。核心思路:
- 在灰度图上按行/列计算取样方差, 平滑后定位"低方差分隔带"(网格线/留白);
- 在中央带内找最宽的一段低方差带作为 gutter, 按其左右/上下边缘切分,
  从而把分隔白线/留白完整排除到单元格之外(避免裁进白线或相邻图);
- 同时检测四周外白边并裁剪掉;
- 无 gutter 时退化为按 rows*cols 均分;
- 每格裁剪后做"内容是否空白"判定, 返回 (PIL Image, is_valid)。
"""
from __future__ import annotations

import argparse
import os

from PIL import Image

# 检测灰色方差时, 低方差判空格的阈值 (0-255)
BLANK_STD_THRESHOLD = 20.0
# gutter 探测时, 中央探测带范围 (占边长比例)
BAND_LO, BAND_HI = 0.30, 0.70
# 判定"存在 gutter"的阈值: 中央带最小方差显著低于该带最大方差
GUTTER_VAR_RATIO = 0.35
# 分隔线=全局最小方差处; 扩展该线时允许的方差近邻容差(绝对量), 避免把平坦内容(海水/天空)并入
SEP_TOL = 2.0
# 认为"干净细分隔线"的最大宽度(占边长比例); 超出说明合并到了空白/内容, 退化为窄切
SEP_MAX_W_RATIO = 0.03


def _smooth(vals: list[float], window: int) -> list[float]:
    """窗口均值平滑, 平滑掉单个噪点, 突出真正的"低方差带"。"""
    n = len(vals)
    if n == 0:
        return vals
    window = max(1, min(window, n))
    half = window // 2
    out = []
    acc = sum(vals[:window])
    out.append(acc / window)
    for i in range(window, n):
        acc += vals[i] - vals[i - window]
        out.append(acc / window)
    # 补齐头部 half 个, 使长度与输入一致(用第一个值填充简化)
    prefix = [out[0]] * half
    return prefix + out


def _profiles(gray: Image.Image, px, step: int = 2) -> tuple[list[float], list[float]]:
    """按行、按列计算取样像素的方差 (0-255), 返回 (row_var, col_var)。"""
    w, h = gray.size
    row_var: list[float] = []
    for y in range(h):
        vals = []
        for x in range(0, w, step):
            vals.append(px[x, y])
        if not vals:
            row_var.append(0.0)
            continue
        m = sum(vals) / len(vals)
        var = sum((v - m) ** 2 for v in vals) / len(vals)
        row_var.append(var)
    col_var: list[float] = []
    for x in range(w):
        vals = []
        for y in range(0, h, step):
            vals.append(px[x, y])
        if not vals:
            col_var.append(0.0)
            continue
        m = sum(vals) / len(vals)
        var = sum((v - m) ** 2 for v in vals) / len(vals)
        col_var.append(var)
    return row_var, col_var


def _sep_line(prof: list[float]) -> tuple[int, int] | None:
    """在中央带内定位"细分隔线"(白色净线), 返回 [start, end) (半开).

    策略: 分隔线是方差接近全局最小值的干净白线; 从最小方差点向两侧扩展,
    只并入方差仍接近最小值的邻近位置(绝对容差 SEP_TOL), 从而不把平坦内容(海水/天空)
    悄悄合并成一条巨型"分隔带"。若扩展后宽度过大(说明实际是空白/内容大块),
    则退化为取最小方差点附近一个窄切, 保证切点不跑到内容深处。
    """
    n = len(prof)
    lo = int(n * BAND_LO)
    hi = min(int(n * BAND_HI), n - 1)
    if hi <= lo:
        hi = lo + 1
    seg = prof[lo:hi + 1]
    ref = max(seg) if seg else 1.0
    if ref <= 1e-6:
        return None  # 整带近乎无变化, 无法定位分隔线
    # 必须存在"明显低于带内最大"的分隔线
    if min(seg) > GUTTER_VAR_RATIO * ref:
        return None
    pos = lo + seg.index(min(seg))
    tol = max(SEP_TOL, min(seg) * 1.5)
    a = pos
    while a - 1 >= lo and prof[a - 1] < min(seg) + tol:
        a -= 1
    b = pos
    while b + 1 <= hi and prof[b + 1] < min(seg) + tol:
        b += 1
    b += 1
    max_w = max(1, int(n * SEP_MAX_W_RATIO))
    if b - a > max_w:
        # 扩展过宽 = 误把平坦内容/空白当分隔线 -> 只按最小方差点做窄切, 安全不伤内容
        a, b = pos, pos + 1
    return a, b


def _edge_rim(prof: list[float]) -> int | None:
    """从 idx0 起连续的低方差外白边, 返回其结束下标(相对该轴). 过窄/不存在返回 None."""
    n = len(prof)
    ref = max(prof) if prof else 1.0
    if ref <= 1e-6:
        return None
    thr = max(SEP_TOL, ref * 0.08)
    limit = int(n * 0.12)  # 只看最外 12%
    i = 0
    while i < limit and i < n and prof[i] < thr:
        i += 1
    if i < max(2, n // 80):  # 太窄视为无边框
        return None
    return i


def _cell_std(img: Image.Image, step: int = 3) -> float:
    """估算裁剪格内像素标准差, 用于判断是否空白。"""
    g = img.convert("L")
    px = g.load()
    w, h = g.size
    vals = []
    for y in range(0, h, step):
        for x in range(0, w, step):
            vals.append(px[x, y])
    if not vals:
        return 0.0
    m = sum(vals) / len(vals)
    return (sum((v - m) ** 2 for v in vals) / len(vals)) ** 0.5


def _strip_std(img: Image.Image, px, axis: str, idx: int, step: int = 3) -> float:
    """某一行(axis='row'/'col')的取样像素标准差。"""
    w, h = img.size
    if axis == "row":
        vals = [px[x, idx] for x in range(0, w, step)]
    else:
        vals = [px[idx, y] for y in range(0, h, step)]
    if not vals:
        return 0.0
    m = sum(vals) / len(vals)
    return (sum((v - m) ** 2 for v in vals) / len(vals)) ** 0.5


def _purge_uniform_edges(img: Image.Image, max_px: int = 30, std_thr: float = 4.0):
    """裁掉每格四周"接近均质"(纯白/纯色)的细边, 用于清除网格线/外白边残余。

    只移除均质边(如白线), 内容边缘因方差高不会被裁→不伤主体。
    返回 (crop_box, img)。
    """
    g = img.convert("L")
    px = g.load()
    w, h = img.size
    left = top = 0
    right, bottom = w, h
    while left < w - 1 and left < max_px and _strip_std(img, px, "col", left) < std_thr:
        left += 1
    while right - 1 > left and h - right < max_px and _strip_std(img, px, "col", right - 1) < std_thr:
        right -= 1
    while top < h - 1 and top < max_px and _strip_std(img, px, "row", top) < std_thr:
        top += 1
    while bottom - 1 > top and h - bottom < max_px and _strip_std(img, px, "row", bottom - 1) < std_thr:
        bottom -= 1
    return (left, top, right, bottom), img.crop((left, top, right, bottom))


def crop_grid(img: Image.Image, rows: int = 2, cols: int = 2):
    """识别并裁剪 grid 为 rows*cols 格。

    返回 (cells, validity):
      - cells: list[PIL.Image], 读取顺序(左上->右上->左下->右下...), 长度=rows*cols
      - validity: list[bool], 与 cells 对齐, 该格是否有有效内容(非空白)
    """
    # 检测用缩小图
    det = img.copy()
    det.thumbnail((600, 600))
    gray = det.convert("L")
    px = gray.load()
    row_var, col_var = _profiles(gray, px)

    sw, sh = gray.size
    # 分隔线定位用小平滑窗口(保留细白线); 外白边用较重平滑(突出大片低方差带)
    row_sep = _smooth(row_var, max(3, sh // 100))
    col_sep = _smooth(col_var, max(3, sw // 100))
    row_sm = _smooth(row_var, max(3, sh // 30))
    col_sm = _smooth(col_var, max(3, sw // 30))
    W, H = img.size

    # 中央分隔线 (det 坐标, [start,end))
    band_y = _sep_line(row_sep)  # 横向分隔线(行方向)
    band_x = _sep_line(col_sep)  # 纵向分隔线(列方向)

    def sx(i) -> int:
        return int(round(i * W / sw))

    def sy(i) -> int:
        return int(round(i * H / sh))

    # 四周外白边裁剪 (det 坐标相对量)
    top_trim = _edge_rim(row_sm)
    bottom_trim = _edge_rim(list(reversed(row_sm)))
    left_trim = _edge_rim(col_sm)
    right_trim = _edge_rim(list(reversed(col_sm)))

    cx_sep_start = sx(band_x[0]) if band_x else None   # 左列末尾(不含白线)
    cx_sep_end = sx(band_x[1]) if band_x else None     # 右列开头
    cy_sep_start = sy(band_y[0]) if band_y else None   # 上行末尾(不含白线)
    cy_sep_end = sy(band_y[1]) if band_y else None     # 下行开头

    boxes: list[tuple[int, int, int, int]] = []
    for r in range(rows):
        for c in range(cols):
            # 纵向 x
            if c == 0:
                x0 = sx(left_trim) if left_trim is not None else 0
            else:
                x0 = cx_sep_end if cx_sep_end is not None else W // 2
            if c == cols - 1:
                x1 = W - sx(right_trim) if right_trim is not None else W
            else:
                x1 = cx_sep_start if cx_sep_start is not None else W // 2
            # 横向 y
            if r == 0:
                y0 = sy(top_trim) if top_trim is not None else 0
            else:
                y0 = cy_sep_end if cy_sep_end is not None else H // 2
            if r == rows - 1:
                y1 = H - sy(bottom_trim) if bottom_trim is not None else H
            else:
                y1 = cy_sep_start if cy_sep_start is not None else H // 2
            boxes.append((x0, y0, x1, y1))

    cells = [img.crop(b) for b in boxes]
    # 清除每格四周的均质细边(网格线/外白边残余), 不伤内容边
    cells = [c[1] for c in (_purge_uniform_edges(c) for c in cells)]
    validity = [_cell_std(c) > BLANK_STD_THRESHOLD for c in cells]
    return cells, validity


def main() -> int:
    global BLANK_STD_THRESHOLD
    ap = argparse.ArgumentParser(description="四宫格智能识别与裁剪")
    ap.add_argument("image", help="输入网格图片")
    ap.add_argument("--rows", type=int, default=2)
    ap.add_argument("--cols", type=int, default=2)
    ap.add_argument("--out", default="./cells")
    ap.add_argument("--prefix", default="cell_")
    ap.add_argument("--min-std", type=float, default=BLANK_STD_THRESHOLD,
                    help="空白判定阈值(0-255)")
    args = ap.parse_args()

    BLANK_STD_THRESHOLD = args.min_std

    with Image.open(args.image) as im:
        im = im.convert("RGB")
        cells, validity = crop_grid(im, args.rows, args.cols)

    os.makedirs(args.out, exist_ok=True)
    name, ext = os.path.splitext(os.path.basename(args.image))
    for i, (cell, ok) in enumerate(zip(cells, validity)):
        out_path = os.path.join(args.out, f"{args.prefix}{name}_{i + 1}.png")
        cell.save(out_path)
        print(f"[{'OK ' if ok else 'BLANK'} ] {out_path}  std~{_cell_std(cell):.1f}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())