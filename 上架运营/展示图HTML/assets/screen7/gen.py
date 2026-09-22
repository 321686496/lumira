# -*- coding: utf-8 -*-
"""用真实素材精确拼合 Screen7 展示图（1080x1920）。素材仅等比缩放，不裁剪不变形。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_v2.png"
FONT = "C:/Windows/Fonts/msyh.ttc"

W, H = 1080, 1920

# ---------- 背景：奶油-暖米莫兰迪渐变 ----------
top = (252, 250, 246)
bot = (239, 230, 216)
bg = Image.new("RGB", (W, H))
stripe = Image.new("RGB", (1, H))
for y in range(H):
    t = y / (H - 1)
    stripe.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
bg = stripe.resize((W, H))

# ---------- 等比载图 ----------
def load_resize(path, width):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    return im.resize((width, int(width * h / w)), Image.LANCZOS)

phone_img = load_resize(f"{ASSETS}/drawer.png", 360)          # 1308x2880 -> 360x793
p1 = load_resize(f"{ASSETS}/poster1.jpg", 264)                # 1080x2308 -> 264x564
p2 = load_resize(f"{ASSETS}/poster2.jpg", 300)                # 1080x2488 -> 300x691
p3 = load_resize(f"{ASSETS}/poster3.jpg", 268)                # 1080x2488 -> 268x617

# ---------- 顶层图层（海报/手机，带透明） ----------
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def paste_rot(img, cx, cy, angle, shadow=False):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    if shadow:
        sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        sd = Image.new("L", rot.size, 0)
        dr = ImageDraw.Draw(sd)
        dr.rounded_rectangle([6, 8, rot.size[0] - 6, rot.size[1] + 10], radius=26, fill=90)
        sd = sd.filter(ImageFilter.GaussianBlur(18))
        sh.putalpha(sd)
        layer.paste(sh, (cx - sh.size[0] // 2, cy - sh.size[1] // 2 + 6), sh)
    layer.paste(rot, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), rot)

# 手机壳（深色圆角 frame）
shell_pad = 14
shell_w = phone_img.width + shell_pad * 2
shell_h = phone_img.height + shell_pad * 2
shell_cx, shell_cy = 560, 1120
shell = Image.new("RGBA", (shell_w, shell_h), (0, 0, 0, 0))
d = ImageDraw.Draw(shell)
d.rounded_rectangle([0, 0, shell_w - 1, shell_h - 1], radius=56, fill=(14, 12, 11, 255))
# 灵动岛
d.rounded_rectangle([shell_w // 2 - 60, 22, shell_w // 2 + 60, 52], radius=22, fill=(14, 12, 11, 255))
layer.paste(shell, (shell_cx - shell_w // 2, shell_cy - shell_h // 2), shell)
# 屏幕
screen = phone_img.resize(
    (phone_img.width, phone_img.height), Image.LANCZOS
)
mask = Image.new("L", screen.size, 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, screen.size[0] - 1, screen.size[1] - 1], radius=40, fill=255)
screen.putalpha(mask)
layer.paste(screen, (shell_cx - screen.size[0] // 2, shell_cy - screen.size[1] // 2), screen)

# 海报（带投影 + 旋转）
paste_rot(p1, 300, 760, -6, shadow=True)
paste_rot(p2, 800, 520, 5, shadow=True)
paste_rot(p3, 820, 1320, -3, shadow=True)

out = Image.alpha_composite(bg.convert("RGBA"), layer)

# ---------- 顶部极简引导 ----------
dr = ImageDraw.Draw(out)
gold = (201, 174, 124)
ink = (58, 51, 41)
dr.rounded_rectangle([72, 96, 72 + 44, 98], radius=2, fill=gold)
try:
    ft = ImageFont.truetype(FONT, 40)
except Exception:
    ft = ImageFont.load_default()
dr.text((142, 76), "把你的照片，变成精致海报", font=ft, fill=ink)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)