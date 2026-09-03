#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成 10 个新增常用场景的竖版封面并压缩到 assets/images/scenes/。
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
TMP_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "tmp_scenes10")

# id -> 针对该场景的中文封面 prompt (氛围 + 3:4 竖构图 + 电影感灯光)
SCENES = {
    "living-room": "家里客厅场景封面：明亮舒适的现代客厅，落地窗洒进午后阳光，米色沙发与绿植，暖色木质地板，治愈居家感，电影感构图，3:4 竖构图",
    "classroom": "学校教室场景封面：洒进阳光的明亮教室，木质课桌与黑板，窗户光线斜射，青春求学氛围，通透清新，电影感构图，3:4 竖构图",
    "dormitory": "大学宿舍场景封面：温馨整洁的宿舍床位，暖黄台灯与挂帘，窗外夜色，个人小天地，电影感构图，3:4 竖构图，氛围温暖",
    "noodle-shop": "面馆烟火场景封面：热气腾腾的小面馆，氤氲蒸汽中一碗面，暖黄灯光与木质桌椅，烟火气疗愈，电影感构图，3:4 竖构图",
    "canteen": "学校食堂场景封面：明亮熙攘的食堂，暖色灯光下的取餐窗口与餐桌，青春饭点气息，电影感构图，3:4 竖构图",
    "office": "现代办公室场景封面：落地玻璃的现代办公区，自然光洒在工位与绿植，专注工作氛围，通透冷调，电影感构图，3:4 竖构图",
    "city-square": "城市广场场景封面：开阔的城市广场，喷泉与鸽子，晚霞下的人群与建筑轮廓，都市开阔氛围，电影感构图，3:4 竖构图",
    "basketball-court": "篮球场场景封面：夕阳下的户外篮球场，地胶与球架剪影，少年跃起投篮，动感活力，电影感构图，3:4 竖构图",
    "market": "菜市场烟火场景封面：清晨热闹的菜市场，缤纷蔬菜水果摊与暖黄灯光，买卖忙碌，人间烟火气，电影感构图，3:4 竖构图",
    "bus-stop": "公交站台场景封面：黄昏的公交站台，站牌与候车人影，街道车流与灯光，归途氛围，电影感构图，3:4 竖构图",
}


def crop_to_3_4(img):
    w, h = img.size
    target = w * 4 / 3
    if h > target:
        top = int((h - target) / 2)
        return img.crop((0, top, w, top + int(target)))
    return img


def main():
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
            raw = max((os.path.join(TMP_DIR, f) for f in os.listdir(TMP_DIR)
                       if f.endswith(".png")), key=lambda p: os.path.getmtime(p))
            img = Image.open(raw).convert("RGB")
            img = crop_to_3_4(img).resize((600, 800), Image.LANCZOS)
            img.save(out_path, "JPEG", quality=82, optimize=True)
            os.remove(raw)
            print(f"[OK] {sid} -> {out_path} ({os.path.getsize(out_path)//1024} KB)")
        except Exception as e:
            print(f"[异常] {sid}: {e}")


if __name__ == "__main__":
    main()