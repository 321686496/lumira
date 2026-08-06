#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MaaS 平台图片/视频生成脚本 (RouteAll 协议, 仅标准库, 零依赖)

平台文档: https://mass.hzxmfg.com/docs
Base URL: https://mass.hzxmfg.com (接口路径均为 /v1/...)

异步任务式生成接口(不是 OpenAI 兼容 /v1/images/generations):
    POST /v1/generations            提交任务 -> {"id":"...","status":"queued"}
    GET  /v1/generations/{id}       轮询     -> {"id","status","result_url?",...}
    POST /v1/generations/{id}/cancel 取消(冻结额度退回)
    状态机: queued -> processing -> succeeded / failed / timed_out / canceled

用法:
    python gen_image.py --list-models                              # 查看可用模型
    python gen_image.py "一只可爱的红熊猫坐在树枝上"                 # 默认模型 doubao-seedream-5-0
    python gen_image.py "..." --model doubao-seedream-4-0 --size 1024x1024
    python gen_image.py "..." --size 9:16 --out ./outputs
    python gen_image.py "..." --model viduq2 --duration 4          # 视频模型
    python gen_image.py "..." --image-url https://... --size 1024x1024  # 图生图/图生视频

API Key 优先级: 环境变量 MASS_API_KEY > 脚本内默认值
模型优先级:     --model 参数 > 环境变量 MASS_MODEL > 默认 doubao-seedream-5-0
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("MASS_BASE_URL", "https://mass.hzxmfg.com")
API_KEY = os.environ.get("MASS_API_KEY", "sk-ra-c57TT8YRQu5khVviGeqcfYkNvtQAJAwU")
DEFAULT_MODEL = os.environ.get("MASS_MODEL", "doubao-seedream-5-0")

# 禁用系统代理: urllib 默认会读 Windows/环境变量里的代理, 导致请求被代理劫持
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

POLL_INTERVAL = 5      # 轮询间隔(秒)
MAX_WAIT = 900         # 最大等待(秒), 超时按失败退出

# 终态集合(除这些外都是进行中)
TERMINAL = {"succeeded", "failed", "timed_out", "canceled"}


def http_json(method: str, path: str, body: dict | None = None, timeout: int = 180):
    url = BASE_URL.rstrip("/") + path
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {API_KEY}",
            "Content-Type": "application/json",
        },
    )
    try:
        with _opener.open(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", errors="replace")
        try:
            return e.code, json.loads(raw)
        except json.JSONDecodeError:
            return e.code, {"error": {"message": raw[:500]}}


def list_models():
    status, data = http_json("GET", "/v1/models")
    if status != 200:
        print(f"[错误] 获取模型列表失败 HTTP {status}: {data}")
        sys.exit(1)
    models = data.get("data", [])
    print(f"可用模型({len(models)} 个):")
    for m in models:
        print(f"  {str(m.get('name')):<36} modality={m.get('modality')}")


def submit_task(model: str, prompt: str, extra: dict) -> dict:
    body = {"model": model, "prompt": prompt, **extra}
    print(f"[提交] POST {BASE_URL}/v1/generations")
    print(f"        body={json.dumps(body, ensure_ascii=False)}")
    status, data = http_json("POST", "/v1/generations", body)
    if status != 200:
        err = data.get("error", data)
        print(f"[错误] 提交失败 HTTP {status}: {err}")
        print("        提示: 401=密钥无效/缺失; 402=余额不足; 400=模型/参数不合法; 429=超限; 503=无可用渠道")
        sys.exit(1)
    task_id = data.get("id")
    if not task_id:
        print(f"[错误] 提交响应无 id: {data}")
        sys.exit(1)
    print(f"[提交] 任务 id={task_id} status={data.get('status')}")
    return data


def poll_task(task_id: str, poll_interval: int, max_wait: int) -> dict:
    path = f"/v1/generations/{task_id}"
    deadline = time.time() + max_wait
    while True:
        status, data = http_json("GET", path)
        if status != 200:
            print(f"[错误] 查询任务失败 HTTP {status}: {data}")
            sys.exit(1)
        st = data.get("status")
        print(f"[轮询] id={task_id} status={st}")
        if st in TERMINAL:
            return data
        if st not in ("queued", "processing"):
            print(f"[错误] 未知状态 {st}: {data}")
            sys.exit(1)
        if time.time() > deadline:
            print(f"[错误] 等待超时(>{max_wait}s), 可稍后手动查询 {path}")
            sys.exit(1)
        time.sleep(poll_interval)


def save_result(task: dict, out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    url = task.get("result_url")
    if not url:
        print(f"[错误] 任务成功但无 result_url: {task}")
        sys.exit(1)
    ext = ".png"
    if "video" in task.get("modality", "") or ".mp4" in url or task.get("result_type") == "video":
        ext = ".mp4"
    elif ".jpg" in url or ".jpeg" in url:
        ext = os.path.splitext(url.split("?")[0])[1]
    ts = int(time.time() * 1000)
    path = os.path.join(out_dir, f"{ts}_{task.get('id', 'task')}{ext}")

    if url.startswith("data:"):
        raw = url.split(",", 1)[1]
        data_bytes = base64.b64decode(raw)
        with open(path, "wb") as f:
            f.write(data_bytes)
        print(f"[完成] 已保存 {path} (data URL)")
    else:
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "MaaS-script/1.0"})
            with _opener.open(req, timeout=120) as r, open(path, "wb") as f:
                f.write(r.read())
            print(f"[完成] 已保存 {path}  <- {url}")
        except Exception as e:
            print(f"[错误] 下载失败: {e}  <- {url}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="调用 MaaS 平台 (mass.hzxmfg.com) 异步生成接口")
    parser.add_argument("prompt", nargs="?", help="生成描述(必填, 除非使用 --list-models)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"模型名, 见 --list-models; 默认 {DEFAULT_MODEL}")
    parser.add_argument("--size", default=None, help="图片尺寸, 如 1024x1024 / 9:16 / 1:1")
    parser.add_argument("--duration", type=int, default=None, help="视频时长(秒)")
    parser.add_argument("--image-url", default=None, help="输入参考图 URL(图生图/图生视频)")
    parser.add_argument("--seed", type=int, default=None, help="随机种子")
    parser.add_argument("--poll-interval", type=int, default=POLL_INTERVAL, help=f"轮询间隔秒, 默认 {POLL_INTERVAL}")
    parser.add_argument("--max-wait", type=int, default=MAX_WAIT, help=f"最大等待秒, 默认 {MAX_WAIT}")
    parser.add_argument("--out", default="./outputs", help="文件保存目录, 默认 ./outputs")
    parser.add_argument("--list-models", action="store_true", help="只列出可用模型后退出")
    args = parser.parse_args()

    if args.list_models:
        list_models()
        return
    if not args.prompt:
        parser.error("缺少 prompt(或加 --list-models 查看可用模型)")

    extra = {}
    for k, v in (("size", args.size), ("duration", args.duration),
                 ("image_url", args.image_url), ("seed", args.seed)):
        if v is not None:
            extra[k] = v

    submit = submit_task(args.model, args.prompt, extra)
    task = poll_task(submit["id"], args.poll_interval, args.max_wait)
    if task.get("status") != "succeeded":
        print(f"[错误] 任务未成功: status={task.get('status')}")
        sys.exit(1)
    save_result(task, args.out)


if __name__ == "__main__":
    main()
