# -*- coding: utf-8 -*-
"""
把 AI 生成的真实场景照片合成进 App 真机截图的取景框区域，保留原有 UI。

用法:
  python scripts/make_viewfinder_shot.py --shot <截图> --photo <照片> --out <输出> \
      --top 548 --bottom 2262 --zoom 1.15 --dx 0.07 --dy 0.70 \
      --panel 41,548,1218,950,26 --panel 286,2051,971,2157,53 --panel 82,2156,1177,2262,38

原理:
  1. 用照片铺满取景框区域（按宽度 cover，支持 zoom/dx/dy 微调）；
  2. 用「局部背景 vs 当前像素」的差异估计 alpha，把原截图上的黑色剪影引导线
     保留并叠到照片上（网格线由 --grid 重绘）；
  3. 把模板卡片、比例胶囊、底部工具栏等不透明 UI 面板原样贴回最上层；
  4. 取景框右下角加「效果示意」标注。
"""
import argparse

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

FONT = r"C:\Windows\Fonts\msyh.ttc"


def place(photo, w, h, zoom=1.0, dx=0.5, dy=0.5):
    """按宽度铺满目标尺寸(可再放大 zoom 倍)，用 dx/dy 控制裁切位置。"""
    iw, ih = photo.size
    s = zoom * w / iw
    nw, nh = max(w, int(round(iw * s))), max(h, int(round(ih * s)))
    im = photo.resize((nw, nh), Image.LANCZOS)
    left = max(0, min(nw - w, int(round((nw - w) * dx))))
    top = max(0, min(nh - h, int(round((nh - h) * dy))))
    return im.crop((left, top, left + w, top + h))


def build_line_alpha(src_region, boxes, top):
    """用局部背景估计 alpha：只保留比周围背景明显更暗的像素(即黑色引导线)。"""
    g = src_region.convert("L")
    gray = np.asarray(g).astype(np.float32)
    blur = np.asarray(g.filter(ImageFilter.GaussianBlur(41))).astype(np.float32)
    ratio = (blur - gray) / np.maximum(blur, 1.0)
    alpha = np.clip((ratio - 0.12) / 0.50, 0.0, 1.0)
    h, w = alpha.shape
    for x0, y0, x1, y1, _r in boxes:  # 面板及其光晕区域不参与抠线
        a0, a1 = max(0, y0 - top - 42), min(h, y1 - top + 42)
        b0, b1 = max(0, x0 - 42), min(w, x1 + 42)
        alpha[a0:a1, b0:b1] = 0.0
    return alpha


def transform_mask(alpha, k=1.0, dx=0.0, dy=0.0):
    """对抠出的引导线掩膜做整体缩放/平移（以掩膜包围盒中心为基准）。"""
    if k == 1.0 and dx == 0 and dy == 0:
        return alpha
    img = Image.fromarray((np.clip(alpha, 0, 1) * 255).astype(np.uint8))
    bbox = img.getbbox()
    if not bbox:
        return alpha
    crop = img.crop(bbox)
    nw = max(1, int(round(crop.width * k)))
    nh = max(1, int(round(crop.height * k)))
    crop = crop.resize((nw, nh), Image.LANCZOS)
    cx = (bbox[0] + bbox[2]) / 2 + dx
    cy = (bbox[1] + bbox[3]) / 2 + dy
    out = Image.new("L", img.size, 0)
    out.paste(crop, (int(round(cx - nw / 2)), int(round(cy - nh / 2))))
    return np.asarray(out).astype(np.float32) / 255.0


def rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1],
                                        radius=int(radius), fill=255)
    return m


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--shot", required=True)
    ap.add_argument("--photo", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--top", type=int, required=True)
    ap.add_argument("--bottom", type=int, required=True)
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--dx", type=float, default=0.5)
    ap.add_argument("--dy", type=float, default=0.5)
    ap.add_argument("--panel", action="append", default=None,
                    help="不透明 UI 面板 x0,y0,x1,y1[,radius]")
    ap.add_argument("--grid", action="store_true", help="重绘相机九宫格网格")
    ap.add_argument("--line-alpha", type=float, default=1.0, help="引导线叠加不透明度")
    ap.add_argument("--guide-zoom", type=float, default=1.0, help="引导线整体缩放")
    ap.add_argument("--guide-dx", type=float, default=0.0, help="引导线水平平移(px)")
    ap.add_argument("--guide-dy", type=float, default=0.0, help="引导线垂直平移(px)")
    ap.add_argument("--no-label", action="store_true")
    ap.add_argument("--label", default="效果示意")
    ap.add_argument("--label-xy", default=None, help="标注左上角绝对坐标 x,y")
    args = ap.parse_args()

    boxes = []
    for spec in (args.panel or []):
        v = [int(t) for t in spec.split(",")]
        boxes.append((v[0], v[1], v[2], v[3], v[4] if len(v) > 4 else 16))

    shot = Image.open(args.shot).convert("RGB")
    W, _H = shot.size
    top, bottom = args.top, args.bottom
    rw, rh = W, bottom - top

    photo = Image.open(args.photo).convert("RGB")
    region = place(photo, rw, rh, args.zoom, args.dx, args.dy)

    src_region = shot.crop((0, top, rw, bottom))
    arr_src = np.asarray(src_region).astype(np.float32)
    alpha = build_line_alpha(src_region, boxes, top)
    alpha = transform_mask(alpha, args.guide_zoom, args.guide_dx, args.guide_dy)
    alpha = (alpha * args.line_alpha)[:, :, None]
    blended = np.asarray(region).astype(np.float32) * (1 - alpha) + arr_src * alpha
    out_region = Image.fromarray(blended.astype(np.uint8))

    if args.grid:
        d = ImageDraw.Draw(out_region, "RGBA")
        for i in (1, 2):
            x = int(rw * i / 3)
            d.line([(x, 0), (x, rh)], fill=(255, 255, 255, 64), width=2)
            y = int(rh * i / 3)
            d.line([(0, y), (rw, y)], fill=(255, 255, 255, 64), width=2)

    for x0, y0, x1, y1, radius in boxes:
        m = rounded_mask((x1 - x0, y1 - y0), radius)
        out_region.paste(shot.crop((x0, y0, x1, y1)), (x0, y0 - top), m)

    shot.paste(out_region, (0, top))

    if not args.no_label:
        d = ImageDraw.Draw(shot, "RGBA")
        fs = 30
        font = ImageFont.truetype(FONT, fs)
        tw = int(d.textlength(args.label, font=font))
        pad = 12
        if args.label_xy:
            x0, y0 = [int(v) for v in args.label_xy.split(",")]
        else:
            x0, y0 = 28, top + 14
        x1, y1 = x0 + tw + pad * 2, y0 + fs + pad * 2
        d.rounded_rectangle([x0, y0, x1, y1], radius=(y1 - y0) // 2,
                            fill=(0, 0, 0, 100))
        d.text((x0 + pad, y0 + pad - 2), args.label, font=font,
               fill=(255, 255, 255, 230))

    shot.save(args.out, quality=94)
    print("saved:", args.out)


if __name__ == "__main__":
    main()
