# -*- coding: utf-8 -*-
"""
「姿势图鉴波」配图生成脚本（常态-2026-10）。

输出：docs/marketing/assets/2026-10/poseguide-20261007/
  poseguide-01-xhs-hotpot.jpg          小红书①首图 3:4   火锅模板 9 张样片九宫格
  poseguide-02-xhs-seaside.jpg         小红书②首图 3:4   海滨模板 9 张样片九宫格
  poseguide-03-xhs-points.jpg          小红书③首图 3:4   三宫格点单
  poseguide-04-wx-header-2.35x1.jpg    公众号头图 2.35:1  图鉴横幅
  poseguide-05-viewfinder-demo.jpg     补充图 3:4        「取景框叠剪影 → 照着摆」对照

说明：
  - 九宫格样片来自 App 模板库真实素材（tpl-srv_AP-DmJEbTGJt / tpl-srv_v8pLGJNfqyCs），属产品内容；
  - 取景框示意使用模板自带的真实人形轮廓（silhouette.png）反色后叠加；
  - 每张图均在角落标注「效果示意」，不使用任何非授权他人照片。
"""

import os

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = r"e:\Project\photo_post"
ASSETS = os.path.join(ROOT, "docs", "marketing", "assets", "2026-10")
APPUI = os.path.join(ASSETS, "app-ui")
HOTPOT = os.path.join(APPUI, "tpl-srv_AP-DmJEbTGJt")
SEASIDE = os.path.join(APPUI, "tpl-srv_v8pLGJNfqyCs")
OUT = os.path.join(ASSETS, "poseguide-20261007")

GOLD = (201, 169, 110)
GOLD_DEEP = (176, 141, 79)
INK = (42, 38, 32)
T2 = (107, 100, 92)
T3 = (154, 143, 124)
PAPER = (253, 251, 247)
PAPER2 = (246, 241, 232)
LINE = (226, 214, 191)
DARK = (52, 47, 41)
SIL = (150, 140, 126)

F_REG = r"C:\Windows\Fonts\msyh.ttc"
F_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"
_font_cache = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(F_BOLD if bold else F_REG, size)
    return _font_cache[key]


def text_ls(draw, xy, s, f, fill, ls=0):
    x, y = xy
    for ch in s:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + ls
    return x - xy[0] - (ls if s else 0)


def text_ls_w(draw, s, f, ls=0):
    return sum(draw.textlength(ch, font=f) for ch in s) + ls * max(0, len(s) - 1)


def center_text(draw, y, s, f, fill, ls=0, W=None):
    W = W or draw.im.size[0]
    w = text_ls_w(draw, s, f, ls)
    text_ls(draw, ((W - w) / 2, y), s, f, fill, ls)
    return w


def corner_chip(canvas, s="效果示意", pos="tr"):
    """统一「效果示意」标注。pos: br / tr。"""
    d = ImageDraw.Draw(canvas)
    f = font(22)
    w = text_ls_w(d, s, f)
    asc, desc = f.getmetrics()
    pad_x, pad_y = 16, 9
    bw, bh = w + pad_x * 2, asc + desc + pad_y * 2
    if pos == "tr":
        x, y = canvas.width - bw - 30, 30
    else:
        x, y = canvas.width - bw - 30, canvas.height - bh - 30
    d.rounded_rectangle([x, y, x + bw, y + bh], radius=12, fill=(255, 255, 255, 225), outline=LINE, width=1)
    d.text((x + pad_x, y + pad_y), s, font=f, fill=T3)


def rounded(im, radius):
    im = im.convert("RGBA")
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=radius, fill=255)
    im.putalpha(mask)
    return im


def load_fit(path, w, h):
    return ImageOps.fit(Image.open(path).convert("RGB"), (w, h), method=Image.LANCZOS)


def base(W, H, bg=PAPER):
    im = Image.new("RGBA", (W, H), bg + (255,))
    ImageDraw.Draw(im).rectangle([26, 26, W - 27, H - 27], outline=LINE, width=2)
    return im


# ---------------------------------------------------------------- 九宫格图鉴
def build_grid(sample_dir, ext, title, subtitle, poses, footer):
    """poses: 9 个短姿势名（用于角标提示，仅取前 6 字）"""
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    center_text(d, 44, "如画 LUMIRA · 姿势图鉴", font(26, True), GOLD_DEEP, ls=3, W=W)
    center_text(d, 80, title, font(58, True), INK, ls=3, W=W)
    center_text(d, 168, subtitle, font(28), T2, ls=2, W=W)
    d.line([(W - 150) // 2, 225, (W + 150) // 2, 225], fill=GOLD, width=3)

    cols = rows = 3
    gap = 18
    cell_w = (W - 120 - gap * (cols - 1)) // cols      # 308
    cell_h = 348
    grid_top = 246
    for i in range(9):
        r, c = divmod(i, cols)
        x = 60 + c * (cell_w + gap)
        y = grid_top + r * (cell_h + gap)
        pic = rounded(load_fit(os.path.join(sample_dir, "image_%d.%s" % (i, ext)), cell_w, cell_h), 18)
        im.alpha_composite(pic, (x, y))
        d.rounded_rectangle([x, y, x + cell_w - 1, y + cell_h - 1], radius=18, outline=(255, 255, 255, 150), width=2)
        # 序号角标
        bx, by, bs = x + 12, y + 12, 46
        d.rounded_rectangle([bx, by, bx + bs, by + bs], radius=13, fill=GOLD_DEEP + (238,))
        nf = font(26, True)
        nx = bx + (bs - text_ls_w(d, str(i + 1), nf)) / 2
        d.text((nx, by + 5), str(i + 1), font=nf, fill=PAPER + (255,))

    center_text(d, 1348, footer, font(28), T2, ls=2, W=W)
    corner_chip(im, pos="tr")
    return im.convert("RGB")


# ---------------------------------------------------------------- 点单三宫格
def build_points():
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    center_text(d, 60, "下期拍哪个场景", font(58, True), INK, ls=4, W=W)
    center_text(d, 148, "评论区打序号 · 票高的先拍", font(28), T2, ls=3, W=W)
    d.line([(W - 150) // 2, 212, (W + 150) // 2, 212], fill=GOLD, width=3)

    items = [
        ("1", "咖啡店下午茶", "靠窗侧光干净 · 容易拍成看手机"),
        ("2", "秋日银杏", "氛围拉满 · 站着容易僵"),
        ("3", "夜市大排档", "烟火气足 · 灯光杂易糊"),
    ]
    top = 268
    card_h = 316
    gapy = 32
    for i, (num, name, desc) in enumerate(items):
        y = top + i * (card_h + gapy)
        d.rounded_rectangle([80, y, W - 80, y + card_h], radius=26, fill=PAPER2 + (255,), outline=LINE, width=2)
        # 序号圆
        cy = y + card_h / 2
        d.ellipse([122, cy - 52, 226, cy + 52], fill=GOLD_DEEP)
        nf = font(54, True)
        d.text((174 - text_ls_w(d, num, nf) / 2, cy - 38), num, font=nf, fill=PAPER + (255,))
        # 右侧取景框
        vw, vh = 168, 220
        vx, vy = W - 80 - 40 - vw, y + (card_h - vh) / 2
        d.rounded_rectangle([vx, vy, vx + vw, vy + vh], radius=16, fill=DARK + (255,))
        for k in (1, 2):
            d.line([vx + 12 + (vw - 24) * k / 3, vy + 12, vx + 12 + (vw - 24) * k / 3, vy + vh - 12],
                   fill=(255, 255, 255, 40), width=1)
            d.line([vx + 12, vy + 12 + (vh - 24) * k / 3, vx + vw - 12, vy + 12 + (vh - 24) * k / 3],
                   fill=(255, 255, 255, 40), width=1)
        d.rounded_rectangle([vx, vy, vx + vw, vy + vh], radius=16, outline=(255, 255, 255, 80), width=2)
        d.text((vx + vw / 2 - 26, vy + vh / 2 - 34), "?", font=font(56, True), fill=(255, 255, 255, 105))
        # 文案
        d.text((282, y + 74), name, font=font(50, True), fill=INK)
        d.text((282, y + 158), desc, font=font(26), fill=T2)
        d.text((282, y + 214), "评论区打「%s」" % num, font=font(24), fill=T3)

    by = top + 3 * (card_h + gapy) + 4
    center_text(d, by, "票数高的那个，我下期拍成完整九张图鉴", font(28), T2, ls=2, W=W)
    corner_chip(im, pos="tr")
    return im.convert("RGB")


# ---------------------------------------------------------------- 公众号头图
def build_header():
    W, H = 1664, 708
    im = base(W, H, PAPER2)
    d = ImageDraw.Draw(im)

    # 左侧：三张错落小样片
    thumbs = [
        (os.path.join(HOTPOT, "image_0.webp"), 168, 208),
        (os.path.join(SEASIDE, "image_1.jpg"), 168, 208),
        (os.path.join(HOTPOT, "image_8.webp"), 168, 208),
    ]
    xs = [120, 236, 352]
    ys = [268, 218, 300]
    for (p, tw, th), x, y in zip(thumbs, xs, ys):
        pic = rounded(load_fit(p, tw, th), 14)
        d.rounded_rectangle([x - 8, y - 8, x + tw + 8, y + th + 8], radius=18, fill=(255, 255, 255, 235),
                            outline=LINE, width=2)
        im.alpha_composite(pic, (x, y))

    tx = 600
    text_ls(d, (tx, 132), "POSE GUIDE · 姿势图鉴", font(26), GOLD_DEEP, ls=5)
    d.text((tx, 178), "9 个姿势图鉴", font=font(72, True), fill=INK)
    d.text((tx, 272), "火锅探店 + 海边旅拍，各 9 个", font=font(36, True), fill=GOLD_DEEP)
    d.line([tx, 352, tx + 96, 352], fill=GOLD, width=4)
    text_ls(d, (tx, 388), "照着剪影摆，不用再想「手放哪」", font(30), T2, ls=2)
    text_ls(d, (tx, 440), "选模板 → 取景框叠轮廓 → 对齐按快门", font(30), T2, ls=2)

    corner_chip(im, pos="br")
    return im.convert("RGB")


# ---------------------------------------------------------------- 取景框对照
def build_demo():
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    center_text(d, 48, "取景框叠剪影", font(56, True), INK, ls=4, W=W)
    center_text(d, 128, "照着轮廓站进去，构图就对齐了", font(28), T2, ls=2, W=W)
    d.line([(W - 150) // 2, 182, (W + 150) // 2, 182], fill=GOLD, width=3)

    pw, ph = 900, 500
    px = (W - pw) / 2
    fl = font(26, True)
    label_gap = 44

    def panel_label(y, s):
        d.rounded_rectangle([px, y, px + text_ls_w(d, s, fl) + 34, y + 40], radius=12, fill=(255, 255, 255, 238),
                            outline=LINE, width=1)
        d.text((px + 17, y + 6), s, font=fl, fill=INK)

    # 上：深色取景框 + 真实轮廓（反色为白）
    y1 = 248
    panel_label(y1 - label_gap + 2, "① 取景框里的剪影引导")
    d.rounded_rectangle([px, y1, px + pw, y1 + ph], radius=20, fill=DARK + (255,))
    for k in (1, 2):
        d.line([px + 16 + (pw - 32) * k / 3, y1 + 16, px + 16 + (pw - 32) * k / 3, y1 + ph - 16],
               fill=(255, 255, 255, 38), width=1)
        d.line([px + 16, y1 + 16 + (ph - 32) * k / 3, px + pw - 16, y1 + 16 + (ph - 32) * k / 3],
               fill=(255, 255, 255, 38), width=1)
    d.rounded_rectangle([px, y1, px + pw, y1 + ph], radius=20, outline=(255, 255, 255, 80), width=2)
    sil = Image.open(os.path.join(HOTPOT, "silhouette.png")).convert("RGBA")
    white = Image.new("RGBA", sil.size, (255, 255, 255, 0))
    white.putalpha(sil.getchannel("A").point(lambda v: int(v * 0.88)))
    th = int(ph * 0.80)
    tw = int(white.width * th / white.height)
    white = white.resize((tw, th), Image.LANCZOS)
    im.alpha_composite(white, (int(px + pw * 0.55 - tw / 2), int(y1 + ph * 0.53 - th / 2)))

    # 下：真实样片（按原始比例完整呈现）+ 说明
    y2 = y1 + ph + 58
    panel_label(y2 - label_gap + 2, "② 照着摆出来的效果")
    src = Image.open(os.path.join(HOTPOT, "image_0.webp")).convert("RGB")
    pwid = int(ph * src.width / src.height)
    pic = rounded(src.resize((pwid, ph), Image.LANCZOS), 20)
    im.alpha_composite(pic, (int(px), int(y2)))
    d.rounded_rectangle([px, y2, px + pwid - 1, y2 + ph - 1], radius=20, outline=(255, 255, 255, 150), width=2)
    tx2 = int(px + pwid + 42)
    d.text((tx2, y2 + 92), "同一套背景", font=font(40, True), fill=INK)
    d.text((tx2, y2 + 156), "手抬到哪、脚站哪", font=font(28), fill=T2)
    d.text((tx2, y2 + 202), "人在画面里占多大", font=font(28), fill=T2)
    d.text((tx2, y2 + 248), "轮廓先帮你框好了", font=font(28), fill=T2)
    d.line([tx2, y2 + 302, tx2 + 84, y2 + 302], fill=GOLD, width=4)
    d.text((tx2, y2 + 324), "剩下的只需要对齐", font=font(26), fill=T3)

    center_text(d, y2 + ph + 28, "样片来自模板库内的效果图", font(26), T3, ls=2, W=W)
    corner_chip(im, pos="tr")
    return im.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [
        ("poseguide-01-xhs-hotpot.jpg",
         build_grid(HOTPOT, "webp", "火锅店拍照 9 个姿势",
                    "照着摆就行 · 手放哪一眼就有答案", None,
                    "9 个姿势 · 收藏起来照着摆")),
        ("poseguide-02-xhs-seaside.jpg",
         build_grid(SEASIDE, "jpg", "海边拍照 9 个姿势",
                    "蓝调时刻 · 从站姿到坐姿一次收好", None,
                    "同一条海岸线 · 9 张不重样")),
        ("poseguide-03-xhs-points.jpg", build_points()),
        ("poseguide-04-wx-header-2.35x1.jpg", build_header()),
        ("poseguide-05-viewfinder-demo.jpg", build_demo()),
    ]
    for name, im in jobs:
        p = os.path.join(OUT, name)
        im.save(p, "JPEG", quality=92, subsampling=1)
        print("[OK] %dx%d  %s" % (im.size[0], im.size[1], p))


if __name__ == "__main__":
    main()
