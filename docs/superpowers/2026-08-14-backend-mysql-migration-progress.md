# 后端存储迁移 SQLite→MySQL 实施进度文档

> 记录时间：2026-08-14
> 状态：**执行中（已暂停）** —— Task 1 完成并已提交，Task 2 起尚未执行，待后续按本文档恢复。
> 恢复入口：本文档 + `docs/superpowers/plans/2026-08-14-backend-mysql-migration.md`（实施计划，含每步代码与命令）。

---

## 1. 目标概述

将 Lumira 后端数据库从 SQLite（better-sqlite3）迁移到 MySQL 8（mysql2 + drizzle-orm/mysql-core），并同步改造：

- 驱动层：同步 better-sqlite3 → 异步 mysql2/promise 连接池
- 迁移机制：启动逐条执行 SQL → 版本化迁移执行器（`_migrations` 表记录已执行文件，幂等）
- schema：`sqlite-core` → `mysql-core`
- 服务层：5 处 SQLite 同步 API（`.run()` / `.all()`）改为 MySQL 异步 API（`.execute()` / `await`）
- CI/CD：GitHub Actions 后端 CI 增加 MySQL 8 service container 跑 e2e；生产部署 docker-compose 新增 `lumira-mysql` 容器

**关键前提**（用户已确认）：
- 现有 SQLite 生产数据不迁移，MySQL 全新开始
- 本地开发与 e2e 测试全部切换 MySQL，不保留 SQLite 双驱动
- 对外 API（`/api/v1/*`）响应结构不变，Flutter / Admin 端无感知

---

## 2. 相关文档索引

| 文档 | 路径 |
|---|---|
| 设计文档 | `docs/superpowers/specs/2026-08-14-backend-mysql-migration-design.md` |
| 实施计划 | `docs/superpowers/plans/2026-08-14-backend-mysql-migration.md` |
| SDD 实时进度台账 | `.superpowers/sdd/progress.md`（末尾新增了本计划的 Task 1/Task 2 记录） |

---

## 3. 总体任务清单与当前状态

| 任务 | 内容 | 状态 | Commit |
|---|---|---|---|
| Task 1 | 驱动与连接层（依赖 + schema + database.service） | ✅ 完成 | `c9f6bfc` |
| Task 2 | 迁移 SQL 重写为 MySQL 语法（001–008 + 删 009） | ⬜ 待做 | — |
| Task 3 | 服务层同步 API 改异步（7 个文件） | ⬜ 待做 | — |
| Task 4 | e2e 测试切换 MySQL（test-db.ts + 8 spec + --runInBand） | ⬜ 待做 | — |
| Task 5 | CI 加 MySQL service container（backend-ci.yml） | ⬜ 待做 | — |
| Task 6 | 生产部署改造（compose / deploy workflow / .env / Dockerfile） | ⬜ 待做 | — |
| Task 7 | 文档同步（DEPLOY.md / AGENTS.md） | ⬜ 待做 | — |
| Task 8 | 全量验证与收尾（typecheck + e2e + 清理残留 + push 双远程） | ⬜ 待做 | — |
| — | 最终 whole-branch review | ⬜ 待做 | — |

**当前分支基线与提交链**：

```
73d72d3 docs: 后端存储迁移 SQLite→MySQL 设计文档
d07ec82 docs: 后端存储迁移 SQLite→MySQL 实施计划
c9f6bfc refactor(backend): 数据库驱动切换为 mysql2 + mysql-core schema + 版本化迁移执行器   ← 当前 HEAD
```

**工作区状态**：干净（`git status` 无未提交改动）。

---

## 4. Task 1 已完成详情（验收通过）

**提交**：`c9f6bfc refactor(backend): 数据库驱动切换为 mysql2 + mysql-core schema + 版本化迁移执行器`

**改动文件**：
- `lumira-server/packages/backend/package.json`：移除 `better-sqlite3` / `@types/better-sqlite3`，新增 `mysql2@^3.9.0`
- `lumira-server/packages/backend/src/database/schema.ts`：全部表定义改为 `drizzle-orm/mysql-core`（`mysqlTable` / `text` / `int` / `longtext` / `uniqueIndex`）
- `lumira-server/packages/backend/src/database/database.service.ts`：重写为 mysql2 连接池 + 版本化迁移执行器
- `lumira-server/pnpm-lock.yaml`：依赖锁文件刷新

**验证结论**（controller 复核）：
- `onModuleInit` 为 async，内部 `await this.runMigrations()`
- 连接池解构修正为 `const conn = await this.pool.getConnection()`（非 `const [conn] = ...`）
- 迁移执行器：建 `_migrations` 表、按文件名排序、`multipleStatements: true`、逐条执行并记录、幂等
- `getRawDb()`（SQLite 原始连接）已随重写移除
- `schema.ts` 无 `sqlite-core` 残留
- **已知预期中间态**：服务层（如 `points.service.ts`）仍引用 `BetterSQLiteTransaction` / `.all()` / `.run()`，导致 typecheck 报错——这是 Task 3 的处理范围，**未完成 Task 3 前 typecheck 允许失败**。

---

## 5. 待办任务要点速览（恢复执行时按计划逐条执行）

### Task 2：迁移 SQL 重写为 MySQL 语法
- 重写 `src/database/migrations/001_init.sql` ~ `008_point_earn_events.sql` 为 MySQL 语法（`VARCHAR` 主键 / 命名外键 `fk_*` / `ENGINE=InnoDB` / `INSERT IGNORE`）
- 设备信息列并入 001（devices 表含 platform/os_version/device_model/app_version），**删除 `009_device_info.sql`**
- 007 仅保留说明性注释（无重复 SQL）
- 可选验证：本机 docker 起 `mysql:8` 灌入 001–008 无语法错误
- 注意：主键/唯一索引文本列用 `VARCHAR`（MySQL TEXT 不能作主键），与 Task 1 schema.ts 对齐

### Task 3：服务层同步 API 改异步（7 个文件）
- `points.service.ts` / `redeem.service.ts` / `admin.service.ts` / `templates.service.ts` / `sign-in.service.ts` / `admin-categories.service.ts` / `admin-templates.service.ts`
- `db.transaction((tx) => {...})` → `await db.transaction(async (tx) => {...})`
- `.all()` → `await ...execute()`；`.run()` 移除并补 await
- `BetterSQLiteTransaction` 类型 → `MySql2Transaction`（`drizzle-orm/mysql2`）
- UNIQUE 冲突文案：SQLite `'UNIQUE constraint failed'` → MySQL `'Duplicate entry'` / `'ER_DUP_ENTRY'`
- `spendPointsSync` 改 async（返回 `Promise<number>`），调用方 `templates.service.ts` 补 `await`
- 完成后 `pnpm --filter @lumira/backend exec tsc --noEmit` 应无错误

### Task 4：e2e 测试切换 MySQL
- 新建 `test/test-db.ts`：`resetTestDatabase()`（DROP + CREATE `lumira_test` 库）
- 8 个 e2e spec 的 `beforeAll` 替换 `:memory:` 逻辑为 DB 环境变量 + `resetTestDatabase()`
- `package.json` `test:e2e` 加 `--runInBand`（避免并行 DROP 同一测试库）
- 本地验证需 docker 起 `mysql:8`（默认 root/root、库 `lumira_test`），验证后清理容器

### Task 5：CI 加 MySQL service container
- `.github/workflows/backend-ci.yml`：`jobs.ci` 下新增 `services.mysql`（`mysql:8` + healthcheck）+ Test 步骤注入 `DB_*` 环境变量
- 完成后 **push 到双远程**：`origin`(gitee) + `github`

### Task 6：生产部署改造
- `deploy/docker-compose.prod.yml`：新增 `lumira-mysql` 服务（`data/mysql` 数据卷 + healthcheck + 不暴露 3306）；后端环境变量改 `DB_HOST=lumira-mysql`，删 `DB_PATH`，加 `depends_on: service_healthy`
- `.github/workflows/backend-deploy.yml`：初始化提示块补 `MYSQL_*` 变量；数据目录步骤加 `mkdir -p $DEPLOY_PATH/data/mysql`
- `lumira-server/packages/backend/.env.example`：加 `DB_*` MySQL 配置
- `lumira-server/packages/backend/Dockerfile`：简化 base 阶段（mysql2 纯 JS）
- `lumira-server/.gitignore`：追加 `data/mysql/`
- `git rm --cached lumira-server/packages/backend/data/lumira.db`
- 完成后 **push 双远程**

### Task 7：文档同步
- `.github/DEPLOY.md`：MySQL 部署说明、`.env` 表加 `MYSQL_*`、常见问题补 MySQL 连不上排查
- `AGENTS.md`：技术栈速查表 better-sqlite3 → MySQL 8 (mysql2)；数据目录注释更新
- 完成后 **push 双远程**

### Task 8：全量验证与收尾
- 全仓 typecheck 无错误
- 本地 docker 起 MySQL 跑 `pnpm --filter @lumira/backend test:e2e` 全部通过（8 个 spec）
- grep 清理 `better-sqlite3` / `sqlite-core` / `DB_PATH` / `:memory:` 残留
- 如有残留改动 commit，最终 push 双远程，确认工作区干净

---

## 6. 环境与流程注意事项

- **push 规则（AGENTS.md 强制）**：凡涉及 `lumira-server/packages/backend/` 或 `lumira-server/packages/admin/` 的改动，每次 commit 后必须同时 push 到 `origin`(gitee) 与 `github`(github)；纯文档改动由用户决定是否推送。本计划的 Task 5/6/7/8 均含 push。
- **本地无 MySQL**：Task 2/4/8 的可选验证与 e2e 运行都依赖 docker 起 `mysql:8` 容器（默认 root/root、库 `lumira_test`），验证后 `docker rm -f` 清理。
- **typecheck 中间态**：Task 3 完成前 `tsc --noEmit` 会因服务层 `.all()`/`.run()` 残留报错，属预期，不得据此回退 Task 1。
- **subagent 投递提示**：本项目历史计划中有「subagent 消息投递偶发失败、改由 controller 内联执行并保留 TDD/逐 commit 质量门」的记录；若 Task 工具派发 subagent 后收不到回包，可采用内联执行兜底（保持每步 commit）。
- **SDD 台账**：每个任务完成后在 `.superpowers/sdd/progress.md` 末尾追加记录（commit 区间 + review 结论），任务间不暂停、连续执行。

---

## 7. 恢复执行的下一步

1. 从 `docs/superpowers/plans/2026-08-14-backend-mysql-migration.md` 的 **Task 2** 开始（先派发/执行 Task 2，重写 001–008 并删除 009）。
2. 每个 Task 完成后：controller 复核 → 更新 `.superpowers/sdd/progress.md` → 继续下一 Task。
3. 含部署/CI 的 Task（5/6/7/8）完成后按 AGENTS.md 规则 push 双远程。
4. 全部 Task 完成后做最终 whole-branch review（`73d72d3..HEAD`），无 Critical/Important 即收尾。
