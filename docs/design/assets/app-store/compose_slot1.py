# -*- coding: utf-8 -*-
"""合成首图展示图 1080x1920（安卓基准），左右卡片等高对称（均裁为 9:16）"""
from PIL import Image, ImageDraw, ImageFont

W, H = 1080, 1920
CREAM = (250, 246, 238, 255)
INK = (62, 58, 52, 255)
MUTED = (134, 132, 124, 255)
GREEN = (158, 178, 158, 255)
GOLD = (200, 170, 106, 255)
PANEL = (243, 238, 228, 255)
BORDER = (219, 211, 197, 255)

def font(path, size):
    return ImageFont.truetype(path, size)

songti = "C:/Windows/Fonts/simsun.ttc"
yahei = "C:/Windows/Fonts/msyh.ttc"

img = Image.new("RGB", (W, H), CREAM)
d = ImageDraw.Draw(img)

# ---------- 顶部 Kicker ----------
MARGIN = 76
d.text((MARGIN, 120), "如 画  L U M I R A", font=font(songti, 30), fill=MUTED)
d.line([(MARGIN, 176), (MARGIN + 300, 176)], fill=GOLD, width=3)

# ---------- 大标题两行 ----------
d.text((MARGIN - 2, 216), "照着模板", font=font(songti, 146), fill=INK)
d.text((MARGIN - 2, 378), "拍出大片", font=font(songti, 146), fill=INK)
d.text((MARGIN, 560), "姿势剪影实时引导 · 照着摆就出片", font=font(yahei, 42), fill=MUTED)

# ---------- 照片统一裁为 9:16，等高 ----------
gap = 52
card_w = (W - MARGIN * 2 - gap) // 2

left_src = Image.open("d:/app/projects/photo_post/docs/design/assets/app-store/slot1_left_stiff_from_template.png").convert("RGB")
right_src = Image.open("d:/app/projects/photo_post/docs/design/assets/app-store/slot1_right_template_cover.png").convert("RGB")

def crop_9_16(im):
    w, h = im.size
    target = 9 / 16
    if w / h > target:
        nw = int(h * target)
        x0 = (w - nw) // 2
        return im.crop((x0, 0, x0 + nw, h))
    else:
        nh = int(w / target)
        y0 = (h - nh) // 2
        return im.crop((0, y0, w, y0 + nh))

ph = int(card_w * 16 / 9)
left = crop_9_16(left_src).resize((card_w, ph), Image.LANCZOS)
right = crop_9_16(right_src).resize((card_w, ph), Image.LANCZOS)

# ---------- 标签 ----------
chip_h = 74
cards_top = 660
label_y = cards_top + 4

def label(text, cx):
    f = font(yahei, 28)
    bbox = d.textbbox((0, 0), text, font=f)
    tw = bbox[2] - bbox[0]
    th = bbox[3] - bbox[1]
    pw = tw + 48
    lx = cx - pw // 2
    d.rounded_rectangle([lx, label_y, lx + pw, label_y + chip_h - 12], radius=(chip_h - 12) // 2, fill=GREEN)
    d.text((lx + 24, label_y + (chip_h - 12 - th) / 2 - bbox[1]), text, font=f, fill=(255, 255, 255, 255))

label(" 随手拍的废片 ", MARGIN + card_w // 2)
label(" 套上模板的出片 ", W - MARGIN - card_w // 2)

# ---------- 照片 ----------
photo_top = cards_top + chip_h + 26
rx = W - MARGIN - card_w

def paste(pil, x, y):
    w, h = pil.size
    pad = 12
    d.rounded_rectangle([x - pad, y - pad, x + w + pad, y + h + pad], radius=32, fill=PANEL, outline=BORDER, width=2)
    cp = pil.copy()
    mask = Image.new("L", pil.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w - 1, h - 1], radius=22, fill=255)
    cp.putalpha(mask)
    img.paste(cp, (x, y), mask)

paste(left, MARGIN, photo_top)
paste(right, rx, photo_top)

# ---------- 中间"套模板"圆形指示 ----------
cy = photo_top + ph // 2
cr = 54
d.ellipse([W // 2 - cr, cy - cr, W // 2 + cr, cy + cr], fill=GOLD)
d.text((W // 2 - 52, cy - 19), "套模板", font=font(yahei, 34), fill=(255, 255, 255, 255))
d.line([W // 2 - cr - 38, cy, W // 2 - cr - 6, cy], fill=GOLD, width=3)
d.line([W // 2 + cr + 6, cy, W // 2 + cr + 38, cy], fill=GOLD, width=3)

# ---------- 底部 ----------
d.line([(MARGIN, 1630), (MARGIN + 240, 1630)], fill=GOLD, width=3)
d.text((MARGIN, 1666), "不会摆姿势？照着模板剪影，秒出大片", font=font(songti, 42), fill=INK)
brand = font(songti, 38)
cur = d.textlength("如画 · Lumira", font=brand)
d.text((MARGIN, 1756), "如画 · Lumira", font=brand, fill=INK)
d.text((MARGIN + cur + 18, 1760), "记录平凡生活里的每一帧如画", font=font(yahei, 32), fill=MUTED)

out = "d:/app/projects/photo_post/docs/design/assets/app-store/slot1_showcase_1080x1920.png"
img.save(out, "PNG")
print("saved", out)