# -*- coding: utf-8 -*-
"""
「互动破冰波」配图生成脚本（常态-2026-10）。

输出：docs/marketing/assets/2026-10/interact-20261007/
  interact-01-xhs-failstack.jpg     小红书①首图 3:4  「最想删的 20 张」拼贴
  interact-02-xhs-stance.jpg        小红书②首图 3:4  站位对比（永远居中 vs 换站位）
  interact-03-xhs-points.jpg        小红书③首图 3:4  三宫格点单（咖啡店/银杏/夜景）
  interact-04-header-2.35x1.jpg     公众号头图 2.35:1 「废片拯救行动」征集横幅

说明：
  - 全部为程序绘制的示意图，人物一律使用「半透明人形剪影」占位，
    **不使用任何真实人物照片**，每张均在角落标注「效果示意」。
  - 延续视觉锤：人形剪影 + 取景框。
"""

import os
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = r"e:\Project\photo_post"
ASSETS = os.path.join(ROOT, "docs", "marketing", "assets", "2026-10")
OUT = os.path.join(ASSETS, "interact-20261007")

GOLD = (201, 169, 110)
GOLD_DEEP = (176, 141, 79)
INK = (42, 38, 32)
T2 = (107, 100, 92)
T3 = (154, 143, 124)
PAPER = (253, 251, 247)
PAPER2 = (246, 241, 232)
BG = (239, 234, 225)
LINE = (226, 214, 191)
SIL = (120, 108, 92)          # 剪影主色
SIL_SOFT = (150, 140, 126)    # 次要剪影
CORAL = (198, 116, 96)        # 标记色（叉号）

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


def chip(draw, xy, s, f, fg, bg, pad=(16, 8), radius=14):
    w = text_ls_w(draw, s, f)
    asc, desc = f.getmetrics()
    h = asc + desc
    x, y = xy
    draw.rounded_rectangle([x, y, x + w + pad[0] * 2, y + h + pad[1] * 2], radius=radius, fill=bg)
    draw.text((x + pad[0], y + pad[1]), s, font=f, fill=fg)


def corner_chip(canvas, s="效果示意"):
    """右下角统一的「效果示意」标注。"""
    d = ImageDraw.Draw(canvas)
    f = font(24)
    w = text_ls_w(d, s, f)
    asc, desc = f.getmetrics()
    pad_x, pad_y = 18, 10
    bw, bh = w + pad_x * 2, asc + desc + pad_y * 2
    x, y = canvas.width - bw - 34, canvas.height - bh - 34
    d.rounded_rectangle([x, y, x + bw, y + bh], radius=14, fill=(255, 255, 255, 220), outline=LINE, width=1)
    d.text((x + pad_x, y + pad_y), s, font=f, fill=T3)


def make_silhouette(h, fill, turn=False):
    """简化的半透明人形剪影（头 + 躯干 + 双臂 + 双腿）。h 为总高度。"""
    h = int(round(h))
    w = int(h * 0.70)
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    cx = w / 2.0
    hr = h * 0.085
    ox = h * 0.04 if turn else 0.0       # 转身时头部略偏
    d.ellipse([cx - hr + ox, h * 0.02, cx + hr + ox, h * 0.02 + 2 * hr], fill=fill)
    tw = h * 0.20
    d.rounded_rectangle([cx - tw / 2, h * 0.20, cx + tw / 2, h * 0.60], radius=int(h * 0.05), fill=fill)
    aw = h * 0.058
    lift = h * 0.10 if turn else 0.0     # 手臂略抬
    d.rounded_rectangle([cx - tw / 2 - aw * 0.8, h * 0.22 - lift, cx - tw / 2 + aw * 0.2, h * 0.56 - lift],
                        radius=int(aw * 0.5), fill=fill)
    d.rounded_rectangle([cx + tw / 2 - aw * 0.2, h * 0.22 + lift, cx + tw / 2 + aw * 0.8, h * 0.56 + lift],
                        radius=int(aw * 0.5), fill=fill)
    lw = h * 0.075
    spread = h * 0.11 if turn else h * 0.085
    d.rounded_rectangle([cx - spread - lw * 0.2, h * 0.58, cx - spread - lw * 0.2 + lw, h * 0.98],
                        radius=int(lw * 0.5), fill=fill)
    d.rounded_rectangle([cx + spread - lw + lw * 0.2, h * 0.58, cx + spread - lw + lw * 0.2 + lw, h * 0.98],
                        radius=int(lw * 0.5), fill=fill)
    return im


def paste_sil(canvas, cx, cy, h, fill=SIL, turn=False, alpha=115):
    sil = make_silhouette(h, fill)
    if alpha < 255:
        a = sil.getchannel("A").point(lambda v: int(v * alpha / 255))
        sil.putalpha(a)
    canvas.alpha_composite(sil, (int(cx - sil.width / 2), int(cy - sil.height / 2)))


def rule_of_thirds(d, box, color):
    x0, y0, x1, y1 = box
    for i in (1, 2):
        x = x0 + (x1 - x0) * i / 3
        y = y0 + (y1 - y0) * i / 3
        d.line([x, y0, x, y1], fill=color, width=1)
        d.line([x0, y, x1, y], fill=color, width=1)


def viewfinder(canvas, box, silhouette_center, h, turn=False, label=None):
    """在 box 内画一个取景框 + 剪影 + 三分线。"""
    d = ImageDraw.Draw(canvas)
    x0, y0, x1, y1 = box
    d.rounded_rectangle([x0, y0, x1, y1], radius=18, fill=(58, 52, 44, 255))
    rule_of_thirds(d, (x0 + 10, y0 + 10, x1 - 10, y1 - 10), (255, 255, 255, 42))
    d.rounded_rectangle([x0, y0, x1, y1], radius=18, outline=(255, 255, 255, 70), width=2)
    cx = x0 + (x1 - x0) * silhouette_center[0]
    cy = y0 + (y1 - y0) * silhouette_center[1]
    paste_sil(canvas, cx, cy, h, SIL_SOFT, turn=turn, alpha=150)
    if label:
        f = font(26, True)
        d.rounded_rectangle([x0, y0 - 46, x0 + text_ls_w(d, label, f) + 34, y0 - 6], radius=12, fill=(255, 255, 255, 235))
        d.text((x0 + 17, y0 - 42), label, font=f, fill=INK)


def base(W, H, bg=PAPER):
    im = Image.new("RGBA", (W, H), bg + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([26, 26, W - 27, H - 27], outline=LINE, width=2)
    return im


# ---------------------------------------------------------------- 图 1
def build_failstack():
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    ft = font(58, True)
    center_text(d, 92, "相册里最想删的", ft, INK, ls=4, W=W)
    center_text(d, 168, "20 张", font(86, True), GOLD_DEEP, ls=6, W=W)
    center_text(d, 284, "我把它拼成了一张图", font(34), T2, ls=3, W=W)
    d.line([(W - 140) // 2, 350, (W + 140) // 2, 350], fill=GOLD, width=3)

    # 4 x 5 = 20 格
    cols, rows = 4, 5
    left, right = 132, W - 132
    top = 384
    cell_gap = 14
    cw = (right - left - cell_gap * (cols - 1)) // cols
    ch = 168
    rnd = random.Random(20261007)
    tones = [(246, 241, 232), (242, 236, 226), (250, 247, 241)]
    for r in range(rows):
        for c in range(cols):
            x = left + c * (cw + cell_gap)
            y = top + r * (ch + cell_gap)
            d.rounded_rectangle([x, y, x + cw, y + ch], radius=14, fill=rnd.choice(tones) + (255,))
            # 剪影基本都站在中间同一位置（呼应"永远站同一个位置"）
            jx = rnd.uniform(-6, 6)
            paste_sil(im, x + cw / 2 + jx, y + ch / 2 + 6, ch * 0.68, SIL, alpha=rnd.randint(70, 105))
            # 部分格打叉
            if rnd.random() < 0.55:
                m = 24
                d.line([x + m, y + m, x + cw - m, y + ch - m], fill=CORAL + (185,), width=5)
                d.line([x + cw - m, y + m, x + m, y + ch - m], fill=CORAL + (185,), width=5)

    fy = top + rows * ch + (rows - 1) * cell_gap + 30
    center_text(d, fy, "同一套站姿，换了 20 个背景", font(30), T2, ls=3, W=W)

    corner_chip(im)
    return im.convert("RGB")


# ---------------------------------------------------------------- 图 2
def build_stance():
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    center_text(d, 96, "差的不是脸", font(64, True), INK, ls=6, W=W)
    center_text(d, 186, "是我永远站在同一个位置", font(40, True), GOLD_DEEP, ls=4, W=W)
    d.line([(W - 140) // 2, 268, (W + 140) // 2, 268], fill=GOLD, width=3)

    gap = 44
    pw = (W - 92 * 2 - gap) // 2
    ph = int(pw * 1.5)
    py = 340
    boxes = [(92, py, 92 + pw, py + ph), (92 + pw + gap, py, 92 + pw + gap + pw, py + ph)]

    viewfinder(im, boxes[0], (0.50, 0.56), ph * 0.62, turn=False, label="A · 永远居中直立")
    viewfinder(im, boxes[1], (0.34, 0.54), ph * 0.66, turn=True, label="B · 站位换一换")

    # 中间 VS
    fc = font(40, True)
    d.ellipse([W / 2 - 46, py + ph / 2 - 46, W / 2 + 46, py + ph / 2 + 46], fill=(255, 255, 255, 235), outline=GOLD, width=3)
    vw = text_ls_w(d, "VS", fc)
    text_ls(d, (W / 2 - vw / 2, py + ph / 2 - 30), "VS", fc, GOLD_DEEP)

    ty = py + ph + 56
    fy = font(34)
    center_text(d, ty, "同一个我、同一片背景", fy, INK, ls=3, W=W)
    center_text(d, ty + 62, "把「站哪」这件事，交给取景框里的剪影", font(30), T2, ls=2, W=W)

    corner_chip(im)
    return im.convert("RGB")


# ---------------------------------------------------------------- 图 3
def build_points():
    W, H = 1080, 1440
    im = base(W, H)
    d = ImageDraw.Draw(im)

    center_text(d, 96, "下期拍什么", font(64, True), INK, ls=6, W=W)
    center_text(d, 186, "你说了算", font(52, True), GOLD_DEEP, ls=6, W=W)
    d.line([(W - 140) // 2, 274, (W + 140) // 2, 274], fill=GOLD, width=3)

    items = [
        ("1", "咖啡店", "靠窗侧身 · 手扶杯 · 半身带环境"),
        ("2", "银杏", "树下侧身抬头 · 手接落叶"),
        ("3", "夜景", "街灯剪影 · 侧脸轮廓 · 留天空"),
    ]
    top = 360
    card_h = 250
    gapy = 34
    for i, (num, name, desc) in enumerate(items):
        y = top + i * (card_h + gapy)
        d.rounded_rectangle([92, y, W - 92, y + card_h], radius=24, fill=PAPER2 + (255,), outline=LINE, width=2)
        # 序号圆
        d.ellipse([132, y + card_h / 2 - 46, 224, y + card_h / 2 + 46], fill=GOLD_DEEP)
        fn = font(48, True)
        nw = text_ls_w(d, num, fn)
        text_ls(d, (178 - nw / 2, y + card_h / 2 - 34), num, fn, PAPER)
        # 右侧小取景框 + 剪影
        vw_, vh_ = 132, 176
        vx, vy = W - 92 - 40 - vw_, y + (card_h - vh_) / 2
        d.rounded_rectangle([vx, vy, vx + vw_, vy + vh_], radius=12, fill=(58, 52, 44, 255))
        d.rounded_rectangle([vx, vy, vx + vw_, vy + vh_], radius=12, outline=(255, 255, 255, 70), width=2)
        paste_sil(im, vx + vw_ * 0.42, vy + vh_ * 0.56, vh_ * 0.66, SIL_SOFT, turn=(i == 1), alpha=160)
        # 文案
        fnm = font(46, True)
        d.text((262, y + 56), name, font=fnm, fill=INK)
        fd = font(26)
        d.text((262, y + 128), desc, font=fd, fill=T2)
        d.text((262, y + 176), "评论区打「%s」" % num, font=font(24), fill=T3)

    by = top + 3 * (card_h + gapy) + 6
    center_text(d, by, "票最高的那一个，我下期拍成完整一组", font(30), T2, ls=2, W=W)

    corner_chip(im)
    return im.convert("RGB")


# ---------------------------------------------------------------- 图 4
def build_header():
    W, H = 1664, 708
    im = Image.new("RGBA", (W, H), PAPER2 + (255,))
    # 暖白渐变
    grad = Image.new("L", (1, H))
    for y in range(H):
        grad.putpixel((0, y), int(20 * (1 - y / H)))
    shade = Image.new("RGBA", (W, H), GOLD + (0,))
    shade.putalpha(grad.resize((W, H)))
    im.alpha_composite(shade)
    d = ImageDraw.Draw(im)
    d.rectangle([26, 26, W - 27, H - 27], outline=LINE, width=2)

    # 左侧：三张"拍立得"小卡（两张打叉，一张打勾）
    rnd = random.Random(77)
    card_w = 236
    for i, (off, rot) in enumerate([(-26, -7), (6, 3), (40, 9)]):
        cw_, chh = card_w, int(card_w * 1.16)
        x = 132 + i * 132
        y = 210 + int(off * 1.2)
        card = Image.new("RGBA", (cw_, chh), (255, 255, 255, 255))
        cd = ImageDraw.Draw(card)
        cd.rectangle([0, 0, cw_ - 1, chh - 1], outline=LINE, width=2)
        cd.rectangle([16, 16, cw_ - 16, chh - 66], fill=(240, 234, 223, 255))
        sil = make_silhouette(int((chh - 98) * 0.9), SIL_SOFT)
        a = sil.getchannel("A").point(lambda v: int(v * 0.62))
        sil.putalpha(a)
        card.alpha_composite(sil, (int((cw_ - sil.width) / 2), 30))
        ok = (i == 2)
        cd.text((22, chh - 52), "?" if ok else "×", font=font(40, True), fill=GOLD_DEEP if ok else CORAL)
        cd.text((cw_ - 108, chh - 44), "废片" if not ok else "救", font=font(26, True), fill=T3)
        card = card.rotate(rot, expand=True, resample=Image.BICUBIC)
        sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
        ImageDraw.Draw(sh).rounded_rectangle([x, y + 16, x + card.width, y + card.height + 16], radius=10,
                                             fill=(60, 48, 28, 62))
        im.alpha_composite(sh.filter(ImageFilter.GaussianBlur(20)))
        im.alpha_composite(card, (x, y))

    # 右侧文案
    tx = 640
    fk = font(26)
    text_ls(d, (tx, 138), "FAQIAN RESCUE · 废片拯救行动", fk, GOLD_DEEP, ls=5)
    d.text((tx, 186), "晒出你最「冒犯」的", font=font(66, True), fill=INK)
    d.text((tx, 268), "一张照片", font=font(66, True), fill=INK)
    d.line([tx, 366, tx + 92, 366], fill=GOLD, width=4)
    text_ls(d, (tx, 402), "留言区交出来，我挑一些认真复盘：", font(30), T2, ls=2)
    text_ls(d, (tx, 452), "这张照片，当时卡在了哪一步", font(30), T2, ls=2)
    fch = font(24)
    cw2 = text_ls_w(d, "效果示意", fch)
    asc, desc = fch.getmetrics()
    d.rounded_rectangle([W - 34 - (cw2 + 36), H - 34 - (asc + desc + 20), W - 34, H - 34],
                        radius=14, fill=(255, 255, 255, 230), outline=LINE, width=1)
    d.text((W - 34 - (cw2 + 36) + 18, H - 34 - (asc + desc + 20) + 10), "效果示意", font=fch, fill=T3)

    return im.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [
        ("interact-01-xhs-failstack.jpg", build_failstack()),
        ("interact-02-xhs-stance.jpg", build_stance()),
        ("interact-03-xhs-points.jpg", build_points()),
        ("interact-04-header-2.35x1.jpg", build_header()),
    ]
    for name, im in jobs:
        p = os.path.join(OUT, name)
        im.save(p, "JPEG", quality=92, subsampling=1)
        print(f"[OK] {im.size[0]}x{im.size[1]}  {p}")


if __name__ == "__main__":
    main()
