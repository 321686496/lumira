#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""批量生成「御姐咖啡厅人像」模板：9 张姿势图 + 9 张剪影图。
姿势图与剪影图均调用 MaaS 平台 qwen-image-3.0-pro 模型（gen_image.py 异步接口）。
输出到根目录 online_templates/御姐咖啡厅人像/{pose,silhouette}/ 下。
"""
import os
import sys
import time
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_image as g  # noqa: E402

MODEL = "qwen-image-3.0-pro"
SIZE = "768x1024"
BASE = r"d:\app\projects\photo_post\online_templates\御姐咖啡厅人像"
MAX_RETRY = 3

# 统一风格基调（御姐风·暖米金咖啡馆）
STYLE = "御姐风格咖啡馆人像写真，气质优雅成熟的中国女性，温暖柔和自然光，浅米色与暖金色调精致咖啡馆背景，高级质感，干净构图，人物完整居中，竖构图，无文字无水印"

# 9 个姿势（源自公众号「归源｜出一组御姐拍照姿势」逐字姿势说明）
POES = [
    ("pose_01", "站姿，肩膀自然放松下沉，双手自然垂放身侧，正面站立"),
    ("pose_02", "斜靠沙发半坐姿势，一只手轻贴脸颊，另一只手自然搭放，慵懒优雅"),
    ("pose_03", "假装边走边拍的行走姿势，一脚在前一脚在后，自然动态随性"),
    ("pose_04", "坐姿，一只手手肘撑在膝盖上，手掌轻轻托住脸颊，另一只手自然垂放"),
    ("pose_05", "站立，一只手挎着包包，手腕轻轻向外摊开，姿态舒展"),
    ("pose_06", "坐姿，一只手搭在沙发靠背上，另一只手轻放在大腿上"),
    ("pose_07", "身体侧向沙发，后背倚靠软垫，侧身坐姿，回眸望向镜头"),
    ("pose_08", "坐姿，一只手拿手机自然举起，另一只手搭在沙发上"),
    ("pose_09", "站直身体，肩膀放松，身体略微侧转，微微看向一侧"),
]

# 剪影图：纯黑人物剪影 + 白色背景（套用模板时叠在取景器上的姿势对准线）
SIL_STYLE = "纯黑色女性人物全身剪影轮廓，边缘清晰利落，无面部细节，无衣物纹理，纯白色背景，高对比度，人物居中，四周留白充足，极简"


def _submit(prompt, size):
    status, data = g.http_json("POST", "/v1/generations", {"model": MODEL, "prompt": prompt, "size": size})
    if status != 200:
        raise RuntimeError(f"提交失败 HTTP {status}: {data}")
    tid = data.get("id")
    if not tid:
        raise RuntimeError(f"提交响应无 id: {data}")
    return tid


def _poll(tid):
    path = f"/v1/generations/{tid}"
    deadline = time.time() + g.MAX_WAIT
    while True:
        status, data = g.http_json("GET", path)
        if status != 200:
            raise RuntimeError(f"查询失败 HTTP {status}: {data}")
        st = data.get("status")
        if st in g.TERMINAL:
            return data
        if time.time() > deadline:
            raise RuntimeError(f"等待超时(>{g.MAX_WAIT}s)")
        time.sleep(g.POLL_INTERVAL)


def _save(task, path):
    url = task.get("result_url")
    if not url:
        raise RuntimeError(f"任务成功但无 result_url: {task}")
    if url.startswith("data:"):
        import base64
        data_bytes = base64.b64decode(url.split(",", 1)[1])
        with open(path, "wb") as f:
            f.write(data_bytes)
    else:
        req = urllib.request.Request(url, headers={"User-Agent": "MaaS-script/1.0"})
        with g._opener.open(req, timeout=120) as r, open(path, "wb") as f:
            f.write(r.read())


def generate_one(name, prompt, out_dir):
    target = os.path.join(out_dir, f"{name}.png")
    for attempt in range(1, MAX_RETRY + 1):
        try:
            print(f"\n===== 生成 {name} 第 {attempt}/{MAX_RETRY} 次 =====", flush=True)
            tid = _submit(prompt, SIZE)
            task = _poll(tid)
            if task.get("status") != "succeeded":
                print(f"[错误] {name} 未成功: {task.get('status')}", flush=True)
                return False
            _save(task, target)
            print(f"[完成] {target}", flush=True)
            return True
        except Exception as e:  # noqa: BLE001
            print(f"[重试] {name} 第 {attempt} 次失败: {e}", flush=True)
            time.sleep(2)
    print(f"[失败] {name} 重试 {MAX_RETRY} 次后仍失败", flush=True)
    return False


def main():
    pose_dir = os.path.join(BASE, "pose")
    sil_dir = os.path.join(BASE, "silhouette")
    os.makedirs(pose_dir, exist_ok=True)
    os.makedirs(sil_dir, exist_ok=True)

    print(f"===== 生成 9 张姿势图 ({MODEL}) =====", flush=True)
    pose_failed = []
    for name, pose in POES:
        target = os.path.join(pose_dir, f"{name}.png")
        if os.path.exists(target):
            print(f"[跳过] {name} 已存在", flush=True)
            continue
        if not generate_one(name, f"{pose}，{STYLE}", pose_dir):
            pose_failed.append(name)
        time.sleep(1)

    print(f"\n===== 生成 9 张剪影图 ({MODEL}) =====", flush=True)
    sil_failed = []
    for name, pose in POES:
        target = os.path.join(sil_dir, f"silhouette_{name.split('_')[1]}.png")
        if os.path.exists(target):
            print(f"[跳过] {name} 剪影已存在", flush=True)
            continue
        prompt = f"{pose}，{SIL_STYLE}"
        if not generate_one(f"silhouette_{name.split('_')[1]}", prompt, sil_dir):
            sil_failed.append(name)
        time.sleep(1)

    print(f"\n完成：姿势图成功 {len(POES) - len(pose_failed)}/9，失败 {len(pose_failed)}（{pose_failed}）", flush=True)
    print(f"剪影图成功 {len(POES) - len(sil_failed)}/9，失败 {len(sil_failed)}（{sil_failed}）", flush=True)
    if pose_failed or sil_failed:
        sys.exit(1)


if __name__ == "__main__":
    main()