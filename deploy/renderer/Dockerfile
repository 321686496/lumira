# =============================================================================
# Lumira 无头渲染容器
# =============================================================================
# 只提供 Chromium 的 CDP 端点（--remote-debugging-port=9222），不含任何业务代码。
# 后端（lumira-backend）经 renderer-net 用 ws://lumira-renderer:9222 连接
# （puppeteer-core.connect），页面级请求拦截与 SSRF 判定全部在后端 TS 侧完成。
#
# 不用 ghcr.io 的现成渲染镜像：开源版不含 stealth/CAPTCHA，且镜像 3.6GB。
# 本镜像走 Debian 官方源（阿里云镜像加速），约 400MB。
FROM debian:bookworm-slim

# 切换为阿里云 Debian 镜像源（与后端 Dockerfile 同写法；|| true 兼容 deb822 与旧格式）
# chromium：无头浏览器本体；fonts-noto-cjk / fonts-wqy-zenhei：中文页面渲染字体；
# fontconfig：字体缓存；ca-certificates：HTTPS 站点证书；curl：仅供 HEALTHCHECK。
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources || true \
    && sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
         chromium fonts-noto-cjk fonts-wqy-zenhei fontconfig ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

# --no-sandbox 是容器内的必需取舍（否则需要 SYS_ADMIN 权限），作为残余风险记录在
# 设计文档第一节；渲染目标由后端在 CDP 请求拦截层做私网拦截。
ENTRYPOINT ["chromium", "--headless=new", "--no-sandbox", "--disable-dev-shm-usage", "--disable-gpu", "--no-first-run", "--remote-debugging-address=0.0.0.0", "--remote-debugging-port=9222", "--user-data-dir=/tmp/chrome"]

HEALTHCHECK --interval=30s --timeout=5s --retries=3 --start-period=20s \
  CMD curl -f http://127.0.0.1:9222/json/version || exit 1