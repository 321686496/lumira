#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""直连测试: 各上游平台 TCP/TLS/HTTP 可达性"""
import socket
import ssl
import sys
import urllib.error
import urllib.request

HOSTS = [
    ("hapi", "image.hapiopen.cc", "/v1/models"),
    ("mass", "mass.hzxmfg.com", "/v1/models"),
    ("mass-alt", "api.mass.hzxmfg.com", "/v1/models"),
    ("qianwen-payg", "dashscope.aliyuncs.com", "/api/v1/models"),
    ("qianwen-token", "token-plan.cn-beijing.maas.aliyuncs.com", "/api/v1/models"),
]

def tcp_check(host, port=443, timeout=8):
    s = socket.create_connection((host, port), timeout=timeout)
    s.close()
    return True

def tls_check(host, port=443, timeout=8):
    ctx = ssl.create_default_context()
    with socket.create_connection((host, port), timeout=timeout) as s:
        with ctx.wrap_socket(s, server_hostname=host) as t:
            ver = t.version()
            peer = t.getpeercert() and t.getpeercert().get("subject", ())
    return ver

def http_check(url, timeout=15):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code  # 4xx/5xx 也说明连通了
    except Exception as e:
        return "ERR:%s" % (e,)

for name, host, path in HOSTS:
    url = "https://%s%s" % (host, path)
    line = []
    try:
        tcp_check(host)
        line.append("TCP OK")
    except Exception as e:
        line.append("TCP FAIL(%s)" % e)
        print("%-14s %-40s %s" % (name, host, " | ".join(line)))
        continue
    try:
        ver = tls_check(host)
        line.append("TLS OK(%s)" % ver)
    except Exception as e:
        line.append("TLS FAIL(%s)" % e)
        print("%-14s %-40s %s" % (name, host, " | ".join(line)))
        continue
    st = http_check(url)
    line.append("HTTP %s" % st)
    print("%-14s %-40s %s" % (name, host, " | ".join(line)))
