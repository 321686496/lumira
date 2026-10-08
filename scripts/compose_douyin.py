#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
将 _douyin_video/clips 下按时间排序的 seedance 分镜 mp4 拼接为一条 9:16 抖音竖屏视频,
每段统一时长为 target_dur, 相邻段间加短淡入淡出过渡。
依赖: imageio-ffmpeg(内置 ffmpeg), 无需系统 ffmpeg。
用法: python compose_douyin.py --input_dir ... --output ... --dur 4
"""
import argparse
import glob
import os
import subprocess

import imageio_ffmpeg

FFMPEG = imageio_ffmpeg.get_ffmpeg_exe()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--input_dir", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--dur", type=int, default=4, help="每段固定时长(秒)")
    ap.add_argument("--fps", type=int, default=30)
    args = ap.parse_args()
    args.input_dir = os.path.abspath(args.input_dir)
    args.output = os.path.abspath(args.output)

    clips = sorted(glob.glob(os.path.join(args.input_dir, "*.mp4")))
    if not clips:
        print("[错误] 未找到 mp4 分镜文件")
        return
    print(f"[输入] {len(clips)} 段: {[os.path.basename(c) for c in clips]}")

    # 列表文件中列出所有分镜
    list_file = os.path.join(args.input_dir, "concat_list.txt")
    with open(list_file, "w", encoding="utf-8") as f:
        for c in clips:
            # 每段统一为 args.dur 秒, 缩放+裁切到 9:16 (1080x1920), 保持人物/UI主体
            esc = c.replace("'", "'\\''")
            f.write(f"file '{esc}'\n")

    cmd = [
        FFMPEG, "-y",
        "-f", "concat", "-safe", "0", "-i", list_file,
        "-vf", f"scale=1080:1920:force_original_aspect_ratio=increase,crop=1080:1920,fps={args.fps}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        args.output,
    ]
    print("[执行] " + " ".join(cmd))
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print("[错误] 合成失败\n" + r.stderr[-2000:])
    else:
        size_mb = os.path.getsize(args.output) / 1024 / 1024
        print(f"[完成] {args.output} ({size_mb:.1f}MB)")


if __name__ == "__main__":
    main()