# Agent Instructions

## Project Status Notice

### uni-app 项目已废弃（仅作原型参考）

`lumira-app/` 目录下的 uni-app 项目是**技术选型后被遗弃的旧项目**，当前**不再维护、不再开发新功能**。

- **当前主项目**：`lumira_app_flutter/`（Flutter，HarmonyOS 兼容，Dart 2.19.6 / Flutter 3.7.12）
- **后端**：`lumira-server/`（NestJS + Fastify + Drizzle ORM + MySQL 8，pnpm monorepo 含 admin Next.js）
- **uni-app 的作用**：仅作为**视觉规格与交互原型参考**，不可作为运行时或修改目标

### 处理原则

1. **不要修改 `lumira-app/` 下的任何代码**，除非用户明确要求
2. 需要参考设计稿、配色、组件样式、交互流程时，可阅读 uni-app 源码作为参考
3. 新功能、Bug 修复一律在 `lumira_app_flutter/` 实现
4. 后端相关改动在 `lumira-server/` 实现
5. 涉及两端协同时，Flutter 端为主，后端提供 API 支持
6. **每次对后端（`lumira-server/packages/backend/`）或后台（`lumira-server/packages/admin/`）完成一次修改或功能增强之后，必须 commit 并同时 push 到两个远程仓库**（不要积压多次改动后再批量推送）：
   - `origin` → gitee（`git@gitee.com:huangh-gitee/photo_post.git`）：`git push origin master`
   - `github` → github（`git@github.com:321686496/lumira.git`）：`git push github master`
   - 仅纯文档或注释改动可由用户决定是否推送

### 技术栈速查

| 层 | 技术 | 位置 |
|---|---|---|
| 客户端 | Flutter 3.7.12 / Dart 2.19.6（不支持 Dart 3 records 语法） | `lumira_app_flutter/` |
| 后端 | NestJS + Fastify + Drizzle ORM + MySQL 8 (mysql2) | `lumira-server/packages/backend/` |
| 后台 | Next.js (App Router) + Tailwind + shadcn/ui | `lumira-server/packages/admin/` |
| 共享类型 | TypeScript | `lumira-server/packages/shared/` |
| 状态管理（Flutter） | flutter_riverpod 2.3.6 + sqflite v11（离线优先） | `lumira_app_flutter/lib/` |
| 路由（Flutter） | GoRouter 6.5.7 | `lumira_app_flutter/lib/app/router.dart` |

---

## 部署与 CI/CD

项目部署**完全由 GitHub CI/CD 驱动**，无 Docker Hub / 镜像仓库依赖。后端采用"服务器直接构建"模式：GitHub Actions → SSH 登录服务器 → `git pull` → `docker build` → `docker compose up -d`。

### 三组件部署方式总览

| 组件 | 技术 | 部署方式 |
|---|---|---|
| 后端 | NestJS Docker 容器 | GitHub Actions（`backend-deploy.yml`）→ SSH → 服务器直接 `docker build` |
| 后台 | Next.js | **Vercel 自动监听 GitHub push**（Root Directory = `lumira-server/packages/admin`） |
| Flutter | 移动端 | 仅 CI 验证（`flutter-ci.yml`），不自动部署，需手动构建发布 |

### 部署/CI 相关文件清单

| 文件 | 作用 |
|---|---|
| `.github/workflows/backend-deploy.yml` | 后端 SSH 部署（push master 且改动 backend/shared/deploy 相关路径时触发） |
| `.github/workflows/backend-ci.yml` | 后端 CI：typecheck + e2e 测试 |
| `.github/workflows/admin-deploy.yml` | 后台构建验证（实际部署走 Vercel） |
| `.github/workflows/flutter-ci.yml` | Flutter analyze + test（锁定 Flutter 3.7.12） |
| `.github/DEPLOY.md` | 完整部署指南（服务器初始化 / Vercel 连接 / 常见问题） |
| `deploy/docker-compose.prod.yml` | 后端生产 compose 配置（部署时由 CI 同步到服务器） |
| `lumira-server/packages/backend/Dockerfile` | 后端多阶段构建镜像（base → builder → runner） |
| `lumira-server/packages/admin/vercel.json` | Vercel 构建/安装命令 |
| `lumira-server/packages/admin/next.config.js` | `/uploads/*` rewrite 代理（解决 Mixed Content） |
| `lumira-server/packages/backend/.env.example` | 后端环境变量模板 |

### 后端 SSH 部署（backend-deploy.yml）

**触发条件**：push 到 master，且改动以下路径之一：
- `lumira-server/packages/backend/**`
- `lumira-server/packages/shared/**`
- `lumira-server/pnpm-lock.yaml` / `pnpm-workspace.yaml` / `package.json`
- `deploy/docker-compose.prod.yml`
- `.github/workflows/backend-deploy.yml`

**GitHub Actions Secrets**（仓库 Settings → Secrets and variables → Actions）：

| Secret | 说明 | 默认值 |
|---|---|---|
| `SSH_HOST` | 服务器 IP/域名 | 必填 |
| `SSH_USER` | SSH 用户 | 必填 |
| `SSH_PRIVATE_KEY` | SSH 私钥完整内容 | 必填 |
| `SSH_PORT` | SSH 端口 | 22 |
| `DEPLOY_PATH` | 服务器部署目录 | `/opt/lumira/backend` |
| `GIT_REMOTE` | 服务器 git remote 名 | `origin` |

**服务器目录结构**：

```
/opt/lumira/backend/
├── repo/                    # git clone 的仓库（CI 在此 git reset --hard origin/master）
├── docker-compose.prod.yml  # CI 从 repo/deploy/ 同步
├── .env                     # 环境变量（服务器本地维护，不在 GitHub Secrets）
├── data/                    # 数据卷（MySQL 数据 + 上传图片持久化）
└── data/mysql/              # MySQL 数据目录（容器挂载，自动创建）
```

**服务器 `.env` 必填变量**：

| 变量 | 说明 |
|---|---|
| `JWT_SECRET` | JWT 签名密钥（`openssl rand -hex 32` 生成） |
| `ADMIN_TOKEN` | Admin API 令牌 |
| `MYSQL_ROOT_PASSWORD` | MySQL root 密码（`openssl rand -hex 16` 生成） |
| `MYSQL_DATABASE` | 数据库名（如 `lumira`） |
| `MYSQL_USER` | 应用数据库用户（如 `lumira`） |
| `MYSQL_PASSWORD` | 应用数据库用户密码（`openssl rand -hex 16` 生成） |
| `NGINX_NETWORK` | nginx 容器所在的 docker network 名（如 `lumira-net`） |
| `BACKEND_PUBLIC_URL` | **后端 API 公网域名**，如 `https://lumira.iwtle.top`（详见下方图片 URL 章节） |

> ⚠️ **`BACKEND_PUBLIC_URL` 必须配置**：后端 `buildPublicUrl()` 用它构造上传图片的可访问 URL，未设置时回退 `http://localhost:3000`，会导致 App 端图片加载失败。修改 `deploy/docker-compose.prod.yml` 后需在服务器 `.env` 同步补充该变量并重新部署。

### 图片上传与 URL 体系（重要）

**上传接口**：所有上传挂在 `/api/v1/admin/*`（AdminAuthGuard 保护），无独立 /upload 接口：
- `POST /api/v1/admin/templates`（创建模板，cover 必填 + silhouette 可选）
- `PATCH /api/v1/admin/templates/:id`（更新）
- `POST /api/v1/admin/categories` / `PATCH .../:key`（分类 + icon）

**物理存储位置**（后端服务器，`UPLOAD_DIR` 默认 `./data/uploads`，生产为 `/app/data/uploads`，挂载到宿主机 `data/`）：

```
{UPLOAD_DIR}/
├── templates/{templateId}/
│   ├── cover.{ext}         # 封面（文件名固定 cover，扩展名随上传文件）
│   └── silhouette.{ext}    # 剪影（可选）
└── categories/{categoryKey}/
    └── icon.{ext}          # 分类图标（可选）
```

**URL 构造**（`admin-templates.service.ts` / `admin-categories.service.ts` 的 `buildPublicUrl`）：
```ts
const base = process.env.BACKEND_PUBLIC_URL || 'http://localhost:3000';
return `${base}/uploads/${category}/${id}/${filename}`;
```
- URL **存入数据库**（`templates.cover_url`、`pose_json.silhouette.url/data`、`template_categories.icon_url`），Flutter 通过 `GET /api/v1/templates/list` / `:id` 拿到该绝对 URL 直接 `Image.network()` 加载
- Admin 前端（Vercel HTTPS）**不直接加载后端 http URL**：`asset-url.ts` 把绝对 URL 转为 `/uploads/...` 相对路径，由 `next.config.js` rewrite 在服务端代理到后端（避免 Mixed Content）。所以 admin 页面 network 里看到 admin 域名是正常设计
- Flutter 端**不经过代理**，直接用 DB 里的 URL → **必须保证 `BACKEND_PUBLIC_URL` 为 App 可访问的公网域名**

### 后台部署（Vercel）

- Vercel 项目配置：Root Directory = `lumira-server/packages/admin`，Framework = Next.js
- 构建命令来自 `vercel.json`：先 `pnpm --filter @lumira/shared build` 再 `pnpm --filter @lumira/admin build`
- Vercel 环境变量：`BACKEND_URL`（后端 API 地址，服务端 fetch 用，无需 `NEXT_PUBLIC_` 前缀）
- 触发：push master 改动 `lumira-server/packages/admin/**` 或 `lumira-server/packages/shared/**`

### Flutter 端 API 配置

- `lumira_app_flutter/lib/core/config/app_config.dart` 的 `AppConfig.baseUrl`，通过 `--dart-define=API_BASE_URL=xxx` 注入
- 当前默认值：`https://lumira.iwtle.top/api/v1`（生产）
- 真机调试：`flutter run --dart-define=API_BASE_URL=http://<局域网IP>:3000/api/v1`

