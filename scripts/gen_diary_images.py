#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
生成「拍摄日记」mock 效果图所需的 8 张照片（展示图⑤：把生活拍成日记）。

后端：9527.codes gpt-image-2.5（OpenAI 兼容 /images/generations）
本脚本只是任务编排：逐条子进程调用 got-image2 技能自带的 generate.py。

前置：必须设置环境变量 CODE_9527_API_KEY（9527 模型组 token，如 codex/gpt-adobe-生图）。

用法:
    python scripts/gen_diary_images.py                        # 生成全部 8 张
    python scripts/gen_diary_images.py --only coffee_01       # 只生成某张
    python scripts/gen_diary_images.py --dry-run              # 只打印将要执行的命令
"""

import argparse
import os
import subprocess
import sys

# 相对本文件路径定位 got-image2 技能的 generate.py
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_GENERATE = os.path.normpath(
    os.path.join(HERE, "..", ".agents", "skills", "got-image2", "scripts", "generate.py")
)
ASSET_DIR = os.path.normpath(
    os.path.join(HERE, "..", "lumira_app_flutter", "assets", "images", "diary")
)

MODEL = "gpt-image-2.5"
SIZE = "1024x1536"  # 竖版 2:3，适配日报网格方形裁剪与 2:2 拼图

# 图片风格基调：莫兰迪低饱和 / 奶油暖调 / 真人实拍 / 构图考究 / 手机摄影感
STYLE_TAIL = (
    "莫兰迪低饱和、奶油暖调、真人实拍、构图考究、柔和光影、手机摄影感、无夸张滤镜、无 AI 感光晕"
)

# (文件名, 描述)
DIARY_IMAGES = [
    # 今天 · 秋日氛围·咖啡探店
    ("mock_coffee_01.png", "秋日咖啡馆内，年轻女生端着拿铁侧身望向窗外，暖光逆光勾勒发丝，木色桌椅与落叶装饰，氛围温馨。"),
    ("mock_coffee_02.png", "咖啡馆木桌上的一杯热拿铁与一本打开的书，暖光透过窗洒落，热气氤氲，温柔的秋日午后。"),
    # 昨天 · 律动街角·街拍
    ("mock_street_01.png", "城市街角，女生行走中的动态人像，微微回头带起衣角与发丝，斑驳光影，街拍抓拍感。"),
    ("mock_street_02.png", "城市街道斑马线，行人在光线下行走的动感剪影，车窗倒影与叶片投影交织，街头电影感。"),
    # 周一 · 城市灯火剪影
    ("mock_night_01.png", "夜晚霓虹灯下的女生人像剪影，身后城市灯火与街灯 bokeh 光斑，蓝紫夜色氛围。"),
    ("mock_night_02.png", "城市夜景长曝光，车流光线与霓虹招牌虚化为暖色 bokeh，夜色中的人影轮廓。"),
    # 更早 · 窗前器物·静物
    ("mock_still_01.png", "窗边暖光下的一只手作陶瓷罐与一小枝干花，柔和侧光，静谧器物之美。"),
    ("mock_still_02.png", "清晨窗台上的玻璃杯、陶瓷杯与绿植，逆光通透，干净轻盈的生活静物。"),
]

PROMPT_TEMPLATE = "{desc}。竖版手机照片，{style}。"


def build_prompts():
    prompts = {}
    for fname, desc in DIARY_IMAGES:
        prompts[fname] = PROMPT_TEMPLATE.format(desc=desc, style=STYLE_TAIL)
    return prompts


def main():
    parser = argparse.ArgumentParser(description="生成日记 mock 8 张照片（gpt-image-2.5）")
    parser.add_argument("--only", default=None, help="只生成指定文件名（不带路径，如 mock_coffee_01.png）")
    parser.add_argument("--dry-run", action="store_true", help="只打印命令不执行")
    args = parser.parse_args()

    if not os.path.exists(SKILL_GENERATE):
        sys.exit(f"[错误] 找不到 generate.py：{SKILL_GENERATE}")

    os.makedirs(ASSET_DIR, exist_ok=True)

    prompts = build_prompts()
    if args.only:
        if args.only not in prompts:
            sys.exit(f"[错误] 未知图片名：{args.only}。可用：{', '.join(prompts)}")
        targets = [args.only]
    else:
        targets = list(prompts.keys())

    if not os.environ.get("CODE_9527_API_KEY"):
        sys.exit("[错误] 未设置环境变量 CODE_9527_API_KEY（9527 模型组 token）。")

    for fname in targets:
        out = os.path.join(ASSET_DIR, fname)
        cmd = [
            sys.executable,
            SKILL_GENERATE,
            prompts[fname],
            "--model", MODEL,
            "--size", SIZE,
            "--output", out,
        ]
        if args.dry_run:
            print("[dry-run] " + " ".join(cmd))
            continue
        print(f"\n[生成] {fname}  ->  {out}")
        r = subprocess.run(cmd, env=os.environ.copy())
        if r.returncode != 0:
            print(f"[错误] {fname} 生成失败，rc={r.returncode}")
            sys.exit(r.returncode)
        print(f"[完成] {fname}")


if __name__ == "__main__":
    main()