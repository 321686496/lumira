# Lumira 部署指南

## 概述

Lumira 项目包含三个组件，部署方式各不相同：

| 组件 | 类型 | 部署方式 |
|------|------|----------|
| **Backend**（NestJS） | Docker 容器 | GitHub Actions → Docker Hub → SSH 部署到私有服务器 |
| **Admin**（Next.js） | Vercel 应用 | Vercel 自动监听 GitHub push 部署 |
| **Flutter App** | 移动应用 | 仅 CI 验证，不自动部署（需手动构建发布） |

---

## GitHub Actions Secrets 清单

在 **GitHub 仓库 → Settings → Secrets and variables → Actions** 中添加以下 secrets：

### 后端部署（必需）

| Secret | 说明 | 示例 |
|--------|------|------|
| `SSH_HOST` | 私有服务器 IP 或域名 | `203.0.113.50` |
| `SSH_USER` | SSH 部署用户 | `deploy` |
| `SSH_PRIVATE_KEY` | SSH 私钥完整内容 | `-----BEGIN OPENSSH PRIVATE KEY-----...` |
| `SSH_PORT` | SSH 端口（可选，默认 22） | `22` |
| `DEPLOY_PATH` | 服务器部署目录（可选，默认 `/opt/lumira/backend`） | `/opt/lumira/backend` |
| `DOCKER_USERNAME` | Docker Hub 用户名 | `lumira` |
| `DOCKER_PASSWORD` | Docker Hub 密码或 Access Token | `dckr_xxxx...` |
| `DOCKER_IMAGE` | 完整 Docker 镜像名（含仓库前缀） | `lumira/backend` |
| `JWT_SECRET` | JWT 签名密钥（生产环境） | `a-very-long-random-string` |
| `ADMIN_TOKEN` | Admin API 令牌（生产环境） | `another-long-random-string` |

> **注意**：`JWT_SECRET` 和 `ADMIN_TOKEN` 同时需要在服务器的 `.env` 文件中配置（docker-compose.yml 通过变量注入）。

---

## 服务器初始化（后端）

### 1. 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# 重新登录以使 docker 组生效
```

### 2. 创建部署目录

```bash
sudo mkdir -p /opt/lumira/backend
sudo chown -R $USER:$USER /opt/lumira/backend
cd /opt/lumira/backend
```

### 3. 放置 docker-compose.yml

将 `lumira-server/packages/backend/docker-compose.yml` 复制到服务器 `/opt/lumira/backend/docker-compose.yml`：

```bash
# 方式一：从本地 scp 上传
scp lumira-server/packages/backend/docker-compose.yml user@server:/opt/lumira/backend/

# 方式二：手动创建（内容相同）
nano docker-compose.yml
```

### 4. 创建 .env 文件

在 `/opt/lumira/backend/` 下创建 `.env`：

```env
DOCKER_IMAGE=<docker-hub-用户名>/lumira-backend
JWT_SECRET=<生产环境-JWT-密钥>
ADMIN_TOKEN=<生产环境-Admin-令牌>
```

### 5. 登录 Docker Hub（如镜像为私有）

```bash
docker login -u <username> -p <password-or-token>
```

### 6. 创建数据目录

```bash
mkdir -p data
```

### 7. 首次拉取并启动

```bash
docker compose pull
docker compose up -d
docker compose logs -f   # 查看启动日志
```

后续部署由 GitHub Actions 自动执行 `docker pull → docker compose down → docker compose up -d`。

---

## Vercel 连接（Admin 后台）

Admin 后台通过 Vercel 自动部署，无需手动操作。

### 1. 在 Vercel 导入项目

1. 登录 [vercel.com](https://vercel.com) → **Add New** → **Project**
2. 选择对应的 GitHub 仓库并 Import

### 2. 配置 Root Directory

在项目设置页面：

- **Root Directory** 设为：`lumira-server/packages/admin`
- **Framework Preset**：Next.js（自动检测）

### 3. Build & Install 命令

`lumira-server/packages/admin/vercel.json` 已配置：

- **Install Command**：`cd ../.. && pnpm install --frozen-lockfile`
  - 从 monorepo 根安装依赖（包含 shared 包）
- **Build Command**：`cd ../.. && pnpm --filter @lumira/admin build`
  - 先构建 shared 包，再构建 admin

### 4. 自动部署

配置完成后，每次 push 到 `master` 分支且修改了以下路径时，Vercel 自动触发部署：

- `lumira-server/packages/admin/**`
- `lumira-server/packages/shared/**`

GitHub Actions 的 `admin-deploy.yml` 会并行运行构建验证，提前发现问题。

---

## CI/CD Workflow 说明

| Workflow | 触发条件 | 用途 |
|----------|----------|------|
| `backend-ci.yml` | Push/PR 到 master（`lumira-server/**`） | Lint、类型检查、单元测试 |
| `backend-deploy.yml` | Push 到 master（`backend/**` 或 `shared/**`） | 构建 Docker 镜像 → 推送 Docker Hub → SSH 部署 |
| `admin-deploy.yml` | Push 到 master（`admin/**` 或 `shared/**`） | 构建验证（实际部署由 Vercel 处理） |
| `flutter-ci.yml` | Push/PR 到 master（`lumira_app_flutter/**`） | Flutter analyze + test |

---

## Docker 镜像构建说明

Dockerfile 位于 `lumira-server/packages/backend/Dockerfile`，构建上下文（context）为 `lumira-server/` 根目录（因依赖 monorepo 中的 shared 包）。

```bash
# 本地构建（在仓库根目录执行）
docker build -f lumira-server/packages/backend/Dockerfile -t lumira-backend lumira-server/

# 本地运行
docker run -p 3000:3000 \
  -e JWT_SECRET=test-secret \
  -e ADMIN_TOKEN=test-token \
  -v $(pwd)/data:/app/data \
  lumira-backend
```

**多阶段构建**：
1. `base` — 安装全部依赖（含 devDependencies，用于编译 TypeScript）
2. `builder` — 构建 shared + backend，然后 prune 到生产依赖
3. `runner` — 最终镜像，仅含 production 依赖 + dist 产物

---

## 常见问题

### Q: 后端部署后健康检查失败？

确认容器内 `/api/v1` 路由可访问。healthcheck 使用 `wget --spider http://localhost:3000/api/v1`。

### Q: Vercel 构建失败提示找不到 `@lumira/shared`？

确保 `vercel.json` 的 installCommand 中 `cd ../..` 正确跳转到 monorepo 根。Vercel Root Directory 必须设为 `lumira-server/packages/admin`。

### Q: Flutter CI 报 Dart SDK 版本不兼容？

项目 `pubspec.yaml` 要求 `sdk: '>=2.19.6 <3.0.0'`，Flutter 3.7.0 自带 Dart 2.19.0。如遇版本冲突，将 `flutter-ci.yml` 中的 `flutter-version` 改为 `3.7.12`（对应 Dart 2.19.6）。
