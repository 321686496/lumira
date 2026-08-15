#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成"拍摄小课堂"教程图片（20 封面 16:9 + 20 步骤图 4:3）。

复用 gen_image.py 的 MaaS 提交/轮询逻辑，逐张生成并直接保存到
lumira_app_flutter/assets/images/tutorials/{name}.png。
统一风格：暖米白 + 金棕品牌色调，柔和自然光，高级质感，干净构图。
"""
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gen_image as g  # noqa: E402

MODEL = os.environ.get("MASS_MODEL", "qwen-image-3.0")
MAX_RETRY = 3
OUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "lumira_app_flutter", "assets", "images", "tutorials",
)

STYLE = "暖米白与金棕品牌色调，柔和自然光，高级质感，干净构图，无文字无水印"

# (文件名, prompt, size)
IMAGES = [
    # ===== 封面 16:9 =====
    ("cover_tut_general_premium", f"极简高级感静物摄影，米白背景上一只咖啡杯与一本书，大片留白，低饱和莫兰迪色调，午后斜阳。{STYLE}", "16:9"),
    ("cover_tut_general_vibe", f"氛围感逆光摄影，人物剪影轮廓镀金色光边，薄雾弥漫，暖调暗色背景，情绪浓郁。{STYLE}", "16:9"),
    ("cover_tut_general_angle", f"摄影角度示意，仰拍与俯拍机位对比，简洁画面，暖米白调。{STYLE}", "16:9"),
    ("cover_tut_general_light", f"侧光塑形摄影，光从侧面打来，主体一半亮一半暗，立体感强，暖金色调。{STYLE}", "16:9"),
    ("cover_tut_general_composition", f"三分法构图示意，画面被九宫格线划分，主体位于交点，简洁暖米白背景。{STYLE}", "16:9"),
    ("cover_tut_general_color", f"莫兰迪色系静物组合，低饱和蓝灰与暖棕器物，相邻色配色，高级质感。{STYLE}", "16:9"),
    ("cover_tut_portrait_window", f"窗边人像摄影，人物侧对窗口，柔和窗光塑造脸部立体感，暖米白窗帘，眼神明亮。{STYLE}", "16:9"),
    ("cover_tut_portrait_backlight", f"逆光人像，人物发丝与轮廓镀金色光边，黄金时刻日落背景，浪漫氛围。{STYLE}", "16:9"),
    ("cover_tut_landscape_golden", f"黄金时刻风光摄影，山峦在日出暖光中拉长影子，天空暖色渐变，开阔留白。{STYLE}", "16:9"),
    ("cover_tut_landscape_leading", f"引导线构图风光，一条小路斜穿画面引向远山，纵深强烈，暖金夕照。{STYLE}", "16:9"),
    ("cover_tut_food_flatlay", f"俯拍美食平铺，木质餐桌上咖啡杯面包与餐具整齐摆盘，俯拍视角，暖米白调。{STYLE}", "16:9"),
    ("cover_tut_food_natural", f"自然光美食摄影，窗边一份早餐，柔和侧光，白纸补光效果，暖调干净。{STYLE}", "16:9"),
    ("cover_tut_street_decisive", f"街头决定性瞬间，路口行人恰好走入画面，光影交错，电影感暖调街拍。{STYLE}", "16:9"),
    ("cover_tut_street_shadow", f"街头光影摄影，建筑影子在地面切出光带，一人走入光中，明暗对比强烈。{STYLE}", "16:9"),
    ("cover_tut_night_bluetime", f"蓝调时刻城市夜景，日落后天空深邃克莱因蓝，暖黄路灯刚亮起，水面反射。{STYLE}", "16:9"),
    ("cover_tut_night_neon", f"霓虹人像，人物身后粉蓝霓虹灯管做背景光斑，暖冷撞色，电影感。{STYLE}", "16:9"),
    ("cover_tut_macro_detail", f"微距摄影，叶片上一颗晶莹水珠映出彩色光斑，极浅景深，暖金光线。{STYLE}", "16:9"),
    ("cover_tut_macro_flower", f"花卉微距摄影，清晨花瓣上露珠与绒毛在侧逆光下发光，暗色背景，暖调。{STYLE}", "16:9"),
    ("cover_tut_still_minimal", f"极简静物摄影，米白背景上一个主体器物，一束侧光，干净留白。{STYLE}", "16:9"),
    ("cover_tut_still_warm", f"温暖静物摄影，午后斜阳洒在咖啡杯书本绿植上，同色系原木米白，光斑点点。{STYLE}", "16:9"),
    # ===== 步骤图 4:3 =====
    ("step_tut_general_premium_1", f"统一色调静物，同色系米白暖棕器物不超过三色，低饱和高级质感。{STYLE}", "4:3"),
    ("step_tut_general_vibe_1", f"逆光氛围，主体轮廓镀金色光边，薄雾前景，暖调暗背景。{STYLE}", "4:3"),
    ("step_tut_general_angle_1", f"微微仰拍人像机位，镜头略低于人物视线，显高显精神，暖调。{STYLE}", "4:3"),
    ("step_tut_general_light_1", f"侧光塑形，主体一半亮一半暗，立体感强，暖金侧光。{STYLE}", "4:3"),
    ("step_tut_general_composition_1", f"三分法构图，主体置于画面交点，简洁暖米白背景。{STYLE}", "4:3"),
    ("step_tut_general_color_1", f"相邻色配色静物，低饱和蓝灰与暖棕器物和谐搭配，高级莫兰迪调。{STYLE}", "4:3"),
    ("step_tut_portrait_window_1", f"窗边人像特写，人物眼睛里映出窗光高光，柔和窗光，暖调。{STYLE}", "4:3"),
    ("step_tut_portrait_backlight_1", f"逆光人像特写，脸部边缘保留金色轮廓光，发丝光清晰。{STYLE}", "4:3"),
    ("step_tut_landscape_golden_1", f"黄金时刻侧光风光，山峦沙丘纹理立体，暖金低角度光。{STYLE}", "4:3"),
    ("step_tut_landscape_leading_1", f"引导线从画面一角斜入，小路引向远方主体，纵深感强。{STYLE}", "4:3"),
    ("step_tut_food_flatlay_1", f"俯拍美食，餐具当画框，盘子杯子餐巾构成画面，暖米白调。{STYLE}", "4:3"),
    ("step_tut_food_natural_1", f"窗边美食暗面用白纸补光，柔和侧光，干净暖调。{STYLE}", "4:3"),
    ("step_tut_street_decisive_1", f"街头预对焦抓拍，人物走入预构图位置，决定性瞬间，暖调街拍。{STYLE}", "4:3"),
    ("step_tut_street_shadow_1", f"街头一人走进地面光带，明暗交界处，光影对比强烈。{STYLE}", "4:3"),
    ("step_tut_night_bluetime_1", f"蓝调时刻，暖黄路灯点缀深邃蓝色天空，城市巷口。{STYLE}", "4:3"),
    ("step_tut_night_neon_1", f"霓虹人像，人物身后粉蓝霓虹光斑，脸朝向光源，电影感。{STYLE}", "4:3"),
    ("step_tut_macro_detail_1", f"微距细节，手肘支撑固定手机拍摄，对焦到水珠核心，极浅景深。{STYLE}", "4:3"),
    ("step_tut_macro_flower_1", f"花卉微距，侧逆光下花瓣绒毛与露珠发光，对焦花蕊，暗背景。{STYLE}", "4:3"),
    ("step_tut_still_minimal_1", f"极简静物，纯色纸背景上一个主体，一束侧光，干净阴影。{STYLE}", "4:3"),
    ("step_tut_still_warm_1", f"温暖静物，午后斜阳把桌面光斑拍进画面，咖啡杯书本，暖金调。{STYLE}", "4:3"),
]


def _submit(model, prompt, size):
    """提交任务，失败抛异常（不退出进程）。"""
    status, data = g.http_json("POST", "/v1/generations", {"model": model, "prompt": prompt, "size": size})
    if status != 200:
        raise RuntimeError(f"提交失败 HTTP {status}: {data}")
    task_id = data.get("id")
    if not task_id:
        raise RuntimeError(f"提交响应无 id: {data}")
    return task_id


def _poll(task_id):
    """轮询至终态，返回数据字典。"""
    path = f"/v1/generations/{task_id}"
    deadline = time.time() + g.MAX_WAIT
    while True:
        status, data = g.http_json("GET", path)
        if status != 200:
            raise RuntimeError(f"查询任务失败 HTTP {status}: {data}")
        st = data.get("status")
        if st in g.TERMINAL:
            return data
        if st not in ("queued", "processing"):
            raise RuntimeError(f"未知状态 {st}: {data}")
        if time.time() > deadline:
            raise RuntimeError(f"等待超时(>{g.MAX_WAIT}s)")
        time.sleep(g.POLL_INTERVAL)


def generate_one(name, prompt, size):
    """生成单张，含重试；成功保存后返回 True，彻底失败返回 False。"""
    import time
    target = os.path.join(OUT_DIR, f"{name}.png")
    for attempt in range(1, MAX_RETRY + 1):
        try:
            print(f"\n===== 生成 {name} ({size}) 第 {attempt}/{MAX_RETRY} 次 =====")
            task_id = _submit(MODEL, prompt, size)
            task = _poll(task_id)
            if task.get("status") != "succeeded":
                print(f"[错误] {name} 未成功: {task.get('status')}")
                return False
            url = task.get("result_url")
            if not url:
                print(f"[错误] {name} 无 result_url")
                return False
            if url.startswith("data:"):
                import base64
                data_bytes = base64.b64decode(url.split(",", 1)[1])
                with open(target, "wb") as f:
                    f.write(data_bytes)
            else:
                req = urllib.request.Request(
                    url, headers={"User-Agent": "MaaS-script/1.0"}
                )
                with g._opener.open(req, timeout=120) as r, open(target, "wb") as f:
                    f.write(r.read())
            print(f"[完成] 已保存 {target}")
            return True
        except Exception as e:  # noqa: BLE001
            print(f"[重试] {name} 第 {attempt} 次失败: {e}")
    print(f"[失败] {name} 重试 {MAX_RETRY} 次后仍失败")
    return False


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    failed = []
    for name, prompt, size in IMAGES:
        target = os.path.join(OUT_DIR, f"{name}.png")
        if os.path.exists(target):
            print(f"[跳过] {name} 已存在")
            continue
        if not generate_one(name, prompt, size):
            failed.append(name)
    print(f"\n完成：成功生成 {len(IMAGES) - len(failed)} 张，失败 {len(failed)} 张")
    if failed:
        print("失败清单:", failed)


if __name__ == "__main__":
    main()