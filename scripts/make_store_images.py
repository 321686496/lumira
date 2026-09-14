from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

W, H = 1080, 1920
BG = (250, 245, 239)
DARK = (42, 37, 30)
WARM_GRAY = (140, 128, 115)
ACCENT = (196, 164, 96)

BASE = 'E:/Project/photo_post/outputs'
OUT = os.path.join(BASE, 'store')
os.makedirs(OUT, exist_ok=True)

font_title = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttf', 64)
font_sub = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttf', 28)
font_brand = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttf', 20)
font_note = ImageFont.truetype('C:/Windows/Fonts/msyhbd.ttf', 22)

def gradient_bg(w, h, top=(250,245,239), bot=(245,236,225)):
    img = Image.new('RGB', (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        r = top[0] + int((bot[0]-top[0]) * y / h)
        g = top[1] + int((bot[1]-top[1]) * y / h)
        b = top[2] + int((bot[2]-top[2]) * y / h)
        d.line([(0,y),(w,y)], fill=(r,g,b))
    return img

def rounded_mask(w, h, r):
    m = Image.new('L', (w, h), 0)
    d = ImageDraw.Draw(m)
    d.rounded_rectangle([0,0,w,h], radius=r, fill=255)
    return m

def phone_mockup(screen, target_w=440):
    sw, sh = screen.size
    scale = target_w / sw
    new_w = target_w
    new_h = int(sh * scale)
    screen = screen.resize((new_w, new_h), Image.LANCZOS)
    bezel = 14
    frame_w = new_w + bezel * 2
    frame_h = new_h + bezel * 2
    corner_r = 48
    frame = Image.new('RGBA', (frame_w + 40, frame_h + 40), (0,0,0,0))
    shadow = Image.new('RGBA', frame.size, (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([20, 28, 20+frame_w, 28+frame_h], radius=corner_r, fill=(0,0,0,50))
    shadow = shadow.filter(ImageFilter.GaussianBlur(18))
    frame = Image.alpha_composite(frame, shadow)
    d = ImageDraw.Draw(frame)
    d.rounded_rectangle([20, 20, 20+frame_w, 20+frame_h], radius=corner_r, fill=(30,28,26,255))
    screen_rgba = screen.convert('RGBA')
    mask = rounded_mask(new_w, new_h, corner_r - bezel)
    frame.paste(screen_rgba, (20+bezel, 20+bezel), mask)
    return frame

def paste_shadow(canvas, img, x, y, alpha=40, blur=15):
    w, h = img.size
    shadow = Image.new('RGBA', (w+40, h+40), (0,0,0,0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([20,24,20+w,24+h], radius=30, fill=(0,0,0,alpha))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.paste(Image.new('RGB', shadow.size, BG), (x-20, y-20), shadow.split()[3])
    if img.mode == 'RGBA':
        canvas.paste(img, (x, y), img)
    else:
        canvas.paste(img, (x, y))

def draw_title(canvas, title, sub, y=56):
    d = ImageDraw.Draw(canvas)
    bbox = d.textbbox((0,0), title, font=font_title)
    tw = bbox[2] - bbox[0]
    tx = (W - tw) // 2
    d.text((tx, y), title, fill=DARK, font=font_title)
    ly = y + bbox[3] + 10
    lx = (W - 100) // 2
    d.rounded_rectangle([lx, ly, lx+100, ly+5], radius=3, fill=ACCENT)
    bbox_s = d.textbbox((0,0), sub, font=font_sub)
    sw = bbox_s[2] - bbox_s[0]
    sx = (W - sw) // 2
    d.text((sx, ly+16), sub, fill=WARM_GRAY, font=font_sub)
    return ly + 16 + bbox_s[3] + 20

def draw_brand(canvas, y=None):
    d = ImageDraw.Draw(canvas)
    if y is None: y = H - 40
    text = '如画 Lumira'
    bbox = d.textbbox((0,0), text, font=font_brand)
    tw = bbox[2] - bbox[0]
    d.text(((W-tw)//2, y), text, fill=(*WARM_GRAY, 150), font=font_brand)

discover = Image.open(os.path.join(BASE, 'app-screens', '02-discover-top.jpeg')).convert('RGB')
home = Image.open(os.path.join(BASE, 'app-screens', '03-home.jpeg')).convert('RGB')
challenge = Image.open(os.path.join(BASE, 'app-screens', '04-challenge.jpeg')).convert('RGB')
detail = Image.open(os.path.join(BASE, 'app-screens', 'detail.jpg')).convert('RGB')

hero = Image.open(os.path.join(BASE, 'hero-portrait.png')).convert('RGB')
pose_compare = Image.open(os.path.join(BASE, 'assets', 'bad-vs-good-pose.png')).convert('RGB')
cafe = Image.open(os.path.join(BASE, 'assets', 'cafe-scene.png')).convert('RGB')
silhouette = Image.open(os.path.join(BASE, 'assets', 'silhouette-overlay.png')).convert('RGB')
diary = Image.open(os.path.join(BASE, 'assets', 'photo-diary.png')).convert('RGB')
styles = Image.open(os.path.join(BASE, 'assets', 'four-styles.png')).convert('RGB')

# 1: Hero
c1 = gradient_bg(W, H)
cy = draw_title(c1, '照着模板拍出大片', '姿势剪影实时引导')
pw = 480
ph = int(pose_compare.height * pw / pose_compare.width)
pose_scaled = pose_compare.resize((pw, ph), Image.LANCZOS)
px = (W - pw) // 2
py = cy + 10
paste_shadow(c1, pose_scaled, px, py, alpha=45)
sil_mock = phone_mockup(silhouette, 380)
sm_w, sm_h = sil_mock.size
sx = (W - sm_w) // 2
sy = py + ph - 100
paste_shadow(c1, sil_mock, sx, sy, alpha=55)
draw_brand(c1)
c1.save(os.path.join(OUT, '01-hero.png'), quality=95)
print('01-hero saved')

# 2: Template Library
c2 = gradient_bg(W, H)
cy = draw_title(c2, '百款模板随心挑', '人像/探店/美食/街拍全覆盖')
disc_mock = phone_mockup(discover, 460)
dm_w, dm_h = disc_mock.size
dx = 30
dy = cy + 10
paste_shadow(c2, disc_mock, dx, dy, alpha=40)
hw = 400
hh = int(hero.height * hw / hero.width)
hero_crop = hero.resize((hw, hh), Image.LANCZOS).crop((0, 0, hw, int(hh*0.65)))
hxr = dx + dm_w - 60
hyr = dy + 60
paste_shadow(c2, hero_crop, hxr, hyr, alpha=55, blur=20)
draw_brand(c2)
c2.save(os.path.join(OUT, '02-template-library.png'), quality=95)
print('02-template-library saved')

# 3: Silhouette
c3 = gradient_bg(W, H)
cy = draw_title(c3, '不会摆姿势？跟着来', '构图姿势一目了然')
sil_mock2 = phone_mockup(silhouette, 440)
sm2_w, sm2_h = sil_mock2.size
sx2 = 40
sy2 = cy + 10
paste_shadow(c3, sil_mock2, sx2, sy2, alpha=50)
detail_mock = phone_mockup(detail, 380)
det_w, det_h = detail_mock.size
dx3 = sx2 + sm2_w - 80
dy3 = sy2 + 80
paste_shadow(c3, detail_mock, dx3, dy3, alpha=50, blur=18)
draw_brand(c3)
c3.save(os.path.join(OUT, '03-silhouette.png'), quality=95)
print('03-silhouette saved')

# 4: Scene
c4 = gradient_bg(W, H)
cy = draw_title(c4, '探店打卡，一键出片', '场景模板直接套用')
cw = 500
ch = int(cafe.height * cw / cafe.width)
cafe_crop = cafe.resize((cw, ch), Image.LANCZOS).crop((0, 0, cw, min(ch, 900)))
cx = (W - cw) // 2
cy4 = cy + 10
paste_shadow(c4, cafe_crop, cx, cy4, alpha=45)
disc_mock2 = phone_mockup(discover, 380)
dm2_w, dm2_h = disc_mock2.size
dx4 = cx + cw - dm2_w - 20
dy4 = cy4 + 100
paste_shadow(c4, disc_mock2, dx4, dy4, alpha=55, blur=18)
draw_brand(c4)
c4.save(os.path.join(OUT, '04-scene.png'), quality=95)
print('04-scene saved')

# 5: Diary
c5 = gradient_bg(W, H)
cy = draw_title(c5, '把生活拍成日记', '每日挑战 · 连续打卡')
chal_mock = phone_mockup(challenge, 440)
cm_w, cm_h = chal_mock.size
cx5 = 40
cy5 = cy + 10
paste_shadow(c5, chal_mock, cx5, cy5, alpha=45)
diw = 400
dih = int(diary.height * diw / diary.width)
diary_crop = diary.resize((diw, dih), Image.LANCZOS).crop((0, 0, diw, int(dih*0.6)))
dix = cx5 + cm_w - 60
diy = cy5 + 50
paste_shadow(c5, diary_crop, dix, diy, alpha=50, blur=20)
draw_brand(c5)
c5.save(os.path.join(OUT, '05-diary.png'), quality=95)
print('05-diary saved')

# 6: Styles
c6 = gradient_bg(W, H)
cy = draw_title(c6, '四种风格随心换', '好看界面匹配你的审美')
stw = 520
sth = int(styles.height * stw / styles.width)
styles_scaled = styles.resize((stw, sth), Image.LANCZOS)
stx = (W - stw) // 2
sty = cy + 10
paste_shadow(c6, styles_scaled, stx, sty, alpha=45)
home_mock = phone_mockup(home, 380)
hm_w, hm_h = home_mock.size
hx6 = (W - hm_w) // 2
hy6 = sty + sth - 40
paste_shadow(c6, home_mock, hx6, hy6, alpha=50, blur=18)
draw_brand(c6)
c6.save(os.path.join(OUT, '06-styles.png'), quality=95)
print('06-styles saved')

print('All 6 images saved to', OUT)
for f in sorted(os.listdir(OUT)):
    fp = os.path.join(OUT, f)
    print(f, os.path.getsize(fp), 'bytes')
