"""
纯色背景去除脚本
将图片中的纯色背景（如白色、绿色、蓝色）去除，输出透明背景 PNG。

用法:
  python remove_background.py input.jpg                      # 单张，自动检测背景色
  python remove_background.py input.jpg -o result.png        # 指定输出路径
  python remove_background.py ./photos/                      # 批量处理目录
  python remove_background.py input.jpg --color "#FFFFFF"    # 手动指定背景色
  python remove_background.py input.jpg --tolerance 40       # 调整去除范围

参数说明:
  --color      背景颜色，格式 "#FFFFFF" 或 "255,255,255"。不指定时自动取四角颜色
  --tolerance  颜色容差 0-255，越大去除越多（默认 30）
  --feather    边缘羽化像素数，让边缘更平滑（默认 3）
"""

import argparse
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SUPPORTED_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp", ".tiff", ".tif"}


def parse_color(text):
    """解析 #RRGGBB 或 R,G,B 格式的颜色"""
    text = text.strip()
    if text.startswith("#"):
        text = text[1:]
        if len(text) == 3:
            text = "".join(c * 2 for c in text)
        return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))
    parts = [int(p.strip()) for p in text.split(",")]
    if len(parts) != 3:
        raise ValueError("颜色格式应为 #RRGGBB 或 R,G,B")
    return tuple(parts)


def detect_bg_color(img):
    """取图片四角区域的平均颜色作为背景色"""
    w, h = img.size
    size = max(4, min(w, h) // 20)
    corners = [
        img.crop((0, 0, size, size)),
        img.crop((w - size, 0, w, size)),
        img.crop((0, h - size, size, h)),
        img.crop((w - size, h - size, w, h)),
    ]
    arr = np.concatenate([np.asarray(c, dtype=np.int16).reshape(-1, 3) for c in corners])
    return tuple(int(x) for x in arr.mean(axis=0))


def remove_background(img, bg_color, tolerance, feather):
    """去除纯色背景，返回透明 PNG 图像"""
    img = img.convert("RGBA")
    rgb = np.asarray(img.convert("RGB"), dtype=np.float32)
    bg = np.array(bg_color, dtype=np.float32)

    # 与背景色的欧氏距离
    dist = np.sqrt(((rgb - bg) ** 2).sum(axis=2))

    # 距离小于 tolerance 的为背景；feather 范围内做渐变过渡
    inner = tolerance
    outer = tolerance + feather
    alpha = np.clip((dist - inner) / max(outer - inner, 1.0), 0.0, 1.0)
    alpha = (alpha * 255).astype(np.uint8)

    rgba = np.dstack([rgb.astype(np.uint8), alpha])
    return Image.fromarray(rgba, "RGBA")


def process_file(src, dst, bg_color, tolerance, feather):
    img = Image.open(src)
    result = remove_background(img, bg_color, tolerance, feather)
    dst.parent.mkdir(parents=True, exist_ok=True)
    result.save(dst, "PNG")


def main():
    parser = argparse.ArgumentParser(description="去除图片纯色背景，输出透明 PNG")
    parser.add_argument("input", type=Path, help="输入图片路径或包含图片的目录")
    parser.add_argument("-o", "--output", type=Path, default=None,
                        help="输出路径（单图模式）。批量模式自动保存到 <目录>_nobg/")
    parser.add_argument("--color", default=None,
                        help="背景色 #RRGGBB 或 R,G,B，默认自动检测四角颜色")
    parser.add_argument("--tolerance", type=int, default=30,
                        help="颜色容差 0-255，越大去除越多（默认 30）")
    parser.add_argument("--feather", type=int, default=3,
                        help="边缘羽化像素数（默认 3）")
    args = parser.parse_args()

    input_path = args.input
    if not input_path.exists():
        print(f"错误：路径不存在 {input_path}", file=sys.stderr)
        sys.exit(1)

    # 收集文件
    if input_path.is_dir():
        files = sorted(
            p for p in input_path.iterdir()
            if p.is_file() and p.suffix.lower() in SUPPORTED_EXTS
        )
        if not files:
            print(f"目录中没有找到支持的图片：{input_path}", file=sys.stderr)
            sys.exit(1)
        out_dir = input_path.parent / f"{input_path.name}_nobg"
        tasks = [(f, out_dir / f"{f.stem}_nobg.png") for f in files]
        print(f"找到 {len(tasks)} 张图片，输出目录：{out_dir}")
    else:
        if args.output:
            out_path = args.output
        else:
            out_path = input_path.parent / f"{input_path.stem}_nobg.png"
        tasks = [(input_path, out_path)]

    # 每张图片单独检测背景色（避免混合检测）
    for i, (src, dst) in enumerate(tasks, 1):
        img = Image.open(src)
        bg_color = parse_color(args.color) if args.color else detect_bg_color(img)
        print(f"[{i}/{len(tasks)}] {src.name} 背景色={bg_color} 容差={args.tolerance}", flush=True)
        try:
            process_file(src, dst, bg_color, args.tolerance, args.feather)
        except Exception as e:
            print(f"  失败：{e}")
            continue
        print(f"  完成 -> {dst}")

    print(f"\n全部处理完成，共 {len(tasks)} 张。")


if __name__ == "__main__":
    main()
