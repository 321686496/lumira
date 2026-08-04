#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
批量生成动作库图片脚本

从 MD 文件提取写实风提示词，调用 gen_image.py 生成图片并保存到项目资源目录。

用法:
    python batch_gen_images.py
"""

import os
import re
import subprocess
import sys
import time
from pathlib import Path

# 项目路径
PROJECT_ROOT = Path(r"d:\app\projects\health_training")
MD_FILE = PROJECT_ROOT / "动作库全量动作指南与AI绘图提示词.md"
GEN_SCRIPT = PROJECT_ROOT / "scripts" / "gen_image.py"
OUTPUT_DIR = PROJECT_ROOT / "fittrack_flutter" / "assets" / "images" / "exercises"

# 模型配置
MODEL = "q3-fast"


def parse_md_file():
    """解析 MD 文件，提取所有写实风提示词"""
    print(f"[解析] 读取 {MD_FILE}")
    content = MD_FILE.read_text(encoding="utf-8")
    
    # 提取动作 ID 和英文名映射
    # 格式: | e1 | 杠铃卧推 | Barbell Bench Press | 胸部 | 杠铃 | ...
    id_name_map = {}
    for line in content.split("\n"):
        if line.startswith("| e"):
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 4:
                action_id = parts[1]  # e1
                english_name = parts[3]  # Barbell Bench Press
                if action_id.startswith("e") and action_id[1:].isdigit():
                    id_name_map[action_id] = english_name.replace(" ", "_").lower()
    
    print(f"[解析] 找到 {len(id_name_map)} 个动作")
    for aid, name in list(id_name_map.items())[:3]:
        print(f"       {aid} -> {name}")
    
    # 提取写实风提示词
    prompts = []
    
    # 匹配动作标题: ### 1. 杠铃卧推（Barbell Bench Press）｜e1
    # 注意：｜是全角竖线
    action_pattern = re.compile(r"###\s+\d+\.\s+.+?｜(e\d+)")
    
    # 匹配写实风提示词: - 写实风：`...`
    realistic_pattern = re.compile(r"-\s*写实风：`([^`]+)`")
    
    # 匹配步骤标题: **步骤1 准备姿势** 或 **封面图提示词**
    step_pattern = re.compile(r"\*\*(步骤(\d+)|封面图)\s+[^*]+\*\*")
    
    current_action = None
    current_step = None
    
    for line_num, line in enumerate(content.split("\n"), 1):
        # 检测动作标题
        action_match = action_pattern.search(line)
        if action_match:
            current_action = action_match.group(1)
            current_step = None
            print(f"[解析] 第 {line_num} 行: 找到动作 {current_action}")
            continue
        
        # 检测步骤标题
        step_match = step_pattern.search(line)
        if step_match:
            step_text = step_match.group(1)
            if step_text == "封面图":
                current_step = "preview"
            elif step_text.startswith("步骤"):
                step_num = step_match.group(2)
                current_step = f"step{step_num}"
            print(f"[解析] 第 {line_num} 行: 找到步骤 {current_step}")
            continue
        
        # 提取写实风提示词
        if current_action and current_step:
            prompt_match = realistic_pattern.search(line)
            if prompt_match:
                prompt = prompt_match.group(1)
                english_name = id_name_map.get(current_action, "")
                if english_name:
                    filename = f"{current_action}_{english_name}_{current_step}"
                    prompts.append({
                        "action_id": current_action,
                        "step": current_step,
                        "prompt": prompt,
                        "filename": filename
                    })
                    print(f"[解析] 第 {line_num} 行: 提取 {filename}")
    
    print(f"\n[解析] 共提取 {len(prompts)} 个写实风提示词")
    return prompts


def generate_image(prompt, filename, aspect_ratio="1:1"):
    """调用 gen_image.py 生成单张图片"""
    # 确定输出目录
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    
    # 构建命令
    cmd = [
        sys.executable,
        str(GEN_SCRIPT),
        prompt,
        "--model", MODEL,
        "--aspect-ratio", aspect_ratio,
        "--out", str(OUTPUT_DIR)
    ]
    
    print(f"[生成] {filename} ({aspect_ratio})")
    print(f"       prompt={prompt[:80]}...")
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=300
        )
        
        if result.returncode != 0:
            print(f"[错误] {filename} 生成失败:")
            print(result.stdout)
            print(result.stderr)
            return None
        
        # 解析输出找到保存的文件
        for line in result.stdout.split("\n"):
            if "[完成] 已保存" in line:
                # 格式: [完成] 已保存 d:\...\1234567890_1.png  <- http://...
                match = re.search(r"已保存\s+(\S+)", line)
                if match:
                    temp_file = match.group(1)
                    # 重命名为标准文件名
                    ext = Path(temp_file).suffix
                    final_path = OUTPUT_DIR / f"{filename}{ext}"
                    Path(temp_file).rename(final_path)
                    print(f"[完成] {final_path.name}")
                    return final_path
        
        print(f"[警告] {filename} 未找到保存路径")
        return None
        
    except subprocess.TimeoutExpired:
        print(f"[错误] {filename} 超时")
        return None
    except Exception as e:
        print(f"[错误] {filename} 异常: {e}")
        return None


def main():
    print("=" * 60)
    print("动作库图片批量生成脚本")
    print("=" * 60)
    
    # 解析 MD 文件
    prompts = parse_md_file()
    
    if not prompts:
        print("[错误] 未提取到任何提示词")
        sys.exit(1)
    
    print(f"\n[准备] 共 {len(prompts)} 张图片待生成")
    print(f"       模型: {MODEL}")
    print(f"       输出: {OUTPUT_DIR}\n")
    
    # 统计
    success = 0
    failed = 0
    failed_list = []
    
    # 批量生成
    for i, item in enumerate(prompts, 1):
        print(f"\n[{i}/{len(prompts)}] 开始生成...")
        
        # 封面图用 1:1，步骤图用 4:3
        aspect_ratio = "1:1" if item["step"] == "preview" else "4:3"
        
        result = generate_image(item["prompt"], item["filename"], aspect_ratio)
        
        if result:
            success += 1
        else:
            failed += 1
            failed_list.append(item["filename"])
        
        # 避免请求过快
        if i < len(prompts):
            print("[等待] 2 秒后继续...")
            time.sleep(2)
    
    # 汇总
    print("\n" + "=" * 60)
    print("生成完成")
    print("=" * 60)
    print(f"成功: {success}")
    print(f"失败: {failed}")
    
    if failed_list:
        print(f"\n失败列表:")
        for name in failed_list:
            print(f"  - {name}")
    
    print(f"\n输出目录: {OUTPUT_DIR}")


if __name__ == "__main__":
    main()
