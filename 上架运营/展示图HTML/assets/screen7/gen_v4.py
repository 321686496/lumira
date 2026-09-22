# -*- coding: utf-8 -*-
"""Screen7 v4: iPhone 17 Pro 壳 + 海报全部外置不遮挡。素材不裁剪不变形。"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ASSETS = "d:/app/projects/photo_post/上架运营/展示图HTML/assets/screen7"
OUT = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_v4.png"
SONG = "C:/Windows/Fonts/simsun.ttc"
YAHEI = "C:/Windows/Fonts/msyh.ttc"

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
p1 = load_resize(f"{ASSETS}/poster1.jpg", 264)
p2 = load_resize(f"{ASSETS}/poster2.jpg", 300)
p3 = load_resize(f"{ASSETS}/poster3.jpg", 268)

# ---- 背景装饰 ----
dec = Image.new("RGBA", (W, H), (0, 0, 0, 0))
dd = ImageDraw.Draw(dec)
dd.ellipse([470, -360, 1270, 440], fill=(224, 196, 180, 60))
dd.ellipse([-180, 1330, 420, 1930], outline=(201, 174, 124, 110), width=3)
dd.line([0, 1560, 1080, 1420], fill=(201, 174, 124, 55), width=2)
bg = Image.alpha_composite(bg.convert("RGBA"), dec)

layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))

def place_rot(img, cx, cy, angle, want_shadow=True, r=20, blur=15, alpha=78, dy=6):
    rot = img.rotate(angle, expand=True, resample=Image.BICUBIC)
    if want_shadow:
        sh = Image.new("RGBA", rot.size, (0, 0, 0, 0))
        sd = Image.new("L", rot.size, 0)
        dr = ImageDraw.Draw(sd)
        dr.rounded_rectangle([5, 8 + dy, rot.size[0] - 5, rot.size[1] + 6 + dy], radius=r, fill=alpha)
        sd = sd.filter(ImageFilter.GaussianBlur(blur))
        sh.putalpha(sd)
        layer.paste(sh, (cx - sh.size[0] // 2, cy - sh.size[1] // 2), sh)
    layer.paste(rot, (cx - rot.size[0] // 2, cy - rot.size[1] // 2), rot)

# ================= 手机：iPhone 17 Pro 壳 =================
pad = 14
sw, shh = phone.width + pad * 2, phone.height + pad * 2
# 壳画布横向多留 28px 放侧键
canvas_w, canvas_h = sw + 28, shh
shell = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
sd = ImageDraw.Draw(shell)
# 机身（居中偏右，左侧留按键带）
bw = sw  # 机身宽
bx0, by0 = 14, 0
sd.rounded_rectangle([bx0, by0, bx0 + bw - 1, by0 + shh - 1], radius=52,
                     fill=(16, 14, 13, 255))                       # 背面
sd.rounded_rectangle([bx0 + 3, 16, bx0 + bw - 4, 70], radius=26,
                     fill=(236, 233, 229, 255))                    # 顶部灵动岛胶囊(浅色屏上方)
# 灵动岛：居中深色胶囊
island_w = 116
sd.rounded_rectangle([bx0 + bw // 2 - island_w // 2, 24,
                      bx0 + bw // 2 + island_w // 2, 52], radius=22, fill=(16, 14, 13, 255))
# 金属边框高光（机身四周细亮线）
sd.rounded_rectangle([bx0 + 1, by0 + 1, bx0 + bw - 2, by0 + shh - 2],
                     radius=50, outline=(90, 86, 82, 255), width=2)
# ---- 侧键 ----
btn = (98, 94, 90)
# 左：Action 键(上) + 音量 ±
sd.rounded_rectangle([2, 170, 16, 208], radius=5, fill=btn)
sd.rounded_rectangle([2, 448, 16, 512], radius=5, fill=btn)   # vol+
sd.rounded_rectangle([2, 524, 16, 582], radius=5, fill=btn)   # vol-
# 右：电源键 + 相机控制键
sd.rounded_rectangle([canvas_w - 16, 396, canvas_w - 2, 452], radius=5, fill=btn)
sd.rounded_rectangle([canvas_w - 14, 688, canvas_w - 2, 754], radius=5, fill=btn)

# 旋转壳并整体定位
shell_cx, shell_cy = 560, 1150
shell_rot = shell.rotate(2, expand=True, resample=Image.BICUBIC)
# 阴影
sh = Image.new("RGBA", shell_rot.size, (0, 0, 0, 0))
sm = Image.new("L", shell_rot.size, 0)
ImageDraw.Draw(sm).rounded_rectangle([4, 10, shell_rot.size[0] - 4, shell_rot.size[1] + 14], radius=52, fill=100)
sm = sm.filter(ImageFilter.GaussianBlur(24))
sh.putalpha(sm)
layer.paste(sh, (shell_cx - shell_rot.size[0] // 2, shell_cy - shell_rot.size[1] // 2), sh)
layer.paste(shell_rot, (shell_cx - shell_rot.size[0] // 2, shell_cy - shell_rot.size[1] // 2), shell_rot)

# 屏幕（mask 圆角 + 2°旋转），贴合机身
smask = Image.new("L", phone.size, 0)
ImageDraw.Draw(smask).rounded_rectangle([0, 0, phone.width - 1, phone.height - 1], radius=40, fill=255)
scr = Image.new("RGBA", phone.size)
scr.paste(phone, (0, 0), smask)
scr = scr.rotate(2, expand=True, resample=Image.BICUBIC)
# 屏中心与机身中心对齐
fx = shell_cx + (bx0 + bw // 2 - canvas_w // 2)
fy = shell_cy + (by0 + shh // 2 - canvas_h // 2)
layer.paste(scr, (fx - scr.size[0] // 2, fy - scr.size[1] // 2), scr)

# ================= 海报：全部外置，不压手机、不遮关键内容 =================
# 手机套件区域约 x 350..800, y 760..1540 —— 海报避开外侧
place_rot(p1, 178, 1050, -8)     # 左侧中
place_rot(p2, 916, 900, 5)       # 右侧上
place_rot(p3, 916, 1370, -4)     # 右侧下

# ================= 标题 =================
out = Image.alpha_composite(bg, layer)
dr = ImageDraw.Draw(out)
gold = (184, 150, 96)
ink = (56, 49, 40)
grey = (140, 130, 118)
try:
    f_title = ImageFont.truetype(SONG, 74)
    f_tag = ImageFont.truetype(YAHEI, 30)
except Exception:
    f_title = f_tag = ImageFont.load_default()
dr.rounded_rectangle([78, 130, 82, 360], radius=3, fill=gold)
dr.text((120, 120), "把平凡的照片", font=f_title, fill=ink)
dr.text((120, 226), "变成值得分享的瞬间", font=f_title, fill=ink)
dr.text((120, 356), "随手一幅 · 一按出片", font=f_tag, fill=grey)
dr.rounded_rectangle([120, 400, 236, 404], radius=2, fill=gold)

out.convert("RGB").save(OUT)
print("saved", OUT, out.size)