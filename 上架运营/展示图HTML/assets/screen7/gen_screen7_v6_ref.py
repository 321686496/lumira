# -*- coding: utf-8 -*-
"""Screen7 v6 参考图复刻：上=文案 左=原片大图 右=三张海报散落。素材只等比缩放平移，不改内容不变比例。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
PHOTO = f"{ASSETS}/poster1.jpg"       # 用作原片大图（参考图右侧产物之一）
P2 = f"{ASSETS}/poster2.jpg"
P3 = f"{ASSETS}/poster3.jpg"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_v6_ref.png"
SERIF = "C:/Windows/Fonts/simsun.ttc"
SANS = "C:/Windows/Fonts/msyh.ttc"

W, H = 1080, 1920

# ---------- 参考图浅灰底（略暖，保持莫兰迪） ----------
stripe = Image.new("RGB", (1, H))
for y in range(H):
    t = y / (H - 1)
    c = (int(236 + (232 - 236) * t), int(232 + (227 - 232) * t), int(226 + (222 - 226) * t))
    stripe.putpixel((0, y), c)
bg = stripe.resize((W, H)).convert("RGBA")

def load(path, target_h):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    tw = int(target_h * w / h)
    return im.resize((tw, target_h), Image.LANCZOS)

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def place(img, cx, cy, angle, shadow=True, r=18, alpha=70, blur=16, dy=8, outline=None, ow=4):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    if shadow:
        sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        sd = Image.new("L", rot.size, 0)
        dr = ImageDraw.Draw(sd)
        dr.rounded_rectangle([5, 8 + dy, rot.size[0] - 5, rot.size[1] + 8 + dy], radius=r, fill=alpha)
        sd = sd.filter(ImageFilter.GaussianBlur(blur))
        sh.putalpha(sd)
        layer.paste(sh, (cx - sh.size[0] // 2, cy - sh.size[1] // 2), sh)
    layer.paste(rot, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), rot)
    if outline:
        e = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        d = ImageDraw.Draw(e)
        d.rounded_rectangle([ow // 2, ow // 2, rot.size[0] - ow//2 - 1, rot.size[1] - ow//2 - 1],
                            radius=r + 2, outline=outline, width=ow)
        layer.paste(e, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), e)

# 布局区：文案顶部 ~0-300；内容区 x 左照片 0-500，右海报 500-1080
# 左侧原片大图（无白边，直接展示，等比；高度 ~880）
photo = load(PHOTO, 880)
place(photo, 210, 1150, 0, shadow=False)

# 右侧三张海报（白色边框卡片，散落错落，互有重叠）
pA = load(P2, 640)   # 右上
pB = load(P3, 700)   # 中
pC = load(PHOTO, 560) # 下
place(pA, 830, 560, 6, outline=(72, 132, 228))          # 选中态蓝框
place(pB, 860, 980, -2, outline=(255, 255, 255))
place(pC, 800, 1460, -8, outline=(255, 255, 255))

out = Image.alpha_composite(bg, layer)
dr = ImageDraw.Draw(out)

# ---------- 上方文案（全幅） ----------
ink = (40, 38, 36)
grey = (150, 140, 130)
gold = (180, 150, 100)
try:
    f_title = ImageFont.truetype(SERIF, 62)
    f_tag = ImageFont.truetype(SANS, 30)
except Exception:
    f_title = f_tag = ImageFont.load_default()
dr.rounded_rectangle([110, 108, 110 + 48, 112], radius=2, fill=gold)
dr.text((196, 92), "好看的照片", font=f_title, fill=ink)
dr.text((196, 188), "忍不住想分享", font=f_title, fill=ink)
dr.text((196, 306), "一键生成专属分享海报", font=f_tag, fill=grey)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)