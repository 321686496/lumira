# =============================================================================
# Base — install all dependencies (pnpm workspace, hoisted node-linker)
# =============================================================================
# 基础镜像用 Debian slim（不能用 alpine）：onnxruntime-node / sharp 的官方
# 预编译原生模块面向 glibc，Alpine/musl 下无法加载（AI 剪影管线依赖）。
FROM node:20-slim AS base

# 切换为阿里云 Debian 镜像源（解决国内服务器无法访问 deb.debian.org 的问题）
# node:20-slim (bookworm) 使用 deb822 格式的 debian.sources；|| true 兼容旧格式。
# libstdc++6：onnxruntime-node / sharp 原生模块运行时依赖。
RUN sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list.d/debian.sources || true \
    && sed -i 's|deb.debian.org|mirrors.aliyun.com|g' /etc/apt/sources.list || true \
    && apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates curl libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

# 配置 pnpm 使用淘宝 npm 镜像加速（国内服务器拉取 npm 包更快）
RUN npm install -g pnpm@9 \
    && pnpm config set registry https://registry.npmmirror.com \
    && pnpm config set fetch-retries 5 \
    && pnpm config set fetch-retry-factor 2 \
    && pnpm config set fetch-retry-mintimeout 20000 \
    && pnpm config set fetch-timeout 120000
WORKDIR /app

# Copy workspace manifests first for better layer caching
COPY pnpm-lock.yaml pnpm-workspace.yaml package.json ./
COPY packages/backend/package.json packages/backend/
COPY packages/admin/package.json packages/admin/
COPY packages/shared/package.json packages/shared/

# Use hoisted node-linker so node_modules is flat (no symlinks to .pnpm store),
# making runtime COPY straightforward.
RUN pnpm config set node-linker hoisted \
    && pnpm install --frozen-lockfile

# =============================================================================
# Builder — build shared + backend, then prune to production deps
# =============================================================================
FROM base AS builder
COPY packages/shared/ packages/shared/
COPY packages/backend/ packages/backend/

# RMBG-1.4 剪影模型（~44MB，AI 剪影管线用）：脚本内部优先 hf-mirror、
# 失败回退 huggingface.co；本地已有完整模型时幂等跳过（.onnx 已 gitignore，
# CI/服务器 checkout 后由本步骤下载）。
RUN node packages/backend/scripts/fetch-rmbg-model.mjs

RUN pnpm --filter @lumira/shared build
RUN pnpm --filter @lumira/backend build

# tsc 不会处理 nest-cli.json 的 assets 配置，手动复制非 TS 资源到 dist
# migrations/*.sql 被 database.service.ts 在运行时读取
RUN cp -r packages/backend/src/database/migrations packages/backend/dist/database/

# Re-install with --prod to remove devDependencies from node_modules
RUN pnpm install --prod --frozen-lockfile

# =============================================================================
# Runner — minimal production image
# =============================================================================
FROM node:20-slim AS runner
WORKDIR /app
ENV NODE_ENV=production

# Production node_modules (pruned, hoisted — workspace symlinks dereferenced on COPY)
COPY --from=builder /app/node_modules/ node_modules/
COPY --from=builder /app/package.json ./
COPY --from=builder /app/packages/backend/package.json packages/backend/
COPY --from=builder /app/packages/shared/package.json packages/shared/

# Built artifacts only (no source)
COPY --from=builder /app/packages/backend/dist/ packages/backend/dist/
COPY --from=builder /app/packages/backend/public/ packages/backend/public/
COPY --from=builder /app/packages/shared/dist/ packages/shared/dist/

# 剪影模型资产（silhouette.pipeline.ts 的 resolveModelPath：
# dist/modules/ai → 上溯 3 级 = packages/backend/assets/models）
COPY --from=builder /app/packages/backend/assets/models/ packages/backend/assets/models/

EXPOSE 3000
CMD ["node", "packages/backend/dist/main.js"]
