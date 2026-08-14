# 后端存储迁移 SQLite→MySQL 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Lumira 后端数据库从 SQLite（better-sqlite3）迁移到 MySQL 8（mysql2 + drizzle-orm/mysql-core），并同步改造 CI（MySQL service container）与生产部署（docker-compose 新增 mysql 容器）。

**Architecture:** 后端保持 NestJS + Drizzle ORM。驱动层从同步的 better-sqlite3 换成异步的 mysql2/promise 连接池；迁移从「启动逐条执行 SQL」改为「版本化迁移执行器」（`_migrations` 表记录已执行文件，幂等）；schema 从 `sqlite-core` 改为 `mysql-core`；服务层 5 处 SQLite 同步 API（`.run()`/`.all()`）改为 MySQL 异步 API（`.execute()`/`await`）。部署通过 docker-compose 新增 `lumira-mysql` 容器，后端容器 `depends_on` 其健康后启动。

**Tech Stack:** NestJS 10 · Fastify · Drizzle ORM 0.38 · mysql2 · mysql:8 · docker-compose · GitHub Actions · pnpm monorepo

## Global Constraints

- Dart 2.19.6 / Flutter 3.7.12（本计划不涉及 Flutter，勿改 `lumira_app_flutter/`）
- 后端依赖：`drizzle-orm@^0.38.0`、`@nestjs/*@^10.3.0`（版本号保持不变，仅增删驱动包）
- 时间戳一律为 unix 秒（INT），与现有 API 兼容，不得改动
- 对外 API（`/api/v1/*`）响应结构不变，Flutter / Admin 端无感知
- 所有代码注释用中文（延续现有风格）；新增代码注释只加在逻辑不自明处
- 生产 MySQL 连接走 docker 内部网络（`lumira-mysql:3306`），不暴露宿主机端口
- 现有 SQLite 生产数据不迁移，MySQL 全新开始（用户已确认）
- 本地开发与 e2e 测试全部切换 MySQL（用户已确认），不保留 SQLite 双驱动
- 部署相关改动（backend / shared / deploy / workflows）完成后须 commit 并 push 到两个远程：`origin`(gitee) 与 `github`(github)（AGENTS.md 规则）
- 迁移文件顺序执行依赖文件名排序（001 < 002 < … < 008），不得重排

---

### Task 1: 数据库驱动与连接层（依赖 + schema + database.service）

**Files:**
- Modify: `lumira-server/packages/backend/package.json`
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Rewrite: `lumira-server/packages/backend/src/database/database.service.ts`

**Interfaces:**
- Consumes: 现有 `DatabaseService.getDb()`（返回 `BetterSQLite3Database`）——将被替换为 `MySql2Database`
- Produces: `DatabaseService.getDb()` 返回 `MySql2Database<typeof schema>`（drizzle-orm/mysql2）；`onModuleInit()` 内完成连接池创建 + 版本化迁移执行；新迁移执行器依赖 `src/database/migrations/*.sql`（Task 2 重写为 MySQL 语法）

- [ ] **Step 1: 更新依赖（package.json）**

在 `dependencies` 中移除 `better-sqlite3`、`@types/better-sqlite3`（devDependencies），新增 `mysql2`：

```json
"dependencies": {
  "@fastify/multipart": "^8.0.0",
  "@fastify/static": "^7.0.0",
  "@lumira/shared": "workspace:*",
  "@nestjs/common": "^10.3.0",
  "@nestjs/core": "^10.3.0",
  "@nestjs/jwt": "^10.2.0",
  "@nestjs/platform-fastify": "^10.3.0",
  "class-transformer": "^0.5.1",
  "class-validator": "^0.14.0",
  "drizzle-orm": "^0.38.0",
  "jsonwebtoken": "^9.0.2",
  "mysql2": "^3.9.0",
  "nanoid": "^3.3.7",
  "reflect-metadata": "^0.2.1",
  "rxjs": "^7.8.1"
},
"devDependencies": {
  "@nestjs/cli": "^10.3.0",
  "@nestjs/testing": "^10.3.0",
  "@types/jest": "^29.5.11",
  "@types/jsonwebtoken": "^9.0.5",
  "@types/node": "^20.11.0",
  "fastify": "^4.28.1",
  "jest": "^29.7.0",
  "supertest": "^6.3.4",
  "ts-jest": "^29.1.1",
  "tsc-watch": "^7.2.1",
  "typescript": "^5.3.0"
}
```

（删除 `@types/better-sqlite3`；其余保持现状。）

- [ ] **Step 2: 重写 schema.ts 为 mysql-core**

将 `src/database/schema.ts` 全部表定义从 `drizzle-orm/sqlite-core` 改为 `drizzle-orm/mysql-core`。替换规则（逐表套用）：
- 导入：`import { mysqlTable, text, int, longtext, uniqueIndex } from 'drizzle-orm/mysql-core';`
- `sqliteTable(` → `mysqlTable(`
- `integer('id').primaryKey({ autoIncrement: true })` → `int('id').primaryKey({ autoIncrement: true })`
- 其余所有 `integer(` → `int(`
- `uniqueIndex('uq_xxx').on(...)` 保持不变（mysql-core 同样支持）

完整目标文件：

```ts
// lumira-server/packages/backend/src/database/schema.ts

import { mysqlTable, text, int, longtext, uniqueIndex } from 'drizzle-orm/mysql-core';

export const devices = mysqlTable('devices', {
  deviceId: text('device_id').primaryKey(),
  alias: text('alias'),
  platform: text('platform'),
  osVersion: text('os_version'),
  deviceModel: text('device_model'),
  appVersion: text('app_version'),
  firstSeenAt: int('first_seen_at').notNull(),
  lastSeenAt: int('last_seen_at').notNull(),
  ipRegion: text('ip_region'),
});

export const userProfiles = mysqlTable('user_profiles', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  username: text('username').notNull(),
  avatarSeed: text('avatar_seed').notNull(),
  updatedAt: int('updated_at').notNull(),
});

export const inviteRecords = mysqlTable('invite_records', {
  id: int('id').primaryKey({ autoIncrement: true }),
  inviterDeviceId: text('inviter_device_id').notNull().references(() => devices.deviceId),
  inviteeDeviceId: text('invitee_device_id').notNull().unique().references(() => devices.deviceId),
  inviteCode: text('invite_code').notNull(),
  channel: text('channel').notNull().default('direct'),
  activatedAt: int('activated_at').notNull(),
  inviterIp: text('inviter_ip'),
  inviteeIp: text('invitee_ip'),
});

export const rewardTiers = mysqlTable('reward_tiers', {
  tier: int('tier').primaryKey(),
  requiredInvites: int('required_invites').notNull(),
  rewardsJson: text('rewards_json').notNull().default('[]'),
  isActive: int('is_active').notNull().default(1),
});

export const rewardUnlocks = mysqlTable('reward_unlocks', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  tier: int('tier').notNull().references(() => rewardTiers.tier),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  status: text('status').notNull().default('unlocked'),
  unlockedAt: int('unlocked_at').notNull(),
  claimedAt: int('claimed_at'),
});

export const redemptionCodeBatches = mysqlTable('redemption_code_batches', {
  batchId: int('batch_id').primaryKey({ autoIncrement: true }),
  campaignName: text('campaign_name').notNull(),
  maxUsesPerCode: int('max_uses_per_code').notNull().default(1),
  totalGenerated: int('total_generated').notNull(),
  totalUsed: int('total_used').notNull().default(0),
  rewardPoints: int('reward_points').notNull().default(0),
  rewardTemplates: text('reward_templates').notNull().default('[]'),
  validFrom: int('valid_from'),
  validUntil: int('valid_until'),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
});

export const redemptionCodes = mysqlTable('redemption_codes', {
  code: text('code').primaryKey(),
  batchId: int('batch_id').notNull().references(() => redemptionCodeBatches.batchId),
  usedCount: int('used_count').notNull().default(0),
  maxUses: int('max_uses').notNull().default(1),
});

export const redemptionRecords = mysqlTable('redemption_records', {
  id: int('id').primaryKey({ autoIncrement: true }),
  code: text('code').notNull().references(() => redemptionCodes.code),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  redeemedAt: int('redeemed_at').notNull(),
  ipAddress: text('ip_address'),
});

export const questionnaireRecords = mysqlTable('questionnaire_records', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull(),
  answersJson: longtext('answers_json').notNull(),
  submittedAt: int('submitted_at').notNull(),
  clientIp: text('client_ip'),
});

export const userPoints = mysqlTable('user_points', {
  deviceId: text('device_id').primaryKey().references(() => devices.deviceId),
  balance: int('balance').notNull().default(0),
  totalEarned: int('total_earned').notNull().default(0),
  totalSpent: int('total_spent').notNull().default(0),
  updatedAt: int('updated_at').notNull(),
});

export const pointTransactions = mysqlTable('point_transactions', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  delta: int('delta').notNull(),
  type: text('type').notNull(),
  refId: text('ref_id'),
  createdAt: int('created_at').notNull(),
});

export const ownedTemplates = mysqlTable('owned_templates', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  templateId: text('template_id').notNull(),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  unlockedAt: int('unlocked_at').notNull(),
});

export const templatePrices = mysqlTable('template_prices', {
  templateId: text('template_id').primaryKey(),
  priceCredits: int('price_credits').notNull(),
  isActive: int('is_active').notNull().default(1),
  updatedAt: int('updated_at').notNull(),
});

export const dailySignInRecords = mysqlTable('daily_sign_in_records', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  signInDate: int('sign_in_date').notNull(),
  dayIndex: int('day_index').notNull(),
  pointsEarned: int('points_earned').notNull(),
  createdAt: int('created_at').notNull(),
});

// 通用积分事件发放记录（每日首拍/完成挑战等新途径，幂等去重）
// UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分
export const pointEarnEvents = mysqlTable('point_earn_events', {
  id: int('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  type: text('type').notNull(),
  refId: text('ref_id').notNull(),
  points: int('points').notNull(),
  createdAt: int('created_at').notNull(),
}, (table) => ({
  uniqueEvent: uniqueIndex('uq_point_earn_event').on(table.deviceId, table.type, table.refId),
}));

// ===== 后台动态模板上传（spec 2026-08-05 第 2.1 节）=====

// 分类管理：三级树形（type/style/method），key + parent_key 联合唯一
export const templateCategories = mysqlTable('template_categories', {
  id: int('id').primaryKey({ autoIncrement: true }),
  key: text('key').notNull(),
  name: text('name').notNull(),
  iconUrl: text('icon_url').notNull(),
  parentKey: text('parent_key'),
  level: int('level').notNull().default(1),
  sortOrder: int('sort_order').notNull().default(0),
  isSystem: int('is_system').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
}, (table) => ({
  keyParentIdx: uniqueIndex('uq_category_key_parent').on(table.key, table.parentKey),
}));

// 后端动态模板内容（结构化存储，5 段内容 JSON 列）
export const templates = mysqlTable('templates', {
  id: text('id').primaryKey(),
  name: text('name').notNull(),
  author: text('author').notNull().default('Lumira'),
  version: text('version').notNull().default('1.0.0'),
  category: text('category').notNull(),
  price: int('price').notNull().default(0),
  coverUrl: text('cover_url').notNull(),
  description: text('description').notNull().default(''),
  referenceSource: text('reference_source').notNull().default(''),
  tagsJson: text('tags_json').notNull().default('[]'),
  tagIdsJson: text('tag_ids_json').notNull().default('[]'),
  classificationJson: text('classification_json').notNull().default('{}'),
  sortOrder: int('sort_order').notNull().default(0),
  isActive: int('is_active').notNull().default(1),
  compositionJson: longtext('composition_json').notNull().default('{}'),
  poseJson: longtext('pose_json').notNull().default('{}'),
  cameraJson: longtext('camera_json').notNull().default('{}'),
  sceneGuideJson: longtext('scene_guide_json').notNull().default('{}'),
  postProcessJson: longtext('post_process_json').notNull().default('{}'),
  createdAt: int('created_at').notNull(),
  updatedAt: int('updated_at').notNull(),
});
```

> 注：`text` 在 mysql-core 中默认映射 `TEXT`，无法给 `unique` 主键列设置长度，但 MySQL TEXT 不能作为 PRIMARY KEY —— 迁移文件（Task 2）中主键列将用 `VARCHAR(...)` 定义（见 Task 2 说明）。Drizzle schema 层 `text()` 仍可标主键（运行时按迁移文件的真实 DDL 建表），两者需在 Task 2 保持一致（主键/唯一索引列用 VARCHAR，其余用 TEXT/LONGTEXT）。

- [ ] **Step 3: 重写 database.service.ts**

将整个文件替换为以下内容（版本化迁移执行器 + mysql2 连接池）：

```ts
// lumira-server/packages/backend/src/database/database.service.ts

import { Injectable, OnModuleInit } from '@nestjs/common';
import { createPool, Pool } from 'mysql2/promise';
import { drizzle, MySql2Database } from 'drizzle-orm/mysql2';
import * as fs from 'fs';
import * as path from 'path';
import * as schema from './schema';

@Injectable()
export class DatabaseService implements OnModuleInit {
  private pool!: Pool;
  private db!: MySql2Database<typeof schema>;

  onModuleInit() {
    const host = process.env.DB_HOST || '127.0.0.1';
    const port = parseInt(process.env.DB_PORT || '3306', 10);
    const user = process.env.DB_USER || 'root';
    const password = process.env.DB_PASSWORD || 'root';
    const database = process.env.DB_NAME || 'lumira';

    this.pool = createPool({
      host,
      port,
      user,
      password,
      database,
      waitForConnections: true,
      connectionLimit: 10,
      // 迁移文件含多条语句，需开启 multipleStatements
      multipleStatements: true,
    });

    this.db = drizzle(this.pool, { schema, mode: 'default' });

    this.runMigrations();
  }

  /**
   * 版本化迁移执行器：
   * 建 _migrations 表记录已执行的文件名，仅执行未记录的迁移，保证幂等。
   * 目录解析同原 SQLite 版（prod 走 dist，dev 走 src）。
   */
  private async runMigrations() {
    const candidates = [
      path.join(__dirname, 'migrations'),
      path.join(__dirname, '..', '..', 'src', 'database', 'migrations'),
    ];
    const migrationsDir = candidates.find((p) => fs.existsSync(p));
    if (!migrationsDir) {
      throw new Error(`Migrations directory not found. Tried: ${candidates.join(', ')}`);
    }

    const [conn] = await this.pool.getConnection();

    try {
      await conn.query(
        'CREATE TABLE IF NOT EXISTS _migrations (`name` VARCHAR(255) PRIMARY KEY, `applied_at` INT NOT NULL)',
      );
      const [rows] = await conn.query('SELECT `name` FROM _migrations');
      const applied = new Set((rows as Array<{ name: string }>).map((r) => r.name));

      const files = fs.readdirSync(migrationsDir)
        .filter((f) => f.endsWith('.sql'))
        .sort();

      for (const file of files) {
        if (applied.has(file)) continue;
        const sql = fs.readFileSync(path.join(migrationsDir, file), 'utf-8');
        // 逐条执行并记录，迁移中途失败时该文件不会被标记，重启后重试
        await conn.query(sql);
        await conn.query('INSERT INTO _migrations (`name`, `applied_at`) VALUES (?, ?)', [
          file,
          Math.floor(Date.now() / 1000),
        ]);
        console.log(`[migrate] applied ${file}`);
      }
    } finally {
      conn.release();
    }
  }

  getDb(): MySql2Database<typeof schema> {
    return this.db;
  }
}
```

> 说明：`getRawDb()`（返回 better-sqlite3 原始连接）已无使用方，随重写一并移除。`onModuleInit` 改为 async（内部 await 迁移）。

- [ ] **Step 4: 全仓库刷新依赖并 typecheck（验证编译通过）**

Run:
```bash
cd lumira-server && pnpm install
```
Expected: 安装成功，node_modules 中出现 mysql2，better-sqlite3 移除。

Run:
```bash
cd lumira-server && pnpm --filter @lumira/shared build && pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 编译通过（此时 Task 2/3 尚未做，`schema.ts` 已是 mysql-core，若服务层仍引用 SQLite 同步 API 会报类型错误——这是预期中的中间态，**允许失败**，只要失败信息只来自服务层的 `.all()/.run()` 相关调用即可；若连 schema/database.service 都报错则需修复后继续）。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/package.json lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/database/database.service.ts lumira-server/pnpm-lock.yaml
git commit -m "refactor(backend): 数据库驱动切换为 mysql2 + mysql-core schema + 版本化迁移执行器"
```

---

### Task 2: 迁移 SQL 重写为 MySQL 语法

**Files:**
- Rewrite: `lumira-server/packages/backend/src/database/migrations/001_init.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/002_points.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/003_templates.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/004_user_profiles.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/005_category_hierarchy.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/006_fix_category_duplicates.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/007_redeem_batch_rewards.sql`
- Rewrite: `lumira-server/packages/backend/src/database/migrations/008_point_earn_events.sql`
- Delete: `lumira-server/packages/backend/src/database/migrations/009_device_info.sql`

**Interfaces:**
- Consumes: Task 1 的版本化迁移执行器（按文件名排序执行、`_migrations` 去重、`multipleStatements` 开启）
- Produces: 与 Task 1 `schema.ts` 对齐的 MySQL DDL；Task 3 服务层查询所依赖的真实表结构

- [ ] **Step 1: 重写 001_init.sql**

```sql
-- lumira-server/packages/backend/src/database/migrations/001_init.sql

CREATE TABLE IF NOT EXISTS devices (
  device_id     VARCHAR(64) PRIMARY KEY,
  alias         VARCHAR(255),
  platform      VARCHAR(64),
  os_version    VARCHAR(64),
  device_model  VARCHAR(128),
  app_version   VARCHAR(64),
  first_seen_at INT NOT NULL,
  last_seen_at  INT NOT NULL,
  ip_region     VARCHAR(255)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invite_records (
  id                INT AUTO_INCREMENT PRIMARY KEY,
  inviter_device_id VARCHAR(64) NOT NULL,
  invitee_device_id VARCHAR(64) NOT NULL UNIQUE,
  invite_code       VARCHAR(64) NOT NULL,
  channel           VARCHAR(32) NOT NULL DEFAULT 'direct',
  activated_at      INT NOT NULL,
  inviter_ip        VARCHAR(64),
  invitee_ip        VARCHAR(64),
  CONSTRAINT fk_invite_inviter FOREIGN KEY (inviter_device_id) REFERENCES devices(device_id),
  CONSTRAINT fk_invite_invitee FOREIGN KEY (invitee_device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_invite_records_inviter ON invite_records(inviter_device_id);
CREATE INDEX idx_invite_records_code ON invite_records(invite_code);

CREATE TABLE IF NOT EXISTS reward_tiers (
  tier             INT PRIMARY KEY,
  required_invites INT NOT NULL,
  rewards_json     TEXT NOT NULL,
  is_active        INT NOT NULL DEFAULT 1
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reward_unlocks (
  id              INT AUTO_INCREMENT PRIMARY KEY,
  device_id       VARCHAR(64) NOT NULL,
  tier            INT NOT NULL,
  source          VARCHAR(64) NOT NULL,
  source_detail   VARCHAR(255),
  status          VARCHAR(32) NOT NULL DEFAULT 'unlocked',
  unlocked_at     INT NOT NULL,
  claimed_at      INT,
  CONSTRAINT fk_reward_unlock_device FOREIGN KEY (device_id) REFERENCES devices(device_id),
  CONSTRAINT fk_reward_unlock_tier FOREIGN KEY (tier) REFERENCES reward_tiers(tier)
) ENGINE=InnoDB;
CREATE INDEX idx_reward_unlocks_device ON reward_unlocks(device_id);

CREATE TABLE IF NOT EXISTS redemption_code_batches (
  batch_id          INT AUTO_INCREMENT PRIMARY KEY,
  campaign_name     VARCHAR(255) NOT NULL,
  max_uses_per_code INT NOT NULL DEFAULT 1,
  total_generated   INT NOT NULL,
  total_used        INT NOT NULL DEFAULT 0,
  reward_points     INT NOT NULL DEFAULT 0,
  reward_templates  TEXT NOT NULL,
  valid_from        INT,
  valid_until       INT,
  is_active         INT NOT NULL DEFAULT 1,
  created_at        INT NOT NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS redemption_codes (
  code       VARCHAR(64) PRIMARY KEY,
  batch_id   INT NOT NULL,
  used_count INT NOT NULL DEFAULT 0,
  max_uses   INT NOT NULL DEFAULT 1,
  CONSTRAINT fk_redemption_codes_batch FOREIGN KEY (batch_id) REFERENCES redemption_code_batches(batch_id)
) ENGINE=InnoDB;
CREATE INDEX idx_redemption_codes_batch ON redemption_codes(batch_id);

CREATE TABLE IF NOT EXISTS redemption_records (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  code        VARCHAR(64) NOT NULL,
  device_id   VARCHAR(64) NOT NULL,
  redeemed_at INT NOT NULL,
  ip_address  VARCHAR(64),
  CONSTRAINT fk_redemption_records_code FOREIGN KEY (code) REFERENCES redemption_codes(code),
  CONSTRAINT fk_redemption_records_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_redemption_records_code ON redemption_records(code);
CREATE INDEX idx_redemption_records_device ON redemption_records(device_id);

-- 默认奖励阶梯配置（INSERT IGNORE 幂等）
INSERT IGNORE INTO reward_tiers (tier, required_invites, rewards_json, is_active) VALUES
  (1, 1, '[{"type":"template","id":"jp-film","label":"日系胶片模板"}]', 1),
  (2, 3, '[{"type":"template_pack","id":"french-retro","label":"法式复古模板包(含3个模板)"}]', 1),
  (3, 5, '[{"type":"template_pack","id":"ambience-portrait","label":"氛围感写真模板包(含5个模板)"}]', 1),
  (4, 10, '[{"type":"achievement","id":"share-master","label":"分享达人成就"}]', 1);

CREATE TABLE IF NOT EXISTS questionnaire_records (
  id           INT AUTO_INCREMENT PRIMARY KEY,
  device_id    VARCHAR(64) NOT NULL,
  answers_json LONGTEXT NOT NULL,
  submitted_at INT NOT NULL,
  client_ip    VARCHAR(64)
) ENGINE=InnoDB;
CREATE INDEX idx_questionnaire_records_device ON questionnaire_records(device_id);
CREATE INDEX idx_questionnaire_records_submitted ON questionnaire_records(submitted_at DESC);
```

> 与旧版差异：devices 表直接包含 platform/os_version/device_model/app_version 列（原 009 迁移的内容并入 001，009 文件删除）；外键用命名约束 `fk_*`；主键/外键文本列用 `VARCHAR`（MySQL TEXT 不能作主键）；`reward_templates` 默认值改为无默认（由服务层始终写入 JSON 字符串）；其余语义与旧 001 一致。

- [ ] **Step 2: 重写 002_points.sql**

```sql
-- lumira-server/packages/backend/src/database/migrations/002_points.sql
-- 积分体系：用户积分账户、流水、已拥有模板、模板定价、签到记录

-- 1. 用户积分账户
CREATE TABLE IF NOT EXISTS user_points (
  device_id    VARCHAR(64) PRIMARY KEY,
  balance      INT NOT NULL DEFAULT 0,
  total_earned INT NOT NULL DEFAULT 0,
  total_spent  INT NOT NULL DEFAULT 0,
  updated_at   INT NOT NULL,
  CONSTRAINT fk_user_points_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;

-- 2. 积分流水
CREATE TABLE IF NOT EXISTS point_transactions (
  id         INT AUTO_INCREMENT PRIMARY KEY,
  device_id  VARCHAR(64) NOT NULL,
  delta      INT NOT NULL,
  type       VARCHAR(64) NOT NULL,
  ref_id     VARCHAR(255),
  created_at INT NOT NULL,
  CONSTRAINT fk_point_tx_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_point_transactions_device ON point_transactions(device_id, created_at DESC);

-- 3. 用户已拥有模板（唯一约束：同设备同模板只记一次）
CREATE TABLE IF NOT EXISTS owned_templates (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(64) NOT NULL,
  template_id   VARCHAR(64) NOT NULL,
  source        VARCHAR(32) NOT NULL,
  source_detail VARCHAR(255),
  unlocked_at   INT NOT NULL,
  UNIQUE (device_id, template_id),
  CONSTRAINT fk_owned_templates_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_owned_templates_device ON owned_templates(device_id);

-- 4. 模板积分定价
CREATE TABLE IF NOT EXISTS template_prices (
  template_id   VARCHAR(64) PRIMARY KEY,
  price_credits INT NOT NULL,
  is_active     INT NOT NULL DEFAULT 1,
  updated_at    INT NOT NULL
) ENGINE=InnoDB;

-- 5. 每日签到记录
CREATE TABLE IF NOT EXISTS daily_sign_in_records (
  id            INT AUTO_INCREMENT PRIMARY KEY,
  device_id     VARCHAR(64) NOT NULL,
  sign_in_date  INT NOT NULL,
  day_index     INT NOT NULL,
  points_earned INT NOT NULL,
  created_at    INT NOT NULL,
  UNIQUE (device_id, sign_in_date),
  CONSTRAINT fk_daily_sign_in_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_daily_sign_in_device ON daily_sign_in_records(device_id, sign_in_date DESC);

-- 6. 种子：13 个付费模板的积分定价（每个 100 积分）
INSERT IGNORE INTO template_prices (template_id, price_credits, is_active, updated_at) VALUES
  ('film_vintage',             100, 1, 0),
  ('macro_flower',             100, 1, 0),
  ('neon_portrait',            100, 1, 0),
  ('urban_architecture',       100, 1, 0),
  ('french_lazy_portrait',     100, 1, 0),
  ('morandi_minimal_portrait', 100, 1, 0),
  ('dark_indoor_portrait',     100, 1, 0),
  ('neon_city_portrait',       100, 1, 0),
  ('y2k_portrait',             100, 1, 0),
  ('anime_dream_portrait',     100, 1, 0),
  ('blue_night_portrait',      100, 1, 0),
  ('purple_dusk_portrait',     100, 1, 0),
  ('elegant_lady_portrait',    100, 1, 0);
```

- [ ] **Step 3: 重写 003_templates.sql**

```sql
-- lumira-server/packages/backend/src/database/migrations/003_templates.sql
-- 后台动态模板上传功能（spec 2026-08-05 第 2.2 节）
-- 幂等由版本化迁移执行器保证（_migrations 表只执行一次）

-- 1. 模板分类表（三级树形：type/style/method，key + parent_key 联合唯一）
CREATE TABLE IF NOT EXISTS template_categories (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  `key`       VARCHAR(64) NOT NULL,
  name        VARCHAR(64) NOT NULL,
  icon_url    VARCHAR(512) NOT NULL,
  parent_key  VARCHAR(64),
  level       INT NOT NULL DEFAULT 1,
  sort_order  INT NOT NULL DEFAULT 0,
  is_system   INT NOT NULL DEFAULT 0,
  is_active   INT NOT NULL DEFAULT 1,
  created_at  INT NOT NULL,
  updated_at  INT NOT NULL,
  UNIQUE KEY uq_category_key_parent (`key`, parent_key)
) ENGINE=InnoDB;

-- 2. 后端动态模板内容表（5 段内容 JSON 列）
CREATE TABLE IF NOT EXISTS templates (
  id                  VARCHAR(64) PRIMARY KEY,
  name                VARCHAR(255) NOT NULL,
  author              VARCHAR(64) NOT NULL DEFAULT 'Lumira',
  version             VARCHAR(32) NOT NULL DEFAULT '1.0.0',
  category            VARCHAR(64) NOT NULL,
  price               INT NOT NULL DEFAULT 0,
  cover_url           VARCHAR(1024) NOT NULL,
  description         TEXT NOT NULL,
  reference_source    VARCHAR(512) NOT NULL DEFAULT '',
  tags_json           TEXT NOT NULL,
  tag_ids_json        TEXT NOT NULL,
  classification_json TEXT NOT NULL,
  sort_order          INT NOT NULL DEFAULT 0,
  is_active           INT NOT NULL DEFAULT 1,
  composition_json    LONGTEXT NOT NULL,
  pose_json           LONGTEXT NOT NULL,
  camera_json         LONGTEXT NOT NULL,
  scene_guide_json    LONGTEXT NOT NULL,
  post_process_json   LONGTEXT NOT NULL,
  created_at          INT NOT NULL,
  updated_at          INT NOT NULL
) ENGINE=InnoDB;
CREATE INDEX idx_templates_category ON templates(category);
CREATE INDEX idx_templates_sort_order ON templates(sort_order);

-- 3. 预置 7 个系统分类（key 与 Flutter 内置 7 类严格对齐，icon_url 空字符串表示用 Flutter 内置映射）
INSERT IGNORE INTO template_categories (`key`, name, icon_url, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('portrait',   '人像', '', 1, 1, 1, 0, 0),
  ('landscape',  '风景', '', 2, 1, 1, 0, 0),
  ('food',       '美食', '', 3, 1, 1, 0, 0),
  ('street',     '街拍', '', 4, 1, 1, 0, 0),
  ('night',      '夜景', '', 5, 1, 1, 0, 0),
  ('macro',      '微距', '', 6, 1, 1, 0, 0),
  ('still-life', '静物', '', 7, 1, 1, 0, 0);
```

> `key` 在 MySQL 中是保留字，必须用反引号 `` `key` `` 包裹（Drizzle mysql-core 生成的列名也会自动处理）。`UNIQUE KEY` 在 MySQL 8 中对 NULL 参与唯一约束：多行 `parent_key IS NULL` 允许重复（与 SQLite 行为一致），且 006 迁移将用 NULL 安全索引处理一级分类去重。

- [ ] **Step 4: 重写 004_user_profiles.sql**

```sql
-- lumira-server/packages/backend/src/database/migrations/004_user_profiles.sql
-- 用户资料表：随设备注册懒创建，首次注册由后端从昵称池/头像池随机分配

CREATE TABLE IF NOT EXISTS user_profiles (
  device_id   VARCHAR(64) PRIMARY KEY,
  username    VARCHAR(64) NOT NULL,
  avatar_seed VARCHAR(64) NOT NULL,
  updated_at  INT NOT NULL,
  CONSTRAINT fk_user_profiles_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
```

- [ ] **Step 5: 重写 005_category_hierarchy.sql**

沿用原文件全部 `INSERT OR IGNORE` 数据行，语法上做两处机械替换：
1. `INSERT OR IGNORE INTO template_categories (key, name, ...)` → `INSERT IGNORE INTO template_categories (\`key\`, name, ...)`
2. `parent_key` 取值不变（`'portrait'`、`NULL` 用具体父 key 字符串）。

完整目标文件：

```sql
-- lumira-server/packages/backend/src/database/migrations/005_category_hierarchy.sql
-- 三级分类扩展（spec 2026-08-05 第 11 节）：预置所有二级(style)/三级(method)系统分类
-- 幂等由版本化迁移执行器保证；UNIQUE(key, parent_key) 约束兜底去重

-- ===== 二级分类（style, level=2）=====

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('japanese',           '日系',       '', 'portrait', 2, 1,  1, 1, 0, 0),
  ('emotional',          '情绪',       '', 'portrait', 2, 2,  1, 1, 0, 0),
  ('film',               '胶片',       '', 'portrait', 2, 3,  1, 1, 0, 0),
  ('western',            '欧美',       '', 'portrait', 2, 4,  1, 1, 0, 0),
  ('ccd_retro',          'CCD复古',    '', 'portrait', 2, 5,  1, 1, 0, 0),
  ('hk_noir',            '港风Noir',   '', 'portrait', 2, 6,  1, 1, 0, 0),
  ('japanese_fresh',     '日系清新',   '', 'portrait', 2, 7,  1, 1, 0, 0),
  ('cream_healing',      '奶油治愈',   '', 'portrait', 2, 8,  1, 1, 0, 0),
  ('chinese_classical',  '中式古典',   '', 'portrait', 2, 9,  1, 1, 0, 0),
  ('french_lazy',        '法式慵懒',   '', 'portrait', 2, 10, 1, 1, 0, 0),
  ('morandi_minimal',    '莫兰迪极简', '', 'portrait', 2, 11, 1, 1, 0, 0),
  ('dark_indoor',        '暗调室内',   '', 'portrait', 2, 12, 1, 1, 0, 0),
  ('neon_city',          '霓虹都市',   '', 'portrait', 2, 13, 1, 1, 0, 0),
  ('fresh_green',        '清新绿意',   '', 'portrait', 2, 14, 1, 1, 0, 0),
  ('y2k',                'Y2K千禧',    '', 'portrait', 2, 15, 1, 1, 0, 0),
  ('anime_dream',        '动漫梦境',   '', 'portrait', 2, 16, 1, 1, 0, 0),
  ('blue_night',         '蓝色之夜',   '', 'portrait', 2, 17, 1, 1, 0, 0),
  ('purple_dusk',        '紫色黄昏',   '', 'portrait', 2, 18, 1, 1, 0, 0),
  ('foodie_portrait',    '美食人像',   '', 'portrait', 2, 19, 1, 1, 0, 0),
  ('sweet_girl',         '甜美少女',   '', 'portrait', 2, 20, 1, 1, 0, 0),
  ('elegant_lady',       '优雅女士',   '', 'portrait', 2, 21, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('fresh', '清新', '', 'landscape', 2, 1, 1, 1, 0, 0),
  ('epic',  '大气', '', 'landscape', 2, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('overhead', '俯拍', '', 'food', 2, 1, 1, 1, 0, 0),
  ('closeup',  '特写', '', 'food', 2, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('casual',    '随性', '', 'street', 2, 1, 1, 1, 0, 0),
  ('geometric', '几何', '', 'street', 2, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('neon',   '霓虹', '', 'night', 2, 1, 1, 1, 0, 0),
  ('starry', '星空', '', 'night', 2, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('nature', '自然', '', 'macro', 2, 1, 1, 1, 0, 0),
  ('object', '物品', '', 'macro', 2, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('minimal', '极简', '', 'still-life', 2, 1, 1, 1, 0, 0),
  ('flat',    '扁平', '', 'still-life', 2, 2, 1, 1, 0, 0);

-- ===== 三级分类（method, level=3）=====

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',    '他拍',   '', 'japanese',          3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'japanese',          3, 2, 1, 1, 0, 0),
  ('overhead',  '俯拍',   '', 'japanese',          3, 3, 1, 1, 0, 0),
  ('wide',      '远景',   '', 'emotional',         3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'emotional',         3, 2, 1, 1, 0, 0),
  ('normal',    '他拍',   '', 'film',              3, 1, 1, 1, 0, 0),
  ('selfie',    '自拍',   '', 'film',              3, 2, 1, 1, 0, 0),
  ('normal',    '他拍',   '', 'western',           3, 1, 1, 1, 0, 0),
  ('wide',      '远景',   '', 'western',           3, 2, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'ccd_retro',         3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'hk_noir',           3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'japanese_fresh',    3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'cream_healing',     3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'chinese_classical', 3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'french_lazy',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'morandi_minimal',   3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'dark_indoor',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'neon_city',         3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'fresh_green',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'y2k',               3, 1, 1, 1, 0, 0),
  ('full_body', '全身',   '', 'anime_dream',       3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'blue_night',        3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'purple_dusk',       3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'foodie_portrait',   3, 1, 1, 1, 0, 0),
  ('half_body', '半身',   '', 'sweet_girl',        3, 1, 1, 1, 0, 0),
  ('seven_body','七分身', '', 'elegant_lady',      3, 1, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('wide',     '远景', '', 'fresh', 3, 1, 1, 1, 0, 0),
  ('flat',     '平拍', '', 'fresh', 3, 2, 1, 1, 0, 0),
  ('wide',     '远景', '', 'epic',  3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'epic',  3, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('flat',     '平拍', '', 'overhead', 3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'overhead', 3, 2, 1, 1, 0, 0),
  ('macro',    '微距', '', 'closeup',  3, 1, 1, 1, 0, 0),
  ('detail',   '细节', '', 'closeup',  3, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',   '随拍', '', 'casual',    3, 1, 1, 1, 0, 0),
  ('wide',     '远景', '', 'casual',    3, 2, 1, 1, 0, 0),
  ('wide',     '远景', '', 'geometric', 3, 1, 1, 1, 0, 0),
  ('overhead', '俯拍', '', 'geometric', 3, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('normal',   '他拍', '', 'neon', 3, 1, 1, 1, 0, 0),
  ('wide',     '远景', '', 'neon', 3, 2, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('macro',    '微距', '', 'nature', 3, 1, 1, 1, 0, 0);

INSERT IGNORE INTO template_categories (`key`, name, icon_url, parent_key, level, sort_order, is_system, is_active, created_at, updated_at) VALUES
  ('single',   '单品', '', 'minimal', 3, 1, 1, 1, 0, 0);
```

- [ ] **Step 6: 重写 006_fix_category_duplicates.sql**

MySQL 8 中唯一索引对 NULL 的处理与 SQLite 相同（NULL 不参与唯一性，多行 `(key, NULL)` 允许重复）。一级分类 `INSERT IGNORE` 到 `UNIQUE KEY uq_category_key_parent (key, parent_key)` 时，parent_key 为 NULL 的重复行仍会被插入。为保持「每个一级 key 仅一条」的语义，本迁移清理重复并建立 NULL 安全唯一索引：

```sql
-- lumira-server/packages/backend/src/database/migrations/006_fix_category_duplicates.sql
-- 修复一级分类重复问题（三级分类 spec 2026-08-05 第 11 节）
-- MySQL 8 唯一索引对 NULL 不生效（多行 (key, NULL) 允许重复），
-- 与旧 SQLite 行为一致，故用 NULL 安全索引 + 清理重复保证幂等。

-- 1. 清理重复的一级分类（每个 key 仅保留 id 最小的一条）
DELETE FROM template_categories
WHERE id NOT IN (
  SELECT MIN(id)
  FROM template_categories
  GROUP BY `key`, IFNULL(parent_key, '')
);

-- 2. NULL 安全唯一索引（COALESCE 将 NULL 归一为 ''，使唯一约束对一级分类生效）
-- 索引列必须是等值表达式；用生成列实现 NULL→'' 归一
ALTER TABLE template_categories
  ADD COLUMN IF NOT EXISTS parent_key_norm VARCHAR(64)
  GENERATED ALWAYS AS (COALESCE(parent_key, '')) STORED;

CREATE UNIQUE INDEX uq_category_key_parent_null_safe
  ON template_categories (`key`, parent_key_norm);
```

> MySQL 8.0.13+ 支持 `ADD COLUMN IF NOT EXISTS`。若部署 MySQL 版本低于 8.0.13，改为在 003 建表时直接加入生成列并在 006 仅建唯一索引；本计划以 `mysql:8`（当前最新 8.x，含 8.0.13+）为准。

- [ ] **Step 7: 重写 007 与 008，删除 009**

007 内容（保留说明性注释，无重复 SQL；新库 001 已含所需列）：

```sql
-- 迁移 007：兑换码批次移除 reward_tier 依赖，增加 reward_templates 列
-- 注：新库由 001_init.sql 直接定义含 reward_templates 的表（不含 reward_tier）
-- 本迁移无重复 SQL；旧库的 ALTER 逻辑已由 SQLite 兼容代码承载（随 SQLite 迁移一并移除）
```

008 内容：

```sql
-- lumira-server/packages/backend/src/database/migrations/008_point_earn_events.sql
-- 通用积分事件发放记录（每日首拍 / 完成挑战等新增获取途径）
-- UNIQUE(device_id, type, ref_id) 保证同一设备同一事件只发一次积分（幂等）

CREATE TABLE IF NOT EXISTS point_earn_events (
  id          INT AUTO_INCREMENT PRIMARY KEY,
  device_id   VARCHAR(64) NOT NULL,
  type        VARCHAR(64) NOT NULL,
  ref_id      VARCHAR(255) NOT NULL,
  points      INT NOT NULL,
  created_at  INT NOT NULL,
  UNIQUE (device_id, type, ref_id),
  CONSTRAINT fk_point_earn_events_device FOREIGN KEY (device_id) REFERENCES devices(device_id)
) ENGINE=InnoDB;
CREATE INDEX idx_point_earn_events_device ON point_earn_events(device_id, created_at DESC);
```

删除 `009_device_info.sql`（设备信息列已并入 001）。

- [ ] **Step 8: 验证迁移 SQL 可在 MySQL 上执行（可选，若本机无 MySQL 则跳过，改由 Task 4 的 CI/e2e 验证）**

Run:
```bash
docker run --rm -d --name lumira-mysql-local -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=lumira -p 3306:3306 mysql:8
```
等待容器 healthy 后，按序把 001-008 的 SQL 用 `docker exec -i lumira-mysql-local mysql -uroot -proot lumira` 灌入验证无语法错误。验证后删除容器：
```bash
docker rm -f lumira-mysql-local
```
Expected: 各文件执行无报错，`SHOW TABLES` 能看到全部表，且分类种子数据各 7/27+7 条不重复。

- [ ] **Step 9: Commit**

```bash
git add lumira-server/packages/backend/src/database/migrations/
git commit -m "refactor(backend): 迁移 SQL 重写为 MySQL 语法，devices 合并设备信息列"
```

---

### Task 3: 服务层同步 API 改造为异步

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/points/points.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/redeem/redeem.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/admin/admin.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/templates.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/sign-in/sign-in.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-categories.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/templates/admin-templates.service.ts`

**Interfaces:**
- Consumes: Task 1 的 `getDb()` 返回 `MySql2Database`（异步事务/查询）
- Produces: 保持各 Service 公开方法签名与返回结构不变（仅内部实现异步化），下游 controller / 调用方无感知

改造规则（对下列每个文件逐一应用）：
1. 所有 `db.transaction((tx) => { ... })` → `await db.transaction(async (tx) => { ... })`，事务内同步调用补 `await`；
2. `tx.select()...all()` → `await tx.select()...execute()`；
3. `tx.insert(...).values(...).run()` → `await tx.insert(...).values(...)`（execute 可省略，await 即执行）；
4. `tx.update(...).set(...).where(...).run()` → `await tx.update(...).set(...).where(...)`；
5. `tx.delete(...).where(...).run()` → `await tx.delete(...).where(...)`；
6. 事务外 `await db.insert(...).run()` → `await db.insert(...)`（去掉 `.run()`）；
7. `spendPointsSync` 由同步改 async（返回 `Promise<number>`），其内部 `.all()` → `await ...execute()`；调用方 `templates.service.ts` 里 `const newBalance = this.pointsService.spendPointsSync(...)` 补 `await`；
8. `BetterSQLiteTransaction` 类型引用改为 MySQL 事务类型：`import type { MySql2Transaction } from 'drizzle-orm/mysql2';`，`tx: MySql2Transaction<typeof schema, ExtractTablesWithRelations<typeof schema>>`；
9. `admin.service.ts` 的 `.returning().all()` → `.returning()`（mysql2 下返回 `Promise<{...}[]>`），`.returning()` 的 update 直接 `await ...returning()`；
10. `points.service.ts` 的 UNIQUE 冲突捕获判断：`e.message.includes('UNIQUE constraint failed')`（SQLite 文案）改为同时兼容 MySQL：`e.message.includes('Duplicate entry') || e.message.includes('ER_DUP_ENTRY')`。

逐文件具体改动点（基于当前源码）：

**points.service.ts**
- 移除 `import type { BetterSQLiteTransaction } from 'drizzle-orm/better-sqlite3';`，改 `import type { MySql2Transaction } from 'drizzle-orm/mysql2';`
- `earnPoints`：`db.transaction((tx) => {` → `await db.transaction(async (tx) => {`；块内三处 `.all()` → `await ...execute()`，四处 `.run()` 移除（`await tx.insert(...)` / `await tx.update(...)`）
- `earnEvent`：同上，`db.transaction((tx) => {` → `await db.transaction(async (tx) => {`；UNIQUE 捕获改 `e.message.includes('Duplicate entry')`
- `spendPoints`：`return db.transaction((tx) => this.spendPointsSync(tx, ...))` → `return db.transaction(async (tx) => this.spendPointsSync(tx, ...))`（内部 await 由 spendPointsSync 处理）
- `spendPointsSync`：返回类型 `number` → `Promise<number>`，签名 tx 类型改 MySql2Transaction，内部 `.all()` → `await ...execute()`、`.run()` 移除并补 await；`return existing.balance - delta;` 不变

**redeem.service.ts**
- 步骤 10-14 的 `db.transaction((tx) => {` → `await db.transaction(async (tx) => {`；块内所有 `.run()` 移除补 await；`tx.select()...all()` → `await ...execute()`；第 160 行 `.all()` → `await ...execute()`

**admin.service.ts**
- `createBatch`：`return db.transaction((tx) => {` → `return db.transaction(async (tx) => {`；`.returning().all()` → `const result = await tx.insert(...).returning();`；`tx.insert(redemptionCodes).values(codeValues).run()` → `await tx.insert(redemptionCodes).values(codeValues)`；`const batchId = result[0].batchId;` 不变
- `toggleBatch`：`.returning()` 已可用，无 `.run()`，无需改动（确认即可）

**templates.service.ts**
- `exchange`：`db.transaction((tx) => {` → `await db.transaction(async (tx) => {`；两处 `tx.select()...all()` → `await ...execute()`；`onConflictDoUpdate({...}).run()` → `await ...onConflictDoUpdate({...})`；`tx.insert(ownedTemplates)...run()` → `await tx.insert(ownedTemplates)...`；`this.pointsService.spendPointsSync(...)` → `await this.pointsService.spendPointsSync(...)`（返回值已是 Promise）
- `grantTemplate`：`await db.insert(ownedTemplates)...run()` → `await db.insert(ownedTemplates)...`（去掉 `.run()`）

**sign-in.service.ts**
- 第 112 行 `await db.insert(dailySignInRecords)...run()` → `await db.insert(dailySignInRecords)...`（去掉 `.run()`）

**admin-categories.service.ts**
- 第 142、181、238 行 `.run()` → 去掉 `.run()`（保留 await）；第 222 行 `await db.delete(templateCategories)...run()` → `await db.delete(templateCategories)...`

**admin-templates.service.ts**
- 第 274、293、417、436、453、456、475、478 行 `.run()` → 去掉 `.run()`（保留 await）

- [ ] **Step 1: 改造 points.service.ts**

按上面「逐文件具体改动点」编辑该文件。

- [ ] **Step 2: 改造 redeem.service.ts**

按上面「逐文件具体改动点」编辑该文件。

- [ ] **Step 3: 改造 admin.service.ts**

按上面「逐文件具体改动点」编辑该文件（仅 createBatch）。

- [ ] **Step 4: 改造 templates.service.ts / sign-in.service.ts / admin-categories.service.ts / admin-templates.service.ts**

按上面「逐文件具体改动点」编辑这四个文件。

- [ ] **Step 5: Typecheck 通过**

Run:
```bash
cd lumira-server && pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 无类型错误（若仍有 `.run()`/`.all()`/`BetterSQLiteTransaction` 残留会报错，逐一清除）。

- [ ] **Step 6: Commit**

```bash
git add lumira-server/packages/backend/src/modules/
git commit -m "refactor(backend): 服务层同步 SQLite API 改造为 mysql2 异步 API"
```

---

### Task 4: e2e 测试切换 MySQL

**Files:**
- Create: `lumira-server/packages/backend/test/test-db.ts`
- Modify: `lumira-server/packages/backend/test/device.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/invite.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/admin.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/templates.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/profile.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/redeem.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/test/rewards.e2e-spec.ts`
- Modify: `lumira-server/packages/backend/package.json`

**Interfaces:**
- Consumes: Task 1 `database.service.ts` 的环境变量驱动连接（`DB_HOST/DB_PORT/DB_USER/DB_PASSWORD/DB_NAME`）
- Produces: `resetTestDatabase(): Promise<void>`（在 `test/test-db.ts`），所有 e2e spec 的 `beforeAll` 调用它实现隔离

- [ ] **Step 1: 创建 test/test-db.ts**

```ts
// lumira-server/packages/backend/test/test-db.ts
import { createConnection } from 'mysql2/promise';

/**
 * 测试库隔离：DROP + CREATE 目标测试库，实现与旧版 SQLite ':memory:' 等效的每文件干净状态。
 * 连接参数与环境变量一致；测试库默认 lumira_test。
 */
export async function resetTestDatabase(): Promise<void> {
  const host = process.env.DB_HOST || '127.0.0.1';
  const port = parseInt(process.env.DB_PORT || '3306', 10);
  const user = process.env.DB_USER || 'root';
  const password = process.env.DB_PASSWORD || 'root';
  const database = process.env.DB_NAME || 'lumira_test';

  // 用 root 连接（不指定 database）重建测试库
  const conn = await createConnection({ host, port, user, password, multipleStatements: true });
  try {
    await conn.query(`DROP DATABASE IF EXISTS \`${database}\``);
    await conn.query(`CREATE DATABASE \`${database}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci`);
  } finally {
    await conn.end();
  }
}
```

> 注意：数据库名来自环境变量（测试固定 `lumira_test`），用反引号包裹即可，非用户输入，无注入风险。

- [ ] **Step 2: 修改 8 个 e2e spec 的 beforeAll**

对每个 spec，把 `process.env.DB_PATH = ':memory:';` 替换为（7 个文件的替换文本完全相同）：

```ts
import { resetTestDatabase } from './test-db';
// ...（文件内原有 import 之上新增这一行，或将调用放入 beforeAll）

beforeAll(async () => {
  process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
  process.env.DB_PORT = process.env.DB_PORT || '3306';
  process.env.DB_USER = process.env.DB_USER || 'root';
  process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
  process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
  process.env.JWT_SECRET = 'test-secret';
  // （admin.e2e-spec.ts 另有 process.env.ADMIN_TOKEN = adminToken; 保留）
  await resetTestDatabase();
  // ...原有 createTestingModule 逻辑不变
});
```

`admin.e2e-spec.ts` 保持其 `process.env.ADMIN_TOKEN = adminToken;` 行不动。

- [ ] **Step 3: 更新 test:e2e 脚本加 --runInBand**

修改 `lumira-server/packages/backend/package.json`：

```json
"test:e2e": "jest --config ./test/jest-e2e.json --runInBand"
```

> 加 `--runInBand` 保证 jest 串行执行，避免多个测试文件进程并行时互相 DROP 同一个测试库。

- [ ] **Step 4: 本地跑 e2e（需本地 MySQL，用 docker 起一个）**

Run:
```bash
docker run --rm -d --name lumira-mysql-test -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=lumira_test -p 3306:3306 mysql:8
```
等待容器 ready（`docker exec lumira-mysql-test mysqladmin ping -uroot -proot` 返回 alive）后：

Run:
```bash
cd lumira-server && pnpm --filter @lumira/backend test:e2e
```
Expected: 全部 e2e 用例通过（8 个 spec 文件）。

Run:
```bash
docker rm -f lumira-mysql-test
```
清理测试容器。

- [ ] **Step 5: Commit**

```bash
git add lumira-server/packages/backend/test/ lumira-server/packages/backend/package.json
git commit -m "test(backend): e2e 测试切换 MySQL，新增 test-db 重建测试库 + --runInBand"
```

---

### Task 5: CI 改造（backend-ci.yml 加 MySQL service）

**Files:**
- Modify: `.github/workflows/backend-ci.yml`

**Interfaces:**
- Consumes: Task 4 的测试库环境变量约定（`DB_*` + `lumira_test`）
- Produces: 服务器部署（Task 6）所需的 .env 约定（`MYSQL_*`）

- [ ] **Step 1: 在 jobs.ci 下新增 services.mysql**

修改 `.github/workflows/backend-ci.yml`，在 `runs-on` 之后、`steps` 之前插入：

```yaml
    services:
      mysql:
        image: mysql:8
        env:
          MYSQL_ROOT_PASSWORD: root
          MYSQL_DATABASE: lumira_test
        ports:
          - 3306:3306
        options: >-
          --health-cmd="mysqladmin ping -h 127.0.0.1 -uroot -proot"
          --health-interval=10s
          --health-timeout=5s
          --health-retries=10
```

- [ ] **Step 2: 在 Test 步骤注入 DB 环境变量**

修改 Test 步骤：

```yaml
      - name: Test
        working-directory: lumira-server
        env:
          DB_HOST: 127.0.0.1
          DB_PORT: 3306
          DB_USER: root
          DB_PASSWORD: root
          DB_NAME: lumira_test
        run: pnpm --filter @lumira/backend test:e2e
```

- [ ] **Step 3: 验证 workflow 语法**

Run（本地 `npx actionlint` 可用则执行，否则通过 push 后 GitHub Actions 运行结果确认）:
```bash
npx --yes actionlint .github/workflows/backend-ci.yml
```
Expected: 无语法错误（若本机无 actionlint 可跳过，由 CI 结果兜底）。

- [ ] **Step 4: Commit + 推送**

```bash
git add .github/workflows/backend-ci.yml
git commit -m "ci(backend): 后端 CI 增加 MySQL 8 service container 跑 e2e"
git push origin master
git push github master
```

---

### Task 6: 生产部署改造（docker-compose + deploy workflow + .env + Dockerfile）

**Files:**
- Modify: `deploy/docker-compose.prod.yml`
- Modify: `.github/workflows/backend-deploy.yml`
- Modify: `lumira-server/packages/backend/.env.example`
- Modify: `lumira-server/packages/backend/Dockerfile`
- Modify: `lumira-server/.gitignore`（可选，确认 data/mysql 不被忽略则加）
- Modify: `lumira-server/packages/backend/.dockerignore`（若存在 data 忽略规则）

**Interfaces:**
- Consumes: Task 1 `database.service.ts` 的 `DB_*` 环境变量；服务器 `.env`（`MYSQL_*`）
- Produces: 生产 MySQL 容器 `lumira-mysql`；后端容器通过 `DB_HOST=lumira-mysql` 连接

- [ ] **Step 1: docker-compose.prod.yml 新增 mysql 服务**

修改 `deploy/docker-compose.prod.yml`：
1. 文件头注释更新 `.env` 必填变量清单（新增 `MYSQL_ROOT_PASSWORD` / `MYSQL_DATABASE` / `MYSQL_USER` / `MYSQL_PASSWORD`）。
2. `services` 下新增 `lumira-mysql`（放在 `lumira-backend` 之前）：

```yaml
  lumira-mysql:
    image: mysql:8
    restart: always
    # 数据持久化：宿主 data/mysql 目录（首次启动自动建库，MySQL 会初始化 /var/lib/mysql）
    volumes:
      - ./data/mysql:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    # 不暴露 3306 到宿主机（仅内部网络访问，更安全）
    healthcheck:
      test: ["CMD-SHELL", "mysqladmin ping -h localhost -uroot -p$${MYSQL_ROOT_PASSWORD} --silent"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - lumira-net
```

3. `lumira-backend` 服务修改：
   - `environment` 中删除 `- DB_PATH=/app/data/lumira.db`，新增：
     ```yaml
     - DB_HOST=lumira-mysql
     - DB_PORT=3306
     - DB_USER=${MYSQL_USER}
     - DB_PASSWORD=${MYSQL_PASSWORD}
     - DB_NAME=${MYSQL_DATABASE}
     ```
   - 新增 `depends_on`：
     ```yaml
     depends_on:
       lumira-mysql:
         condition: service_healthy
     ```

> 提示：`backend-deploy.yml` 中 `docker compose build` 只需构建 backend；`up -d` 时 compose 会先启动 mysql（`depends_on: service_healthy` 保证后端等 MySQL ready 再起）。`.env` 中 `MYSQL_*` 未配置时 `docker compose` 会警告空值，后端将连不上——部署提示信息会在本任务 Step 3 补充。

- [ ] **Step 2: backend-deploy.yml 更新初始化提示与数据目录**

1. 初始化失败提示块（约 60-69 行）追加 mysql 相关 `.env` 变量说明：

```bash
              echo "::error::  cat > .env <<EOF"
              echo "::error::  JWT_SECRET=\$(openssl rand -hex 32)"
              echo "::error::  ADMIN_TOKEN=\$(openssl rand -hex 32)"
              echo "::error::  MYSQL_ROOT_PASSWORD=\$(openssl rand -hex 16)"
              echo "::error::  MYSQL_DATABASE=lumira"
              echo "::error::  MYSQL_USER=lumira"
              echo "::error::  MYSQL_PASSWORD=\$(openssl rand -hex 16)"
              echo "::error::  EOF"
```

2. `[3/5] 确保数据目录存在` 步骤改为：

```bash
            echo "==> [3/5] 确保数据目录存在"
            mkdir -p $DEPLOY_PATH/data
            mkdir -p $DEPLOY_PATH/data/mysql
```

- [ ] **Step 3: 更新 backend/.env.example**

修改 `lumira-server/packages/backend/.env.example`：

```dotenv
# 服务器端口
PORT=3000

# JWT 密钥（生产环境务必替换为随机长字符串）
JWT_SECRET=change-me-in-production-please-use-a-long-random-string

# Admin API 令牌
ADMIN_TOKEN=change-me-admin-token

# MySQL 连接配置（本地开发默认 127.0.0.1:3306 root/root，库名 lumira）
# 生产环境由 docker-compose 通过 MYSQL_* 注入，无需在本文件维护
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=root
DB_NAME=lumira

# CORS 允许的来源（运营后台域名）
CORS_ORIGIN=https://admin.lumira.app

# 文件上传根目录（@fastify/static 服务根目录，模板封面/剪影/分类图标存放于此）
# 访问路径：${BACKEND_PUBLIC_URL}/uploads/...（不含 /api/v1 前缀）
UPLOAD_DIR=./data/uploads

# 后端公开 URL（用于构造上传文件的完整可访问 URL，供 Admin/Flutter 拉取）
# 生产环境应设置为 https://api.lumira.app 等真实域名
BACKEND_PUBLIC_URL=http://localhost:3000
```

- [ ] **Step 4: 简化 Dockerfile**

修改 `lumira-server/packages/backend/Dockerfile` 的 base 阶段，移除原生编译依赖（mysql2 纯 JS，无需 gcc/python/make）：

```dockerfile
FROM node:20-alpine AS base

# 切换为阿里云 Alpine 镜像源（解决国内服务器无法访问 dl-cdn.alpinelinux.org 的问题）
RUN sed -i 's|dl-cdn.alpinelinux.org|mirrors.aliyun.com|g' /etc/apk/repositories \
    && apk add --no-cache libc6-compat

# 配置 pnpm 使用淘宝 npm 镜像加速（国内服务器拉取 npm 包更快）
RUN npm install -g pnpm@9 \
    && pnpm config set registry https://registry.npmmirror.com \
    && pnpm config set fetch-retries 5 \
    && pnpm config set fetch-retry-factor 2 \
    && pnpm config set fetch-retry-mintimeout 20000 \
    && pnpm config set fetch-timeout 120000
WORKDIR /app
```

> 若 `pnpm install --frozen-lockfile` 因移除原生依赖仍报错，再恢复 `libc6-compat`；以 CI 构建结果为准（原步骤保留 libc6-compat 以防 mysql2 的某些可选原生依赖如 `sqlstring` 需要）。

- [ ] **Step 5: 确认 .gitignore / .dockerignore 覆盖 data**

检查 `lumira-server/.gitignore`（当前含 `data/*.db`）。新增 `data/mysql/` 忽略（MySQL 数据目录不应入库）：

```
data/mysql/
```

（追加到 `lumira-server/.gitignore` 末尾。）

- [ ] **Step 6: 移除已入库的 lumira.db**

Run:
```bash
cd lumira-server/packages/backend && git rm --cached data/lumira.db
```
确认 `data/*.db` 已在 .gitignore 覆盖后，磁盘文件可保留（生产环境自行清理）。

> 注意：`git rm --cached` 仅移除 git 跟踪，保留工作区文件；若 `data/lumira.db` 未被 .gitignore 匹配到才会重新出现，故 Step 5 必须完成。

- [ ] **Step 7: Commit + 推送**

```bash
git add deploy/docker-compose.prod.yml .github/workflows/backend-deploy.yml lumira-server/packages/backend/.env.example lumira-server/packages/backend/Dockerfile lumira-server/.gitignore
git commit -m "deploy(backend): 生产环境新增 MySQL 8 容器，后端改连 MySQL，简化 Dockerfile"
git push origin master
git push github master
```

---

### Task 7: 文档与仓库规则同步

**Files:**
- Modify: `.github/DEPLOY.md`
- Modify: `AGENTS.md`

**Interfaces:**
- Consumes: Task 5/6 确定的部署与 CI 约定
- Produces: 后续维护者可遵循的部署文档

- [ ] **Step 1: 更新 DEPLOY.md**

按以下要点修改 `.github/DEPLOY.md`（沿用原有结构，逐处替换）：
1. 「后端部署架构」说明图不变；「服务器目录结构」中 `data/` 注释改为 `# 数据卷（MySQL 数据 + 上传图片持久化）`，并补充 `└── data/mysql/  # MySQL 数据目录（容器挂载，自动创建）`。
2. 「后端环境变量（在服务器 .env 中配置）」表格新增 4 行：

| `MYSQL_ROOT_PASSWORD` | MySQL root 密码（`openssl rand -hex 16` 生成） |
| `MYSQL_DATABASE` | 数据库名（如 `lumira`） |
| `MYSQL_USER` | 应用数据库用户（如 `lumira`） |
| `MYSQL_PASSWORD` | 应用数据库用户密码（`openssl rand -hex 16` 生成） |

3. 「6. 创建 .env 文件」示例更新：

```bash
cat > /opt/lumira/backend/.env <<EOF
JWT_SECRET=$(openssl rand -hex 32)
ADMIN_TOKEN=$(openssl rand -hex 32)
MYSQL_ROOT_PASSWORD=$(openssl rand -hex 16)
MYSQL_DATABASE=lumira
MYSQL_USER=lumira
MYSQL_PASSWORD=$(openssl rand -hex 16)
NGINX_NETWORK=lumira-net
BACKEND_PUBLIC_URL=https://api.your-domain.com
EOF
```

4. 「8. 首次构建并启动」步骤追加 mysql 数据目录说明：`mkdir -p data/mysql`（在已有 `mkdir -p data` 之后）。
5. 「9. 验证部署」补充：

```bash
docker compose -f docker-compose.prod.yml ps          # 确认 lumira-mysql 为 healthy
docker compose -f docker-compose.prod.yml logs lumira-mysql | tail -30   # 首次启动初始化日志
docker compose -f docker-compose.prod.yml exec lumira-backend node -e "require('http').get('http://localhost:3000/api/v1/health',(r)=>{console.log(r.statusCode);process.exit(0)})"
```

6. 「常见问题」新增一条：`Q: 后端连不上 MySQL / 迁移失败？`——检查 `docker compose ps` 中 `lumira-mysql` 是否 healthy、`.env` 的 `MYSQL_*` 是否与后端 `DB_*` 一致；首次部署时 MySQL 首次初始化需 30-60 秒，`start_period` 已覆盖。
7. 所有 `data` 相关 SQLite 描述（如「SQLite 数据库持久化」）改为 MySQL 描述。

- [ ] **Step 2: 更新 AGENTS.md**

修改 `AGENTS.md` 中后端部署相关描述：
1. 技术栈速查表：`后端 | NestJS + Fastify + Drizzle ORM + better-sqlite3` → `后端 | NestJS + Fastify + Drizzle ORM + MySQL 8 (mysql2)`
2. 服务器目录结构注释：`data/  # 数据卷（SQLite + 上传图片持久化）` → `data/  # 数据卷（MySQL 数据 + 上传图片持久化）`
3. `.github/DEPLOY.md` 引用不变。

- [ ] **Step 3: Commit + 推送**

```bash
git add .github/DEPLOY.md AGENTS.md
git commit -m "docs: 部署指南与项目规则同步 MySQL 存储改造"
git push origin master
git push github master
```

---

### Task 8: 全量验证与收尾

**Files:**
- 无新文件；仅运行验证命令

**Interfaces:**
- Consumes: Task 1-7 全部产物
- Produces: 验收结论

- [ ] **Step 1: 全仓 typecheck**

Run:
```bash
cd lumira-server && pnpm --filter @lumira/backend exec tsc --noEmit
```
Expected: 无错误。

- [ ] **Step 2: 本地 MySQL e2e 全量通过**

Run:
```bash
docker run --rm -d --name lumira-mysql-verify -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=lumira_test -p 3306:3306 mysql:8
# 等待 ready 后
cd lumira-server && pnpm --filter @lumira/backend test:e2e
docker rm -f lumira-mysql-verify
```
Expected: 8 个 e2e spec 全部通过。

- [ ] **Step 3: 清理残留引用**

Run:
```bash
grep -rn "better-sqlite3\|sqlite-core\|DB_PATH\|:memory:" lumira-server/packages/backend lumira-server/.github 2>/dev/null | grep -v node_modules | grep -v dist
```
Expected: 无输出（说明 SQLite 相关引用已全部清除；`dist/` 目录可 `rm -rf` 后重建）。

> 若仍有命中（如注释、文档），逐处清理。

- [ ] **Step 4: 最终 commit（如有残留改动）并推送**

```bash
git add -A lumira-server
git commit -m "chore(backend): 清理 SQLite 残留引用"   # 仅当有改动
git push origin master
git push github master
```

Expected: 工作区干净（`git status` 无未提交改动），后端 master 已同步到 gitee 与 github。

---

## Self-Review 结论

**Spec 覆盖：**
- 驱动/连接层（mysql2 + mysql-core + 版本化迁移）→ Task 1
- 迁移 SQL 重写（001-008 + 删 009）→ Task 2
- 服务层异步化（points/redeem/admin/templates/sign-in/categories/admin-templates）→ Task 3
- e2e 切 MySQL（test-db + 8 spec + --runInBand）→ Task 4
- CI 加 MySQL service → Task 5
- 生产部署（compose + deploy workflow + .env.example + Dockerfile + gitignore + git rm lumira.db）→ Task 6
- 文档（DEPLOY.md + AGENTS.md）→ Task 7
- 全量验证与收尾 → Task 8

**占位符检查：** 无 TBD/TODO；每个步骤含具体代码或命令。

**类型一致性：** `MySql2Database` / `MySql2Transaction` / `resetTestDatabase()` / `DB_*`、`MYSQL_*` 环境变量名在 Task 1/3/4/5/6 间保持一致；`spendPointsSync` 从同步改 async 后，Task 3 中其唯一调用方（templates.service.ts）同步补 `await`。
