# -*- coding: utf-8 -*-
"""Screen7 v5 精简版：素净背景、手机主角、海报右侧竖排、钛金属机模。素材不裁剪不变形。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_v5.png"
SONG = "C:/Windows/Fonts/simsun.ttc"
YAHEI = "C:/Windows/Fonts/msyh.ttc"

W, H = 1080, 1920

# 素净奶油底（无装饰）
bg = Image.new("RGB", (W, H), (250, 248, 244))

def load_resize(path, width):
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    return im.resize((width, int(width * h / w)), Image.LANCZOS)

phone = load_resize(f"{ASSETS}/drawer.png", 400)
p1 = load_resize(f"{ASSETS}/poster1.jpg", 150)
p2 = load_resize(f"{ASSETS}/poster2.jpg", 150)
p3 = load_resize(f"{ASSETS}/poster3.jpg", 150)

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def place_rot(img, cx, cy, angle, r=18, blur=14, alpha=70, dy=6):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
    sd = Image.new("L", rot.size, 0)
    dr = ImageDraw.Draw(sd)
    dr.rounded_rectangle([4, 8 + dy, rot.size[0] - 4, rot.size[1] + 6 + dy], radius=r, fill=alpha)
    sd = sd.filter(ImageFilter.GaussianBlur(blur))
    sh.putalpha(sd)
    layer.paste(sh, (cx - sh.size[0] // 2, cy - sh.size[1] // 2), sh)
    layer.paste(rot, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), rot)

# ================= 手机：钛金属机模 =================
screen_w = phone.width
screen_h = phone.height
# 边框比例（真机边框很窄）——四边约 10px 金属框
frame = 12
fx0, fy0 = 0, 0
fw = screen_w + frame * 2
fh = screen_h + frame * 2
# 钛金属渐变边框（横向渐变，模拟金属高光）
import math
titan = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
td = ImageDraw.Draw(titan)
def metal_grad(x):
    if x < fw * 0.15: return (176, 178, 182, 255)
    if x < fw * 0.40: return (214, 216, 220, 255)
    if x < fw * 0.75: return (188, 190, 195, 255)
    return (214, 216, 220, 255)
for x in range(fw):
    c = metal_grad(x)
    ImageDraw.Draw(titan).line([x, 0, x, fh], fill=c, width=1)
# 用圆角框裁切金属渐变
mm = Image.new("L", (fw, fh), 0)
ImageDraw.Draw(mm).rounded_rectangle([0, 0, fw - 1, fh - 1], radius=58, fill=255)
titan.putalpha(mm)
# 内置黑色屏幕底（更窄）
sbx, sby = frame + 2, frame + 2
sw_, sh_ = screen_w - 4, screen_h - 4
black = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
bd = ImageDraw.Draw(black)
bd.rounded_rectangle([sbx, sby, sbx + sw_ - 1, sby + sh_ - 1], radius=42, fill=(10, 10, 10, 255))
# 灵动岛（胶囊，居中顶部）
island_w = 118
bd.rounded_rectangle([fw // 2 - island_w // 2, 34, fw // 2 + island_w // 2, 62],
                     radius=24, fill=(8, 8, 8, 255))
titan.alpha_composite(black)
# 侧键（钛金属细长，精确位置）
btn = (160, 163, 168, 255)
# 左：Action(上) + 音量±(下)
ImageDraw.Draw(titan).rounded_rectangle([0, 210, 16, 248], radius=6, fill=btn)
ImageDraw.Draw(titan).rounded_rectangle([0, 470, 16, 528], radius=6, fill=btn)   # vol+
ImageDraw.Draw(titan).rounded_rectangle([0, 544, 16, 598], radius=6, fill=btn)   # vol-
# 右：电源 + 相机控制
ImageDraw.Draw(titan).rounded_rectangle([fw - 16, 430, fw, 486], radius=6, fill=btn)
ImageDraw.Draw(titan).rounded_rectangle([fw - 14, 700, fw, 764], radius=6, fill=btn)

phone_cx, phone_cy = 520, 1230
place_rot(titan, phone_cx, phone_cy, 0, r=44, blur=22, alpha=90, dy=12)
# 屏幕内容（盖在黑色屏上）
smask = Image.new("L", screen_w, 0) if False else None
scr = phone
layer.paste(scr, (phone_cx - screen_w // 2, phone_cy - screen_h // 2), scr)

# ===== 海报：右侧竖向排开，小、均匀、留距，不做旋转 =====
# 手机盒约 x 340..900 y 640..1560；海报放右侧 x 950 附近
ph_w = 150
ph1_h = int(ph_w * 2308 / 1080)   # 320
ph2_h = int(ph_w * 2488 / 1080)   # 345
ph3_h = ph2_h
col_x = 975
top_y = 600
gap = 52
p1c = (int(col_x), int(top_y + ph1_h / 2))
p2c = (int(col_x), int(top_y + ph1_h + gap + ph2_h / 2))
p3c = (int(col_x), int(top_y + ph1_h + gap + ph2_h + gap + ph3_h / 2))
place_rot(p1, *p1c, 0)
place_rot(p2, *p2c, 0)
place_rot(p3, *p3c, 0)

# ================= 标题（顶部，素净） =================
out = Image.alpha_composite(bg.convert("RGBA"), layer)
dr = ImageDraw.Draw(out)
ink = (56, 49, 40)
grey = (140, 130, 118)
try:
    f_title = ImageFont.truetype(SONG, 62)
    f_tag = ImageFont.truetype(YAHEI, 28)
except Exception:
    f_title = f_tag = ImageFont.load_default()
dr.text((120, 120), "把平凡的照片", font=f_title, fill=ink)
dr.text((120, 214), "变成值得分享的瞬间", font=f_title, fill=ink)
dr.text((120, 340), "随手一幅 · 一按出片", font=f_tag, fill=grey)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)