#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通过 RouteAll 本地网关 (gen_image.py) 批量生成 17 款人像模板的剪影图。

用法:
  python batch_gen_silhouettes.py                       # 生成全部 17 张剪影
  python batch_gen_silhouettes.py --start 0 --end 3     # 只生成第 0~2 个
  python batch_gen_silhouettes.py --model q3-fast       # 指定模型
  python batch_gen_silhouettes.py --also-covers         # 同时生成效果图

前置条件:
  - RouteAll 网关已启动 (localhost:3000)
  - 环境变量 ROUTEALL_API_KEY 已设置，或修改 gen_image.py 内置 API_KEY
"""

import argparse
import os
import re
import subprocess
import sys
import time
from pathlib import Path

# 复用 batch_generate_templates.py 中的模板定义
HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))
from batch_generate_templates import TEMPLATES  # noqa: E402

GEN_SCRIPT = HERE / "gen_image.py"
PROJECT_ROOT = HERE.parent
OUTPUT_BASE = PROJECT_ROOT / "lumira_app_flutter" / "assets" / "images"
SILHOUETTES_DIR = OUTPUT_BASE / "silhouettes"
COVERS_DIR = OUTPUT_BASE / "templates"

# 剪影统一使用 9:16（gen_image.py 不支持 1:2，9:16 最接近）
# 注意：q3-fast/q3-lite 不支持 resolution 参数，仅用 aspect-ratio
SILHOUETTE_ASPECT = "9:16"

# 画幅 -> aspect-ratio 映射（效果图用）
COVER_ASPECT_MAP = {
    "3:4": "9:16",  # 3:4 最接近 9:16（竖向）
    "4:5": "9:16",
    "9:16": "9:16",
    "1:1": "1:1",
}


def call_gen_image(prompt: str, model: str, aspect_ratio: str,
                   out_dir: Path) -> Path | None:
    """调用 gen_image.py 生成单张图片，返回保存的文件路径。"""
    out_dir.mkdir(parents=True, exist_ok=True)
    cmd = [
        sys.executable,
        str(GEN_SCRIPT),
        prompt,
        "--model", model,
        "--aspect-ratio", aspect_ratio,
        "--out", str(out_dir),
    ]
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=300,
        )
        if result.returncode != 0:
            print(f"  [错误] 生成失败 (exit={result.returncode})")
            if result.stdout:
                print(f"  stdout: {result.stdout[-500:]}")
            if result.stderr:
                print(f"  stderr: {result.stderr[-500:]}")
            return None

        # 解析 stdout 找到保存路径: "[完成] 已保存 <path>  <- <url>"
        for line in result.stdout.split("\n"):
            if "[完成] 已保存" in line:
                match = re.search(r"已保存\s+(\S+)", line)
                if match:
                    return Path(match.group(1))
        # 没匹配到，打印全部输出帮助排查
        print(f"  [警告] 未找到保存路径，完整输出:")
        print(result.stdout[-800:])
        return None
    except subprocess.TimeoutExpired:
        print(f"  [错误] 超时 (>300s)")
        return None
    except Exception as e:
        print(f"  [错误] 异常: {e}")
        return None


def generate_one(prompt: str, model: str, aspect_ratio: str,
                 out_dir: Path, filename_prefix: str,
                 idx: int, total: int, label: str) -> bool:
    """生成单张图片并重命名为模板 ID。"""
    print(f"\n{'=' * 60}")
    print(f"[{idx}/{total}] 正在生成{label}...")
    print(f"  aspect={aspect_ratio}")
    print(f"  prompt={prompt[:80]}...")

    start = time.time()
    saved = call_gen_image(prompt, model, aspect_ratio, out_dir)
    if not saved:
        elapsed = time.time() - start
        print(f"[{idx}/{total}] 生成失败 ({elapsed:.1f}s)")
        return False

    # 重命名为模板 ID
    ext = saved.suffix or ".png"
    final_path = out_dir / f"{filename_prefix}{ext}"
    if final_path.exists():
        final_path.unlink()
    saved.rename(final_path)

    elapsed = time.time() - start
    print(f"[{idx}/{total}] 完成! 耗时 {elapsed:.1f}s -> {final_path.name}")
    return True


def main():
    parser = argparse.ArgumentParser(description="通过 RouteAll 网关批量生成模板剪影图")
    parser.add_argument("--model", default="q3-fast", help="模型名 (q3-fast / q3-lite)")
    parser.add_argument("--start", type=int, default=0, help="起始模板索引 (0-based)")
    parser.add_argument("--end", type=int, default=None, help="结束模板索引 (exclusive)")
    parser.add_argument("--also-covers", action="store_true", help="同时生成效果图")
    parser.add_argument("--only-covers", action="store_true", help="只生成效果图")
    args = parser.parse_args()

    end = args.end or len(TEMPLATES)
    templates = TEMPLATES[args.start:end]
    total = len(templates)

    print(f"共 {total} 个模板")
    print(f"模型: {args.model}")
    print(f"剪影输出: {SILHOUETTES_DIR}")
    if args.also_covers or args.only_covers:
        print(f"效果图输出: {COVERS_DIR}")

    results = {"covers": [], "silhouettes": []}

    # 生成效果图
    if args.also_covers or args.only_covers:
        print(f"\n{'#' * 60}")
        print(f"# 开始生成效果图 ({total} 张)")
        print(f"{'#' * 60}")
        for i, tpl in enumerate(templates, 1):
            idx = args.start + i
            aspect = COVER_ASPECT_MAP.get(tpl["aspect"], "9:16")
            ok = generate_one(
                tpl["cover_prompt"], args.model, aspect,
                COVERS_DIR, tpl["id"], idx, total, f"{tpl['name']}效果图",
            )
            results["covers"].append({"id": tpl["id"], "name": tpl["name"], "ok": ok})

    # 生成剪影
    if not args.only_covers:
        print(f"\n{'#' * 60}")
        print(f"# 开始生成剪影 ({total} 张)")
        print(f"{'#' * 60}")
        for i, tpl in enumerate(templates, 1):
            idx = args.start + i
            ok = generate_one(
                tpl["silhouette_prompt"], args.model,
                SILHOUETTE_ASPECT,
                SILHOUETTES_DIR, tpl["id"], idx, total, f"{tpl['name']}剪影",
            )
            results["silhouettes"].append({"id": tpl["id"], "name": tpl["name"], "ok": ok})

    # 汇总
    print(f"\n{'=' * 60}")
    print("生成结果汇总")
    print(f"{'=' * 60}")
    if results["covers"]:
        ok_count = sum(1 for r in results["covers"] if r["ok"])
        print(f"\n效果图: {ok_count}/{len(results['covers'])} 成功")
        for r in results["covers"]:
            status = "v" if r["ok"] else "x"
            print(f"  [{status}] {r['id']} ({r['name']})")
    if results["silhouettes"]:
        ok_count = sum(1 for r in results["silhouettes"] if r["ok"])
        print(f"\n剪影: {ok_count}/{len(results['silhouettes'])} 成功")
        for r in results["silhouettes"]:
            status = "v" if r["ok"] else "x"
            print(f"  [{status}] {r['id']} ({r['name']})")


if __name__ == "__main__":
    main()
