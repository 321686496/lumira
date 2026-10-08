#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
fill_viewfinder.py
================================================================================
拍摄页截图「白色取景框」实景填充工具（合成，不改动 UI 与剪影）

分工：
  1) dry-run（默认）: 只做像素分析，定位每张截图的「白色取景框 bbox」与
     「黑色剪影像素」，输出 JSON + 预览 PNG，验证定位正确性（零成本）。
  2) fill: 用生成的实景图，等比缩放后填入取景框区域；黑色剪影原样叠回；
     取景框之外的 UI 像素一像素都不变。

用法:
  # dry-run 定位（可在任意机上跑，不耗 API key）
  python fill_viewfinder.py --dir "上架运营/推流文章相关素材" --dry-run

  # 填充（实景图需已生成，名称: {原截图去扩展名}_bg.png）
  python fill_viewfinder.py --dir "上架运营/推流文章相关素材" --fill --out ./out
================================================================================
"""
import argparse
import json
import os
import sys

from PIL import Image, ImageDraw

WHITE_TH = 235   # 取景框判定: RGB 每通道 >= 此值视为"白底"
INK_TH = 150     # 剪影判定: 取景框内 RGB 每通道 <= 此值视为"黑色剪影线条"
MIN_RATIO = 0.18  # 取景框至少占原图面积比例
MAX_RATIO = 0.62  # 取景框最多占原图面积比例


def load(dirpath):
    """收集目录下所有截图。"""
    names = sorted(
        f for f in os.listdir(dirpath)
        if f.lower().endswith(".png") and f.lower().startswith("screenshot")
    )
    print(f"[load] {dirpath}: {len(names)} 张截图")
    return names


def analyze(img):
    """返回 (viewfinder_bbox or None, ink_fraction)。ink_fraction: 框内剪影占比。

    用"投影法"定位：对每行/列统计白像素占比，取景框是连续高占比的矩形条带，
    健壮于剪影线条将白色区域切分成多块(此前 303/559 因剪影断开而定位失败)。
    """
    w, h = img.size
    gray = img.convert("L")
    px = gray.load()

    # 行投影：每行白像素占比
    row_ratio = []
    for y in range(h):
        cnt = sum(1 for x in range(w) if px[x, y] >= WHITE_TH)
        row_ratio.append(cnt / w)
    for r in range(h):
        row_ratio[r] = min(row_ratio[r], 1.0)

    # 归一化：找到既含大量白、又有一定连续性的行区间
    # 先做轻中值平滑，避免单点噪声分裂区间
    sm = list(row_ratio)
    for y in range(1, h - 1):
        sm[y] = (row_ratio[y - 1] + row_ratio[y] + row_ratio[y + 1]) / 3.0

    # 取景框行 = 白占宽比例超过 55%
    ROW_TH = 0.55
    row_marks = [1 if sm[y] >= ROW_TH else 0 for y in range(h)]
    # 找最大连续区间
    best_run_y = None
    best_len = 0
    i = 0
    while i < h:
        if row_marks[i]:
            j = i
            while j < h and row_marks[j]:
                j += 1
            if (j - i) > best_len:
                best_len = j - i
                best_run_y = (i, j)
            i = j
        else:
            i += 1

    if not best_run_y or best_len < int(h * 0.15):
        return None, 0.0
    miny, maxy = best_run_y

    # 列投影：仅在已定的行区间内统计每列白像素占比
    col_ratio = []
    band = maxy - miny
    for x in range(w):
        cnt = sum(1 for yy in range(miny, maxy) if px[x, yy] >= WHITE_TH)
        col_ratio.append(cnt / band)
    cols = [1 if col_ratio[x] >= ROW_TH else 0 for x in range(w)]
    best_run_x = None
    best_len = 0
    i = 0
    while i < w:
        if cols[i]:
            j = i
            while j < w and cols[j]:
                j += 1
            if (j - i) > best_len:
                best_len = j - i
                best_run_x = (i, j)
            i = j
        else:
            i += 1
    if not best_run_x or best_len < int(w * 0.2):
        return None, 0.0
    minx, maxx = best_run_x

    bbox = (minx, miny, maxx, maxy)
    bw, bh = maxx - minx, maxy - miny

    # 2) 框内剪影占比
    ink = 0
    box_norm = gray.crop((minx, miny, maxx, maxy)).load()
    for x in range(bw):
        for y in range(bh):
            if box_norm[x, y] <= INK_TH:
                ink += 1
    ink_fraction = ink / (bw * bh)
    return bbox, ink_fraction


def make_preview(img, bbox, out_path):
    """输出带框标注的预览图。"""
    pv = img.convert("RGB")
    d = ImageDraw.Draw(pv)
    if bbox:
        d.rectangle(bbox, outline=(255, 0, 0), width=6)
        d.text((bbox[0] + 6, bbox[1] + 6), "VIEWFINDER", fill=(255, 0, 0))
    pv.save(out_path)
    print(f"  [preview] {out_path}")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dir", required=True)
    ap.add_argument("--dry-run", action="store_true", help="只分析定位，不合成")
    ap.add_argument("--fill", action="store_true", help="执行合成填充")
    ap.add_argument("--out", default="./vf_out")
    ap.add_argument("--mask", default="./vf_mask")
    args = ap.parse_args()

    names = load(args.dir)
    os.makedirs(args.mask, exist_ok=True)

    report = {}
    for i, name in enumerate(names, 1):
        path = os.path.join(args.dir, name)
        img = Image.open(path)
        bbox, ink = analyze(img)
        if bbox:
            print(f"[{i}] {name}  viewfinder={bbox}  ink={ink:.3f}  ({img.size[0]}x{img.size[1]})")
            report[name] = {"bbox": list(bbox), "ink": ink, "size": list(img.size)}
        else:
            print(f"[{i}] {name}  !! 未识别到取景框 (控制台截图? 需人工确认)")
            report[name] = None
        make_preview(img, bbox, os.path.join(args.mask, name.replace(".png", "_vf.png")))

    with open(os.path.join(args.mask, "report.json"), "w", encoding="utf-8") as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    print("\n[dry-run] report ->", os.path.join(args.mask, "report.json"))

    if not args.fill:
        return

    os.makedirs(args.out, exist_ok=True)
    bg_root = os.path.join(args.dir, "_bg")
    for name in names:
        bbox = report[name] and report[name]["bbox"]
        if not bbox:
            continue
        base = name.replace(".png", "")
        bg_path = os.path.join(bg_root, f"{base}_bg.png")
        if not os.path.exists(bg_path):
            print(f"  [skip] 缺实景图: {bg_path}")
            continue
        img = Image.open(os.path.join(args.dir, name)).convert("RGB")
        bg = Image.open(bg_path).convert("RGB")
        minx, miny, maxx, maxy = bbox
        bw, bh = maxx - minx, maxy - miny
        resized = bg.resize((bw, bh), Image.LANCZOS)
        # 合成：仅把"原图几乎纯白"的取景框区域替换为实景，其余(剪影/UI/文字/深色)像素原样保留
        canvas = img.copy()
        src = img.load()
        outpx = canvas.load()
        bgpx = resized.load()
        for x in range(bw):
            for y in range(bh):
                sy, sx = y + miny, x + minx
                r, g, b = src[sx, sy][:3]
                if r >= WHITE_TH and g >= WHITE_TH and b >= WHITE_TH:
                    outpx[sx, sy] = bgpx[x, y]
        out = os.path.join(args.out, name)
        canvas.save(out)
        print(f"  [fill] {out}")


if __name__ == "__main__":
    main()