#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成 24 个新增场景的竖版封面并压缩到 assets/images/scenes/。
- 生成模型: qwen-image-3.0-pro (1024x1024)
- 处理: 中心裁切为 3:4 -> 缩放到 600x800 -> JPEG 质量 82 -> scene_<id>.jpg
- 可断点续跑: 目标文件已存在则跳过
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_image  # noqa: E402
from PIL import Image  # noqa: E402

MODEL = "qwen-image-3.0-pro"
ASSET_DIR = os.path.normpath(
    os.path.join(os.path.dirname(os.path.abspath(__file__)),
                 "../lumira_app_flutter/assets/images/scenes")
)
TMP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tmp_scenes")

# id -> 针对该场景的中文封面 prompt (氛围 + 3:4 竖构图 + 电影感灯光)
SCENES = {
    "art-museum": "美术馆艺术展厅场景封面：空旷的现代白色美术馆展厅，几何感展墙与挑高空间，柔和天窗自然光洒下，深色剪影的人站在展画前，电影感构图，3:4 竖构图，氛围高级安静",
    "city-mall": "商场购物场景封面：明亮现代的中庭商场，暖色灯光与玻璃天幕，人们手拎购物袋穿行，通透奶油色调，电影感构图，3:4 竖构图，氛围温馨热闹",
    "hotpot-restaurant": "火锅暖席场景封面：热气腾腾的火锅桌，氤氲蒸汽升腾，暖黄灯光下围坐涮菜，温馨烟火气，电影感构图，3:4 竖构图，氛围温暖治愈",
    "izakaya": "日料居酒屋场景封面：暖红色灯笼与木质吧台，昏黄灯光下的居酒屋，串烧与清酒，浮世绘般温暖氛围，电影感构图，3:4 竖构图，氛围治愈慵懒",
    "gym": "健身房场景封面：落地玻璃健身房，清晨斜光洒在器械与跑步机上，冷色调现代空间，活力动感，电影感构图，3:4 竖构图，氛围自律阳光",
    "dance-studio": "舞蹈练习室场景封面：木质地板大镜面舞蹈室，逆光剪影的舞者在跳跃，深色空间与聚光灯，电影感构图，3:4 竖构图，氛围自由热烈",
    "tea-room": "茶室禅意场景封面：素雅中式茶室，竹帘透进柔和日光，茶具与袅袅茶烟，禅意留白，电影感构图，3:4 竖构图，氛围宁静致远",
    "balcony-garden": "阳台绿植场景封面：洒满阳光的居家阳台，绿植环绕与藤编座椅，柔和晨光下的治愈角落，电影感构图，3:4 竖构图，氛围清新治愈",
    "heritage-courtyard": "老宅天井场景封面：青砖老宅四方天井，天光从上方倾泻而下，梁柱与侧柏剪影，中式建筑美学，电影感构图，3:4 竖构图，氛围静谧怀旧",
    "retro-barber": "复古理发馆场景封面：复古理发馆，老式理发椅与霓虹灯牌，暖橙与粉蓝撞色，胶片质感，电影感构图，3:4 竖构图，氛围复古摩登",
    "night-market": "夜市烟火场景封面：热闹夜市街头，彩色霓虹招牌与鼎沸摊位，热气与灯光交织，人间烟火气，电影感构图，3:4 竖构图，氛围温暖热闹",
    "dawn-mist": "清晨雾光场景封面：清晨薄雾弥漫的道路与树林，第一缕朝阳穿雾而落，柔和青白金辉，电影感构图，3:4 竖构图，氛围缥缈清晨",
    "road-sunset": "落日公路场景封面：笔直延伸的公路伸向落日，金色晚霞铺满天际，逆光剪影的人在路上，电影感构图，3:4 竖构图，氛围辽阔浪漫",
    "street-style": "城市街拍场景封面：现代都市街道，霓虹与建筑交错，潮人穿梭于斑马线，时尚电影感，电影感构图，3:4 竖构图，氛围潮酷活力",
    "hutong": "胡同老巷场景封面：老北京胡同小巷，青灰色砖墙与晾衣绳，午后斜光洒在石板路，市井生活感，电影感构图，3:4 竖构图，氛围烟火怀旧",
    "campus": "校园操场场景封面：绿茵操场与红色跑道，下午阳光下的教学楼，青春身影奔跑，通透清新色调，电影感构图，3:4 竖构图，氛围青春活力",
    "lakeside": "湖畔河堤场景封面：波光粼粼的湖畔河堤，水天一色的柔和光，人沿堤岸散步的剪影，电影感构图，3:4 竖构图，氛围宁静开阔",
    "park-lawn": "公园草地场景封面：开阔翠绿草坪与野餐垫，午后斑驳树影，家庭与风筝，明媚治愈色调，电影感构图，3:4 竖构图，氛围轻松惬意",
    "flower-field": "花海春日场景封面：漫山遍野的春日花海，粉白花朵随风摇曳，逆光下的花田与人的剪影，电影感构图，3:4 竖构图，氛围浪漫梦幻",
    "reed-field": "芦苇秋色场景封面：黄昏芦苇荡，金色芦苇随风起伏，落日余晖与剪影，秋意浓烈，电影感构图，3:4 竖构图，氛围萧瑟唯美",
    "snow-scene": "雪境留白场景封面：纯白雪原与飘雪，皑皑白雪覆盖的寂静大地，一人留下的足印，极简留白，电影感构图，3:4 竖构图，氛围清冷空灵",
    "commuter-rain": "雨中归途场景封面：雨后夜晚的街道，湿漉漉路面的霓虹倒影，撑伞匆匆归家的背影，电影感构图，3:4 竖构图，氛围孤寂治愈",
    "midnight-bookstore": "深夜书店场景封面：深夜安静的独立书店，暖黄灯光与高书架，垂首阅读的身影，静谧氛围，电影感构图，3:4 竖构图，氛围温暖静谧",
    "window-alone": "独坐窗边场景封面：窗前独坐的人，窗外暮色与城市灯光，逆光剪影与咖色室内，留白构图，电影感构图，3:4 竖构图，氛围安静独处",
}


def crop_to_3_4(img: Image.Image) -> Image.Image:
    w, h = img.size
    target = w * 4 / 3  # 目标高度 = 宽度 * (4/3), 保持宽度裁高度
    if h > target:
        top = int((h - target) / 2)
        return img.crop((0, top, w, top + int(target)))
    return img


def process(scene_id: str, raw_path: str) -> str:
    out_path = os.path.join(ASSET_DIR, f"scene_{scene_id}.jpg")
    img = Image.open(raw_path).convert("RGB")
    img = crop_to_3_4(img)
    img = img.resize((600, 800), Image.LANCZOS)
    img.save(out_path, "JPEG", quality=82, optimize=True)
    size_kb = os.path.getsize(out_path) // 1024
    print(f"[OK] {scene_id} -> {out_path} ({size_kb} KB)")
    return out_path


def main():
    os.makedirs(TMP_DIR, exist_ok=True)
    for sid, prompt in SCENES.items():
        out_path = os.path.join(ASSET_DIR, f"scene_{sid}.jpg")
        if os.path.exists(out_path):
            print(f"[跳过] {sid} 已存在")
            continue
        try:
            submit = gen_image.submit_task(MODEL, prompt, {})
            task = gen_image.poll_task(submit["id"], gen_image.POLL_INTERVAL, gen_image.MAX_WAIT)
            if task.get("status") != "succeeded":
                print(f"[失败] {sid} 任务未成功: status={task.get('status')}")
                continue
            gen_image.save_result(task, TMP_DIR)
            # save_result 用时间戳命名, 找到刚保存的最新 png
            raw = max((os.path.join(TMP_DIR, f) for f in os.listdir(TMP_DIR)
                       if f.endswith(".png")), key=lambda p: os.path.getmtime(p))
            process(sid, raw)
        except Exception as e:
            print(f"[异常] {sid}: {e}")


if __name__ == "__main__":
    main()