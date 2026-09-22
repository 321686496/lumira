#!/usr/bin/env python3
"""第7张展示图 - 竞品风格v3（阶梯层叠卡片：近方卡 + 右下递进 + 外挂标签）
完美复刻参考图：右侧3张近方形卡片阶梯向右下叠加，每张底部被下一张盖约25%，
微旋转±3°，名称标签在卡片外部下方、不参与遮挡。
Canvas: 1080x1920
"""
import os
from PIL import Image, ImageDraw, ImageFont

A_CAST = "c:/Users/Administrator/.trae-cn/attachments/6aacdae5b334b2eb2a3e3fc3/13bda186-cecb-48e5-82ea-1be2d85d1d39_b967f67a-def6-4d0f-8768-280eb6505119_9ec5fcf3-7ac2-4413-8743-87c48d39299a.png"
POSTERS = [
    "c:/Users/Administrator/.trae-cn/attachments/6aacdae5b334b2eb2a3e3fc3/010f83f3-e96f-4afe-afd2-e2a9deb815ef_625b1cac-c9e6-472d-99c5-9359cdbe6250_354243b8b8b190a5ee41b64dbd7e965b.jpg",
    "c:/Users/Administrator/.trae-cn/attachments/6aacdae5b334b2eb2a3e3fc3/fef1ea41-8c38-471b-9e33-03733fec31c2_c026da28-1afa-49d4-90fb-51d05e54a8bf_16684b73f854819558eda78502724fb0.jpg",
    "c:/Users/Administrator/.trae-cn/attachments/6aacdae5b334b2eb2a3e3fc3/19768d65-1b3b-470c-8ea6-9251eb9fb03a_90ae9581-3e16-46bf-9047-c9f596d2478a_139ed6de5269538d0ca34a1471fa8517.jpg",
]
NAMES = ["杂志面感", "社交卡片感", "海报模板"]
HILIGHT = 0   # 卡片1带空 = 高亮选中

W, H = 1080, 1920
CANVAS = Image.new("RGB", (W, H), "#F7F2EC")
draw = ImageDraw.Draw(CANVAS)

def _font(size, bold=False):
    cands = (["C:/Windows/Fonts/msyhbd.ttc", "C:/Windows/Fonts/NotoSansCJK-Bold.ttc"] if bold
             else ["C:/Windows/Fonts/msyh.ttc", "C:/Windows/Fonts/NotoSansCJK-Regular.ttc"])
    for c in cands:
        if os.path.exists(c):
            return ImageFont.truetype(c, size)
    return ImageFont.load_default()

# ---- 顶部标题 ---- 
MARGIN = 64
draw.text((MARGIN, 110), "好看的照片，忍不住想分享", font=_font(54, True), fill="#3A2E28")
draw.text((MARGIN + 2, 214), "一键生成专属分享海报", font=_font(27), fill="#8C7A68")

# ---- 手机样机(偏左) ----
phone_w = 500
screen_ratio = 0.667
screen_w = phone_w - 28
screen_h = int(screen_w / screen_ratio)   # 708
body_h = screen_h + 44
body_w = phone_w
phone_x = 72
phone_y = 380

cast = Image.open(A_CAST).convert("RGB").resize((screen_w, screen_h), Image.LANCZOS)
body = Image.new("RGBA", (body_w, body_h), (0,0,0,0))
bd = ImageDraw.Draw(body)
bd.rounded_rectangle([0,0,body_w-1,body_h-1], radius=54, fill=(30,30,34,255))
sx = (body_w - screen_w)//2
sy = (body_h - screen_h)//2
body.paste(cast, (sx, sy))
CANVAS.paste(body, (phone_x, phone_y), body)
# 灵动岛
iw, ih = 140, 24
ix = phone_x + (body_w - iw)//2
draw.rounded_rectangle([ix, phone_y+13, ix+iw, phone_y+13+ih], radius=ih//2, fill="#1A1A1E")
# home indicator
hiw = 120
hix = phone_x + (body_w - hiw)//2
draw.rounded_rectangle([hix, phone_y+body_h-13, hix+hiw, phone_y+body_h-13+6], radius=3, fill="#DCDCDC")

# ---- 右侧 3 张近方形卡片: 扇形铺开堆叠 ----
card_w = 292
card_h = int(card_w * 1.25)   # 365, 高:宽 1.25
rot_mid = -2.0                # 中间卡角度
spread = 5.0                  # 首尾卡与中间卡的夹角
rots = [rot_mid - spread, rot_mid, rot_mid + spread]   # -7 / -2 / +3 扇形展开
fan_cx = phone_x + body_w + 30     # 扇形枢轴(右下, 各卡向此聚拢)
fan_cy = phone_y + body_h - 40     # 扇形底部

for i in range(len(POSTERS)):
    img = Image.open(POSTERS[i]).convert("RGB")
    take = img.width * 1.25
    if take < img.height:
        img = img.crop((0, 0, img.width, int(take)))
    img = img.resize((card_w, card_h), Image.LANCZOS)

    rot = rots[i]
    # 扇形: 各卡绕枢轴旋转, 顶部向中心摊开, 底部聚拢
    img_r = img.rotate(rot, expand=True, fillcolor=(247,242,236), resample=Image.BICUBIC)
    # 卡片左上角定位: 以枢轴点为锚, 让卡片底部一角朝向枢轴
    # 简化: 卡片左上角围绕枢轴按旋转散开
    base_x = fan_cx - int(card_w*0.48)
    base_y = fan_cy - card_h - 30
    # 角度决定水平偏移(扇形)
    ang = rot * 3.14159 / 180
    px = base_x + int(rot * 28)      # 越偏角度越右移
    py = base_y - int(abs(rot) * 14) # 翘起的略高

    # 中心对齐旋转图
    cx = px + card_w//2
    cy = py + card_h//2
    rx0 = int(cx - img_r.width//2)
    ry0 = int(cy - img_r.height//2)

    # 阴影 + 白描边
    draw.rectangle([rx0+6, ry0+10, rx0+img_r.width+6, ry0+img_r.height+10], fill="#00000014")
    CANVAS.paste(img_r, (rx0, ry0))
    draw.rectangle([rx0, ry0, rx0+img_r.width-1, ry0+img_r.height-1], outline="#FFFFFF", width=4)

    # 名称标签: 卡片下方独立白底胶囊
    tag = NAMES[i]
    tf = _font(25, True)
    tw = int(tf.getlength(tag)) + 30
    th = 40
    tx = px
    ty = py + card_h + 8
    draw.rounded_rectangle([tx, ty, tx+tw, ty+th], radius=th//2, fill="#FFFFFF")
    draw.text((tx+15, ty+8), tag, font=tf, fill="#3A2E28")
    if i == HILIGHT:
        r = 13
        hx, hy = tx+tw+r, ty-th//2
        draw.ellipse([hx-r, hy-r, hx+r, hy+r], fill="#C9A466", outline="#FFFFFF", width=2)
        draw.line([(hx-4,hy),(hx-1,hy+4),(hx+5,hy-4)], fill="#FFFFFF", width=3)

out = "d:/app/projects/photo_post/上架运营/展示图HTML/ios/screen7_sync.png"
os.makedirs(os.path.dirname(out), exist_ok=True)
CANVAS.save(out)
print("saved:", out, CANVAS.size)