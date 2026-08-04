#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
通过 RouteAll 本地网关 (gen_image.py) 批量生成 17 款人像模板的剪影图。

直接 import gen_image 模块的函数，自行实现下载逻辑（带重试），
避免 subprocess 调用时因 gen_image.py 内 sys.exit(1) 导致整个批次中断。

用法:
  python batch_gen_silhouettes.py                       # 生成全部 17 张剪影
  python batch_gen_silhouettes.py --start 0 --end 3     # 只生成第 0~2 个
  python batch_gen_silhouettes.py --model q3-fast       # 指定模型
  python batch_gen_silhouettes.py --also-covers         # 同时生成效果图
  python batch_gen_silhouettes.py --only-covers         # 只生成效果图

前置条件:
  - RouteAll 网关已启动 (localhost:3000)
  - 环境变量 ROUTEALL_API_KEY 已设置，或修改 gen_image.py 内置 API_KEY
"""

import argparse
import os
import sys
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).parent
sys.path.insert(0, str(HERE))

# 复用模板定义
from batch_generate_templates import TEMPLATES  # noqa: E402

# import gen_image 模块（不使用 from，以便设置其全局变量）
import gen_image  # noqa: E402

PROJECT_ROOT = HERE.parent
OUTPUT_BASE = PROJECT_ROOT / "lumira_app_flutter" / "assets" / "images"
SILHOUETTES_DIR = OUTPUT_BASE / "silhouettes"
COVERS_DIR = OUTPUT_BASE / "templates"

SILHOUETTE_ASPECT = "9:16"

COVER_ASPECT_MAP = {
    "3:4": "9:16",
    "4:5": "9:16",
    "9:16": "9:16",
    "1:1": "1:1",
}

# 下载重试配置
DOWNLOAD_RETRIES = 3
DOWNLOAD_TIMEOUT = 120


def download_with_retry(url: str, out_path: Path, retries: int = DOWNLOAD_RETRIES) -> bool:
    """带重试的图片下载。"""
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for attempt in range(1, retries + 1):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "RouteAll-script/1.0"})
            with opener.open(req, timeout=DOWNLOAD_TIMEOUT) as r:
                data = r.read()
            if data and len(data) > 0:
                out_path.write_bytes(data)
                return True
            print(f"    下载返回空数据 (尝试 {attempt}/{retries})")
        except Exception as e:
            print(f"    下载失败 (尝试 {attempt}/{retries}): {e}")
        if attempt < retries:
            time.sleep(3)
    return False


def generate_one(prompt: str, model: str, aspect_ratio: str,
                 out_dir: Path, filename_prefix: str,
                 idx: int, total: int, label: str) -> bool:
    """生成单张图片：提交任务 -> 轮询 -> 下载 -> 重命名。"""
    print(f"\n{'=' * 60}")
    print(f"[{idx}/{total}] 正在生成{label}...")
    print(f"  aspect={aspect_ratio}")
    print(f"  prompt={prompt[:80]}...", flush=True)

    start = time.time()
    out_dir.mkdir(parents=True, exist_ok=True)

    # 1. 提交任务
    extra = {"aspect_ratio": aspect_ratio}
    try:
        submit = gen_image.submit_task(model, prompt, extra)
    except SystemExit:
        # gen_image.submit_task 失败时会 sys.exit(1)
        elapsed = time.time() - start
        print(f"[{idx}/{total}] 提交失败 ({elapsed:.1f}s)")
        return False

    task_id = submit.get("id")
    if not task_id:
        print(f"[{idx}/{total}] 提交响应无 id: {submit}")
        return False

    # 2. 轮询
    try:
        task = gen_image.poll_task(task_id, poll_interval=5, max_wait=300)
    except SystemExit:
        elapsed = time.time() - start
        print(f"[{idx}/{total}] 轮询失败 ({elapsed:.1f}s)")
        return False

    status = task.get("status")
    if status != "succeeded":
        print(f"[{idx}/{total}] 任务未成功: status={status}")
        return False

    # 3. 获取图片 URL
    url = task.get("result_url") or task.get("cover_url")
    if not url:
        print(f"[{idx}/{total}] 任务成功但无 result_url/cover_url")
        return False

    # 4. 下载（带重试）
    if url.startswith("data:"):
        import base64
        raw = url.split(",", 1)[1]
        out_path = out_dir / f"{filename_prefix}.png"
        out_path.write_bytes(base64.b64decode(raw))
    else:
        ext = ".png"
        if ".mp4" in url or task.get("result_type") == "video":
            ext = ".mp4"
        out_path = out_dir / f"{filename_prefix}_tmp{ext}"
        print(f"  正在下载 (带重试)...", flush=True)
        if not download_with_retry(url, out_path):
            elapsed = time.time() - start
            print(f"[{idx}/{total}] 下载失败 ({elapsed:.1f}s)")
            return False

    # 5. 重命名为模板 ID
    final_path = out_dir / f"{filename_prefix}{out_path.suffix}"
    if final_path.exists():
        final_path.unlink()
    out_path.rename(final_path)

    elapsed = time.time() - start
    print(f"[{idx}/{total}] 完成! 耗时 {elapsed:.1f}s -> {final_path.name}", flush=True)
    return True


def main():
    parser = argparse.ArgumentParser(description="通过 RouteAll 网关批量生成模板剪影图")
    parser.add_argument("--model", default="q3-fast", help="模型名 (q3-fast / q3-lite)")
    parser.add_argument("--start", type=int, default=0, help="起始模板索引 (0-based)")
    parser.add_argument("--end", type=int, default=None, help="结束模板索引 (exclusive)")
    parser.add_argument("--also-covers", action="store_true", help="同时生成效果图")
    parser.add_argument("--only-covers", action="store_true", help="只生成效果图")
    args = parser.parse_args()

    # 确保 gen_image 使用正确的 API_KEY（从环境变量或内置默认值）
    api_key = os.environ.get("ROUTEALL_API_KEY") or gen_image.API_KEY
    gen_image.API_KEY = api_key
    print(f"网关: {gen_image.BASE_URL}")
    print(f"API Key: {api_key[:12]}...{api_key[-4:]}")

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
        print(f"{'#' * 60}", flush=True)
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
        print(f"{'#' * 60}", flush=True)
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

    # 打印失败列表，方便重跑
    failed = [r["id"] for r in results["silhouettes"] if not r["ok"]]
    if failed:
        print(f"\n失败模板 ID: {','.join(failed)}")
        print("可使用 --start/--end 参数重跑失败项")


if __name__ == "__main__":
    main()
