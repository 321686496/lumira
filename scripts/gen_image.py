#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RouteAll 本地网关异步生成脚本(Vidu 任务式,单文件,仅标准库,零依赖)

方案 B:走任务式生成接口(不是 OpenAI 兼容 /v1/images/generations):
    POST /v1/generations            提交任务 → {"id":"1","status":"queued",...}
    GET  /v1/generations/:id        轮询     → {"id","status","result_url?","cover_url?",...}
    状态机:queued → processing → succeeded / failed / timed_out / canceled

用法:
    python gen_image.py --list-models                                  # 查看可用模型
    python gen_image.py "健身教练真在做哑铃卧推" --model q3-fast
    python gen_image.py "..." --model q3-fast --mode reference2image --aspect-ratio 16:9 --resolution 1080p
    python gen_image.py "..." --model q3-fast --poll-interval 3 --max-wait 900 --out ./outputs

前置条件:
    - 网关已 docker compose up(gateway 在 :3000)
    - API Key 余额足够(否则 402 insufficient_balance)
    - 目标模型 active 且已配置生成渠道(否则 404/400 等上游错误)
"""

import argparse
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

BASE_URL = os.environ.get("ROUTEALL_BASE_URL", "http://localhost:3000")
API_KEY = os.environ.get("ROUTEALL_API_KEY", "sk-ra-6sg15DBqjcfBjD8w5Gcj9ofCUIRtCUHW")

# 禁用系统代理:urllib 默认会读 Windows/环境变量里的代理,导致请求被代理劫持(如 127.0.0.1:7877 → 404)
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

POLL_INTERVAL = 5      # 轮询间隔(秒)
MAX_WAIT = 900         # 最大等待(秒),超时按失败退出

# 终态集合(除这些外都是进行中)
TERMINAL = {"succeeded", "failed", "timed_out", "canceled"}


def http_json(method: str, path: str, body: dict | None = None):
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
        with _opener.open(req, timeout=180) as resp:
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
    print(f"可用模型({len(data.get('data', []))} 个):")
    for m in data.get("data", []):
        print(f"  {str(m.get('name')):<36} modality={m.get('modality')}")


def submit_task(model: str, prompt: str, extra: dict) -> dict:
    body = {"model": model, "prompt": prompt, **extra}
    print(f"[提交] POST {BASE_URL}/v1/generations")
    print(f"        body={json.dumps(body, ensure_ascii=False)}")
    status, data = http_json("POST", "/v1/generations", body)
    if status != 200:
        err = data.get("error", data)
        print(f"[错误] 提交失败 HTTP {status}: {err}")
        print("        提示: 402=余额不足; 400=模型/参数不合法; 404/503=无可用生成渠道或上游错误")
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
            print(f"[错误] 等待超时(>{max_wait}s),可稍后手动查询 {path}")
            sys.exit(1)
        time.sleep(poll_interval)


def save_result(task: dict, out_dir: str):
    os.makedirs(out_dir, exist_ok=True)
    url = task.get("result_url") or task.get("cover_url")
    if not url:
        print(f"[错误] 任务成功但无 result_url/cover_url: {task}")
        sys.exit(1)
    ext = ".png"
    if "video" in task.get("modality", "") or "mp4" in url or task.get("result_type") == "video":
        ext = ".mp4"
    ts = int(time.time() * 1000)
    path = os.path.join(out_dir, f"{ts}_{task.get('id', 'task')}{ext}")

    if url.startswith("data:"):
        # data: URL(base64)直接解码
        raw = url.split(",", 1)[1]
        data_bytes = base64.b64decode(raw)
        with open(path, "wb") as f:
            f.write(data_bytes)
        print(f"[完成] 已保存 {path} (data URL)")
    else:
        # http(s) URL 下载(Vidu 上游 URL 约 24h 过期,尽早下载)
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "RouteAll-script/1.0"})
            with _opener.open(req, timeout=120) as r, open(path, "wb") as f:
                f.write(r.read())
            print(f"[完成] 已保存 {path}  <- {url}")
        except Exception as e:
            print(f"[错误] 下载失败: {e}  <- {url}")
            sys.exit(1)
    if task.get("cover_url") and task.get("cover_url") != url:
        print(f"       封面: {task.get('cover_url')}")


def main():
    parser = argparse.ArgumentParser(description="调用本地 RouteAll 网关异步生成接口(Vidu 任务式)")
    parser.add_argument("prompt", nargs="?", help="生成描述(必填,除非使用 --list-models)")
    parser.add_argument("--model", default=os.environ.get("ROUTEALL_MODEL", ""), help="模型名,见 --list-models")
    # 透传 Vidu 参数(白名单见 create-generation.dto)
    parser.add_argument("--mode", default=None, help="显式模式: text2video/img2video/reference2video/start-end2video/reference2image/lip-sync;不填按模型模态自动选")
    parser.add_argument("--images", nargs="*", default=None, help="参考图 URL 列表(img2video 恰 1 张;reference 1-7 张)")
    parser.add_argument("--aspect-ratio", default=None, help="如 16:9 / 9:16 / 1:1")
    parser.add_argument("--resolution", default=None, help="如 540p / 720p / 1080p / 2K / 4K")
    parser.add_argument("--duration", type=int, default=None, help="视频时长(秒,1-16)")
    parser.add_argument("--seed", type=int, default=None, help="随机种子")
    parser.add_argument("--moderation", default=None, help="enabled/disabled(Vidu 专用;disabled=跳过审核,画质更好)")
    parser.add_argument("--poll-interval", type=int, default=POLL_INTERVAL, help=f"轮询间隔秒,默认 {POLL_INTERVAL}")
    parser.add_argument("--max-wait", type=int, default=MAX_WAIT, help=f"最大等待秒,默认 {MAX_WAIT}")
    parser.add_argument("--out", default="./outputs", help="文件保存目录,默认 ./outputs")
    parser.add_argument("--list-models", action="store_true", help="只列出可用模型后退出")
    args = parser.parse_args()

    if args.list_models:
        list_models()
        return
    if not args.prompt:
        parser.error("缺少 prompt(或加 --list-models 查看可用模型)")
    if not args.model:
        print("[错误] 请用 --model 指定模型名(可先 --list-models 查看)")
        sys.exit(1)

    # 组装透传参数(只传用户显式给的)
    extra = {}
    for k, v in (("mode", args.mode), ("images", args.images), ("aspect_ratio", args.aspect_ratio),
                 ("resolution", args.resolution), ("duration", args.duration), ("seed", args.seed),
                 ("moderation", args.moderation)):
        if v is not None:
            extra[k] = v

    submit = submit_task(args.model, args.prompt, extra)
    task = poll_task(submit["id"], args.poll_interval, args.max_wait)
    save_result(task, args.out)


if __name__ == "__main__":
    main()
