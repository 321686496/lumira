# Lumira 部署指南

## 概述

Lumira 项目包含三个组件，部署方式各不相同：

| 组件 | 类型 | 部署方式 |
|------|------|----------|
| **Backend**（NestJS） | Docker 容器 | GitHub Actions → SSH → 服务器直接 `docker build` 部署 |
| **Admin**（Next.js） | Vercel 应用 | Vercel 自动监听 GitHub push 部署 |
| **Flutter App** | 移动应用 | 仅 CI 验证，不自动部署（需手动构建发布） |

**后端部署架构（服务器直接构建模式）：**

```
GitHub Push (master)
    ↓ 触发 backend-deploy.yml
GitHub Actions Runner
    ↓ SSH 登录服务器
私有服务器
    ├─ git pull origin master        # 拉取最新代码
    ├─ docker compose build          # 多阶段构建镜像
    └─ docker compose up -d          # 重启容器
```

**为什么不用 Docker Hub：**
- 无需任何外部容器镜像仓库账号
- 国内服务器部署快（不依赖境外网络拉取镜像）
- 构建产物直接在服务器本地，无中转

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
| `GIT_REMOTE` | 服务器上 git remote 名称（可选，默认 `origin`） | `origin` |

### 后端环境变量（在服务器 .env 中配置，不在 GitHub Secrets 中）

| 变量 | 说明 |
|------|------|
| `JWT_SECRET` | JWT 签名密钥（生产环境） |
| `ADMIN_TOKEN` | Admin API 令牌（生产环境） |

> 这两个变量通过服务器的 `.env` 文件注入（docker-compose 通过 `--env-file .env` 加载），**不要**放在 GitHub Secrets 中。

---

## 服务器初始化（后端）

### 1. 安装 Docker

```bash
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# 重新登录以使 docker 组生效
```

### 2. 安装 Git（如未安装）

```bash
# Ubuntu/Debian
sudo apt update && sudo apt install -y git

# CentOS/RHEL
sudo yum install -y git
```

### 3. 配置服务器访问 GitHub 仓库

服务器需要能 `git pull` 仓库。两种方式任选其一：

**方式 A：仓库为 Public** — 直接 clone，无需凭证
```bash
git clone https://github.com/<your-username>/lumira.git
```

**方式 B：仓库为 Private** — 使用 Deploy Key（推荐）
```bash
# 在服务器上生成专用 SSH key
ssh-keygen -t ed25519 -f ~/.ssh/lumira_deploy_key -N ""

# 打印公钥，添加到 GitHub 仓库 Settings → Deploy keys（勾选 Allow write access 不需要）
cat ~/.ssh/lumira_deploy_key.pub

# 配置 SSH 使用该 key 访问 GitHub
cat >> ~/.ssh/config <<EOF
Host github.com-lumira
    HostName github.com
    User git
    IdentityFile ~/.ssh/lumira_deploy_key
    IdentitiesOnly yes
EOF

# 用专用 host clone
git clone git@github.com-lumira:<your-username>/lumira.git
```

### 4. 创建部署目录结构

```bash
sudo mkdir -p /opt/lumira/backend
sudo chown -R $USER:$USER /opt/lumira/backend
cd /opt/lumira/backend
```

目录结构如下：

```
/opt/lumira/backend/
├── repo/                    # git clone 的仓库
├── docker-compose.prod.yml  # 从 repo/deploy/ 同步的部署配置
├── .env                     # 环境变量（手动创建）
└── data/                    # 数据卷（SQLite 数据库持久化）
```

### 5. Clone 仓库到 repo/ 子目录

```bash
cd /opt/lumira/backend

# Public 仓库
git clone https://github.com/<your-username>/lumira.git repo

# 或 Private 仓库（使用方式 B 配置的 deploy key）
git clone git@github.com-lumira:<your-username>/lumira.git repo
```

### 6. 创建 .env 文件

```bash
cat > /opt/lumira/backend/.env <<EOF
JWT_SECRET=$(openssl rand -hex 32)
ADMIN_TOKEN=$(openssl rand -hex 32)
NGINX_NETWORK=lumira-net
EOF

# 查看并记下这些值（用于客户端配置）
cat /opt/lumira/backend/.env
```

### 7. 创建 docker 网络（用于 nginx 与后端容器通信）

```bash
# 如果还没有网络
docker network create lumira-net

# 如果你的 nginx 容器已在另一个网络中（如 nginx-proxy 网络），
# 把 .env 中的 NGINX_NETWORK 改为该网络名
# 查询现有网络：docker network ls
```

> 后端容器会加入此网络，nginx 容器也必须加入同一网络才能通过容器名 `lumira-backend` 反向代理。
> 如果你的 nginx 是独立的 docker compose 项目，在那边的 networks 配置中 `external: true` 引用此网络即可。

### 8. 首次构建并启动

```bash
cd /opt/lumira/backend

# 同步部署用 compose 文件
cp repo/deploy/docker-compose.prod.yml .

# 创建数据目录
mkdir -p data

# 构建镜像（首次会拉取 node:20-alpine 基础镜像，需要 3-10 分钟）
docker compose -f docker-compose.prod.yml --env-file .env build

# 启动容器
docker compose -f docker-compose.prod.yml --env-file .env up -d

# 查看启动日志
docker compose -f docker-compose.prod.yml logs -f
```

### 9. 验证部署

容器未暴露端口到宿主机，需通过 nginx 反向代理访问，或在容器内验证：

```bash
# 查看容器状态
docker compose -f docker-compose.prod.yml ps

# 进入容器验证健康检查
docker compose -f docker-compose.prod.yml exec lumira-backend wget -qO- http://localhost:3000/api/v1
```

### 10. 配置 Nginx 反向代理（必需）

将 [deploy/nginx-lumira.conf.example](file:///d:/app/projects/photo_post/deploy/nginx-lumira.conf.example) 复制到你的 nginx 配置目录，按注释替换占位符：

```bash
# 示例（nginx 容器挂载的配置目录）
cp /opt/lumira/backend/repo/deploy/nginx-lumira.conf.example /etc/nginx/conf.d/lumira-api.conf

# 替换 <<YOUR_API_DOMAIN>> 为你的域名
nano /etc/nginx/conf.d/lumira-api.conf

# 测试 + 重载
nginx -t && nginx -s reload
```

**关键参数对照**（nginx 配置中需要替换的占位符）：

| 占位符 | 说明 | 示例 |
|---|---|---|
| `<<YOUR_API_DOMAIN>>` | 后端 API 域名 | `api.lumira.example.com` |
| `lumira-backend` | 后端容器服务名（已在 docker-compose.prod.yml 中固定） | 无需修改 |
| `3000` | 后端容器内端口（已在 docker-compose.prod.yml 中固定） | 无需修改 |

**申请 HTTPS 证书**（如果 nginx 在宿主机直接运行）：

```bash
sudo apt install -y certbot python3-certbot-nginx
sudo certbot --nginx -d api.your-domain.com
```

**如果 nginx 也是 docker 容器**：建议用 [nginx-proxy](https://github.com/nginx-proxy/nginx-proxy) + [acme-companion](https://github.com/nginx-proxy/acme-companion) 自动处理证书，或用 [Caddy](https://caddyserver.com/) 替代 nginx（自动 HTTPS）。

后续部署由 GitHub Actions 自动执行：`git pull → docker build → docker compose up -d`。

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
- **Build Command**：`cd ../.. && pnpm --filter @lumira/shared build && pnpm --filter @lumira/admin build`
  - 先构建 shared 包，再构建 admin

### 4. 配置环境变量

在 Vercel 项目设置 → Environment Variables 中添加：

| 变量 | 说明 |
|------|------|
| `BACKEND_URL` | 后端 API 内网或公网地址（Vercel 服务器需可访问），如 `https://api.your-domain.com` 或 `http://203.0.113.50:3000` |

> Admin 是 Next.js 服务端渲染（用了 `next/headers` 的 `cookies()`），fetch 发生在服务端而非浏览器，所以变量名是 `BACKEND_URL`，不需要 `NEXT_PUBLIC_` 前缀。
>
> 如果后端 HTTPS 证书是自签的，建议配置正规证书（Let's Encrypt），否则 Vercel 服务端 fetch 会因证书校验失败而报错。

### 5. 自动部署

配置完成后，每次 push 到 `master` 分支且修改了以下路径时，Vercel 自动触发部署：

- `lumira-server/packages/admin/**`
- `lumira-server/packages/shared/**`

GitHub Actions 的 `admin-deploy.yml` 会并行运行构建验证，提前发现问题。

---

## CI/CD Workflow 说明

| Workflow | 触发条件 | 用途 |
|----------|----------|------|
| `backend-ci.yml` | Push/PR 到 master（`lumira-server/**`） | Lint、类型检查、单元测试 |
| `backend-deploy.yml` | Push 到 master（`backend/**` 或 `shared/**`） | SSH 登录服务器执行 git pull + docker build + compose up |
| `admin-deploy.yml` | Push 到 master（`admin/**` 或 `shared/**`） | 构建验证（实际部署由 Vercel 处理） |
| `flutter-ci.yml` | Push/PR 到 master（`lumira_app_flutter/**`） | Flutter analyze + test |

---

## Docker 镜像构建说明

Dockerfile 位于 `lumira-server/packages/backend/Dockerfile`，构建上下文（context）为 `lumira-server/` 根目录（因依赖 monorepo 中的 shared 包）。

**多阶段构建**（`Dockerfile`）：

1. `base` — 安装全部依赖（含 devDependencies，用于编译 TypeScript）
2. `builder` — 构建 shared + backend，然后 prune 到生产依赖
3. `runner` — 最终镜像，仅含 production 依赖 + dist 产物

本地手动构建（在仓库根目录执行）：

```bash
docker build -f lumira-server/packages/backend/Dockerfile -t lumira-backend lumira-server/

docker run -p 3000:3000 \
  -e JWT_SECRET=test-secret \
  -e ADMIN_TOKEN=test-token \
  -v $(pwd)/data:/app/data \
  lumira-backend
```

---

## 常见问题

### Q: 后端部署后健康检查失败？

确认容器内 `/api/v1` 路由可访问：
```bash
docker compose -f docker-compose.prod.yml logs
curl http://localhost:3000/api/v1
```
healthcheck 使用 `wget --spider http://localhost:3000/api/v1`。

### Q: GitHub Actions SSH 部署超时？

首次构建镜像可能需要 5-15 分钟（拉取基础镜像 + pnpm install + tsc build）。`backend-deploy.yml` 已设置 `script_timeout: 30m`，若仍超时，可拆分为两步：先手动 SSH 构建镜像，再让 CI 仅做 `docker compose up -d`。

### Q: Vercel 构建失败提示找不到 `@lumira/shared`？

确保 `vercel.json` 的 installCommand 中 `cd ../..` 正确跳转到 monorepo 根。Vercel Root Directory 必须设为 `lumira-server/packages/admin`。

### Q: Flutter CI 报 Dart SDK 版本不兼容？

项目 `pubspec.yaml` 要求 `sdk: '>=2.19.6 <3.0.0'`，CI 已锁定 Flutter 3.7.12（对应 Dart 2.19.6）。如版本冲突，检查 `flutter-ci.yml` 中的 `flutter-version`。

### Q: 服务器 git pull 失败提示认证失败？

如果仓库是 Private，需要按"方式 B"配置 Deploy Key。Public 仓库无需认证。

### Q: 如何查看后端运行日志？

```bash
cd /opt/lumira/backend
docker compose -f docker-compose.prod.yml logs -f          # 实时日志
docker compose -f docker-compose.prod.yml logs --tail=100  # 最近 100 行
```
