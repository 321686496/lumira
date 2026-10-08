#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gen_vf_i2i.py   图生图：把拍摄页截图当参考图，让 AI 仅在白色取景框区域内
                绘制真实人像画面，UI/剪影/文字/导航一像素不动。
产出: {dir}/_i2i_full/{截图像名去扩展}.png
"""
import os
import subprocess
import sys

DIR = "上架运营/推流文章相关素材"
OUT = os.path.join(DIR, "_i2i_full")
os.makedirs(OUT, exist_ok=True)

# 每个截图对应的"取景框内要画的场景"描述
SCENES = {
    "Screenshot_2026-10-08T103036.png": "初秋公园午后斜阳，普通东亚年轻女生穿米色软糯针织开衫和深色格纹百褶短裙，侧身回头看向镜头，右手端着一杯纸杯美式咖啡，正在走路，金色发丝被逆光点亮，背景是虚化的公园林荫道与掉落银杏叶",
    "Screenshot_2026-10-08T103038.png": "初秋公园午后投光，普通东亚年轻女生穿米色软糯针织开衫和深色格纹百褶短裙，坐在公园长椅上，双手捧着纸杯美式咖啡，姿态放松自然，金色发丝被逆光点亮，背景是虚化的公园林荫道",
    "Screenshot_2026-10-08T103040.png": "初秋公园午后斜阳，普通东亚年轻女生穿米色软糯针织开衫和深色格纹百褶短裙，侧身站着一手提着一杯纸杯美式咖啡、一手自然微抬，侧头微笑看向镜头，金色发丝被逆光点亮，背景是虚化的公园林荫道",
    "Screenshot_2026-10-08T103042.png": "初秋公园午后斜阳，普通东亚年轻女生穿米色软糯针织开衫和深色格纹百褶短裙，在铺满金色落叶的公园小路上回眸看向镜头，迈步走路姿态自然，金色发丝被逆光点亮，背景是虚化的公园林荫道",
    "Screenshot_2026-10-08T103257.png": "午后居家客厅窗前柔和自然光，普通东亚年轻女生穿米白色棉质短袖上衣，慵懒地坐在布艺沙发上，双手捧着一杯水，姿态放松偏上头视角，背景是居家沙发与绿植",
    "Screenshot_2026-10-08T103300.png": "午后居家客厅窗前柔和自然光，普通东亚年轻女生穿米白色棉质短袖上衣，慵懒地靠在沙发扶手上，一手托腮，姿态放松，背景是居家沙发与绿植",
    "Screenshot_2026-10-08T103302.png": "午后居家卧室窗边柔和自然光，普通东亚年轻女生穿米白色棉质短袖上衣，坐在床沿双腿自然垂下，姿态慵懒放松，背景是卧室床单与窗帘",
    "Screenshot_2026-10-08T103303.png": "午后居家客厅柔和自然光，普通东亚年轻女生穿米白色棉质短袖上衣，坐在矮凳上，一手托腮一手放松垂下，慵懒随意，背景是居家客厅陈设与绿植",
    "Screenshot_2026-10-08T103555.png": "韩系氛围感咖啡馆暖色吊灯柔和光线，普通东亚年轻女生戴棒球帽穿宽松奶白毛衣，坐在吧台椅上，手拿咖啡杯凑近嘴边喝，桌上放一部手机，姿态自然随意，背景是虚化的咖啡店吧台",
    "Screenshot_2026-10-08T103557.png": "韩系氛围感咖啡馆暖色吊灯柔和光线，普通东亚年轻女生戴棒球帽穿宽松奶白毛衣，坐在窗边高脚椅上，一手托腮望着窗外，桌上放一杯拿铁，姿态自然随意，背景是虚化的咖啡店与玻璃窗",
    "Screenshot_2026-10-08T103559.png": "韩系氛围感咖啡馆暖色吊灯柔和光线，普通东亚年轻女生戴棒球帽穿宽松奶白毛衣，坐在木桌边双手捧着马克杯，低头看杯中咖啡拉花，桌上放一本书，姿态自然，背景是虚化的咖啡店",
    "Screenshot_2026-10-08T103602.png": "韩系氛围感咖啡馆暖色吊灯柔和光线，普通东亚年轻女生戴棒球帽穿宽松奶白毛衣，坐在沙发位上侧身望向镜头，一手拿着咖啡杯，姿态自然随意，背景是虚化的咖啡店陈设",
}

PREFIX = (
    "这是一张手机拍照应用的拍摄界面截图。请只把图中白色取景框区域内绘制成一幅真实的人像照片画面，"
    "画面要求：真实的手机相机直出写实摄影，保留真实皮肤毛孔和轻微拍照噪点，禁止磨皮、禁止美颜滤镜、禁止光晕、"
    "禁止过分柔光，脸部有自然瑕疵，随手抓拍自然。除此之外，截图里的所有 App 界面元素——顶部标题栏、"
    "取景框的白色边框与框内的人形剪影线条、底部参数与比例条、缩放条、快门按钮、模板信息 Banner、底部四个图标导航，"
    "以及所有文字和图标——必须原样保留，一像素都不能改变、拉伸、变形或遮挡。"
)


def gen_one(name, scene, key):
    base = name.replace(".png", "")
    out_prefix = os.path.join(OUT, base)
    cmd = [
        "python", os.path.join("scripts", "gpt_image2.py"),
        "--platform", "hapi",
        "--model", "gpt-image-2",
        "--image", os.path.join(DIR, name),
        PREFIX + scene,
        "--quality", "high",
        "--out", out_prefix,
    ]
    env = dict(os.environ)
    env["HAPI_API_KEY"] = key
    print(f"\n=== i2i: {name} ===")
    r = subprocess.run(cmd, capture_output=True, text=True, env=env)
    print((r.stdout or "")[-1200:])
    if r.stderr:
        print("[stderr]", r.stderr[-800:])
    return r.returncode == 0


def main():
    key = os.environ.get("HAPI_API_KEY")
    if not key:
        print("[错误] 请设置 HAPI_API_KEY")
        sys.exit(1)
    targets = sys.argv[1:] or list(SCENES.keys())
    ok = 0
    for name in targets:
        if name not in SCENES:
            print(f"[跳过] 未定义场景: {name}")
            continue
        ok += gen_one(name, SCENES[name], key)
    print(f"\n完成: {ok}/{len(targets)}")


if __name__ == "__main__":
    main()