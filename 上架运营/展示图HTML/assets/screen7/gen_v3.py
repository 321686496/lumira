# -*- coding: utf-8 -*-
"""Screen7 v3 带设计感版式。素材仅等比缩放 + 旋转，不裁剪不变形。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_v3.png"
SONG = "C:/Windows/Fonts/simsun.ttc"      # 衬线，标题用
YAHEI = "C:/Windows/Fonts/msyh.ttc"       # 黑体

W, H = 1080, 1920

def lin_grad(top_c, bot_c):
    s = Image.new("RGB", (1, H))
    for y in range(H):
        t = y / (H - 1)
        s.putpixel((0, y), tuple(int(top_c[i] + (bot_c[i] - top_c[i]) * t) for i in range(3)))
    return s.resize((W, H))

bg = lin_grad((252, 250, 246), (242, 233, 218))

def load_resize(path, width):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    return im.resize((width, int(width * h / w)), Image.LANCZOS)

phone = load_resize(f"{ASSETS}/drawer.png", 352)
p1 = load_resize(f"{ASSETS}/poster1.jpg", 270)
p2 = load_resize(f"{ASSETS}/poster2.jpg", 318)
p3 = load_resize(f"{ASSETS}/poster3.jpg", 288)

# ---- 背景装饰（不涉及素材）：右上一大角圆弧 + 左下细线圈 + 细线 ----
dec = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(dec)
# 右上大圆弧（莫兰迪暖粉）
dd.ellipse([470, -360, 1270, 440], fill=(224, 196, 180, 70))
dd.ellipse([560, -270, 1220, 390], outline=(255, 255, 255, 150), width=2)
# 左下细线圈
dd.ellipse([-180, 1330, 420, 1930], outline=(201, 174, 124, 120), width=3)
# 中部一道斜金线
dd.line([0, 1580, 1080, 1420], fill=(201, 174, 124, 60), width=2)
bg = Image.alpha_composite(bg.convert("RGBA"), dec)

# ---- 顶层：手机 + 海报 ----
layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def soft_shadow_rot(img, cx, cy, angle, r=20, blur=16, alpha=80, dy=6):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
    sd = Image.new("L", rot.size, 0)
    dr = ImageDraw.Draw(sd)
    dr.rounded_rectangle([5, 8 + dy, rot.size[0] - 5, rot.size[1] + 6 + dy], radius=r, fill=alpha)
    sd = sd.filter(ImageFilter.GaussianBlur(blur))
    sh.putalpha(sd)
    layer.paste(sh, (cx - sh.size[0] // 2, cy - sh.size[1] // 2), sh)
    rot.alpha_composite(
        Image.merge("RGBA",
            (rot.split()[0], rot.split()[1], rot.split()[2],
             rot.split()[3].point(lambda a: a)))
    )
    layer.paste(rot, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), rot)

# 手机壳
pad = 14
sw, shh = phone.width + pad * 2, phone.height + pad * 2
shell_cx, shell_cy = 548, 1180
shell = Image.new("RGBA", (sw, shh), (0, 0, 0, 0))
sd = ImageDraw.Draw(shell)
sd.rounded_rectangle([0, 0, sw - 1, shh - 1], radius=54, fill=(15, 13, 12, 255))
sd.rounded_rectangle([sw // 2 - 58, 22, sw // 2 + 58, 50], radius=20, fill=(15, 13, 12, 255))
# 手机整体倾斜 +2°（带投影）
soft_shadow_rot(shell.rotate(2, expand=True, resample=Image.BICUBIC), 548, 1180, 0, r=40, blur=20, alpha=90, dy=10)
# 屏幕
mask = Image.new("L", phone.size, 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, phone.width - 1, phone.height - 1], radius=40, fill=255)
screen = Image.new("RGBA", phone.size)
screen.paste(phone, (0, 0), mask)
screen = screen.rotate(2, expand=True, resample=Image.BICUBIC)
layer.paste(screen, (548 - screen.size[0] // 2, 1180 - screen.size[1] // 2), screen)

# 海报：大小不一、斜向、出血感但保持完整
soft_shadow_rot(p1, 296, 700, -9)                              # 左上
soft_shadow_rot(p2, 806, 620, 6)                               # 右偏上较大
soft_shadow_rot(p3, 470, 1560, -5)                             # 靠近手机下方
# 右上贴边大圆弧处补一张倾斜 ? 不需要，三张已够

# ---- 标题：衬线大字 + 竖线装饰，设计感排版 ----
out = Image.alpha_composite(bg, layer)
dr = ImageDraw.Draw(out)
gold = (184, 150, 96)
ink = (56, 49, 40)
grey = (140, 130, 118)

try:
    f_title = ImageFont.truetype(SONG, 74)
    f_sub = ImageFont.truetype(YAHEI, 30)
    f_tag = ImageFont.truetype(YAHEI, 26)
except Exception:
    f_title = f_sub = f_tag = ImageFont.load_default()

# 左侧竖金线
dr.rounded_rectangle([78, 130, 82, 360], radius=3, fill=gold)
# 主标题两行（衬线）
dr.text((120, 120), "把平凡的照片", font=f_title, fill=ink)
dr.text((120, 226), "变成值得分享的瞬间", font=f_title, fill=ink)
# 小tag
dr.text((120, 356), "随手一幅 · 一按出片", font=f_tag, fill=grey)
# 金色点缀块
dr.rounded_rectangle([120, 400, 236, 404], radius=2, fill=gold)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)