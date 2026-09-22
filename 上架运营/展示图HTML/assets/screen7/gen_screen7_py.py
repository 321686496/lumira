# -*- coding: utf-8 -*-
"""Screen7 程序合成版：三张真实海报等比缩放拼图，内容/比例零改动，无手机、不新增画面。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_py.png"
SERIF = "C:/Windows/Fonts/simsun.ttc"   # 衬线（标题）
SANS = "C:/Windows/Fonts/msyh.ttc"      # 黑体（副标题）

W, H = 1080, 1920

# ---------- 奶油白-暖米莫兰迪渐变底 ----------
top = (250, 247, 242)
bot = (238, 229, 215)
stripe = Image.new("RGB", (1, H))
for y in range(H):
    t = y / (H - 1)
    stripe.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
bg = stripe.resize((W, H)).convert("RGBA")

# ---------- 等比载图（不裁剪不变形，保持 9:16） ----------
def load(path, target_h):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    tw = int(target_h * w / h)
    return im.resize((tw, target_h), Image.LANCZOS)

# 主角用 poster2，两张小图用 poster1 / poster3
hero = load(f"{ASSETS}/poster2.jpg", 1020)   # 高 1020 -> 宽约 443
s1 = load(f"{ASSETS}/poster1.jpg", 780)      # 高 780 -> 宽约 365
s2 = load(f"{ASSETS}/poster3.jpg", 860)      # 高 860 -> 宽约 373

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def place(img, cx, cy, angle, shadow=True, r=18, alpha=70, blur=16, dy=8):
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

# 主角居中偏左（黄色金属高亮）
place(hero, 400, 1120, -2, r=22, alpha=80)
# 右肩两张，高低错落 + 轻微角度，互不遮挡主角核心
place(s1, 840, 760, 5, r=16, alpha=60, dy=6)   # 右上
place(s2, 840, 1420, -4, r=16, alpha=60, dy=6) # 右下

out = Image.alpha_composite(bg, layer)
dr = ImageDraw.Draw(out)

# ---------- 顶部标题 ----------
ink = (58, 51, 41)
grey = (140, 130, 118)
gold = (180, 150, 100)
try:
    f_title = ImageFont.truetype(SERIF, 60)
    f_tag = ImageFont.truetype(SANS, 30)
except Exception:
    f_title = f_tag = ImageFont.load_default()
# 金色细线
dr.rounded_rectangle([120, 120, 120 + 46, 124], radius=2, fill=gold)
dr.text((200, 104), "好看的照片", font=f_title, fill=ink)
dr.text((200, 196), "忍不住想分享", font=f_title, fill=ink)
dr.text((200, 320), "一键生成专属分享海报", font=f_tag, fill=grey)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)