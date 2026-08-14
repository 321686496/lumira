# 后端存储迁移：SQLite → MySQL（含 CI/CD 部署改造）

日期：2026-08-14
状态：已获用户批准（设计）

## 背景与目标

Lumira 后端（NestJS + Fastify + Drizzle ORM）目前使用 SQLite（better-sqlite3）作为数据库，
生产环境通过 docker-compose 将数据卷挂载到宿主机 `./data/lumira.db`。

目标：

1. 后端存储改为 MySQL（mysql:8 容器，随 docker-compose 一起部署）。
2. CI/CD 同步改造：GitHub Actions 后端 CI 使用 MySQL service container 跑 e2e 测试；
   生产部署时创建 mysql 容器，后端通过内部网络连接。
3. 现有 SQLite 生产数据**不迁移**，MySQL 全新开始（已与用户确认）。
4. 本地开发与 e2e 测试**全部切换 MySQL**（已与用户确认），不再维护 SQLite 双驱动。

## 现状梳理

- 驱动：`better-sqlite3` + `drizzle-orm/better-sqlite3`，schema 全部用 `sqlite-core`。
- 连接与迁移集中在 `lumira-server/packages/backend/src/database/database.service.ts`：
  - SQLite 连接 + WAL/foreign_keys PRAGMA；
  - 9 个迁移文件 `001_init.sql` ~ `009_device_info.sql`（SQLite 语法），启动时按文件名排序
    逐条 `exec`；009 实际 ALTER 逻辑在 JS 兼容代码中幂等执行；
  - 若干 SQLite 专属的旧库兼容代码（`PRAGMA table_info` 检测、建表重建等）。
- `getRawDb()` 未被任何模块使用（仅定义），可移除。
- 服务层使用 Drizzle 查询，但以下三处用了 SQLite 同步 API，需改造：
  - `modules/points/points.service.ts`：`db.transaction((tx) => { ... tx.select()...all() ... })`；
  - `modules/redeem/redeem.service.ts`：同上模式；
  - `modules/admin/admin.service.ts`：`tx.insert(...).values(...).run()`。
- e2e 测试（`test/*.e2e-spec.ts`）在 `beforeAll` 中设置 `process.env.DB_PATH = ':memory:'`。
- CI：`.github/workflows/backend-ci.yml` 只跑 typecheck + test:e2e，无数据库服务。
- 部署：`deploy/docker-compose.prod.yml` 单服务 `lumira-backend`；`.env` 由服务器维护；
  `backend-deploy.yml` 负责 SSH → git pull → docker build → compose up。

## 设计方案

### 1. 驱动与连接层

- 依赖：移除 `better-sqlite3`、`@types/better-sqlite3`，新增 `mysql2`。
- `src/database/schema.ts`：全部表定义从 `drizzle-orm/sqlite-core` 改为 `drizzle-orm/mysql-core`：
  - `sqliteTable` → `mysqlTable`；
  - `integer('id').primaryKey({ autoIncrement: true })` → `int('id').primaryKey({ autoIncrement: true })`；
  - 其余 `integer(...)` → `int(...)`；
  - `text(...)` 短文本保持 `text`，大 JSON 列（模板 5 段内容 `compositionJson`/`poseJson`/`cameraJson`/`sceneGuideJson`/`postProcessJson`、问卷 `answersJson`）用 `longtext`；
  - `uniqueIndex('...').on(...)` 用法在 mysql-core 中保持不变。
- `src/database/database.service.ts` 重写：
  - 使用 `mysql2/promise` 创建连接池，连接参数全部来自环境变量：
    `DB_HOST`、`DB_PORT`、`DB_USER`、`DB_PASSWORD`、`DB_NAME`（提供与现有 `.env.example` 一致的默认值以便本地开发）。
  - 创建 `drizzle(pool, { schema, mode: 'default' })`。
  - **版本化迁移执行器**：启动时建 `_migrations(name VARCHAR(255) PRIMARY KEY, applied_at INT)` 表，
    读取 `dist/database/migrations`（或 dev 的 `src/database/migrations`）下按文件名排序的 `.sql` 文件，
    仅执行未记录的迁移，成功后写入 `_migrations`，保证幂等。
  - 连接池开启 `multipleStatements: true`（迁移文件含多条语句，mysql2 单条 `query` 需要该选项）。
  - 删除所有 SQLite 专属兼容代码（`upgradeCategorySchemaIfNeeded`、PRAGMA 检测、JS 内 ALTER 等）。
  - 移除 `getRawDb()`（无使用方）。

### 2. 迁移 SQL 重写（001-008）

- 保留 001-008 的文件结构，逐条重写为 MySQL 8 语法：
  - `INTEGER PRIMARY KEY AUTOINCREMENT` → `INT AUTO_INCREMENT PRIMARY KEY`；
  - `INSERT OR IGNORE INTO` → `INSERT IGNORE INTO`；
  - `CREATE INDEX IF NOT EXISTS` → `CREATE INDEX`（幂等由版本化 runner 保证）；
  - 统一指定 `ENGINE=InnoDB`，字符集沿用 MySQL 8 默认 `utf8mb4`；
  - 与 schema.ts 对应：大 JSON 列用 `LONGTEXT`，其余文本列 `TEXT`/`VARCHAR`。
- devices 表：把设备信息列（`platform`、`os_version`、`device_model`、`app_version`）直接并入 001，
  废弃 009 文件（删除）。
- 种子数据（`reward_tiers` 默认阶梯、`template_prices` 13 条）保留，`INSERT IGNORE` 幂等。

### 3. 服务层适配

- `points.service.ts`、`redeem.service.ts`：事务回调改为 async，
  `tx.select()...all()` → `await tx.select()...execute()`（或直接 await 查询）；
- `admin.service.ts`：`.run()` → `await ...execute()`；
- 其余模块已使用 `await db.select()...` 异步风格，无需改动。

### 4. 测试

- 新增 `test/test-db.ts`：`resetTestDatabase()` 使用 root 连接对测试库执行
  `DROP DATABASE IF EXISTS <test-db>; CREATE DATABASE <test-db>;`。
- 各 e2e spec 的 `beforeAll` 中 `process.env.DB_PATH = ':memory:'` 替换为：
  设置 DB 连接环境变量默认值（host 127.0.0.1、user root、password root、db lumira_test），
  先 `await resetTestDatabase()` 再创建 App 实例，实现与 `:memory:` 等效的每文件隔离。
- `test:e2e` 脚本加 `--runInBand`，避免 jest 并行进程互相 DROP 测试库。
- 数据库连接在测试环境沿用现有代码路径（`database.service.ts` 读取环境变量），无独立 mock。

### 5. CI/CD 与部署

- `.github/workflows/backend-ci.yml`：
  - 新增 `services.mysql`：`image: mysql:8`，env 设 `MYSQL_ROOT_PASSWORD=root`、
    `MYSQL_DATABASE=lumira_test`，healthcheck 就绪后再跑测试；
  - Test 步骤注入 `DB_HOST=127.0.0.1`、`DB_PORT=3306`、`DB_USER=root`、`DB_PASSWORD=root`、`DB_NAME=lumira_test`。
- `deploy/docker-compose.prod.yml`：
  - 新增服务 `lumira-mysql`：`image: mysql:8`，`restart: always`，
    数据卷绑定 `./data/mysql:/var/lib/mysql` 持久化，**不暴露宿主机端口**；
    env：`MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}`、`MYSQL_DATABASE=${MYSQL_DATABASE}`、
    `MYSQL_USER=${MYSQL_USER}`、`MYSQL_PASSWORD=${MYSQL_PASSWORD}`；
    healthcheck：`mysqladmin ping -h localhost`；
    加入同一外部网络 `lumira-net`。
  - `lumira-backend` 增加环境变量：`DB_HOST=lumira-mysql`、`DB_PORT=3306`、
    `DB_USER=${MYSQL_USER}`、`DB_PASSWORD=${MYSQL_PASSWORD}`、`DB_NAME=${MYSQL_DATABASE}`；
    移除 `DB_PATH`；`depends_on: lumira-mysql: condition: service_healthy`。
- `.github/workflows/backend-deploy.yml`：
  - 服务器目录初始化失败时的提示信息补充 mysql 相关 `.env` 变量；
  - `mkdir -p $DEPLOY_PATH/data/mysql`（明确创建数据目录）。
- `lumira-server/packages/backend/.env.example`：删除 `DB_PATH`，新增 `DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME` 及 `MYSQL_*` 说明。
- `.github/DEPLOY.md`：更新服务器初始化 `.env` 模板、目录结构（`data/mysql`）、
  GitHub Actions Secrets 表、常见问题（MySQL 容器健康检查、首次启动建库说明）。

### 6. 清理

- `Dockerfile`：`base` 阶段移除 `python3 make g++` 与 `libc6-compat`（better-sqlite3 移除后无需原生编译；
  mysql2 为纯 JS）。若 CI 构建验证暴露其他原生依赖需要保留，则以 CI 结果为准调整。
- 仓库内已提交的 `lumira-server/packages/backend/data/lumira.db`：从 git 移除并加入 .gitignore
  （若后端 `data/` 已被 .gitignore 覆盖则仅需 `git rm`）。
- `pnpm-lock.yaml` 重新生成（移除 better-sqlite3、新增 mysql2）。

## 数据与兼容性

- 现有 SQLite 生产数据不迁移（用户确认），MySQL 首次启动由迁移执行器建表 + 种子数据。
- 对外 API（`/api/v1/*`）与数据库表结构（列名、类型语义）保持不变，
  Flutter / Admin 端无需改动；时间戳仍为 unix 秒（INT）。
- `_migrations` 表为内部实现，不对 API 暴露。

## 验证方式

- 本地：`pnpm install` 后跑 `pnpm --filter @lumira/backend test:e2e`（需本地 MySQL，
  或使用 `docker run -d -p 3306:3306 ... mysql:8`）。
- CI：backend-ci.yml 在 GitHub Actions 上跑 typecheck + e2e（MySQL service container）。
- 部署：backend-deploy.yml 触发后，服务器 `docker compose ps` 确认 mysql 容器 healthy、
  后端日志显示迁移成功、`curl /api/v1/health` 正常。
