#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
多平台图片生成 / 编辑 API 脚本 (仅标准库, 零依赖)

支持平台 (前端可切换):
  - hapi           HAPI 三方中转 gpt-image-2   https://image.hapiopen.cc                OpenAI 兼容 · 同步
  - mass           MaaS (mass.hzxmfg.com)      https://mass.hzxmfg.com/v1               OpenAI 兼容 · 异步任务轮询
  - qianwen_payg   千问 AI · 按量付费           https://dashscope.aliyuncs.com/api/v1     DashScope 原生 · 异步任务
  - qianwen_token  千问 AI · Token Plan         https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1 · 异步任务

功能:
  - 文生图   同步: POST /images/generations (OpenAI 兼容, HAPI); 异步: POST /v1/generations -> GET /v1/generations/{id} (MaaS)
  - 文生图/编辑 千问: POST /services/aigc/multimodal-generation/generation (X-DashScope-Async) -> GET /tasks/{task_id}
  - 多图编辑 POST /images/edits        (多张参考图: 一次处理 / 批量处理; MaaS 用 image_url data URL; 千问用 input.messages image)
  - 尺寸控制: auto / WxH / W:H(宽高比) / from-image(按输入图宽高自适应) (千问自动转 W*H)
  - 内置 HTTP 服务: 托管同目录 gpt_image2.html 并代理图片请求, API Key 不出本机

API Key: 各平台优先取请求携带的 Key(页面输入, 存浏览器 localStorage), 其次服务端环境变量
  - HAPI:          HAPI_API_KEY
  - MaaS:          MASS_API_KEY
  - 千问按量:      QIANWEN_API_KEY
  - 千问TokenPlan: QIANWEN_TOKEN_API_KEY

用法:
  # 文生图 (默认 hapi, 1024x1024)
  python gpt_image2.py "一只橘猫趴在窗台上"
  # 千问按量付费
  python gpt_image2.py "竖版海报, 山间晨雾" --size 9:16 --platform qianwen_payg
  # MaaS 异步网关
  python gpt_image2.py "横版宣传图" --size 1536x1024 --platform mass --api-key sk-ra-...
  # 多图一次处理
  python gpt_image2.py "把这些物品都放进明亮的摄影棚" --image a.png b.png c.png --once --size from-image
  # 多图批量处理
  python gpt_image2.py "保持主体不变, 换成纯白背景" --image a.png b.png --batch
  # 启动 Web 页面服务: 浏览器打开 http://127.0.0.1:8765
  python gpt_image2.py --server
"""

import argparse
import base64
import json
import math
import mimetypes
import os
import re
import secrets
import struct
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# ---------------------------------------------------------------- 平台配置

PLATFORMS = {
    "hapi": {
        "name": "HAPI gpt-image2",
        "key_env": "HAPI_API_KEY",
        "key_label": "HAPI API Key",
        "base_url": "https://image.hapiopen.cc",
        "mode": "sync",          # sync: 同步 OpenAI 兼容; async: 异步任务轮询
        "size_sep": "x",         # 尺寸分隔符 (OpenAI 风格用 x)
        "edit_multi": "image[]", # 多图编辑时参考图字段名
        "models": ["gpt-image-2"],
    },
    "mass": {
        "name": "MaaS (mass.hzxmfg.com)",
        "key_env": "MASS_API_KEY",
        "key_label": "MaaS API Key",
        "base_url": "https://mass.hzxmfg.com/v1",  # 亦可用 https://api.mass.hzxmfg.com/v1
        "mode": "async",
        "size_sep": "x",
        "edit_multi": "image[]",
        "models": ["gpt-image-2", "gpt-image-1", "dall-e-3", "seedream-4.0",
                   "flux-1.1-pro", "wan2.7-image-pro", "qwen-image-2.0-pro"],
    },
    "qianwen_payg": {
        "name": "千问 AI · 按量付费",
        "key_env": "QIANWEN_API_KEY",
        "key_label": "千问 API Key (按量, sk-...)",
        "base_url": "https://dashscope.aliyuncs.com/api/v1",  # DashScope 原生接口 (multimodal-generation)
        "mode": "dashscope",     # dashscope: 原生接口, 异步任务提交+轮询
        "size_sep": "*",         # 千问尺寸用 W*H
        "edit_multi": "image",
        "models": ["wan2.7-image-pro", "wan2.7-image", "z-image-turbo",
                   "qwen-image-2.0-pro", "qwen-image-2.0",
                   "qwen-image-3.0-pro", "qwen-image-3.0", "wan2.6-image"],
    },
    "qianwen_token": {
        "name": "千问 AI · Token Plan",
        "key_env": "QIANWEN_TOKEN_API_KEY",
        "key_label": "千问 Token Plan Key (sk-sp-...)",
        "base_url": "https://token-plan.cn-beijing.maas.aliyuncs.com/api/v1",
        "mode": "dashscope",
        "size_sep": "*",
        "edit_multi": "image",
        "models": ["wan2.7-image-pro", "wan2.7-image", "z-image-turbo",
                   "qwen-image-2.0-pro", "qwen-image-2.0",
                   "qwen-image-3.0-pro", "qwen-image-3.0", "wan2.6-image"],
    },
}

# 兼容旧环境变量
DEFAULT_MODEL = os.environ.get("HAPI_MODEL", "gpt-image-2")

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
HTML_PATH = os.path.join(SCRIPT_DIR, "gpt_image2.html")
RESULTS_DIR = os.path.join(SCRIPT_DIR, "results")

# 站内 Image Studio 已验证的推荐范围
MAX_SIDE = 3840          # 宽高都不超过
MIN_PIXELS = 655360      # 总像素下限
MAX_PIXELS = 8294400     # 总像素上限
TARGET_PIXELS = 1572864  # 默认目标总像素(约 1536x1024)
MAX_RATIO = 3.0          # 长边:短边 <= 3:1

# 禁用系统代理: urllib 默认会读 Windows/环境变量里的代理, 导致请求被劫持
_opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))

# 部分上游的 WAF/防火墙对默认 Python-urllib UA 更严格, 统一带浏览器 UA 更稳
_UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
       "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36")
_RESET_ERRNOS = (10054, 104)   # Windows: 远程主机强制关闭; Linux: 连接被重置

def _friendly_error(e) -> str:
    """把底层异常转成可读信息; 对连接被强制关闭(WinError 10054)给出原因提示"""
    reason = getattr(e, "reason", None)
    if isinstance(reason, ConnectionResetError) or getattr(reason, "errno", None) in _RESET_ERRNOS:
        return ("上游服务器在请求过程中强制关闭了连接(10054)。常见原因: "
                "① 同步平台(HAPI)生成耗时过长, 被上游代理/防火墙超时掐断; "
                "② 图生图请求体过大(多张大图)被 WAF 拒绝; "
                "③ 并发过高触发上游限流。已自动重试, 若仍失败请稍后重试, "
                "或改用异步平台(mass / 千问)。")
    return f"{e}"

def _open(req, timeout):
    """统一网络入口: 附加浏览器 UA, 对瞬态连接重置(WinError 10054)自动重试最多 3 次"""
    req.add_header("User-Agent", _UA)
    last = None
    for attempt in range(3):
        try:
            return _opener.open(req, timeout=timeout)
        except urllib.error.HTTPError:
            raise   # HTTP 错误码(401/404等)属于正常响应, 不重试
        except urllib.error.URLError as e:
            reason = getattr(e, "reason", None)
            if isinstance(reason, ConnectionResetError) or getattr(reason, "errno", None) in _RESET_ERRNOS:
                last = e
                time.sleep(1.5 * (attempt + 1))   # 1.5s / 3s / 4.5s 退避
                continue
            raise
    raise last

SIZE_RE = re.compile(r"^(\d+)[xX](\d+)$")
RATIO_RE = re.compile(r"^(\d+)[:：/](\d+)$")


# ---------------------------------------------------------------- 尺寸工具

def _round16(v: int) -> int:
    """四舍五入到 16 的倍数且不小于 16"""
    v = max(16, int(round(v)))
    return int(round(v / 16) * 16)


def _clamp_size(w: int, h: int):
    """把 w,h 约束到边长/总像素/比例均合法的范围, 返回 (w, h)"""
    k = min(1.0, MAX_SIDE / w, MAX_SIDE / h)
    if k < 1.0:
        w, h = int(round(w * k)), int(round(h * k))
    pix = w * h
    if pix < MIN_PIXELS:
        k = math.sqrt(MIN_PIXELS / pix)
        w, h = int(round(w * k)), int(round(h * k))
    elif pix > MAX_PIXELS:
        k = math.sqrt(MAX_PIXELS / pix)
        w, h = int(round(w * k)), int(round(h * k))
    if w / h > MAX_RATIO:
        h = int(round(w / MAX_RATIO))
    if h / w > MAX_RATIO:
        w = int(round(h / MAX_RATIO))
    w, h = _round16(w), _round16(h)
    return min(MAX_SIDE, w), min(MAX_SIDE, h)


def size_from_ratio(ratio_w: int, ratio_h: int) -> str:
    """根据宽高比 W:H 计算合法的 size 字符串, 如 '9:16' -> '1080x1920'"""
    ratio_w, ratio_h = max(1, int(ratio_w)), max(1, int(ratio_h))
    if ratio_w / ratio_h > MAX_RATIO:
        ratio_w = int(round(ratio_h * MAX_RATIO))
    if ratio_h / ratio_w > MAX_RATIO:
        ratio_h = int(round(ratio_w * MAX_RATIO))
    base = math.sqrt(TARGET_PIXELS / (ratio_w * ratio_h))
    w, h = _clamp_size(int(round(ratio_w * base)), int(round(ratio_h * base)))
    return f"{w}x{h}"


def size_from_image(src_w: int, src_h: int) -> str:
    """根据输入图宽高自适应计算 size (保持输入图宽高比)"""
    if not src_w or not src_h:
        return "auto"
    w, h = int(src_w), int(src_h)
    return f"{_clamp_size(w, h)[0]}x{_clamp_size(w, h)[1]}"


def image_size(data: bytes):
    """仅标准库读取图片宽高, 支持 PNG/JPEG/GIF/WebP; 失败返回 None"""
    try:
        if data[:8] == b"\x89PNG\r\n\x1a\n" and len(data) >= 24:
            w, h = struct.unpack(">II", data[16:24])
            return int(w), int(h)
        if data[:6] == b"GIF87a" or data[:6] == b"GIF89a":
            w, h = struct.unpack("<HH", data[6:10])
            return int(w), int(h)
        if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
            return _webp_size(data)
        if data[:2] == b"\xff\xd8":
            return _jpeg_size(data)
    except Exception:
        pass
    return None


def _webp_size(data: bytes):
    tag = data[12:16]
    if tag == b"VP8X" and len(data) >= 30:  # 扩展格式
        w = int.from_bytes(data[24:27], "little") + 1
        h = int.from_bytes(data[27:30], "little") + 1
        return w, h
    if tag == b"VP8 " and len(data) >= 30:   # 有损
        w = (data[26] | (data[27] << 8)) & 0x3FFF
        h = (data[28] | (data[29] << 8)) & 0x3FFF
        return w, h
    if tag == b"VP8L" and len(data) >= 25:   # 无损
        bits = int.from_bytes(data[21:25], "little")
        w = (bits & 0x3FFF) + 1
        h = ((bits >> 14) & 0x3FFF) + 1
        return w, h
    return None


def _jpeg_size(data: bytes):
    i, n = 2, len(data)
    while i + 9 < n:
        if data[i] != 0xFF:
            i += 1
            continue
        marker = data[i + 1]
        if marker in (0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7,
                      0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF):  # SOF
            h, w = struct.unpack(">HH", data[i + 5:i + 9])
            return int(w), int(h)
        if marker in (0xD8, 0xD9) or 0xD0 <= marker <= 0xD7:  # 无长度段
            i += 2
        else:
            seg_len = struct.unpack(">H", data[i + 2:i + 4])[0]
            i += 2 + seg_len
    return None


def resolve_size(size, first_image: bytes | None = None) -> str:
    """
    把用户传入的尺寸描述解析为 API 接受的 size 字符串。
    size 取值: auto | WxH | W:H(宽高比) | from-image(按输入图自适应)
    """
    if not size:
        return None
    size = str(size).strip()
    key = size.lower()
    if key == "auto":
        return "auto"
    if key in ("from-image", "from_image", "fromimage", "image"):
        if first_image:
            dims = image_size(first_image)
            if dims:
                return size_from_image(*dims)
        return "auto"
    m = SIZE_RE.match(key)
    if m:
        return f"{int(m.group(1))}x{int(m.group(2))}"
    m = RATIO_RE.match(key)
    if m:
        return size_from_ratio(int(m.group(1)), int(m.group(2)))
    raise ValueError(f"无法识别的 size: {size} (可选 auto / WxH / W:H / from-image)")


# ---------------------------------------------------------------- HTTP 请求

def build_multipart(payload: dict) -> tuple:
    """
    构造 multipart/form-data 请求体。
    payload = {"fields": {k: v}, "files": [{"name","filename","content_type","data"}]}
    返回 (boundary, body_bytes)
    """
    boundary = "----HapiBoundary" + secrets.token_hex(12)
    buf = bytearray()
    for k, v in payload.get("fields", {}).items():
        buf += f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode("utf-8")
    for f in payload.get("files", []):
        buf += (f'--{boundary}\r\n'
                f'Content-Disposition: form-data; name="{f["name"]}"; filename="{f["filename"]}"\r\n'
                f'Content-Type: {f["content_type"]}\r\n\r\n').encode("utf-8")
        buf += f["data"]
        buf += b"\r\n"
    buf += f"--{boundary}--\r\n".encode("utf-8")
    return boundary, bytes(buf)


def guess_ext(url: str, content_type: str = "") -> str:
    path_only = url.split("?")[0].lower()
    for e in (".png", ".jpg", ".jpeg", ".webp", ".gif"):
        if path_only.endswith(e):
            return e.lstrip(".")
    if "webp" in content_type:
        return "webp"
    if "jpeg" in content_type or "jpg" in content_type:
        return "jpg"
    if "png" in content_type:
        return "png"
    return "png"


def download_to_local(url: str, out_dir: str, prefix: str = "") -> tuple:
    """下载结果图到本地, 返回 (本地路径, 文件名)"""
    os.makedirs(out_dir, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Lumira-image2/1.0"})
    with _opener.open(req, timeout=180) as r:
        data = r.read()
        content_type = r.headers.get("Content-Type", "")
    ext = guess_ext(url, content_type)
    name = f"{prefix}{secrets.token_hex(4)}.{ext}"
    path = os.path.join(out_dir, name)
    with open(path, "wb") as f:
        f.write(data)
    return path, name


def _data_url(content_type: str, data: bytes) -> str:
    mime = content_type or "image/png"
    return f"data:{mime};base64,{base64.b64encode(data).decode('ascii')}"


class TaskCancelled(Exception):
    """任务被用户取消(停止轮询/丢弃结果)"""


# ---------------------------------------------------------------- 平台客户端

class OpenAICompatibleImages:
    """OpenAI 兼容同步客户端 (HAPI / 千问按量 / 千问 Token Plan)"""

    def __init__(self, api_key: str, base_url: str, size_sep: str = "x",
                 edit_multi: str = "image[]"):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")
        self.size_sep = size_sep
        self.edit_multi = edit_multi

    def _norm_size(self, size):
        """把 'WxH' 统一转换为平台要求的尺寸格式 (如 千问用 W*H)"""
        if not size:
            return size
        s = str(size).strip()
        m = re.match(r"^(\d+)[xX*](\d+)$", s)
        if m:
            return f"{m.group(1)}{self.size_sep}{m.group(2)}"
        return s

    def _request(self, method, path, json_body=None, multipart=None, timeout=300):
        url = self.base_url + path
        data = None
        headers = {"Authorization": f"Bearer {self.api_key}"}
        if json_body is not None:
            data = json.dumps(json_body, ensure_ascii=False).encode("utf-8")
            headers["Content-Type"] = "application/json"
        elif multipart is not None:
            boundary, data = build_multipart(multipart)
            headers["Content-Type"] = f"multipart/form-data; boundary={boundary}"
        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with _opener.open(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", "replace")
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"error": {"message": raw[:500]}}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, {"error": {"message": raw[:500]}}

    def generate(self, model, prompt, size=None, n=1, quality=None,
                 output_format=None, background=None, moderation=None,
                 timeout=300, cancel_check=None):
        body = {"model": model, "prompt": prompt, "n": int(n)}
        for k, v in (("size", self._norm_size(size)), ("quality", quality),
                     ("output_format", output_format), ("background", background),
                     ("moderation", moderation)):
            if v:
                body[k] = v
        status, resp = self._request("POST", "/images/generations",
                                     json_body=body, timeout=timeout)
        if cancel_check and cancel_check():
            raise TaskCancelled("任务已取消")
        return status, resp

    def edit(self, model, prompt, images, size=None, n=1, quality=None,
             output_format=None, input_fidelity=None, background=None,
             moderation=None, timeout=300, cancel_check=None):
        """
        images: [(filename, content_type, data), ...]
        单张 -> 字段名 image; 多张 -> 平台配置的字段名 (HAPI: image[]; 千问: image)
        """
        fields = {"model": model, "prompt": prompt, "n": str(int(n))}
        for k, v in (("size", self._norm_size(size)), ("quality", quality),
                     ("output_format", output_format), ("input_fidelity", input_fidelity),
                     ("background", background), ("moderation", moderation)):
            if v:
                fields[k] = v
        field_name = "image" if len(images) == 1 else self.edit_multi
        files = [
            {"name": field_name, "filename": fn, "content_type": ct or "image/png", "data": data}
            for fn, ct, data in images
        ]
        status, resp = self._request("POST", "/images/edits",
                                     multipart={"fields": fields, "files": files}, timeout=timeout)
        if cancel_check and cancel_check():
            raise TaskCancelled("任务已取消")
        return status, resp


class MassImages:
    """MaaS (mass.hzxmfg.com) 异步任务客户端: 提交 -> 轮询 -> 取 result_url"""

    def __init__(self, api_key: str, base_url: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

    def _norm_size(self, size):
        s = str(size).strip() if size else size
        m = re.match(r"^(\d+)[xX*](\d+)$", s or "")
        if m:
            return f"{m.group(1)}x{m.group(2)}"
        return s

    def _post_json(self, path, body, timeout=300):
        url = self.base_url + path
        req = urllib.request.Request(
            url, data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            method="POST",
            headers={"Authorization": f"Bearer {self.api_key}",
                     "Content-Type": "application/json"})
        try:
            with _opener.open(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", "replace")
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"error": {"message": raw[:500]}}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, {"error": {"message": raw[:500]}}

    def _get_json(self, path, timeout=60):
        url = self.base_url + path
        req = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {self.api_key}"})
        try:
            with _opener.open(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", "replace")
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"error": {"message": raw[:500]}}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, {"error": {"message": raw[:500]}}

    def _poll(self, job_id: str, timeout: int = 600, cancel_check=None):
        start = time.time()
        while time.time() - start < timeout:
            if cancel_check and cancel_check():
                raise TaskCancelled("任务已取消")
            status, resp = self._get_json(f"/generations/{job_id}")
            if status != 200:
                return status, resp
            st = (resp or {}).get("status")
            if st == "succeeded":
                return 200, resp
            if st in ("failed", "timed_out", "canceled"):
                msg = resp.get("error") or resp.get("message") or f"任务状态 {st}"
                return 200, {"error": {"message": msg}, "status": st}
            time.sleep(3)
        return 408, {"error": {"message": f"轮询任务 {job_id} 超时 ({int(timeout)}s)"}}

    def _run_job(self, body, timeout: int = 600, cancel_check=None):
        """提交一次异步任务并轮询到终态, 返回 (status, resp)"""
        status, resp = self._post_json("/generations", body, timeout=timeout)
        if status != 200:
            return status, resp
        job_id = (resp or {}).get("id")
        if not job_id:
            return 502, {"error": {"message": f"提交任务未返回 id: {resp}"}}
        return self._poll(job_id, timeout=timeout, cancel_check=cancel_check)

    def generate(self, model, prompt, size=None, n=1, quality=None,
                 output_format=None, background=None, moderation=None,
                 timeout=600, cancel_check=None):
        n = max(1, int(n))
        results = []
        for i in range(n):
            if cancel_check and cancel_check():
                raise TaskCancelled("任务已取消")
            body = {"model": model, "prompt": prompt}
            if size:
                body["size"] = self._norm_size(size)
            status, resp = self._run_job(body, timeout=timeout, cancel_check=cancel_check)
            if status != 200:
                return status, resp
            if (resp or {}).get("status") != "succeeded":
                return 502, resp
            results.append({"url": (resp or {}).get("result_url")})
        return 200, {"data": results}

    def edit(self, model, prompt, images, size=None, n=1, quality=None,
             output_format=None, input_fidelity=None, background=None,
             moderation=None, timeout=600, cancel_check=None):
        """images 转 base64 data URL 通过 image_url 传给异步任务"""
        n = max(1, int(n))
        data_urls = [_data_url(ct, data) for _, ct, data in images]
        results = []
        for i in range(n):
            if cancel_check and cancel_check():
                raise TaskCancelled("任务已取消")
            body = {"model": model, "prompt": prompt,
                    "image_url": data_urls[0] if len(data_urls) == 1 else data_urls}
            if size:
                body["size"] = self._norm_size(size)
            status, resp = self._run_job(body, timeout=timeout, cancel_check=cancel_check)
            if status != 200:
                return status, resp
            if (resp or {}).get("status") != "succeeded":
                return 502, resp
            results.append({"url": (resp or {}).get("result_url")})
        return 200, {"data": results}


class DashScopeImages:
    """千问 AI (DashScope 原生接口) 客户端: multimodal-generation, 异步任务提交+轮询

    文档: https://platform.qianwenai.com/docs/developer-guides/getting-started/image-models
    端点 (基于 base_url, 形如 https://dashscope.aliyuncs.com/api/v1):
      POST /services/aigc/multimodal-generation/generation   (需 X-DashScope-Async: enable)
      GET  /tasks/{task_id}
    文生图: input.messages[0].content = [{"text": prompt}]
    多图编辑: content = [{"image": dataURL}, ..., {"text": prompt}]
    返回统一转换为 OpenAI 兼容的 {"data": [{"url" 或 "b64_json", ...}]}
    """

    GEN_PATH = "/services/aigc/multimodal-generation/generation"

    def __init__(self, api_key: str, base_url: str):
        self.api_key = api_key
        self.base_url = base_url.rstrip("/")

    def _norm_size(self, size):
        """把 'WxH' 统一转换为千问的 'W*H'; 'auto'/空 返回 None(不传 size 让模型自判)"""
        if not size:
            return None
        s = str(size).strip()
        if s.lower() == "auto":
            return None
        m = re.match(r"^(\d+)[xX*](\d+)$", s)
        if m:
            return f"{m.group(1)}*{m.group(2)}"
        return s

    def _post(self, path, body, timeout=60):
        url = self.base_url + path
        headers = {"Authorization": f"Bearer {self.api_key}",
                   "Content-Type": "application/json",
                   "X-DashScope-Async": "enable"}
        req = urllib.request.Request(
            url, data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            method="POST", headers=headers)
        try:
            with _opener.open(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", "replace")
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"error": {"message": raw[:500]}}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, {"error": {"message": raw[:500]}}

    def _get_task(self, task_id: str):
        url = f"{self.base_url}/tasks/{task_id}"
        req = urllib.request.Request(
            url, headers={"Authorization": f"Bearer {self.api_key}"})
        try:
            with _open(req, timeout=60) as resp:
                raw = resp.read().decode("utf-8", "replace")
                try:
                    return resp.status, json.loads(raw)
                except json.JSONDecodeError:
                    return resp.status, {"error": {"message": raw[:500]}}
        except urllib.error.HTTPError as e:
            raw = e.read().decode("utf-8", "replace")
            try:
                return e.code, json.loads(raw)
            except json.JSONDecodeError:
                return e.code, {"error": {"message": raw[:500]}}

    def _poll(self, task_id: str, timeout: int = 900, cancel_check=None):
        start = time.time()
        while time.time() - start < timeout:
            if cancel_check and cancel_check():
                raise TaskCancelled("任务已取消")
            status, resp = self._get_task(task_id)
            if status != 200:
                return status, resp
            out = (resp or {}).get("output") or {}
            st = out.get("task_status")
            if st == "SUCCEEDED":
                return 200, resp
            if st in ("FAILED", "CANCELED", "UNKNOWN"):
                msg = out.get("message") or out.get("code") or f"任务状态 {st}"
                return 200, {"error": {"message": msg}, "status": st}
            time.sleep(3)
        return 408, {"error": {"message": f"轮询任务 {task_id} 超时 ({int(timeout)}s)"}}

    @staticmethod
    def _to_data(resp: dict) -> list:
        """把 DashScope 响应 output.results[] 转为 data[] (url / b64_json)"""
        out = (resp or {}).get("output") or {}
        data = []
        for item in out.get("results", []):
            entry = {}
            if item.get("url"):
                entry["url"] = item["url"]
            elif item.get("image_base64"):
                b64 = item["image_base64"]
                if "," in b64:  # data:image/png;base64,xxx
                    b64 = b64.split(",", 1)[1]
                entry["b64_json"] = b64
            else:
                entry["error"] = "结果无 url"
            data.append(entry)
        return data

    def _run(self, model, content, size=None, n=1, timeout=900, cancel_check=None):
        body = {"model": model,
                "input": {"messages": [{"role": "user", "content": content}]}}
        params = {"n": max(1, int(n))}
        size = self._norm_size(size)
        if size:
            params["size"] = size
        body["parameters"] = params
        status, resp = self._post(self.GEN_PATH, body, timeout=60)
        if status != 200:
            return status, resp
        out = (resp or {}).get("output") or {}
        task_id = out.get("task_id")
        if not task_id:
            # 某些模型同步直接返回结果
            return 200, {"data": self._to_data(resp)}
        status, resp = self._poll(task_id, timeout=timeout, cancel_check=cancel_check)
        if status != 200:
            return status, resp
        if (resp.get("output") or {}).get("task_status") != "SUCCEEDED":
            return 502, resp
        return 200, {"data": self._to_data(resp)}

    def generate(self, model, prompt, size=None, n=1, quality=None,
                 output_format=None, background=None, moderation=None,
                 timeout=900, cancel_check=None):
        return self._run(model, [{"text": prompt}], size=size, n=n,
                         timeout=timeout, cancel_check=cancel_check)

    def edit(self, model, prompt, images, size=None, n=1, quality=None,
             output_format=None, input_fidelity=None, background=None,
             moderation=None, timeout=900, cancel_check=None):
        content = [{"image": _data_url(ct, data)} for _, ct, data in images]
        content.append({"text": prompt})
        return self._run(model, content, size=size, n=n,
                         timeout=timeout, cancel_check=cancel_check)


def make_client(platform: str, api_key: str, base_url: str = None):
    """按平台构造客户端"""
    cfg = PLATFORMS.get(platform)
    if not cfg:
        raise ValueError(f"不支持的平台: {platform} (可选 {', '.join(PLATFORMS)})")
    base = (base_url or "").strip() or cfg["base_url"]
    if cfg["mode"] == "async":
        return MassImages(api_key, base)
    if cfg["mode"] == "dashscope":
        return DashScopeImages(api_key, base)
    return OpenAICompatibleImages(api_key, base,
                                  size_sep=cfg["size_sep"], edit_multi=cfg["edit_multi"])


def extract_and_save(data_list, out_dir: str, prefix: str = "", url_prefix: str = "") -> list:
    """把响应 data[] 保存下来, 返回 [{name,url,remote_url,index,revised_prompt}]"""
    results = []
    os.makedirs(out_dir, exist_ok=True)
    for i, item in enumerate(data_list or [], 1):
        entry = {"index": i, "name": None, "url": "", "remote_url": item.get("url", ""),
                 "revised_prompt": item.get("revised_prompt")}
        b64 = item.get("b64_json")
        if b64:
            name = f"{prefix}{int(time.time() * 1000)}_{i}.png"
            with open(os.path.join(out_dir, name), "wb") as f:
                f.write(base64.b64decode(b64))
            entry["name"] = name
            entry["url"] = f"{url_prefix}/{name}" if url_prefix else os.path.join(out_dir, name)
        elif item.get("url"):
            try:
                path, name = download_to_local(item["url"], out_dir, f"{prefix}{i}_")
                entry["name"] = name
                entry["url"] = f"{url_prefix}/{name}" if url_prefix else path
            except Exception as e:
                entry["error"] = f"下载失败: {e}"
        else:
            entry["error"] = "结果无 url/b64_json"
        results.append(entry)
    return results


def decode_data_urls(items) -> list:
    """把 data:image/*;base64,xxx 列表解码为 [(filename, content_type, bytes)]，供 /api/batch 图生图使用"""
    out = []
    for i, s in enumerate(items or [], 1):
        s = str(s or "").strip()
        if not s:
            continue
        m = re.match(r"^data:(image/[a-zA-Z0-9.+-]+);base64,(.*)$", s, re.S)
        if not m:
            raise ValueError(f"第 {i} 张图片不是合法的 data URL")
        ct, b64 = m.group(1), m.group(2)
        ext = mimetypes.guess_extension(ct) or ".png"
        out.append((f"img{i}{ext}", ct, base64.b64decode(b64)))
    return out


# ---------------------------------------------------------------- 多任务并发管理

# 全局并发池大小(所有批次共享): 可通过环境变量 BATCH_MAX_WORKERS 调整
GLOBAL_MAX_WORKERS = max(4, int(os.environ.get("BATCH_MAX_WORKERS", "8")))
BATCH_TTL = 3600  # 批次保留时长(秒), 超时被清理


class Task:
    """单个生成任务: 状态机 pending -> running -> done/error/cancelled"""

    __slots__ = ("id", "prompt", "config", "images", "status",
                 "created_at", "started_at", "finished_at",
                 "results", "error", "cancel_evt")

    def __init__(self, tid, prompt, config, images=None):
        self.id = tid
        self.prompt = prompt
        self.config = config or {}      # JSON 安全(不含图片)
        self.images = images            # 编辑模式解码后的图片列表
        self.status = "pending"
        self.created_at = time.time()
        self.started_at = None
        self.finished_at = None
        self.results = []
        self.error = None
        self.cancel_evt = threading.Event()

    @property
    def elapsed(self):
        end = self.finished_at or time.time()
        start = self.started_at
        return round(max(end - start, 0.0), 1) if start else 0.0

    def snapshot(self):
        return {"id": self.id, "prompt": self.prompt, "status": self.status,
                "elapsed": self.elapsed, "results": self.results,
                "error": self.error, "config": self.config}


class Batch:
    """一个批次: 若干任务 + 本批次并发上限(每批 semaphore 由调度队列实现)"""

    def __init__(self, bid):
        self.bid = bid
        self.status = "pending"   # pending | running | done
        self.created_at = time.time()
        self.keys = {}            # 提交时的各平台 Key 映射
        self.max_workers = 4
        self.tasks = []
        self._queue = []
        self._inflight = 0
        self._lock = threading.Lock()

    def add_task(self, task):
        self.tasks.append(task)

    def enqueue_all(self, max_workers):
        with self._lock:
            self.status = "running"
            self.max_workers = max(1, int(max_workers))
            for t in self.tasks:
                if t.status == "pending":
                    self._queue.append(t)
            self._pump()

    def retry_tasks(self, ids, configs):
        with self._lock:
            self.status = "running"
            n = 0
            for t in self.tasks:
                if t.id in ids:
                    cfg = configs.get(t.id)
                    if cfg:
                        t.config.update(cfg)
                    # 重解析平台/Key
                    pc = t.config.get("platform") or "hapi"
                    t.config["base_url"] = t.config.get("base_url") or PLATFORMS.get(pc, PLATFORMS["hapi"])["base_url"]
                    t.config["api_key"] = (self.keys.get(pc) or "").strip() or Handler.default_keys.get(pc, "")
                    t.status = "pending"
                    t.started_at = None
                    t.finished_at = None
                    t.results = []
                    t.error = None
                    t.cancel_evt = threading.Event()
                    self._queue.append(t)
                    n += 1
            self._pump()
            return n

    def cancel_tasks(self, ids):
        """ids 为空表示取消全部 pending/running 任务"""
        with self._lock:
            n = 0
            for t in self.tasks:
                if t.status in ("pending", "running"):
                    if not ids or t.id in ids:
                        t.cancel_evt.set()
                        n += 1
            return n

    def _pump(self):
        """从队列取出任务提交到全局池, 保持本批并发不超过 max_workers"""
        while self._inflight < self.max_workers and self._queue:
            t = self._queue.pop(0)
            self._inflight += 1
            BATCH_EXECUTOR.submit(_run_task, self, t)

    def _task_finished(self, task):
        with self._lock:
            self._inflight -= 1
            self._pump()
            if not self._inflight and not self._queue:
                self.status = "done"

    def finished_count(self):
        return sum(1 for t in self.tasks if t.status in ("done", "error", "cancelled"))

    def snapshot(self):
        return {"batch_id": self.bid, "status": self.status,
                "total": len(self.tasks), "finished": self.finished_count(),
                "created_at": self.created_at,
                "max_workers": self.max_workers,
                "tasks": [t.snapshot() for t in self.tasks]}


def _run_task(batch: Batch, task: Task):
    """在全局线程池中执行单个任务"""
    task.started_at = time.time()
    try:
        if task.cancel_evt.is_set():
            task.status = "cancelled"
            return
        task.status = "running"
        cfg = task.config
        mode = cfg.get("mode") or "generate"
        platform = cfg.get("platform") or "hapi"
        api_key = (cfg.get("api_key") or "").strip() or Handler.default_keys.get(platform, "")
        if not api_key:
            raise ValueError(f"未提供 {PLATFORMS.get(platform, PLATFORMS['hapi'])['key_label']} 的 Key")
        client = make_client(platform, api_key, cfg.get("base_url"))
        cancel_check = task.cancel_evt.is_set
        size_desc = cfg.get("size") or ("from-image" if mode == "edit" else "auto")
        timeout = int(cfg.get("timeout") or (900 if PLATFORMS.get(platform, {}).get("mode") != "sync" else 300))
        if mode == "edit":
            imgs = task.images
            if not imgs:
                raise ValueError("图生图模式缺少参考图(images)")
            size = resolve_size(size_desc, imgs[0][2])
            status, resp = client.edit(
                model=cfg.get("model") or DEFAULT_MODEL, prompt=task.prompt, images=imgs,
                size=size, n=int(cfg.get("n") or 1), quality=cfg.get("quality"),
                output_format=cfg.get("output_format"),
                input_fidelity=cfg.get("input_fidelity"),
                background=cfg.get("background"), timeout=timeout, cancel_check=cancel_check)
        else:
            size = resolve_size(size_desc)
            status, resp = client.generate(
                model=cfg.get("model") or DEFAULT_MODEL, prompt=task.prompt, size=size,
                n=int(cfg.get("n") or 1), quality=cfg.get("quality"),
                output_format=cfg.get("output_format"),
                timeout=timeout, cancel_check=cancel_check)
        if task.cancel_evt.is_set():
            task.status = "cancelled"
            return
        if status != 200:
            task.status = "error"
            task.error = resp
            return
        saved = extract_and_save(resp.get("data", []), RESULTS_DIR, f"task{task.id}_", "/results")
        if mode == "edit" and saved:
            for s in saved:
                s["input"] = task.images[0][0]
        task.results = saved
        task.status = "done"
    except TaskCancelled:
        task.status = "cancelled"
    except ValueError as e:
        task.status = "error"
        task.error = str(e)
    except Exception as e:
        task.status = "error"
        task.error = f"请求异常: {_friendly_error(e)}"
    finally:
        task.finished_at = time.time()
        batch._task_finished(task)


class _BatchRegistry:
    """批次注册表: 创建/查询/过期清理"""

    def __init__(self):
        self._lock = threading.Lock()
        self._batches = {}
        self._seq = 0

    def new(self):
        with self._lock:
            self._seq += 1
            b = Batch(f"B{self._seq}")
            self._batches[b.bid] = b
            return b

    def get(self, bid):
        with self._lock:
            return self._batches.get(bid)

    def cleanup(self):
        now = time.time()
        with self._lock:
            for k in [k for k, v in self._batches.items() if now - v.created_at > BATCH_TTL]:
                del self._batches[k]


BATCH_EXECUTOR = ThreadPoolExecutor(max_workers=GLOBAL_MAX_WORKERS, thread_name_prefix="batch")
BatchRegistry = _BatchRegistry()


# ---------------------------------------------------------------- CLI

def _load_images(paths: list) -> list:
    images = []
    for p in paths:
        with open(p, "rb") as f:
            data = f.read()
        ct = mimetypes.guess_type(p)[0] or "image/png"
        images.append((os.path.basename(p), ct, data))
    return images


def _print_results(results: list):
    for r in results:
        print(f"  [{r['index']}] {r.get('name') or ''}  <- {r.get('remote_url') or r.get('url')}")
        if r.get("revised_prompt"):
            print(f"       revised_prompt: {r['revised_prompt']}")
        if r.get("error"):
            print(f"       [错误] {r['error']}")


def run_edit(client, model: str, prompt: str, images: list, size_desc: str,
             mode: str, n: int, quality: str, output_format: str,
             input_fidelity: str, out_dir: str, timeout: int):
    first = images[0][2]
    if mode == "once":
        size = resolve_size(size_desc, first)
        print(f"[编辑·一次] 输入 {len(images)} 张, size={size}")
        status, resp = client.edit(model, prompt, images, size=size, n=n,
                                   quality=quality, output_format=output_format,
                                   input_fidelity=input_fidelity, timeout=timeout)
        if status != 200:
            print(f"[错误] 编辑失败 HTTP {status}: {resp}")
            return 1
        results = extract_and_save(resp.get("data", []), out_dir, "once_")
        _print_results(results)
    else:
        for i, (fn, ct, data) in enumerate(images, 1):
            size = resolve_size(size_desc, data)
            print(f"[编辑·批量 {i}/{len(images)}] {fn}, size={size}")
            status, resp = client.edit(model, prompt, [(fn, ct, data)], size=size, n=n,
                                       quality=quality, output_format=output_format,
                                       input_fidelity=input_fidelity, timeout=timeout)
            if status != 200:
                print(f"[错误] 第 {i} 张失败 HTTP {status}: {resp}")
                continue
            results = extract_and_save(resp.get("data", []), out_dir, f"b{i}_")
            for r in results:
                r["input"] = fn
            _print_results(results)
    return 0


def build_parser():
    p = argparse.ArgumentParser(description="调用多平台图片生成/编辑 API (HAPI / MaaS / 千问 AI)")
    p.add_argument("prompt", nargs="?", default=None, help="提示词(文生图/图片编辑必填)")
    p.add_argument("--platform", choices=list(PLATFORMS), default="hapi",
                   help="平台: hapi / mass / qianwen_payg / qianwen_token (默认 hapi)")
    p.add_argument("-i", "--image", action="append", default=None,
                   help="参考图路径, 可多次传入实现多图(编辑模式)")
    p.add_argument("--model", default=None, help=f"模型名, 默认取平台默认模型 ({DEFAULT_MODEL})")
    p.add_argument("--size", default=None,
                   help="尺寸: auto / WxH(如 1536x1024) / W:H(宽高比, 如 9:16) / from-image(按输入图自适应, 编辑默认)")
    p.add_argument("--n", type=int, default=1, help="输出图片数量, 默认 1")
    p.add_argument("--quality", default=None, choices=["low", "medium", "high"],
                   help="质量(部分平台支持, 如 HAPI)")
    p.add_argument("--output-format", default=None, choices=["png", "jpeg", "webp"], help="输出格式(部分平台支持)")
    p.add_argument("--input-fidelity", default=None, choices=["low", "high"], help="参考图保真度(编辑, 部分平台支持)")
    g = p.add_mutually_exclusive_group()
    g.add_argument("--batch", dest="mode", action="store_const", const="batch",
                   help="多图批量处理: 每张图各发一次请求")
    g.add_argument("--once", dest="mode", action="store_const", const="once",
                   help="多图一次处理: 全部图放同一个请求")
    p.set_defaults(mode=None)
    p.add_argument("--api-key", default=None, help="平台 API Key (默认取对应平台环境变量)")
    p.add_argument("--base-url", default=None, help="接口地址(默认取平台预设)")
    p.add_argument("--out", default="./outputs", help="输出目录, 默认 ./outputs")
    p.add_argument("--timeout", type=int, default=900, help="单个请求超时秒数, 默认 900 (异步任务轮询上限)")
    p.add_argument("--json", action="store_true", help="额外打印原始响应 JSON")
    p.add_argument("--server", action="store_true", help="启动内置 Web 服务(托管 gpt_image2.html)")
    p.add_argument("--host", default="127.0.0.1", help="Web 服务监听地址, 默认 127.0.0.1")
    p.add_argument("--port", type=int, default=8765, help="Web 服务端口, 默认 8765")
    return p


def main():
    args = build_parser().parse_args()
    cfg = PLATFORMS[args.platform]

    if args.server:
        run_server(args.host, args.port)
        return

    api_key = args.api_key or os.environ.get(cfg["key_env"], "")
    if not api_key:
        print(f"[错误] 未设置 {cfg['key_label']}: 请设置环境变量 {cfg['key_env']} 或使用 --api-key",
              file=sys.stderr)
        sys.exit(1)
    if not args.prompt:
        build_parser().error("缺少 prompt")

    base_url = args.base_url or cfg["base_url"]
    model = args.model or (cfg["models"][0] if cfg.get("models") else DEFAULT_MODEL)
    client = make_client(args.platform, api_key, base_url)

    try:
        if args.image:
            images = _load_images(args.image)
            if not images:
                print("[错误] 参考图读取失败", file=sys.stderr)
                sys.exit(1)
            mode = args.mode or ("once" if len(images) == 1 else "batch")
            if mode == "once" and len(images) > 1:
                print(f"[提示] 一次处理: {len(images)} 张参考图将放入同一个请求")
            rc = run_edit(client, model, args.prompt, images, args.size or "from-image", mode,
                          args.n, args.quality, args.output_format, args.input_fidelity,
                          args.out, args.timeout)
            sys.exit(rc)
        else:
            size = resolve_size(args.size or "auto")
            print(f"[生成] platform={args.platform} model={model} size={size} n={args.n}")
            status, resp = client.generate(model, args.prompt, size=size, n=args.n,
                                           quality=args.quality,
                                           output_format=args.output_format,
                                           timeout=args.timeout)
            if args.json:
                print(json.dumps(resp, ensure_ascii=False, indent=2))
            if status != 200:
                print(f"[错误] 生成失败 HTTP {status}: {resp}")
                sys.exit(1)
            results = extract_and_save(resp.get("data", []), args.out, "gen_")
            _print_results(results)
            print(f"[完成] 已保存到 {os.path.abspath(args.out)}")
    except ValueError as e:
        print(f"[错误] {e}", file=sys.stderr)
        sys.exit(1)


# ---------------------------------------------------------------- HTTP 服务

def parse_multipart(body: bytes, content_type: str) -> list:
    """手写 multipart/form-data 解析器, 返回 [{name, filename, content_type, data}]"""
    m = re.search(r'boundary=(?:"([^"]+)"|([^;]+))', content_type or "")
    if not m:
        raise ValueError("Content-Type 缺少 boundary")
    boundary = (m.group(1) or m.group(2)).strip().encode("utf-8")
    parts = []
    for chunk in body.split(b"--" + boundary):
        chunk = chunk.strip(b"\r\n")
        if not chunk or chunk == b"--":
            continue
        head, _, content = chunk.partition(b"\r\n\r\n")
        headers = {}
        for line in head.split(b"\r\n"):
            if b":" in line:
                k, _, v = line.partition(b":")
                headers[k.decode("ascii", "ignore").strip().lower()] = v.strip()
        disp = headers.get("content-disposition", b"")
        name = filename = None
        nm = re.search(rb'name="([^"]*)"', disp)
        if nm:
            name = nm.group(1).decode("utf-8", "replace")
        fm = re.search(rb'filename="([^"]*)"', disp)
        if fm:
            filename = fm.group(1).decode("utf-8", "replace")
        ctype = headers.get("content-type")
        ctype = ctype.decode("ascii", "ignore") if ctype else None
        parts.append({"name": name, "filename": filename, "content_type": ctype, "data": content})
    return parts


class Handler(BaseHTTPRequestHandler):
    default_keys = {p: os.environ.get(c["key_env"], "") for p, c in PLATFORMS.items()}
    server_version = "Lumira-image2/1.0"

    def _client_for(self, platform, base_url=None, request_key=None):
        """按请求(平台+Key+BaseURL)构造客户端; Key 优先请求携带, 其次服务端环境变量"""
        platform = platform or "hapi"
        cfg = PLATFORMS.get(platform, PLATFORMS["hapi"])
        key = (request_key or "").strip() or self.default_keys.get(platform, "")
        base = (base_url or "").strip() or cfg["base_url"]
        return make_client(platform, key, base)

    # ---- 基础工具 ----
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, Authorization")

    def log_message(self, fmt, *args):
        sys.stderr.write("[%s] %s\n" % (self.log_date_time_string(), fmt % args))

    def _send_json(self, obj, status=200):
        body = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self) -> bytes:
        length = int(self.headers.get("Content-Length") or 0)
        return self.rfile.read(length) if length else b""

    def _serve_file(self, fpath, ctype):
        if not os.path.isfile(fpath):
            self._send_json({"ok": False, "error": "file not found"}, 404)
            return
        with open(fpath, "rb") as f:
            body = f.read()
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self._cors()
        self.end_headers()
        self.wfile.write(body)

    # ---- 路由 ----
    def do_OPTIONS(self):
        self.send_response(204)
        self._cors()
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            self._serve_file(HTML_PATH, "text/html; charset=utf-8")
        elif path == "/api/health":
            self._send_json({
                "ok": True,
                "default_model": DEFAULT_MODEL,
                "batch_max_workers": GLOBAL_MAX_WORKERS,
                "platforms": {p: {"name": c["name"], "configured": bool(self.default_keys.get(p)),
                                  "base_url": c["base_url"], "models": c["models"]}
                              for p, c in PLATFORMS.items()},
            })
        elif path == "/api/batch/status":
            self.handle_batch_status()
        elif path.startswith("/results/"):
            name = os.path.basename(path)
            self._serve_file(os.path.join(RESULTS_DIR, name),
                             mimetypes.guess_type(name)[0] or "application/octet-stream")
        else:
            self._send_json({"ok": False, "error": "not found"}, 404)

    def do_POST(self):
        path = urllib.parse.urlparse(self.path).path
        if path == "/api/generate":
            self.handle_generate()
        elif path == "/api/edit":
            self.handle_edit()
        elif path == "/api/batch":
            self.handle_batch()
        elif path == "/api/batch/cancel":
            self.handle_batch_cancel()
        elif path == "/api/batch/retry":
            self.handle_batch_retry()
        else:
            self._send_json({"ok": False, "error": "not found"}, 404)

    # ---- 文生图 ----
    def handle_generate(self):
        try:
            body = json.loads(self._read_body().decode("utf-8"))
        except Exception:
            return self._send_json({"ok": False, "error": "请求体不是合法 JSON"}, 400)
        if not body.get("prompt"):
            return self._send_json({"ok": False, "error": "缺少 prompt"}, 400)
        platform = body.get("platform") or "hapi"
        cfg = PLATFORMS.get(platform, PLATFORMS["hapi"])
        request_key = self.headers.get("X-HAPI-Key") or body.get("api_key")
        if not (request_key or "").strip() and not self.default_keys.get(platform):
            return self._send_json({"ok": False,
                                    "error": f"未提供 {cfg['key_label']}：请在页面输入，或配置 {cfg['key_env']}"}, 401)
        client = self._client_for(platform, body.get("base_url"), request_key)
        try:
            size = resolve_size(body.get("size") or "auto")
        except ValueError as e:
            return self._send_json({"ok": False, "error": str(e)}, 400)
        try:
            status, resp = client.generate(
                model=body.get("model") or DEFAULT_MODEL,
                prompt=body["prompt"],
                size=size,
                n=int(body.get("n") or 1),
                quality=body.get("quality"),
                output_format=body.get("output_format"),
                timeout=int(body.get("timeout") or 300))
        except Exception as e:
            return self._send_json({"ok": False, "error": f"请求异常: {e}"}, 500)
        if status != 200:
            return self._send_json({"ok": False, "platform": platform,
                                    "status": status, "error": resp}, status)
        results = extract_and_save(resp.get("data", []), RESULTS_DIR, "gen_", "/results")
        return self._send_json({"ok": True, "platform": platform,
                                "requested_size": size, "results": results})

    # ---- 图片编辑 ----
    def handle_edit(self):
        try:
            parts = parse_multipart(self._read_body(), self.headers.get("Content-Type", ""))
        except Exception as e:
            return self._send_json({"ok": False, "error": f"解析上传失败: {e}"}, 400)
        fields = {p["name"]: p["data"].decode("utf-8", "replace")
                  for p in parts if p["name"] and p["filename"] is None}
        imgs = [p for p in parts if p["name"] in ("image", "image[]") and p["filename"]]
        if not imgs:
            return self._send_json({"ok": False, "error": "缺少参考图(image 字段)"}, 400)
        if not fields.get("prompt"):
            return self._send_json({"ok": False, "error": "缺少 prompt"}, 400)
        platform = fields.get("platform") or "hapi"
        cfg = PLATFORMS.get(platform, PLATFORMS["hapi"])
        request_key = self.headers.get("X-HAPI-Key") or fields.get("api_key")
        if not (request_key or "").strip() and not self.default_keys.get(platform):
            return self._send_json({"ok": False,
                                    "error": f"未提供 {cfg['key_label']}：请在页面输入，或配置 {cfg['key_env']}"}, 401)
        client = self._client_for(platform, fields.get("base_url"), request_key)

        mode = fields.get("mode", "once")
        size_desc = fields.get("size") or "from-image"
        common = dict(model=fields.get("model") or DEFAULT_MODEL,
                      n=int(fields.get("n") or 1),
                      quality=fields.get("quality"),
                      output_format=fields.get("output_format"),
                      input_fidelity=fields.get("input_fidelity"),
                      background=fields.get("background"),
                      timeout=int(fields.get("timeout") or 300))
        try:
            if mode == "batch":
                results = []
                for i, p in enumerate(imgs, 1):
                    size = resolve_size(size_desc, p["data"])
                    status, resp = client.edit(
                        model=common["model"], prompt=fields["prompt"],
                        images=[(p["filename"], p["content_type"], p["data"])],
                        size=size, n=common["n"], quality=common["quality"],
                        output_format=common["output_format"],
                        input_fidelity=common["input_fidelity"],
                        background=common["background"], timeout=common["timeout"])
                    if status != 200:
                        return self._send_json({"ok": False, "platform": platform, "step": i,
                                                "input": p["filename"], "status": status,
                                                "error": resp}, status)
                    saved = extract_and_save(resp.get("data", []), RESULTS_DIR,
                                             f"edit{i}_", "/results")
                    for s in saved:
                        s["input"] = p["filename"]
                    results.extend(saved)
                return self._send_json({"ok": True, "platform": platform,
                                        "mode": "batch", "results": results})

            size = resolve_size(size_desc, imgs[0]["data"])
            status, resp = client.edit(
                model=common["model"], prompt=fields["prompt"],
                images=[(p["filename"], p["content_type"], p["data"]) for p in imgs],
                size=size, n=common["n"], quality=common["quality"],
                output_format=common["output_format"],
                input_fidelity=common["input_fidelity"],
                background=common["background"], timeout=common["timeout"])
            if status != 200:
                return self._send_json({"ok": False, "platform": platform,
                                        "status": status, "error": resp}, status)
            saved = extract_and_save(resp.get("data", []), RESULTS_DIR, "edit_", "/results")
            return self._send_json({"ok": True, "platform": platform, "mode": "once",
                                    "requested_size": size, "results": saved})
        except ValueError as e:
            return self._send_json({"ok": False, "error": str(e)}, 400)
        except Exception as e:
            return self._send_json({"ok": False, "error": f"请求异常: {e}"}, 500)

    # ---- 多任务并发 ----
    def handle_batch(self):
        """异步提交一批任务, 立即返回 batch_id; 进度/结果通过 /api/batch/status 轮询获取
        请求体 JSON:
          tasks: [{id, prompt, config?{platform,model,size,n,...}}]
          keys: {platform: apiKey}  (可选, 各平台 Key; 供逐任务平台覆盖时使用)
          mode: generate|edit  images: [dataURL,...]  batch: bool
          platform/base_url/model/size/n/quality/output_format/... (全局默认)
          max_workers: 本批并发上限
        """
        try:
            body = json.loads(self._read_body().decode("utf-8"))
        except Exception:
            return self._send_json({"ok": False, "error": "请求体不是合法 JSON"}, 400)
        tasks = [t for t in (body.get("tasks") or []) if (t or {}).get("prompt", "").strip()]
        if not tasks:
            return self._send_json({"ok": False, "error": "缺少任务列表(tasks)，每个任务至少包含 prompt"}, 400)

        keys = body.get("keys") or {}
        if not isinstance(keys, dict):
            keys = {}
        if not any((str(k or "").strip()) for k in keys.values()) and not any(self.default_keys.values()):
            return self._send_json({"ok": False,
                                    "error": "未提供任何平台的 API Key：请在页面输入，或配置环境变量"}, 401)

        mode = body.get("mode") or "generate"
        if mode == "edit":
            try:
                imgs = decode_data_urls(body.get("images") or [])
            except ValueError as e:
                return self._send_json({"ok": False, "error": str(e)}, 400)
            if not imgs:
                return self._send_json({"ok": False, "error": "图生图模式缺少参考图(images)"}, 400)
        else:
            imgs = []

        platform = body.get("platform") or "hapi"
        cfg = PLATFORMS.get(platform, PLATFORMS["hapi"])
        common = dict(model=body.get("model") or DEFAULT_MODEL,
                      n=int(body.get("n") or 1),
                      quality=body.get("quality"),
                      output_format=body.get("output_format"),
                      input_fidelity=body.get("input_fidelity"),
                      background=body.get("background"),
                      timeout=int(body.get("timeout") or 300),
                      mode=mode,
                      size=body.get("size") or ("from-image" if mode == "edit" else "auto"),
                      base_url=body.get("base_url"),
                      keys=keys)

        batch = BatchRegistry.new()
        batch.keys = dict(keys)
        max_workers = min(max(1, int(body.get("max_workers") or 4)), GLOBAL_MAX_WORKERS)
        for i, t in enumerate(tasks):
            tcfg = t.get("config") or {}
            p_i = tcfg.get("platform") or platform
            pc_i = PLATFORMS.get(p_i, cfg)
            c_i = dict(common)
            # 逐任务独立配置覆盖 (仅覆盖显式给出的字段)
            for k in ("platform", "model", "size", "n", "base_url",
                      "timeout", "quality", "output_format", "input_fidelity", "background"):
                if k in tcfg and tcfg[k] not in (None, ""):
                    c_i[k] = tcfg[k]
            # 平台覆盖时 Base URL / 超时 / Key 跟随该平台
            if tcfg.get("platform"):
                c_i["base_url"] = c_i.get("base_url") or pc_i["base_url"]
                if "timeout" not in tcfg and pc_i.get("mode") != "sync":
                    c_i["timeout"] = 900
            if not c_i.get("base_url"):
                c_i["base_url"] = pc_i["base_url"]
            if not c_i.get("timeout"):
                c_i["timeout"] = 900 if pc_i.get("mode") != "sync" else 300
            c_i["api_key"] = (keys.get(p_i) or "").strip() or self.default_keys.get(p_i, "")
            batch.add_task(Task(t.get("id", i), t["prompt"].strip(), c_i,
                                imgs if mode == "edit" else None))
        batch.enqueue_all(max_workers)
        BatchRegistry.cleanup()
        return self._send_json({"ok": True, "batch_id": batch.bid,
                                "task_count": len(batch.tasks),
                                "max_workers": max_workers,
                                "global_max_workers": GLOBAL_MAX_WORKERS})

    def handle_batch_status(self):
        """GET /api/batch/status?batch_id=B1 返回批次当前快照(含每个任务状态/结果)"""
        qs = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        bid = (qs.get("batch_id") or [""])[0]
        batch = BatchRegistry.get(bid)
        if not batch:
            return self._send_json({"ok": False, "error": "batch 不存在或已过期"}, 404)
        return self._send_json({"ok": True, **batch.snapshot()})

    def handle_batch_cancel(self):
        """POST /api/batch/cancel  {batch_id, task_ids?[]} 取消指定/全部任务"""
        try:
            body = json.loads(self._read_body().decode("utf-8"))
        except Exception:
            return self._send_json({"ok": False, "error": "请求体不是合法 JSON"}, 400)
        batch = BatchRegistry.get(body.get("batch_id") or "")
        if not batch:
            return self._send_json({"ok": False, "error": "batch 不存在或已过期"}, 404)
        ids = body.get("task_ids")
        if ids is not None:
            try:
                ids = {int(x) for x in ids}
            except (TypeError, ValueError):
                return self._send_json({"ok": False, "error": "task_ids 必须是整数数组"}, 400)
        n = batch.cancel_tasks(ids)
        return self._send_json({"ok": True, "cancelled": n})

    def handle_batch_retry(self):
        """POST /api/batch/retry  {batch_id, tasks:[{id, config?}] 或 [id,...]}
        重新排队指定任务(默认重试全部 失败/已取消 任务), 可选带新配置
        """
        try:
            body = json.loads(self._read_body().decode("utf-8"))
        except Exception:
            return self._send_json({"ok": False, "error": "请求体不是合法 JSON"}, 400)
        batch = BatchRegistry.get(body.get("batch_id") or "")
        if not batch:
            return self._send_json({"ok": False, "error": "batch 不存在或已过期"}, 404)
        items = body.get("tasks") or []
        ids, configs = set(), {}
        try:
            for it in items:
                if isinstance(it, dict):
                    iid = int(it.get("id"))
                    ids.add(iid)
                    if it.get("config"):
                        configs[iid] = it["config"]
                else:
                    ids.add(int(it))
        except (TypeError, ValueError):
            return self._send_json({"ok": False, "error": "tasks 格式错误"}, 400)
        if not ids:
            ids = {t.id for t in batch.tasks if t.status in ("error", "cancelled")}
        n = batch.retry_tasks(ids, configs)
        return self._send_json({"ok": True, "retried": n})


def run_server(host, port):
    httpd = ThreadingHTTPServer((host, port), Handler)
    print("[服务] 多平台图片生成 Web 页面已启动")
    print(f"[服务] 浏览器打开: http://{host}:{port}/")
    configured = [p for p, k in Handler.default_keys.items() if k]
    print(f"[服务] 服务端已配置 Key 的平台: {', '.join(configured) or '无 (可在页面内输入, 保存在浏览器 localStorage)'}")
    print("[服务] 按 Ctrl+C 停止")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n[服务] 已停止")


if __name__ == "__main__":
    main()
