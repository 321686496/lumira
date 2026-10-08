#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""宫格（k×k 或 1×n / n×1 排布）智能识别与裁剪。

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
# 判定"存在 gutter"的阈值: 连续低方差带上限 = profile 最大方差的此比例
GUTTER_VAR_RATIO = 0.35
# 外白边/均质边识别时的方差容差上限(绝对量, 0-255)
SEP_TOL = 2.0


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


def _gutter_bands(prof: list[float], rel_thr: float = GUTTER_VAR_RATIO,
                  min_w: int = 2) -> list[tuple[int, int]]:
    """返回连续低方差 band(分隔 gutter/白线/留白)列表 [start, end)。

    只保留宽度 >= min_w 的带, 排除单点噪点。这是定位「可切割的缝隙」的依据:
    真实格线是一条宽度一致的低方差带, 而不是单个极小方差点——只认波动区间、
    不认单点, 就能避免把天空/空白里某个低方差点误当成格线切进内容。
    """
    n = len(prof)
    ref = max(prof) if prof else 0.0
    if ref <= 1e-6:
        return []
    thr = rel_thr * ref
    bands: list[tuple[int, int]] = []
    i = 0
    while i < n:
        if prof[i] <= thr:
            j = i
            while j < n and prof[j] <= thr:
                j += 1
            if j - i >= min_w:
                bands.append((i, j))
            i = j
        else:
            i += 1
    return bands


def _sep_lines(prof: list[float], count: int) -> list[int]:
    """定位 count-1 条分界切点(prof 索引, 升序)。

    原则(修复「裁到上下两格中间区域」的关键):
      * 只在「期望等分位置近邻(±win)」内存在真实 gutter 带时才切, 切在带的中心,
        从而剔除白线并保证切的是缝隙而不是内容;
      * 近邻内找不到 gutter 时, 退回该期望等分位置做均分切——绝不把切点投进
        高方差的内容区(那正是旧实现把切点落在人物/场景中间的最大原因)。
    """
    n = len(prof)
    if count <= 1 or n <= 2:
        return [n // 2] * max(0, count - 1)
    min_w = max(2, int(n * 0.004))
    bands = [b for b in _gutter_bands(prof) if b[1] - b[0] >= min_w]
    span = n / count
    win = max(3, int(span * 0.4))
    cuts: list[int] = []
    for k in range(1, count):
        center = int(round(span * k))
        lo, hi = max(0, center - win), min(n, center + win)
        best: tuple[int, int] | None = None
        best_d = float("inf")
        for a, b in bands:
            bc = (a + b) / 2.0
            if lo <= bc <= hi:
                d = abs(bc - center)
                if d < best_d:
                    best_d, best = d, (a, b)
        if best is not None and best_d <= win:
            cut = int(round((best[0] + best[1]) / 2.0))
        else:
            cut = center  # 无可靠缝隙 -> 均分, 不硬切内容
        cuts.append(cut)
    # 升序、不重叠、落在 [1, n-1]
    prev = 0
    result: list[int] = []
    for c in cuts:
        c = max(min(c, n - 1), prev + 1)
        result.append(c)
        prev = c
    return result


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

    # 内部分隔切点 (det 坐标, 单点; 对应两条相邻格的共用边界)
    row_cuts = _sep_lines(row_sep, rows)   # 横向分隔切点(行方向)
    col_cuts = _sep_lines(col_sep, cols)   # 纵向分隔切点(列方向)

    def sx(i) -> int:
        return int(round(i * W / sw))

    def sy(i) -> int:
        return int(round(i * H / sh))

    # 四周外白边裁剪 (det 坐标相对量)
    top_trim = _edge_rim(row_sm)
    bottom_trim = _edge_rim(list(reversed(row_sm)))
    left_trim = _edge_rim(col_sm)
    right_trim = _edge_rim(list(reversed(col_sm)))

    def col_edge(c: int, left: bool) -> int:
        """第 c 列的左/右边界(不含白线); c 超出范围时退回整幅边界。"""
        if left:
            if c <= 0:
                return sx(left_trim) if left_trim is not None else 0
            return sx(col_cuts[c - 1])
        if c >= cols - 1:
            return W - sx(right_trim) if right_trim is not None else W
        return sx(col_cuts[c])

    def row_edge(r: int, top: bool) -> int:
        """第 r 行的上/下边界(不含白线); r 超出范围时退回整幅边界。"""
        if top:
            if r <= 0:
                return sy(top_trim) if top_trim is not None else 0
            return sy(row_cuts[r - 1])
        if r >= rows - 1:
            return H - sy(bottom_trim) if bottom_trim is not None else H
        return sy(row_cuts[r])

    boxes: list[tuple[int, int, int, int]] = []
    for r in range(rows):
        for c in range(cols):
            x0 = col_edge(c, True)
            x1 = col_edge(c, False)
            y0 = row_edge(r, True)
            y1 = row_edge(r, False)
            boxes.append((x0, y0, x1, y1))

    cells = [img.crop(b) for b in boxes]
    # 清除每格四周的均质细边(网格线/外白边残余), 不伤内容边
    cells = [c[1] for c in (_purge_uniform_edges(c) for c in cells)]
    validity = [_cell_std(c) > BLANK_STD_THRESHOLD for c in cells]
    return cells, validity


def main() -> int:
    global BLANK_STD_THRESHOLD
    ap = argparse.ArgumentParser(description="宫格智能识别与裁剪")
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