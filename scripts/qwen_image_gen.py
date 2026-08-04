#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
千问 AI 平台 (Token Plan) 文生图脚本

端点: https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation
官方文档: https://platform.qianwenai.com/docs/developer-guides/image-generation/text-to-image

依赖: 仅 Python 标准库（无需安装任何第三方包）
API Key: 优先级 --api-key 命令行参数 > 脚本内 DEFAULT_API_KEY 变量 > 环境变量 DASHSCOPE_API_KEY

用法示例:
  # 基本使用
  python qwen_image_gen.py --prompt "一间有着精致窗户的花店，漂亮的木质门，摆放着花朵"

  # 指定模型和分辨率
  python qwen_image_gen.py --prompt "赛博朋克风格的城市夜景" --model wan2.7-image-pro --size 2048*2048

  # 生成多张
  python qwen_image_gen.py --prompt "可爱猫咪" --n 4

  # 交互模式（不传 --prompt 时从命令行输入）
  python qwen_image_gen.py
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

try:
    import requests as _requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# Token Plan 专属端点
API_URL = "https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation"

# 默认 API Key（脚本内变量，可在此修改）。
# 优先级: --api-key 命令行参数 > 本变量 > 环境变量 DASHSCOPE_API_KEY
DEFAULT_API_KEY = "sk-sp-H.XLLDX.RN0w.MEQCIDncJKK5FJRY6PcZdBvrgnVsvc2U4QZVFVTrTq7F86TfAiAnLO8PugIJ9re0ivo88LIRvKT9DNlYtK9aBPpdUCmaZA"

# 默认负面提示词（参考官方文档示例），可覆盖
DEFAULT_NEGATIVE_PROMPT = (
    "low resolution, severe blur, out of focus, overexposed, underexposed, "
    "heavy noise, grain, compression artifacts, smearing, chromatic aberration, "
    "excessive skin smoothing, plastic look, oversaturated, harsh contrast, "
    "HDR artifacts, loss of tonal range, obvious color cast, white balance error, "
    "distortion, content logic errors, pseudo-text gibberish, typographical errors, "
    "spelling mistakes, watermarks, overlays."
)


def call_api(api_key: str, model: str, prompt: str, size: str,
             n: int, negative_prompt: str, prompt_extend: bool,
             watermark: bool) -> dict:
    """调用千问文生图 API，返回完整 JSON 响应。"""
    payload = {
        "model": model,
        "input": {
            "messages": [
                {
                    "role": "user",
                    "content": [{"text": prompt}]
                }
            ]
        },
        "parameters": {
            "prompt_extend": prompt_extend,
            "watermark": watermark,
            "n": n,
            "negative_prompt": negative_prompt or "",
        }
    }
    if size:
        payload["parameters"]["size"] = size

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        API_URL,
        data=data,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        resp = urllib.request.urlopen(req, timeout=300)
        return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")
        print(f"HTTP {e.code}: {body}")
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"网络错误: {e.reason}")
        sys.exit(1)


def extract_images(response: dict) -> list:
    """从响应中提取所有图片 URL。"""
    urls = []
    choices = response.get("output", {}).get("choices", [])
    for choice in choices:
        content = choice.get("message", {}).get("content", [])
        for item in content:
            if isinstance(item, dict) and item.get("image"):
                urls.append(item["image"])
    return urls


def download_images(urls: list, output_dir: str) -> list:
    """下载图片到本地目录，返回保存的文件路径列表。"""
    os.makedirs(output_dir, exist_ok=True)
    saved = []
    for i, url in enumerate(urls):
        ext = os.path.splitext(url.split("?")[0])[1] or ".png"
        path = os.path.join(output_dir, f"qwen_img_{int(time.time())}_{i + 1}{ext}")
        print(f"正在下载: {url}")
        try:
            if HAS_REQUESTS:
                resp = _requests.get(url, timeout=120)
                resp.raise_for_status()
                with open(path, "wb") as f:
                    f.write(resp.content)
            else:
                with urllib.request.urlopen(url, timeout=120) as resp, open(path, "wb") as f:
                    f.write(resp.read())
            saved.append(path)
            print(f"已保存: {path}")
        except Exception as e:
            print(f"下载失败: {e}")
    return saved


def parse_args():
    parser = argparse.ArgumentParser(
        description="基于千问 AI 平台 (Token Plan) 的文生图脚本",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter,
    )
    parser.add_argument("--prompt", help="图片描述提示词（不传则进入交互模式）")
    parser.add_argument("--model", default="wan2.7-image",
                        help="模型名，如 wan2.7-image / wan2.7-image-pro / "
                             "qwen-image-2.0-pro / qwen-image-max / qwen-image-plus")
    parser.add_argument("--size", help="分辨率，如 1280*1280 / 2048*2048；Wan 2.7 可用简写 1K/2K/4K")
    parser.add_argument("--n", type=int, default=1,
                        help="生成图片数量（测试阶段建议为 1）")
    parser.add_argument("--output", default="./qwen_images", help="图片输出目录")
    parser.add_argument("--api-key", help="API Key（默认优先使用脚本内 DEFAULT_API_KEY 变量，其次环境变量 DASHSCOPE_API_KEY）")
    parser.add_argument("--negative-prompt", default=DEFAULT_NEGATIVE_PROMPT,
                        help="负面提示词（wan2.7-image-pro / wan2.7-image 不支持，会自动忽略）")
    parser.add_argument("--no-prompt-extend", action="store_true",
                        help="禁用提示词自动扩展（默认开启）")
    parser.add_argument("--watermark", action="store_true",
                        help="启用水印（默认关闭）")
    return parser.parse_args()


def main():
    args = parse_args()

    api_key = args.api_key or DEFAULT_API_KEY or os.getenv("DASHSCOPE_API_KEY")
    if not api_key:
        print("未找到 API Key。请设置环境变量 DASHSCOPE_API_KEY、使用 --api-key 参数，或修改脚本内 DEFAULT_API_KEY 变量。")
        sys.exit(1)

    prompt = args.prompt
    if not prompt:
        prompt = input("请输入图片描述提示词: ").strip()
        if not prompt:
            print("提示词不能为空。")
            sys.exit(1)

    model = args.model
    # wan2.7-image-pro / wan2.7-image 不支持 negative_prompt 与 prompt_extend
    if model in ("wan2.7-image-pro", "wan2.7-image"):
        negative_prompt = ""
        prompt_extend = True
    else:
        negative_prompt = args.negative_prompt
        prompt_extend = not args.no_prompt_extend

    print(f"调用模型 {model} 生成图片...")
    response = call_api(
        api_key=api_key,
        model=model,
        prompt=prompt,
        size=args.size,
        n=args.n,
        negative_prompt=negative_prompt,
        prompt_extend=prompt_extend,
        watermark=args.watermark,
    )

    urls = extract_images(response)
    if not urls:
        print("未在响应中找到图片 URL。")
        print("完整响应:", json.dumps(response, ensure_ascii=False, indent=2))
        sys.exit(1)

    print(f"共生成 {len(urls)} 张图片，开始下载...")
    saved = download_images(urls, args.output)
    if saved:
        print(f"完成！图片已保存至: {args.output}")
    else:
        print("图片下载失败。")


if __name__ == "__main__":
    main()
