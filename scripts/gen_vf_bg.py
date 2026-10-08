#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_vf_bg.py  为 12 张拍摄页截图批量生成"真实感实景背景"（复用 gpt_image2.py）
产出命名: {dir}/_bg/{截图像名去扩展}_bg.png  (供 fill_viewfinder.py --fill 直接用)

姿势/场景清单按各截图剪影手动指定；单一真实感强化前缀见 REAL_PREFIX。
"""
import json
import os
import subprocess
import sys

DIR = "上架运营/推流文章相关素材"
BG_DIR = os.path.join(DIR, "_bg")

# 无 AI 痕迹强约束统一前缀（真实手机直出）
REAL = (
    "苹果手机后置摄像头直出的真实生活照，摄影写实风格，"
    "保留真实皮肤毛孔和轻微拍照噪点，禁止磨皮，禁止美颜滤镜，禁止光晕，"
    "禁止过分柔光的假氛围光线，脸部有自然小瑕疵，随手抓拍不摆拍的感觉。"
)

# {截图像名: 详细Prompt}
PLANS = {
    "Screenshot_2026-10-08T103036.png": "初秋公园午后斜阳，普通东亚女生穿米色软糯针织开衫和深色格纹百褶短裙，侧身回头看向镜头，右手拿一杯纸杯美式咖啡，正在走路，金棕色发丝被逆阳台光照亮，背景是虚化的公园林荫道和掉落银杏叶。",
    "Screenshot_2026-10-08T103038.png": "初秋公园午后斜阳，普通东亚女生穿米色软糯针织开衫和深色格纹百褶短裙，坐在公园长椅上，双手捧着纸杯美式咖啡，姿态放松自然，金棕色发丝被逆阳照亮，背景是虚化的公园林荫道。",
    "Screenshot_2026-10-08T103040.png": "初秋公园午后斜阳，普通东亚女生穿米色软糯针织开衫和深色格纹百褶短裙，侧身站立侧头望向镜头，一手拿纸杯美式咖啡，一手自然垂下，金棕色发丝被逆阳照亮，背景是虚化的公园林荫道。",
    "Screenshot_2026-10-08T103042.png": "初秋公园午后斜阳，普通东亚女生穿米色软糯针织开衫和深色格纹百褶短裙，走在公园小路上回眸看向镜头，走路姿态迈步自然，金棕色发丝被逆阳照亮，背景是虚化的公园林荫道和落叶。",
    "Screenshot_2026-10-08T103257.png": "午后居家客厅窗前，柔和的自然光，普通东亚女生穿米白色棉质短袖上衣慵懒地坐在沙发上，双手捧着一杯水，姿态放松偏头像自拍视角，背景是居家沙发和绿植，光线柔和偏暖。",
    "Screenshot_2026-10-08T103300.png": "午后居家客厅窗前，柔和的自然光，普通东亚女生穿米白色棉质短袖上衣慵懒地靠在沙发扶手边，一手托腮，姿态放松，背景是居家沙发和绿植，光线柔和偏暖。",
    "Screenshot_2026-10-08T103302.png": "午后居家卧室窗边，柔和的自然光，普通东亚女生穿米白色棉质短袖上衣坐在床沿，双腿自然垂下，姿态慵懒放松，背景是卧室床单和窗帘，光线柔和偏暖。",
    "Screenshot_2026-10-08T103303.png": "午后居家客厅，柔和的自然光，普通东亚女生穿米白色棉质短袖上衣坐在茶几边的矮凳上，一手托腮、一手垂放，慵懒随意，背景是居家客厅陈设与绿植，光线柔和偏暖。",
    "Screenshot_2026-10-08T103555.png": "韩系氛围感咖啡馆内，暖色吊灯柔和光线，普通东亚女生戴棒球帽穿宽松奶白毛衣，坐在吧台椅上手拿咖啡杯凑近嘴边喝，桌上放一部手机，姿态自然随意，背景是虚化的咖啡店吧台。",
    "Screenshot_2026-10-08T103557.png": "韩系氛围感咖啡馆内，暖色吊灯柔和光线，普通东亚女生戴棒球帽穿宽松奶白毛衣，坐在窗边高脚椅上一手托腮望着窗外，桌上放着一杯拿铁，姿态自然随意，背景是虚化的咖啡店与玻璃窗。",
    "Screenshot_2026-10-08T103559.png": "韩系氛围感咖啡馆内，暖色吊灯柔和光线，普通东亚女生戴棒球帽穿宽松奶白毛衣，坐在木桌边双手捧着马克杯，低头看杯中的咖啡拉花，桌上放一本书，姿态自然随意，背景是虚化的咖啡店。",
    "Screenshot_2026-10-08T103602.png": "韩系氛围感咖啡馆内，暖色吊灯柔和光线，普通东亚女生戴棒球帽穿宽松奶白毛衣，坐在沙发位上侧身望向镜头，一手拿咖啡杯，姿态自然随意，背景是虚化的咖啡店陈设。",
}


def gen_one(name, prompt, key):
    base = name.replace(".png", "")
    out_prefix = os.path.join(BG_DIR, base)
    cmd = [
        "python", os.path.join("scripts", "gpt_image2.py"),
        REAL + prompt,
        "--platform", "hapi",
        "--model", "gpt-image-2",
        "--size", "9:16",
        "--out", out_prefix,
    ]
    env = dict(os.environ)
    env["HAPI_API_KEY"] = key
    print(f"\n=== 生成: {name} ===")
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    out = (r.stdout or "") + (r.stderr or "")
    print(out[-2000:])
    if r.returncode != 0:
        return False
    return True


def main():
    key = os.environ.get("HAPI_API_KEY")
    if not key:
        print("[错误] 请在环境变量设置 HAPI_API_KEY")
        sys.exit(1)
    os.makedirs(BG_DIR, exist_ok=True)
    targets = sys.argv[1:] or list(PLANS.keys())
    for name in targets:
        if name not in PLANS:
            print(f"[跳过] 未定义 prompt: {name}")
            continue
        gen_one(name, PLANS[name], key)


if __name__ == "__main__":
    main()