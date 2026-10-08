# -*- coding: utf-8 -*-
"""
微信公众号「把照片变成一张能"扫"的海报」配图生成脚本。

素材来源（全部为项目内既有素材）：
  docs/marketing/assets/2026-10/autumn-0*.jpg        秋日样片
  docs/marketing/assets/2026-10/shot-01-fullscreen-plaza.jpg  取景框 + 剪影界面截图
  lumira_app_flutter/assets/images/logo.png           App 图标
  lumira_app_flutter/assets/images/watermark_sample.jpg

输出：docs/marketing/assets/2026-10/wx-20261005/
  wx-00-header-2.35x1.jpg   头条头图
  wx-01-poster-sample.jpg   配图 1  分享海报示例（照片 + 水印 + 二维码）
  wx-02-qr-closeup.jpg      配图 2  二维码特写（扫码打开同款模板）
  wx-03-viewfinder.jpg      配图 3  取景框 + 半透明剪影界面
  wx-04-endcard.jpg         文末配图 App 图标 + slogan

二维码为「品牌占位图形」（非真实可扫码），与 App 缩略图态一致，配合文中"效果示意"标注。
"""

import os
import random

from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = r"e:\Project\photo_post"
ASSETS = os.path.join(ROOT, "docs", "marketing", "assets", "2026-10")
OUT = os.path.join(ASSETS, "wx-20261005")
APP_ASSETS = os.path.join(ROOT, "lumira_app_flutter", "assets", "images")

GOLD = (201, 169, 110)
GOLD_DEEP = (176, 141, 79)
INK = (42, 38, 32)
T2 = (107, 100, 92)
T3 = (154, 143, 124)
PAPER = (253, 251, 247)
PAPER2 = (246, 241, 232)
BG = (239, 234, 225)
LINE = (226, 214, 191)

F_REG = r"C:\Windows\Fonts\msyh.ttc"
F_BOLD = r"C:\Windows\Fonts\msyhbd.ttc"
_font_cache = {}


def font(size, bold=False):
    key = (size, bold)
    if key not in _font_cache:
        _font_cache[key] = ImageFont.truetype(F_BOLD if bold else F_REG, size)
    return _font_cache[key]


def text_ls(draw, xy, s, f, fill, ls=0):
    """带字距的文本绘制，返回绘制宽度。xy 为左上角。"""
    x, y = xy
    for ch in s:
        draw.text((x, y), ch, font=f, fill=fill)
        x += draw.textlength(ch, font=f) + ls
    return x - xy[0] - (ls if s else 0)


def text_ls_w(draw, s, f, ls=0):
    return sum(draw.textlength(ch, font=f) for ch in s) + ls * max(0, len(s) - 1)


def cover_crop(im, w, h):
    """按 cover 方式裁剪到 w×h。"""
    r = max(w / im.width, h / im.height)
    nw, nh = int(im.width * r + 0.5), int(im.height * r + 0.5)
    im = im.resize((nw, nh), Image.LANCZOS)
    x = (nw - w) // 2
    y = (nh - h) // 3  # 略偏上，保人物头部
    return im.crop((x, y, x + w, y + h))


def rounded(im, r):
    mask = Image.new("L", im.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, im.width - 1, im.height - 1], radius=r, fill=255)
    out = im.convert("RGBA")
    out.putalpha(mask)
    return out


def drop_shadow(canvas, box, radius=24, blur=26, alpha=64, offset=(0, 16)):
    """在 canvas(RGBA) 上为 box=(x0,y0,x1,y1) 画柔和投影。"""
    x0, y0, x1, y1 = box
    sh = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.rounded_rectangle(
        [x0 + offset[0], y0 + offset[1], x1 + offset[0], y1 + offset[1]],
        radius=radius, fill=(60, 48, 28, alpha),
    )
    sh = sh.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(sh)


def qr_graphic(size, seed=17):
    """品牌占位二维码图形（21×21 模块，含三个定位角），非真实可扫码。"""
    n = 21
    rnd = random.Random(seed)
    grid = [[0] * n for _ in range(n)]

    def finder(r, c):
        for i in range(7):
            for j in range(7):
                border = i in (0, 6) or j in (0, 6)
                core = 2 <= i <= 4 and 2 <= j <= 4
                grid[r + i][c + j] = 1 if (border or core) else 0

    # 定位角
    finder(0, 0)
    finder(0, n - 7)
    finder(n - 7, 0)
    # 时序/校正图形
    grid[n - 8][8] = 1
    for i in range(8):
        grid[6][i] = 1 if i % 2 == 0 else grid[6][i]
    # 数据区随机（避开定位角与分隔带）
    for r in range(n):
        for c in range(n):
            if (r < 8 and c < 8) or (r < 8 and c >= n - 8) or (r >= n - 8 and c < 8):
                continue
            if r == 6 or c == 6:
                continue
            grid[r][c] = 1 if rnd.random() < 0.46 else 0
    # 分隔带留白
    for i in range(8):
        grid[7][i] = 0
        grid[i][7] = 0
        grid[7][n - 1 - i] = 0
        grid[i][n - 8] = 0

    cell = size / n
    img = Image.new("RGB", (size, size), (255, 255, 255))
    d = ImageDraw.Draw(img)
    for r in range(n):
        for c in range(n):
            if grid[r][c]:
                x0 = int(round(c * cell))
                y0 = int(round(r * cell))
                x1 = int(round((c + 1) * cell))
                y1 = int(round((r + 1) * cell))
                d.rectangle([x0, y0, x1 - 1, y1 - 1], fill=INK)
    return img


def chip(draw, xy, s, f, fg, bg, pad=(16, 8), radius=14):
    w = text_ls_w(draw, s, f)
    asc, desc = f.getmetrics()
    h = asc + desc
    x, y = xy
    draw.rounded_rectangle([x, y, x + w + pad[0] * 2, y + h + pad[1] * 2], radius=radius, fill=bg)
    draw.text((x + pad[0], y + pad[1]), s, font=f, fill=fg)


def build_poster_card(photo_path, w, h, author, slogan, seed=17):
    """生成一张 3:4 分享海报卡片（照片 + 水印 + 二维码）。"""
    s = w / 900.0
    card = Image.new("RGBA", (w, h), PAPER + (255,))
    d = ImageDraw.Draw(card)
    # 内描边
    inset = int(26 * s)
    d.rectangle([inset, inset, w - inset, h - inset], outline=LINE, width=max(1, int(1.4 * s)))

    pad = int(58 * s)
    # 品牌行
    fb = font(int(40 * s), True)
    text_ls(d, (pad, int(66 * s)), "如画 LUMIRA", fb, GOLD_DEEP, ls=int(5 * s))
    fs = font(int(24 * s))
    tag = "分享海报"
    text_ls(d, (w - pad - text_ls_w(d, tag, fs, int(4 * s)), int(76 * s)), tag, fs, T3, ls=int(4 * s))
    # 分隔线
    d.line([pad, int(132 * s), w - pad, int(132 * s)], fill=LINE, width=max(1, int(1.4 * s)))

    # 照片
    ph_y = int(164 * s)
    ph_h = int(632 * s)
    ph = cover_crop(Image.open(photo_path).convert("RGB"), w - pad * 2, ph_h)
    card.paste(ph, (pad, ph_y))
    d.rectangle([pad, ph_y, w - pad - 1, ph_y + ph_h - 1], outline=LINE, width=max(1, int(1.4 * s)))
    # 照片左下角水印
    fw = font(int(26 * s), True)
    d.rectangle([pad, ph_y + ph_h - int(56 * s), pad + int(text_ls_w(d, "如画 Lumira", fw) + 34 * s), ph_y + ph_h],
                fill=(28, 24, 18, 150))
    text_ls(d, (pad + int(17 * s), ph_y + ph_h - int(50 * s)), "如画 Lumira", fw, PAPER, ls=int(2 * s))

    # 底部：左水印信息 + 右二维码
    base = ph_y + ph_h + int(42 * s)
    f1 = font(int(30 * s), True)
    text_ls(d, (pad, base), "如画 Lumira · " + author, f1, INK, ls=int(2 * s))
    f2 = font(int(24 * s))
    text_ls(d, (pad, base + int(52 * s)), "AI 合成示意画面 · 效果示意", f2, T3, ls=int(2 * s))
    # 二维码块
    qs = int(160 * s)
    qx = w - pad - qs
    qy = base - int(8 * s)
    d.rounded_rectangle([qx - int(12 * s), qy - int(12 * s), qx + qs + int(12 * s), qy + qs + int(12 * s)],
                        radius=int(16 * s), fill=(255, 255, 255), outline=GOLD, width=max(1, int(1.6 * s)))
    card.paste(qr_graphic(qs, seed), (qx, qy))
    fc = font(int(20 * s))
    cw = text_ls_w(d, "长按识别二维码", fc, int(2 * s))
    text_ls(d, (qx + qs // 2 - cw / 2, qy + qs + int(10 * s)), "长按识别二维码", fc, T3, ls=int(2 * s))

    # 底部 slogan
    y = h - int(122 * s)
    d.line([pad, h - int(148 * s), w - pad, h - int(148 * s)], fill=LINE, width=max(1, int(1.4 * s)))
    fsg = font(int(30 * s), True)
    sw = text_ls_w(d, slogan, fsg, int(8 * s))
    text_ls(d, ((w - sw) / 2, y), slogan, fsg, GOLD_DEEP, ls=int(8 * s))
    return card


def build_header():
    W, H = 1664, 708
    header = Image.new("RGBA", (W, H), PAPER2 + (255,))
    d = ImageDraw.Draw(header)
    # 柔和暖白渐变
    grad = Image.new("L", (1, H))
    for y in range(H):
        grad.putpixel((0, y), int(18 * (1 - y / H)))
    shade = Image.new("RGBA", (W, H), GOLD + (0,))
    shade.putalpha(grad.resize((W, H)))
    header.alpha_composite(shade)
    d.rectangle([26, 26, W - 27, H - 27], outline=LINE, width=2)

    # 左侧海报卡
    ch = 596
    cw = int(ch * 3 / 4)
    card = build_poster_card(os.path.join(ASSETS, "autumn-01-ginkgo.jpg"), cw, ch, "@随记", "照着模板拍，秒出大片")
    cx, cy = 116, (H - ch) // 2
    drop_shadow(header, (cx, cy, cx + cw, cy + ch), radius=10, blur=30, alpha=70, offset=(0, 18))
    header.alpha_composite(card, (cx, cy))

    # 右侧文案
    tx = cx + cw + 96
    fk = font(26)
    text_ls(d, (tx, 158), "SHARE POSTER · 分享海报", fk, GOLD_DEEP, ls=6)
    ft = font(66, True)
    d.text((tx, 206), "把照片变成", font=ft, fill=INK)
    d.text((tx, 288), "一张能“扫”的海报", font=ft, fill=INK)
    d.line([tx, 386, tx + 92, 386], fill=GOLD, width=4)
    fsub = font(30)
    text_ls(d, (tx, 424), "照片 · 水印 · 二维码，扫码打开同款模板", fsub, T2, ls=2)
    chip(d, (tx, 498), "效果示意", font(24), T3, PAPER)
    return header.convert("RGB")


def build_qr_closeup():
    S = 1080
    im = Image.new("RGBA", (S, S), PAPER + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([26, 26, S - 27, S - 27], outline=LINE, width=2)

    card = 660
    box = ((S - card) // 2, 150, (S + card) // 2, 150 + card)
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([box[0], box[1] + 14, box[2], box[3] + 14], radius=28,
                                             fill=(60, 48, 28, 60))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(24)))
    d.rounded_rectangle(box, radius=28, fill=(255, 255, 255), outline=GOLD, width=2)
    qs = 520
    im.paste(qr_graphic(qs, 23), (box[0] + (card - qs) // 2, box[1] + (card - qs) // 2))

    ft = font(48, True)
    t = "扫码打开同款模板"
    tw = text_ls_w(d, t, ft, 6)
    text_ls(d, ((S - tw) / 2, 866), t, ft, INK, ls=6)
    fs = font(28)
    s2 = "取景框会叠出一条半透明剪影，照着站就行"
    sw = text_ls_w(d, s2, fs, 2)
    text_ls(d, ((S - sw) / 2, 946), s2, fs, T2, ls=2)
    chip(d, ((S - (text_ls_w(d, "效果示意", font(22)) + 32)) / 2, 1000), "效果示意", font(22), T3, PAPER)
    return im.convert("RGB")


def build_viewfinder():
    src = Image.open(os.path.join(ASSETS, "shot-01-fullscreen-plaza.jpg")).convert("RGB")
    # 裁掉顶部状态栏与底部手势条
    src = src.crop((0, 84, src.width, src.height - 96))
    w = 1080
    h = int(src.height * w / src.width)
    return src.resize((w, h), Image.LANCZOS)


def build_endcard():
    S = 1080
    im = Image.new("RGBA", (S, S), PAPER + (255,))
    d = ImageDraw.Draw(im)
    d.rectangle([26, 26, S - 27, S - 27], outline=LINE, width=2)

    icon = Image.open(os.path.join(APP_ASSETS, "logo.png")).convert("RGBA").resize((300, 300), Image.LANCZOS)
    icon = rounded(icon, 66)
    shadow = Image.new("RGBA", im.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle([390, 264, 690, 564], radius=66, fill=(60, 48, 28, 55))
    im.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(26)))
    im.alpha_composite(icon, (390, 250))

    fw = font(62, True)
    t = "如画 Lumira"
    tw = text_ls_w(d, t, fw, 8)
    text_ls(d, ((S - tw) / 2, 618), t, fw, INK, ls=8)
    fs = font(40, True)
    t2 = "照着模板拍，秒出大片"
    t2w = text_ls_w(d, t2, fs, 10)
    text_ls(d, ((S - t2w) / 2, 716), t2, fs, GOLD_DEEP, ls=10)
    d.line([(S - 120) // 2, 800, (S + 120) // 2, 800], fill=LINE, width=2)
    f3 = font(26)
    t3 = "应用商店搜「如画 Lumira」· 鸿蒙已上架，iOS 即将上架"
    t3w = text_ls_w(d, t3, f3, 2)
    text_ls(d, ((S - t3w) / 2, 838), t3, f3, T2, ls=2)
    return im.convert("RGB")


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = []

    header = build_header()
    p = os.path.join(OUT, "wx-00-header-2.35x1.jpg")
    header.save(p, "JPEG", quality=92, subsampling=1)
    jobs.append(p)

    poster = build_poster_card(os.path.join(ASSETS, "autumn-01-ginkgo.jpg"), 1080, 1440, "@随记", "照着模板拍，秒出大片")
    p = os.path.join(OUT, "wx-01-poster-sample.jpg")
    poster.convert("RGB").save(p, "JPEG", quality=92, subsampling=1)
    jobs.append(p)

    p = os.path.join(OUT, "wx-02-qr-closeup.jpg")
    build_qr_closeup().save(p, "JPEG", quality=92, subsampling=1)
    jobs.append(p)

    p = os.path.join(OUT, "wx-03-viewfinder.jpg")
    build_viewfinder().save(p, "JPEG", quality=92, subsampling=1)
    jobs.append(p)

    p = os.path.join(OUT, "wx-04-endcard.jpg")
    build_endcard().save(p, "JPEG", quality=92, subsampling=1)
    jobs.append(p)

    for p in jobs:
        im = Image.open(p)
        print(f"[OK] {im.size[0]}x{im.size[1]}  {p}")


if __name__ == "__main__":
    main()
