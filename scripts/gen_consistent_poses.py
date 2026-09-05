# -*- coding: utf-8 -*-
"""经典一致性姿势图生成: 每模板 pose[0]=锚点(文生图, 固定为 anchor.png), pose[1..3]=以锚点做参考图图生图只改姿势。
锚点失败自动重试; 锚点未就绪则不生成衍生图, 保证一致性。
用法: python gen_consistent_poses.py <folder>       (生成整套 0..3)
对应关系写入 <folder>/pose_images.json (pose name -> filename)
"""
import codecs, json, subprocess, sys, time
from pathlib import Path

ROOT = Path(r"e:\Project\photo_post\selfie_templates")
SCRIPT = r"e:\Project\photo_post\scripts\gpt_image2.py"
KEY = "sk-8d0149c3e8dbf782ed1356b0be5e25579121eef8326c29db64884786bdf959df"
MODEL = "gpt-image-2"
SIZE = "3:4"
ANCHOR = "anchor.png"
MAX_TRY = 4
TIMEOUT = 300  # 单次 subprocess 超时(秒), 挂死自动重试

STYLE = {
 "23_oldmoney_amer":"写实美式老钱风人像, 一位约24岁东亚女性, 低饱和克制, 垂感真丝/针织搭配廓形, 木质书房拱窗书廊石墙实景, 午后侧光保留明暗层次, 沉稳耐看, 竖构图",
 "24_maillard":"写实美拉德焦糖风人像, 一位约24岁东亚女性, 浅棕/焦糖/深褐/暖橙分层色系, 咖啡馆秋日落叶街角, 暖调低饱和温润, 竖构图",
 "25_showa_fresh":"写实昭和复古甜美鬼马人像, 一位约22岁东亚女性, 复古碎花裙+红蝴蝶结对镜头, 暖调闪光灯直出胶片颗粒, 复古墙纸老式家电背景, 竖构图",
 "26_dopamine":"写实多巴胺活力人像, 一位约22岁东亚女性, 高饱和互补撞色, 彩色墙面涂鸦明亮背景, 逆光前景虚化, 肤色通透, 活泼生命力, 竖构图",
 "27_sport_campus":"写实美式运动校园人像, 一位约22岁东亚女性, Polo衫+百褶裙+高马尾, 操场球场阳光胶片颗粒, 竖构图",
 "28_home_pure":"写实居家温馨日常人像, 一位约25岁东亚女性, 穿着舒适棉质家居服, 卧室暖台灯侧光与温馨床品, 自然通透光, 温馨慵懒家常氛围, 竖构图",
 "29_french_garden":"写实法式田园梦幻人像, 一位约23岁东亚女性, 纯白蕾丝纱裙+藤编+花束, 花房碎花壁纸, 奶白低饱和色调, 逆光柔美梦幻, 竖构图",
 "30_natural_documentary":"写实原生感生活纪实人像, 一位约24岁东亚女性, 素颜不化妆, 生活化场景(树下/便利店/电车站/街角), 逆光柔光发丝光晕, 动态抓拍自然松弛, 暖调胶片颗粒, 保留皮肤纹理, 竖构图",
 "31_school_candy":"写实元气学院风格人像, 一位约23岁东亚女性, 粉衬衫+百褶裙校服清爽穿搭, 手拿彩色汽水与樱桃, 低饱和粉色系柔光, 蜜色皮肤通透, 青春自然, 校园氛围, 竖构图",
 "32_academia_dark":"写实暗黑学院书卷气人像, 一位约23岁东亚女性, 粗花呢/勃艮第红针织+眼镜+书, 古老大学图书馆暖金光单侧照明另一侧落暗, 书卷气文艺氛围, 竖构图",
 "33_oil_morandi":"写实古典油画质感人像, 一位约24岁东亚女性, 缎面蕾丝珍珠, 莫兰迪绿/米灰底色背景, 古典油画暖柔光, 低饱和复古色, 优雅静奢, 竖构图",
 "34_coquette":"写实Coquette蝴蝶结复古质感人像, 一位约24岁东亚女性, 米白裸色底+一只红色蝴蝶结发饰, 优雅针织与纯色搭配, 珍珠耳饰, 做旧Polaroid质感, 端庄雅致, 竖构图",
 "35_clean_girl":"写实Clean Girl干净质感人像, 一位约24岁东亚女性, 米白杏色极简, 深发低盘发, 金色细首饰, 无痕裸妆只留唇油, 无硬阴影人脸光, 干净高级通勤感, 竖构图",
 "36_ethereal":"写实白日空灵仙女仙气人像, 一位约22岁东亚女性, 花环/头纱/薄纱羽翼, 纯白薄纱花草, 柔和粉调眼妆, 逆光见发丝光晕, 晶莹通透, 空灵氛围, 竖构图","37_skincare_morning":"写实清晨素肌原相机自拍, 一位约24岁东亚女性, 素颜清透不过度美颜, 穿白色宽松睡衣裙, 卧室纱帘清晨漫射柔光, 手持手机前置镜头第一人称自拍, 慵懒干净元气, 真实自然, 竖构图","38_warm_nightlight":"写实夜晚卧室暖台灯氛围自拍, 一位约25岁东亚女性, 乳白家居服, 只留一盏3000K暖台灯其余背景压暗, 皮肤细腻温暖, 手持手机前置第一人称自拍, 慵懒松弛微醺感, 克制温和, 竖构图","39_mirror_home_ootd":"写实对镜居家穿搭自拍, 一位约24岁东亚女性, 在家中卧室或玄关落地镜前记录穿搭, 手机入镜, 干净墙面, 均匀自然光, 半身或全身, 真实随手感, 竖构图","40_curl_up_bed":"写实被窝奶油治愈自拍, 一位约24岁东亚女性, 奶白床单被窝把自己裹成舒展小团只露脸, 蓬松枕头, 奶白软色调, 窗外逆光微微轮廓, 手持手机前置第一人称自拍, 温暖治愈, 竖构图","41_light_shadow":"写实居家光影高级感自拍, 一位约24岁东亚女性, 窗边侧逆光/纱帘弥散光/黄昏墙面暖色光斑, 手遮半脸或闭眼仰头或局部特写, 阴影清晰有层次, 宁欠勿曝, 手持手机前置第一人称自拍, 氛围高级, 竖构图",
}

def save_mapping(folder, pose_name, filename):
    rec = ROOT / folder / "pose_images.json"
    m = {}
    if rec.exists():
        try: m = json.load(codecs.open(rec, encoding="utf-8-sig"))
        except Exception: m = {}
    m[pose_name] = filename
    json.dump(m, open(rec,"w",encoding="utf-8"), ensure_ascii=False, indent=2)

def get_anchor(outdir):
    f = outdir / ANCHOR
    return f if f.is_file() else None

def newest_png(folder, before):
    pngs = sorted((ROOT / folder).glob("*.png"), key=lambda p: p.stat().st_mtime)
    for p in reversed(pngs):
        if p not in before:
            return p
    return None

def gen_with_retry(cmd, outdir, before, label):
    for attempt in range(1, MAX_TRY+1):
        print(f"[{label}] 尝试 {attempt}/{MAX_TRY}", flush=True)
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=TIMEOUT)
        except subprocess.TimeoutExpired:
            print(f"   -> 超时({TIMEOUT}s) 视作失败", flush=True)
            r = type('R', (), {'returncode': -1, 'stderr': '', 'stdout': ''})()
            time.sleep(2)
            continue
        time.sleep(1)
        fn = newest_png(outdir, before)
        if fn:
            return r, fn
        if r.returncode == 0:
            break  # 成功但无文件? 停止重试
        err = (r.stderr or "")[-300:]
        print(f"   -> 第{attempt}次失败 exit={r.returncode} {err}", flush=True)
        time.sleep(5)
    return r, None

def run(folder):
    tpl = ROOT / folder / "template.pptpl"
    doc = json.load(open(tpl, encoding="utf-8"))
    poses = doc["pose"]
    style = STYLE.get(folder, "写实人像摄影")
    outdir = ROOT / folder; outdir.mkdir(exist_ok=True)

    # 1) 确保锚点存在
    anchor = get_anchor(outdir)
    if anchor is None:
        p0 = poses[0]
        before = set(outdir.glob("*.png"))
        prompt = f"{style}。姿势动作：{p0['description']}。竖构图半身或全身人像, 真实爆款感, 画面干净有质感。"
        cmd = [sys.executable, SCRIPT, prompt, "--platform","hapi","--model",MODEL,"--size",SIZE,"--out",str(outdir),"--api-key",KEY]
        r, fn = gen_with_retry(cmd, outdir, before, "锚点 "+p0["name"])
        if fn is None:
            print(f"!! ANCHOR FAILED for {folder}, 终止本套生成", flush=True)
            return
        anchor = outdir / ANCHOR
        if fn != anchor:
            if anchor.exists(): anchor.unlink()
            fn.rename(anchor)
        save_mapping(folder, p0["name"], ANCHOR)
        print(f"   锚点就绪 -> {ANCHOR}", flush=True)

    # 2) 生成衍生姿势
    for i, p in enumerate(poses):
        if i == 0:
            continue
        if (outdir / ANCHOR) == anchor and mapped(folder, p["name"]):
            pass
        if mapped(folder, p["name"]):
            print(f"[{i}] skip {p['name']} (done)", flush=True); continue
        before = set(outdir.glob("*.png"))
        prompt = (f"保持参考图中同一位置同一套穿搭与发型、同一背景与光线不变, 只改变人物的姿势动作。姿势动作：{p['description']}。竖构图。")
        cmd = [sys.executable, SCRIPT, prompt, "--image", str(anchor), "--platform","hapi","--model",MODEL,"--size",SIZE,"--once","--out",str(outdir),"--api-key",KEY]
        r, fn = gen_with_retry(cmd, outdir, before, "衍生 "+p["name"])
        if fn is None:
            print(f"[{i}] {p['name']} FAILED exit={r.returncode}", flush=True)
            continue
        save_mapping(folder, p["name"], fn.name)
        print(f"[{i}] {p['name']} -> {fn.name} ({time.time():.0f})", flush=True)

def mapped(folder, pose_name):
    rec = ROOT / folder / "pose_images.json"
    if rec.exists():
        try:
            m = json.load(codecs.open(rec, encoding="utf-8-sig"))
            fn = m.get(pose_name, "")
            if fn:
                f = ROOT / folder / fn
                if f.is_file(): return True
        except Exception:
            pass
    return False

if __name__ == "__main__":
    folder = sys.argv[1]
    run(folder)
    print("done", flush=True)
