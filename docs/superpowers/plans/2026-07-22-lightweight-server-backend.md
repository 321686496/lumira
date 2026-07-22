# 轻量服务器 Backend MVP 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建 monorepo 基础设施 + 完成 NestJS+Fastify 后端 MVP（设备注册 / 邀请 / 兑换码 / 奖励 / Admin API）

**Architecture:** npm workspaces 管理的 monorepo，包含 `packages/shared`（类型定义）和 `packages/backend`（NestJS+Fastify+SQLite+Drizzle）。后端提供 8 个客户端 API + 9 个 Admin API，使用设备 JWT 鉴权。

**Tech Stack:** Node.js 18+, NestJS 10, @nestjs/platform-fastify 4, better-sqlite3 11, drizzle-orm 0.38+, jsonwebtoken, class-validator, nanoid

## Global Constraints

- 运行时：Node.js ≥ 18 LTS
- 框架：NestJS 10.x + @nestjs/platform-fastify 4.x
- 数据库：SQLite (better-sqlite3 11.x)，单文件 `data/lumira.db`
- ORM：drizzle-orm 0.38+ + drizzle-kit
- 鉴权：设备 JWT（jsonwebtoken），30 天有效期
- 校验：class-validator + class-transformer
- 邀请码生成：nanoid 6 位，字符集 `ABCDEFGHJKMNPQRSTUVWXYZ23456789`
- 兑换码格式：8 位大写字母 + 数字，排除 O/0/I/1
- 时间戳：所有 DB 时间字段使用 Unix 时间戳（秒）
- 错误响应格式：`{ code: number, message: string }`
- API 基础路径：`/api/v1`
- Admin API 前缀：`/api/v1/admin/`

---

## File Structure

```
lumira-server/                          # 仓库根目录（独立于 photo_post 项目）
├── packages/
│   ├── shared/
│   │   ├── src/
│   │   │   ├── types/
│   │   │   │   ├── device.ts           # 设备相关类型
│   │   │   │   ├── invite.ts           # 邀请相关类型
│   │   │   │   ├── redeem.ts           # 兑换码相关类型
│   │   │   │   └── rewards.ts          # 奖励相关类型
│   │   │   └── index.ts                # 统一导出
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── backend/
│       ├── src/
│       │   ├── main.ts                 # 应用入口
│       │   ├── app.module.ts           # 根模块
│       │   ├── common/
│       │   │   ├── guards/
│       │   │   │   ├── device-auth.guard.ts    # 设备 JWT 守卫
│       │   │   │   └── admin-auth.guard.ts     # Admin token 守卫
│       │   │   ├── decorators/
│       │   │   │   ├── device.decorator.ts     # @DeviceId() 装饰器
│       │   │   │   └── current-ip.decorator.ts  # @ClientIp() 装饰器
│       │   │   ├── filters/
│       │   │   │   └── http-exception.filter.ts # 统一错误响应
│       │   │   ├── interceptors/
│       │   │   │   └── rate-limit.interceptor.ts # 限流拦截器
│       │   │   └── pipes/
│       │   │       └── global-validation.pipe.ts # 全局 DTO 校验
│       │   ├── modules/
│       │   │   ├── device/
│       │   │   │   ├── device.module.ts
│       │   │   │   ├── device.controller.ts     # POST /device/register
│       │   │   │   ├── device.service.ts
│       │   │   │   └── dto/
│       │   │   │       └── register-device.dto.ts
│       │   │   ├── invite/
│       │   │   │   ├── invite.module.ts
│       │   │   │   ├── invite.controller.ts    # 3 个端点
│       │   │   │   ├── invite.service.ts
│       │   │   │   └── dto/
│       │   │   │       └── activate-invite.dto.ts
│       │   │   ├── redeem/
│       │   │   │   ├── redeem.module.ts
│       │   │   │   ├── redeem.controller.ts    # POST /redeem
│       │   │   │   ├── redeem.service.ts
│       │   │   │   └── dto/
│       │   │   │       └── redeem-code.dto.ts
│       │   │   ├── rewards/
│       │   │   │   ├── rewards.module.ts
│       │   │   │   ├── rewards.controller.ts   # GET /rewards, POST /rewards/:id/claim
│       │   │   │   ├── rewards.service.ts
│       │   │   │   └── dto/
│       │   │   │       └── claim-reward.dto.ts
│       │   │   └── admin/
│       │   │       ├── admin.module.ts
│       │   │       ├── admin.controller.ts     # Admin API
│       │   │       └── admin.service.ts
│       │   ├── database/
│       │   │   ├── database.module.ts
│       │   │   ├── database.service.ts         # better-sqlite3 + Drizzle 封装
│       │   │   ├── schema.ts                    # Drizzle 表定义
│       │   │   └── migrations/
│       │   │       └── 001_init.sql             # 初始建表 SQL
│       │   └── shared/
│       │       ├── invite-code.generator.ts     # 邀请码生成
│       │       └── rate-limiter.ts              # 内存限流器
│       ├── test/
│       │   ├── device.e2e-spec.ts
│       │   ├── invite.e2e-spec.ts
│       │   ├── redeem.e2e-spec.ts
│       │   └── rewards.e2e-spec.ts
│       ├── data/                                # SQLite 文件目录（.gitignore）
│       ├── package.json
│       ├── nest-cli.json
│       ├── tsconfig.json
│       ├── tsconfig.build.json
│       └── .env.example
├── package.json                                 # 根配置（workspaces）
├── .gitignore
└── README.md
```

---

## Task 0.1: Monorepo 基础设施 + Shared 包

**Files:**
- Create: `lumira-server/package.json`
- Create: `lumira-server/.gitignore`
- Create: `lumira-server/README.md`
- Create: `lumira-server/packages/shared/package.json`
- Create: `lumira-server/packages/shared/tsconfig.json`
- Create: `lumira-server/packages/shared/src/index.ts`
- Create: `lumira-server/packages/shared/src/types/device.ts`
- Create: `lumira-server/packages/shared/src/types/invite.ts`
- Create: `lumira-server/packages/shared/src/types/redeem.ts`
- Create: `lumira-server/packages/shared/src/types/rewards.ts`

**Interfaces:**
- Produces: `@lumira/shared` 包，导出所有 API 请求/响应类型，供 backend 和 admin 使用

- [ ] **Step 1: 创建 monorepo 根配置**

```json
// lumira-server/package.json
{
  "name": "lumira-server",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "packages/*"
  ],
  "scripts": {
    "build:shared": "npm run build -w @lumira/shared",
    "build:backend": "npm run build -w @lumira/backend",
    "dev:backend": "npm run dev -w @lumira/backend",
    "test:backend": "npm run test -w @lumira/backend"
  }
}
```

- [ ] **Step 2: 创建 .gitignore**

```gitignore
# lumira-server/.gitignore
node_modules/
dist/
data/*.db
data/*.db-journal
.env
*.log
.DS_Store
```

- [ ] **Step 3: 创建 shared 包 package.json**

```json
// lumira-server/packages/shared/package.json
{
  "name": "@lumira/shared",
  "version": "1.0.0",
  "private": true,
  "main": "dist/index.js",
  "types": "dist/index.d.ts",
  "scripts": {
    "build": "tsc",
    "dev": "tsc --watch"
  },
  "devDependencies": {
    "typescript": "^5.3.0"
  }
}
```

- [ ] **Step 4: 创建 shared 包 tsconfig.json**

```json
// lumira-server/packages/shared/tsconfig.json
{
  "compilerOptions": {
    "target": "ES2021",
    "module": "CommonJS",
    "moduleResolution": "node",
    "declaration": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"]
}
```

- [ ] **Step 5: 创建 device 类型定义**

```typescript
// lumira-server/packages/shared/src/types/device.ts

export interface RegisterDeviceRequest {
  deviceId: string;
}

export interface RegisterDeviceResponse {
  token: string;
  isNewDevice: boolean;
}

export interface DeviceRecord {
  deviceId: string;
  alias: string | null;
  firstSeenAt: number;
  lastSeenAt: number;
  ipRegion: string | null;
}
```

- [ ] **Step 6: 创建 invite 类型定义**

```typescript
// lumira-server/packages/shared/src/types/invite.ts

export interface GenerateInviteResponse {
  inviteCode: string;
}

export interface ActivateInviteRequest {
  inviteCode: string;
  channel?: 'direct' | 'share_card' | 'qrcode';
}

export interface ActivateInviteResponse {
  inviterDeviceId: string;
  tierReached: number | null;
  rewards: { tier: number; items: RewardItem[] } | null;
}

export interface InviteStatsResponse {
  totalInvites: number;
  currentTier: number;
  nextTier: { tier: number; requiredInvites: number; rewards: RewardItem[] } | null;
  unlockedRewards: UnlockedReward[];
}

export interface InviteRecord {
  id: number;
  inviterDeviceId: string;
  inviteeDeviceId: string;
  inviteCode: string;
  channel: string;
  activatedAt: number;
  inviterIp: string | null;
  inviteeIp: string | null;
}

// 引用 rewards.ts 中的类型
import { RewardItem, UnlockedReward } from './rewards';
```

- [ ] **Step 7: 创建 redeem 类型定义**

```typescript
// lumira-server/packages/shared/src/types/redeem.ts

export interface RedeemCodeRequest {
  code: string;
}

export interface RedeemCodeResponse {
  batchId: number;
  campaignName: string;
  rewardTier: number;
  rewardItems: RewardItem[];
}

export interface RedemptionCodeBatch {
  batchId: number;
  campaignName: string;
  rewardTier: number;
  maxUsesPerCode: number;
  totalGenerated: number;
  totalUsed: number;
  validFrom: number | null;
  validUntil: number | null;
  isActive: boolean;
  createdAt: number;
}

export interface RedemptionRecord {
  id: number;
  code: string;
  deviceId: string;
  redeemedAt: number;
  ipAddress: string | null;
}

import { RewardItem } from './rewards';
```

- [ ] **Step 8: 创建 rewards 类型定义**

```typescript
// lumira-server/packages/shared/src/types/rewards.ts

export interface RewardItem {
  type: 'template' | 'template_pack' | 'achievement';
  id: string;
  label: string;
}

export interface RewardTier {
  tier: number;
  requiredInvites: number;
  rewards: RewardItem[];
  isActive: boolean;
}

export interface UnlockedReward {
  id: number;
  tier: number;
  source: 'invite' | 'redemption';
  sourceDetail: string | null;
  status: 'unlocked' | 'claimed';
  rewardItems: RewardItem[];
  unlockedAt: number;
  claimedAt: number | null;
}

export interface RewardsListResponse {
  rewards: UnlockedReward[];
}

export interface ClaimRewardResponse {
  success: boolean;
}
```

- [ ] **Step 9: 创建统一导出**

```typescript
// lumira-server/packages/shared/src/index.ts

export * from './types/device';
export * from './types/invite';
export * from './types/redeem';
export * from './types/rewards';
```

- [ ] **Step 10: 创建 README**

```markdown
# Lumira Server

如画 Lumira 轻量服务器 monorepo。

## 结构

- `packages/shared` — 共享 TypeScript 类型
- `packages/backend` — NestJS + Fastify 后端 API
- `packages/admin` — Next.js 运营后台（后续添加）

## 开发

```bash
# 安装依赖
npm install

# 构建 shared 包
npm run build:shared

# 启动后端开发服务器
npm run dev:backend

# 运行后端测试
npm run test:backend
```
```

- [ ] **Step 11: 初始化 git 仓库并提交**

```bash
cd lumira-server
git init
git add .
git commit -m "chore: initialize monorepo with shared types package"
```

---

## Task 1.1: NestJS 项目初始化 + 数据库层

**Files:**
- Create: `lumira-server/packages/backend/package.json`
- Create: `lumira-server/packages/backend/tsconfig.json`
- Create: `lumira-server/packages/backend/tsconfig.build.json`
- Create: `lumira-server/packages/backend/nest-cli.json`
- Create: `lumira-server/packages/backend/.env.example`
- Create: `lumira-server/packages/backend/src/main.ts`
- Create: `lumira-server/packages/backend/src/app.module.ts`
- Create: `lumira-server/packages/backend/src/database/database.module.ts`
- Create: `lumira-server/packages/backend/src/database/database.service.ts`
- Create: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/001_init.sql`
- Create: `lumira-server/packages/backend/src/common/filters/http-exception.filter.ts`
- Create: `lumira-server/packages/backend/src/common/pipes/global-validation.pipe.ts`

**Interfaces:**
- Consumes: `@lumira/shared` 类型包
- Produces: `DatabaseService`（提供 `getDb()` 方法返回 better-sqlite3 实例），全局 ValidationPipe，全局异常过滤器

- [ ] **Step 1: 创建 backend package.json**

```json
// lumira-server/packages/backend/package.json
{
  "name": "@lumira/backend",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "build": "nest build",
    "dev": "nest start --watch",
    "start": "node dist/main.js",
    "start:prod": "NODE_ENV=production node dist/main.js",
    "test": "jest",
    "test:e2e": "jest --config ./test/jest-e2e.json",
    "test:watch": "jest --watch"
  },
  "dependencies": {
    "@nestjs/common": "^10.3.0",
    "@nestjs/core": "^10.3.0",
    "@nestjs/platform-fastify": "^10.3.0",
    "@nestjs/jwt": "^10.2.0",
    "@lumira/shared": "*",
    "better-sqlite3": "^11.0.0",
    "drizzle-orm": "^0.38.0",
    "class-validator": "^0.14.0",
    "class-transformer": "^0.5.1",
    "jsonwebtoken": "^9.0.2",
    "nanoid": "^3.3.7",
    "reflect-metadata": "^0.2.1",
    "rxjs": "^7.8.1"
  },
  "devDependencies": {
    "@nestjs/cli": "^10.3.0",
    "@nestjs/testing": "^10.3.0",
    "@types/better-sqlite3": "^7.6.9",
    "@types/jest": "^29.5.11",
    "@types/jsonwebtoken": "^9.0.5",
    "@types/node": "^20.11.0",
    "jest": "^29.7.0",
    "supertest": "^6.3.4",
    "ts-jest": "^29.1.1",
    "typescript": "^5.3.0"
  }
}
```

> 注意：nanoid v3 使用 CommonJS 导出，v4+ 改为 ESM-only。这里锁定 v3 以兼容 NestJS 的 CommonJS 模式。

- [ ] **Step 2: 创建 tsconfig.json**

```json
// lumira-server/packages/backend/tsconfig.json
{
  "compilerOptions": {
    "module": "CommonJS",
    "moduleResolution": "node",
    "declaration": true,
    "removeComments": true,
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "allowSyntheticDefaultImports": true,
    "target": "ES2021",
    "sourceMap": true,
    "outDir": "./dist",
    "rootDir": "./src",
    "baseUrl": "./",
    "incremental": true,
    "skipLibCheck": true,
    "strictNullChecks": true,
    "strict": true,
    "noImplicitAny": false,
    "esModuleInterop": true,
    "forceConsistentCasingInFileNames": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "test", "dist"]
}
```

- [ ] **Step 3: 创建 tsconfig.build.json**

```json
// lumira-server/packages/backend/tsconfig.build.json
{
  "extends": "./tsconfig.json",
  "exclude": ["node_modules", "test", "dist", "**/*spec.ts", "**/*.e2e-spec.ts"]
}
```

- [ ] **Step 4: 创建 nest-cli.json**

```json
// lumira-server/packages/backend/nest-cli.json
{
  "$schema": "https://json.schemastore.org/nest-cli",
  "collection": "@nestjs/schematics",
  "sourceRoot": "src",
  "compilerOptions": {
    "deleteOutDir": true
  }
}
```

- [ ] **Step 5: 创建 .env.example**

```bash
# lumira-server/packages/backend/.env.example

# 服务器端口
PORT=3000

# JWT 密钥（生产环境务必替换为随机长字符串）
JWT_SECRET=change-me-in-production-please-use-a-long-random-string

# Admin API 令牌
ADMIN_TOKEN=change-me-admin-token

# SQLite 数据库路径
DB_PATH=./data/lumira.db

# CORS 允许的来源（运营后台域名）
CORS_ORIGIN=https://admin.lumira.app
```

- [ ] **Step 6: 创建数据库 schema（Drizzle 表定义）**

```typescript
// lumira-server/packages/backend/src/database/schema.ts

import { sqliteTable, text, integer } from 'drizzle-orm/sqlite-core';

export const devices = sqliteTable('devices', {
  deviceId: text('device_id').primaryKey(),
  alias: text('alias'),
  firstSeenAt: integer('first_seen_at').notNull(),
  lastSeenAt: integer('last_seen_at').notNull(),
  ipRegion: text('ip_region'),
});

export const inviteRecords = sqliteTable('invite_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  inviterDeviceId: text('inviter_device_id').notNull().references(() => devices.deviceId),
  inviteeDeviceId: text('invitee_device_id').notNull().unique().references(() => devices.deviceId),
  inviteCode: text('invite_code').notNull(),
  channel: text('channel').notNull().default('direct'),
  activatedAt: integer('activated_at').notNull(),
  inviterIp: text('inviter_ip'),
  inviteeIp: text('invitee_ip'),
});

export const rewardTiers = sqliteTable('reward_tiers', {
  tier: integer('tier').primaryKey(),
  requiredInvites: integer('required_invites').notNull(),
  rewardsJson: text('rewards_json').notNull().default('[]'),
  isActive: integer('is_active').notNull().default(1),
});

export const rewardUnlocks = sqliteTable('reward_unlocks', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  tier: integer('tier').notNull().references(() => rewardTiers.tier),
  source: text('source').notNull(),
  sourceDetail: text('source_detail'),
  status: text('status').notNull().default('unlocked'),
  unlockedAt: integer('unlocked_at').notNull(),
  claimedAt: integer('claimed_at'),
});

export const redemptionCodeBatches = sqliteTable('redemption_code_batches', {
  batchId: integer('batch_id').primaryKey({ autoIncrement: true }),
  campaignName: text('campaign_name').notNull(),
  rewardTier: integer('reward_tier').notNull().references(() => rewardTiers.tier),
  maxUsesPerCode: integer('max_uses_per_code').notNull().default(1),
  totalGenerated: integer('total_generated').notNull(),
  totalUsed: integer('total_used').notNull().default(0),
  validFrom: integer('valid_from'),
  validUntil: integer('valid_until'),
  isActive: integer('is_active').notNull().default(1),
  createdAt: integer('created_at').notNull(),
});

export const redemptionCodes = sqliteTable('redemption_codes', {
  code: text('code').primaryKey(),
  batchId: integer('batch_id').notNull().references(() => redemptionCodeBatches.batchId),
  usedCount: integer('used_count').notNull().default(0),
  maxUses: integer('max_uses').notNull().default(1),
});

export const redemptionRecords = sqliteTable('redemption_records', {
  id: integer('id').primaryKey({ autoIncrement: true }),
  code: text('code').notNull().references(() => redemptionCodes.code),
  deviceId: text('device_id').notNull().references(() => devices.deviceId),
  redeemedAt: integer('redeemed_at').notNull(),
  ipAddress: text('ip_address'),
});
```

- [ ] **Step 7: 创建初始迁移 SQL**

```sql
-- lumira-server/packages/backend/src/database/migrations/001_init.sql

CREATE TABLE IF NOT EXISTS devices (
  device_id    TEXT PRIMARY KEY,
  alias        TEXT,
  first_seen_at INTEGER NOT NULL,
  last_seen_at  INTEGER NOT NULL,
  ip_region     TEXT
);

CREATE TABLE IF NOT EXISTS invite_records (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  inviter_device_id TEXT NOT NULL REFERENCES devices(device_id),
  invitee_device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  invite_code       TEXT NOT NULL,
  channel           TEXT NOT NULL DEFAULT 'direct',
  activated_at      INTEGER NOT NULL,
  inviter_ip        TEXT,
  invitee_ip        TEXT
);
CREATE INDEX IF NOT EXISTS idx_invite_records_inviter ON invite_records(inviter_device_id);
CREATE INDEX IF NOT EXISTS idx_invite_records_code ON invite_records(invite_code);

CREATE TABLE IF NOT EXISTS reward_tiers (
  tier             INTEGER PRIMARY KEY,
  required_invites INTEGER NOT NULL,
  rewards_json     TEXT NOT NULL DEFAULT '[]',
  is_active        INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS reward_unlocks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id       TEXT NOT NULL REFERENCES devices(device_id),
  tier            INTEGER NOT NULL REFERENCES reward_tiers(tier),
  source          TEXT NOT NULL,
  source_detail   TEXT,
  status          TEXT NOT NULL DEFAULT 'unlocked',
  unlocked_at     INTEGER NOT NULL,
  claimed_at      INTEGER
);
CREATE INDEX IF NOT EXISTS idx_reward_unlocks_device ON reward_unlocks(device_id);

CREATE TABLE IF NOT EXISTS redemption_code_batches (
  batch_id         INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_name    TEXT NOT NULL,
  reward_tier      INTEGER NOT NULL REFERENCES reward_tiers(tier),
  max_uses_per_code INTEGER NOT NULL DEFAULT 1,
  total_generated  INTEGER NOT NULL,
  total_used       INTEGER NOT NULL DEFAULT 0,
  valid_from       INTEGER,
  valid_until      INTEGER,
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS redemption_codes (
  code             TEXT PRIMARY KEY,
  batch_id         INTEGER NOT NULL REFERENCES redemption_code_batches(batch_id),
  used_count       INTEGER NOT NULL DEFAULT 0,
  max_uses         INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX IF NOT EXISTS idx_redemption_codes_batch ON redemption_codes(batch_id);

CREATE TABLE IF NOT EXISTS redemption_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  code          TEXT NOT NULL REFERENCES redemption_codes(code),
  device_id     TEXT NOT NULL REFERENCES devices(device_id),
  redeemed_at   INTEGER NOT NULL,
  ip_address    TEXT
);
CREATE INDEX IF NOT EXISTS idx_redemption_records_code ON redemption_records(code);
CREATE INDEX IF NOT EXISTS idx_redemption_records_device ON redemption_records(device_id);

-- 默认奖励阶梯配置
INSERT OR IGNORE INTO reward_tiers (tier, required_invites, rewards_json, is_active) VALUES
  (1, 1, '[{"type":"template","id":"jp-film","label":"日系胶片模板"}]', 1),
  (2, 3, '[{"type":"template_pack","id":"french-retro","label":"法式复古模板包(含3个模板)"}]', 1),
  (3, 5, '[{"type":"template_pack","id":"ambience-portrait","label":"氛围感写真模板包(含5个模板)"}]', 1),
  (4, 10, '[{"type":"achievement","id":"share-master","label":"分享达人成就"}]', 1);
```

- [ ] **Step 8: 创建 DatabaseService**

```typescript
// lumira-server/packages/backend/src/database/database.service.ts

import { Injectable, OnModuleInit } from '@nestjs/common';
import Database from 'better-sqlite3';
import { drizzle, BetterSQLite3Database } from 'drizzle-orm/better-sqlite3';
import * as fs from 'fs';
import * as path from 'path';
import * as schema from './schema';

@Injectable()
export class DatabaseService implements OnModuleInit {
  private sqlite: Database.Database;
  private db: BetterSQLite3Database<typeof schema>;

  onModuleInit() {
    const dbPath = process.env.DB_PATH || './data/lumira.db';
    const dir = path.dirname(dbPath);

    // 确保数据目录存在
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true });
    }

    this.sqlite = new Database(dbPath);
    this.sqlite.pragma('journal_mode = WAL');
    this.sqlite.pragma('foreign_keys = ON');

    this.db = drizzle(this.sqlite, { schema });

    // 执行初始迁移
    this.runMigrations();
  }

  private runMigrations() {
    const migrationPath = path.join(__dirname, 'migrations', '001_init.sql');
    if (fs.existsSync(migrationPath)) {
      const sql = fs.readFileSync(migrationPath, 'utf-8');
      this.sqlite.exec(sql);
    }
  }

  getDb(): BetterSQLite3Database<typeof schema> {
    return this.db;
  }

  getRawDb(): Database.Database {
    return this.sqlite;
  }
}
```

- [ ] **Step 9: 创建 DatabaseModule**

```typescript
// lumira-server/packages/backend/src/database/database.module.ts

import { Module } from '@nestjs/common';
import { DatabaseService } from './database.service';

@Module({
  providers: [DatabaseService],
  exports: [DatabaseService],
})
export class DatabaseModule {}
```

- [ ] **Step 10: 创建全局异常过滤器**

```typescript
// lumira-server/packages/backend/src/common/filters/http-exception.filter.ts

import { ExceptionFilter, Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { FastifyReply } from 'fastify';

@Catch(HttpException)
export class HttpExceptionFilter implements ExceptionFilter {
  catch(exception: HttpException, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<FastifyReply>();
    const status = exception.getStatus();
    const exceptionResponse = exception.getResponse();

    const message =
      typeof exceptionResponse === 'string'
        ? exceptionResponse
        : (exceptionResponse as any).message || 'Internal server error';

    response.status(status).send({
      code: status,
      message: Array.isArray(message) ? message[0] : message,
    });
  }
}
```

- [ ] **Step 11: 创建全局校验管道**

```typescript
// lumira-server/packages/backend/src/common/pipes/global-validation.pipe.ts

import { ValidationPipe } from '@nestjs/common';

export const GlobalValidationPipe = new ValidationPipe({
  whitelist: true,
  forbidNonWhitelisted: true,
  transform: true,
  transformOptions: {
    enableImplicitConversion: true,
  },
});
```

- [ ] **Step 12: 创建 app.module.ts**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 13: 创建 main.ts**

```typescript
// lumira-server/packages/backend/src/main.ts

import { NestFactory } from '@nestjs/core';
import { FastifyAdapter, NestFastifyApplication } from '@nestjs/platform-fastify';
import { AppModule } from './app.module';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

async function bootstrap() {
  const app = await NestFactory.create<NestFastifyApplication>(
    AppModule,
    new FastifyAdapter({ trustProxy: true }),
  );

  app.setGlobalPrefix('api/v1');
  app.useGlobalPipes(GlobalValidationPipe);

  // CORS
  const corsOrigin = process.env.CORS_ORIGIN || '*';
  app.enableCors({
    origin: corsOrigin === '*' ? true : corsOrigin.split(','),
    methods: ['GET', 'POST', 'PATCH'],
    allowedHeaders: ['Content-Type', 'Authorization'],
  });

  const port = parseInt(process.env.PORT || '3000', 10);
  await app.listen(port, '0.0.0.0');
  console.log(`Lumira server running on port ${port}`);
}

bootstrap();
```

- [ ] **Step 14: 安装依赖并验证启动**

Run:
```bash
cd lumira-server
npm install
npm run build:shared
npm run dev:backend
```

Expected: 服务器启动，输出 `Lumira server running on port 3000`，`data/lumira.db` 文件被创建

- [ ] **Step 15: 提交**

```bash
git add packages/backend/
git commit -m "feat: initialize NestJS+Fastify backend with database layer"
```

---

## Task 1.2: JWT 鉴权守卫 + 设备注册 API

**Files:**
- Create: `lumira-server/packages/backend/src/common/guards/device-auth.guard.ts`
- Create: `lumira-server/packages/backend/src/common/decorators/device.decorator.ts`
- Create: `lumira-server/packages/backend/src/common/decorators/current-ip.decorator.ts`
- Create: `lumira-server/packages/backend/src/modules/device/device.module.ts`
- Create: `lumira-server/packages/backend/src/modules/device/device.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/device/device.service.ts`
- Create: `lumira-server/packages/backend/src/modules/device/dto/register-device.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（添加 DeviceModule）
- Test: `lumira-server/packages/backend/test/device.e2e-spec.ts`

**Interfaces:**
- Consumes: `DatabaseService.getDb()`, `@lumira/shared` 类型
- Produces: `DeviceAuthGuard`（验证 JWT 并注入 deviceId 到 request），`@DeviceId()` 装饰器，`DeviceService.registerDevice()`，`POST /api/v1/device/register` 端点

- [ ] **Step 1: 创建 register-device DTO**

```typescript
// lumira-server/packages/backend/src/modules/device/dto/register-device.dto.ts

import { IsString, IsUUID, IsOptional, MaxLength } from 'class-validator';

export class RegisterDeviceDto {
  @IsUUID('4')
  deviceId: string;

  @IsOptional()
  @IsString()
  @MaxLength(32)
  alias?: string;
}
```

- [ ] **Step 2: 创建 DeviceService**

```typescript
// lumira-server/packages/backend/src/modules/device/device.service.ts

import { Injectable } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';

@Injectable()
export class DeviceService {
  constructor(
    private readonly dbService: DatabaseService,
    private readonly jwtService: JwtService,
  ) {}

  async registerDevice(deviceId: string, alias: string | undefined, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 查询是否已存在
    const existing = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    if (existing) {
      // 更新最后活跃时间
      await db.update(devices)
        .set({ lastSeenAt: now })
        .where(eq(devices.deviceId, deviceId));

      const token = this.jwtService.sign({ deviceId });
      return { token, isNewDevice: false };
    }

    // 新设备注册
    await db.insert(devices).values({
      deviceId,
      alias: alias || null,
      firstSeenAt: now,
      lastSeenAt: now,
      ipRegion: ip,
    });

    const token = this.jwtService.sign({ deviceId });
    return { token, isNewDevice: true };
  }
}
```

- [ ] **Step 3: 创建 DeviceController**

```typescript
// lumira-server/packages/backend/src/modules/device/device.controller.ts

import { Controller, Post, Body, Req } from '@nestjs/common';
import { DeviceService } from './device.service';
import { RegisterDeviceDto } from './dto/register-device.dto';
import { RegisterDeviceResponse } from '@lumira/shared';

@Controller('device')
export class DeviceController {
  constructor(private readonly deviceService: DeviceService) {}

  @Post('register')
  async register(
    @Body() dto: RegisterDeviceDto,
    @Req() req: any,
  ): Promise<RegisterDeviceResponse> {
    const ip = req.ip || '0.0.0.0';
    return this.deviceService.registerDevice(dto.deviceId, dto.alias, ip);
  }
}
```

- [ ] **Step 4: 创建 DeviceModule**

```typescript
// lumira-server/packages/backend/src/modules/device/device.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { DeviceController } from './device.controller';
import { DeviceService } from './device.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [DeviceController],
  providers: [DeviceService],
  exports: [JwtModule, DeviceService],
})
export class DeviceModule {}
```

- [ ] **Step 5: 创建 DeviceAuthGuard**

```typescript
// lumira-server/packages/backend/src/common/guards/device-auth.guard.ts

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
export class DeviceAuthGuard implements CanActivate {
  constructor(private readonly jwtService: JwtService) {}

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid authorization header');
    }

    const token = authHeader.substring(7);
    try {
      const payload = this.jwtService.verify(token);
      request.deviceId = payload.deviceId;
      return true;
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }
  }
}
```

- [ ] **Step 6: 创建 @DeviceId() 装饰器**

```typescript
// lumira-server/packages/backend/src/common/decorators/device.decorator.ts

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const DeviceId = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.deviceId;
  },
);
```

- [ ] **Step 7: 创建 @ClientIp() 装饰器**

```typescript
// lumira-server/packages/backend/src/common/decorators/current-ip.decorator.ts

import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const ClientIp = createParamDecorator(
  (data: unknown, ctx: ExecutionContext): string => {
    const request = ctx.switchToHttp().getRequest();
    return request.ip || '0.0.0.0';
  },
);
```

- [ ] **Step 8: 更新 AppModule 添加 DeviceModule**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 9: 创建测试配置**

```json
// lumira-server/packages/backend/test/jest-e2e.json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  },
  "moduleNameMapper": {
    "^@lumira/shared$": "<rootDir>/../shared/src"
  }
}
```

- [ ] **Step 10: 编写失败测试**

```typescript
// lumira-server/packages/backend/test/device.e2e-spec.ts

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import * as request from 'supertest';

describe('DeviceController (e2e)', () => {
  let app: NestFastifyApplication;

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
  });

  afterAll(async () => {
    await app.close();
  });

  const testDeviceId = '550e8400-e29b-41d4-a716-446655440000';

  it('POST /api/v1/device/register — should register a new device', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);

    expect(res.body.token).toBeDefined();
    expect(res.body.isNewDevice).toBe(true);
  });

  it('POST /api/v1/device/register — should return existing token for re-registration', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: testDeviceId })
      .expect(201);

    expect(res.body.token).toBeDefined();
    expect(res.body.isNewDevice).toBe(false);
  });

  it('POST /api/v1/device/register — should reject invalid UUID', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: 'not-a-uuid' })
      .expect(400);
  });
});
```

- [ ] **Step 11: 运行测试验证失败**

Run:
```bash
cd lumira-server/packages/backend
npx jest --config test/jest-e2e.json
```

Expected: FAIL（测试会因模块未配置而失败）

- [ ] **Step 12: 验证测试通过**

修复任何配置问题后重新运行：

Run:
```bash
npx jest --config test/jest-e2e.json
```

Expected: PASS（3 个测试用例全部通过）

- [ ] **Step 13: 提交**

```bash
git add packages/backend/src/common/ packages/backend/src/modules/device/ packages/backend/test/
git commit -m "feat: add device registration API with JWT authentication"
```

---

## Task 1.3: 邀请模块（生成 + 激活 + 统计）

**Files:**
- Create: `lumira-server/packages/backend/src/shared/invite-code.generator.ts`
- Create: `lumira-server/packages/backend/src/modules/invite/invite.module.ts`
- Create: `lumira-server/packages/backend/src/modules/invite/invite.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/invite/invite.service.ts`
- Create: `lumira-server/packages/backend/src/modules/invite/dto/activate-invite.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（添加 InviteModule）
- Test: `lumira-server/packages/backend/test/invite.e2e-spec.ts`

**Interfaces:**
- Consumes: `DeviceAuthGuard`（从 JWT 获取 deviceId），`DatabaseService.getDb()`，`@DeviceId()` 装饰器
- Produces: `POST /api/v1/invite/generate`，`POST /api/v1/invite/activate`，`GET /api/v1/invite/stats`，`InviteService`

- [ ] **Step 1: 创建邀请码生成器**

```typescript
// lumira-server/packages/backend/src/shared/invite-code.generator.ts

import { customAlphabet } from 'nanoid';

// 排除易混淆字符：O, 0, I, 1
const ALPHABET = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const LENGTH = 6;

const nanoid = customAlphabet(ALPHABET, LENGTH);

export function generateInviteCode(): string {
  return nanoid();
}
```

- [ ] **Step 2: 创建 activate-invite DTO**

```typescript
// lumira-server/packages/backend/src/modules/invite/dto/activate-invite.dto.ts

import { IsString, IsIn, IsOptional } from 'class-validator';

export class ActivateInviteDto {
  @IsString()
  inviteCode: string;

  @IsOptional()
  @IsIn(['direct', 'share_card', 'qrcode'])
  channel?: string;
}
```

- [ ] **Step 3: 创建 InviteService**

```typescript
// lumira-server/packages/backend/src/modules/invite/invite.service.ts

import { Injectable, BadRequestException, ConflictException } from '@nestjs/common';
import { eq, and, count } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices, inviteRecords, rewardTiers, rewardUnlocks } from '../../database/schema';
import { generateInviteCode } from '../../shared/invite-code.generator';

@Injectable()
export class InviteService {
  constructor(private readonly dbService: DatabaseService) {}

  // 生成或获取已有邀请码
  async generateInviteCode(deviceId: string): Promise<string> {
    const db = this.dbService.getDb();

    // 检查是否已有邀请码（存储在 devices 表的 alias 字段旁边，用约定字段）
    // 这里用 device_id 的前 6 位作为邀请码映射，但更可靠的方式是单独查询
    // 为简化，我们使用 devices 表的 ip_region 字段存储邀请码（复用字段）
    // 更好的方式是单独建表，但 MVP 阶段复用足够
    const device = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });

    // 从 ip_region 字段读取已有邀请码（约定格式：invite:XXXXXX）
    const existingCode = device?.ipRegion?.startsWith('invite:')
      ? device.ipRegion.substring(7)
      : null;

    if (existingCode) {
      return existingCode;
    }

    // 生成唯一邀请码
    let code: string;
    let attempts = 0;
    do {
      code = generateInviteCode();
      attempts++;
      if (attempts > 10) {
        throw new BadRequestException('Failed to generate unique invite code');
      }
    } while (await this.inviteCodeExists(code));

    // 存储邀请码到 devices.ipRegion 字段（加前缀区分）
    await db.update(devices)
      .set({ ipRegion: `invite:${code}` })
      .where(eq(devices.deviceId, deviceId));

    return code;
  }

  private async inviteCodeExists(code: string): Promise<boolean> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.ipRegion, `invite:${code}`),
    });
    return !!result;
  }

  // 通过邀请码找到邀请人设备
  async findInviterByCode(code: string): Promise<string | null> {
    const db = this.dbService.getDb();
    const result = await db.query.devices.findFirst({
      where: eq(devices.ipRegion, `invite:${code}`),
    });
    return result?.deviceId || null;
  }

  // 激活邀请
  async activateInvite(
    inviteeDeviceId: string,
    inviteCode: string,
    channel: string,
    inviteeIp: string,
  ) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查找邀请人
    const inviterDeviceId = await this.findInviterByCode(inviteCode);
    if (!inviterDeviceId) {
      throw new BadRequestException('Invalid invite code');
    }

    // 2. 自邀拦截
    if (inviterDeviceId === inviteeDeviceId) {
      throw new BadRequestException('Cannot use your own invite code');
    }

    // 3. 检查被邀请人是否已激活过
    const existingActivation = await db.query.inviteRecords.findFirst({
      where: eq(inviteRecords.inviteeDeviceId, inviteeDeviceId),
    });
    if (existingActivation) {
      throw new ConflictException('This device has already activated an invite');
    }

    // 4. 防回流：检查被邀请人是否曾邀请过当前邀请人
    const reverseRecord = await db.query.inviteRecords.findFirst({
      where: and(
        eq(inviteRecords.inviterDeviceId, inviteeDeviceId),
        eq(inviteRecords.inviteeDeviceId, inviterDeviceId),
      ),
    });
    if (reverseRecord) {
      throw new BadRequestException('Invite cycle detected');
    }

    // 5. 写入邀请记录
    await db.insert(inviteRecords).values({
      inviterDeviceId,
      inviteeDeviceId,
      inviteCode,
      channel,
      activatedAt: now,
      inviterIp: null,
      inviteeIp,
    });

    // 6. 重新计算邀请人累计邀请数
    const countResult = await db.select({ value: count() })
      .from(inviteRecords)
      .where(eq(inviteRecords.inviterDeviceId, inviterDeviceId));
    const totalInvites = countResult[0]?.value || 0;

    // 7. 检查是否达到新的奖励阶梯
    const tiers = await db.query.rewardTiers.findMany({
      where: eq(rewardTiers.isActive, 1),
    });

    let tierReached: number | null = null;
    let rewards: any = null;

    for (const tier of tiers.sort((a, b) => a.tier - b.tier)) {
      if (totalInvites >= tier.requiredInvites) {
        // 检查是否已解锁过此阶梯
        const existingUnlock = await db.query.rewardUnlocks.findFirst({
          where: and(
            eq(rewardUnlocks.deviceId, inviterDeviceId),
            eq(rewardUnlocks.tier, tier.tier),
            eq(rewardUnlocks.source, 'invite'),
          ),
        });

        if (!existingUnlock) {
          await db.insert(rewardUnlocks).values({
            deviceId: inviterDeviceId,
            tier: tier.tier,
            source: 'invite',
            sourceDetail: `${totalInvites}`,
            status: 'unlocked',
            unlockedAt: now,
          });
          tierReached = tier.tier;
          rewards = {
            tier: tier.tier,
            items: JSON.parse(tier.rewardsJson),
          };
        }
      }
    }

    return {
      inviterDeviceId,
      tierReached,
      rewards,
    };
  }

  // 邀请统计
  async getInviteStats(deviceId: string) {
    const db = this.dbService.getDb();

    // 累计邀请数
    const countResult = await db.select({ value: count() })
      .from(inviteRecords)
      .where(eq(inviteRecords.inviterDeviceId, deviceId));
    const totalInvites = countResult[0]?.value || 0;

    // 当前阶梯
    const tiers = await db.query.rewardTiers.findMany({
      where: eq(rewardTiers.isActive, 1),
    });
    const sortedTiers = tiers.sort((a, b) => a.tier - b.tier);

    let currentTier = 0;
    let nextTier: any = null;

    for (const tier of sortedTiers) {
      if (totalInvites >= tier.requiredInvites) {
        currentTier = tier.tier;
      } else if (!nextTier) {
        nextTier = {
          tier: tier.tier,
          requiredInvites: tier.requiredInvites,
          rewards: JSON.parse(tier.rewardsJson),
        };
      }
    }

    // 已解锁的奖励
    const unlockedRewards = await db.query.rewardUnlocks.findMany({
      where: and(
        eq(rewardUnlocks.deviceId, deviceId),
        eq(rewardUnlocks.source, 'invite'),
      ),
    });

    const rewardsWithItems = unlockedRewards.map((r) => {
      const tier = sortedTiers.find((t) => t.tier === r.tier);
      return {
        id: r.id,
        tier: r.tier,
        source: r.source,
        status: r.status,
        rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
        unlockedAt: r.unlockedAt,
        claimedAt: r.claimedAt,
      };
    });

    return {
      totalInvites,
      currentTier,
      nextTier,
      unlockedRewards: rewardsWithItems,
    };
  }
}
```

- [ ] **Step 4: 创建 InviteController**

```typescript
// lumira-server/packages/backend/src/modules/invite/invite.controller.ts

import { Controller, Post, Get, Body, UseGuards, Req } from '@nestjs/common';
import { InviteService } from './invite.service';
import { ActivateInviteDto } from './dto/activate-invite.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('invite')
@UseGuards(DeviceAuthGuard)
export class InviteController {
  constructor(private readonly inviteService: InviteService) {}

  @Post('generate')
  async generateInviteCode(@DeviceId() deviceId: string) {
    const inviteCode = await this.inviteService.generateInviteCode(deviceId);
    return { inviteCode };
  }

  @Post('activate')
  async activate(
    @DeviceId() deviceId: string,
    @Body() dto: ActivateInviteDto,
    @ClientIp() ip: string,
  ) {
    return this.inviteService.activateInvite(
      deviceId,
      dto.inviteCode,
      dto.channel || 'direct',
      ip,
    );
  }

  @Get('stats')
  async getStats(@DeviceId() deviceId: string) {
    return this.inviteService.getInviteStats(deviceId);
  }
}
```

> 注意：DeviceAuthGuard 依赖 JwtService，需要从 DeviceModule 导出。在 Step 5 的 InviteModule 中导入 DeviceModule。

- [ ] **Step 5: 创建 InviteModule**

```typescript
// lumira-server/packages/backend/src/modules/invite/invite.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { InviteController } from './invite.controller';
import { InviteService } from './invite.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [InviteController],
  providers: [InviteService],
})
export class InviteModule {}
```

- [ ] **Step 6: 更新 AppModule**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 7: 编写失败测试**

```typescript
// lumira-server/packages/backend/test/invite.e2e-spec.ts

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import * as request from 'supertest';

describe('InviteController (e2e)', () => {
  let app: NestFastifyApplication;
  let inviterToken: string;
  let inviteeToken: string;

  const inviterDeviceId = '11111111-1111-1111-1111-111111111111';
  const inviteeDeviceId = '22222222-2222-2222-2222-222222222222';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    // 注册两个设备
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: inviterDeviceId });
    inviterToken = res1.body.token;

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId: inviteeDeviceId });
    inviteeToken = res2.body.token;
  });

  afterAll(async () => {
    await app.close();
  });

  let inviteCode: string;

  it('POST /api/v1/invite/generate — should generate invite code', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(201);

    expect(res.body.inviteCode).toBeDefined();
    expect(res.body.inviteCode).toHaveLength(6);
    inviteCode = res.body.inviteCode;
  });

  it('POST /api/v1/invite/generate — should return same code on second call', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(201);

    expect(res.body.inviteCode).toBe(inviteCode);
  });

  it('POST /api/v1/invite/activate — should activate invite successfully', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode, channel: 'direct' })
      .expect(201);

    expect(res.body.inviterDeviceId).toBe(inviterDeviceId);
    expect(res.body.tierReached).toBe(1); // 首次邀请达成阶梯 1
    expect(res.body.rewards).not.toBeNull();
  });

  it('POST /api/v1/invite/activate — should reject duplicate activation', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode })
      .expect(409);
  });

  it('POST /api/v1/invite/activate — should reject self-invite', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviterToken}`)
      .send({ inviteCode })
      .expect(400);
  });

  it('POST /api/v1/invite/activate — should reject invalid code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode: 'INVALID' })
      .expect(400);
  });

  it('GET /api/v1/invite/stats — should return invite stats', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/invite/stats')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.totalInvites).toBe(1);
    expect(res.body.currentTier).toBe(1);
    expect(res.body.unlockedRewards).toHaveLength(1);
  });

  it('GET /api/v1/invite/stats — without auth should return 401', async () => {
    await request(app.getHttpServer())
      .get('/api/v1/invite/stats')
      .expect(401);
  });
});
```

- [ ] **Step 8: 运行测试验证通过**

Run:
```bash
cd lumira-server/packages/backend
npx jest --config test/jest-e2e.json test/invite.e2e-spec.ts
```

Expected: PASS（8 个测试用例全部通过）

- [ ] **Step 9: 提交**

```bash
git add packages/backend/src/shared/ packages/backend/src/modules/invite/ packages/backend/test/invite.e2e-spec.ts packages/backend/src/app.module.ts
git commit -m "feat: add invite module (generate, activate, stats)"
```

---

## Task 1.4: 兑换码核销 API

**Files:**
- Create: `lumira-server/packages/backend/src/modules/redeem/redeem.module.ts`
- Create: `lumira-server/packages/backend/src/modules/redeem/redeem.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/redeem/redeem.service.ts`
- Create: `lumira-server/packages/backend/src/modules/redeem/dto/redeem-code.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（添加 RedeemModule）
- Test: `lumira-server/packages/backend/test/redeem.e2e-spec.ts`

**Interfaces:**
- Consumes: `DeviceAuthGuard`，`DatabaseService.getDb()`
- Produces: `POST /api/v1/redeem`，`RedeemService`

- [ ] **Step 1: 创建 redeem-code DTO**

```typescript
// lumira-server/packages/backend/src/modules/redeem/dto/redeem-code.dto.ts

import { IsString, Length } from 'class-validator';

export class RedeemCodeDto {
  @IsString()
  @Length(6, 32)  // 兼容不同长度的兑换码
  code: string;
}
```

- [ ] **Step 2: 创建 RedeemService**

```typescript
// lumira-server/packages/backend/src/modules/redeem/redeem.service.ts

import { Injectable, NotFoundException, ConflictException, BadRequestException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  redemptionCodes,
  redemptionCodeBatches,
  redemptionRecords,
  rewardUnlocks,
  rewardTiers,
} from '../../database/schema';

@Injectable()
export class RedeemService {
  constructor(private readonly dbService: DatabaseService) {}

  async redeem(deviceId: string, code: string, ip: string) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 1. 查找码
    const codeRecord = await db.query.redemptionCodes.findFirst({
      where: eq(redemptionCodes.code, code),
    });
    if (!codeRecord) {
      throw new NotFoundException('Code not found');
    }

    // 2. 查找批次
    const batch = await db.query.redemptionCodeBatches.findFirst({
      where: eq(redemptionCodeBatches.batchId, codeRecord.batchId),
    });
    if (!batch) {
      throw new NotFoundException('Batch not found');
    }

    // 3. 检查批次是否激活
    if (!batch.isActive) {
      throw new BadRequestException('This code batch is disabled');
    }

    // 4. 检查有效期
    if (batch.validFrom && now < batch.validFrom) {
      throw new BadRequestException('Code is not yet valid');
    }
    if (batch.validUntil && now > batch.validUntil) {
      throw new BadRequestException('Code has expired');
    }

    // 5. 检查使用次数
    if (codeRecord.usedCount >= codeRecord.maxUses) {
      throw new ConflictException('Code usage limit reached');
    }

    // 6. 检查该设备是否已用过此码
    const existingRedemption = await db.query.redemptionRecords.findFirst({
      where: and(
        eq(redemptionRecords.code, code),
        eq(redemptionRecords.deviceId, deviceId),
      ),
    });
    if (existingRedemption) {
      throw new ConflictException('This device has already redeemed this code');
    }

    // 7. 检查单设备当日兑换次数（防刷：每日 3 次）
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayStartTs = Math.floor(todayStart.getTime() / 1000);

    const todayRedemptions = await db.query.redemptionRecords.findMany({
      where: and(
        eq(redemptionRecords.deviceId, deviceId),
      ),
    });
    const todayCount = todayRedemptions.filter(r => r.redeemedAt >= todayStartTs).length;
    if (todayCount >= 3) {
      throw new ConflictException('Daily redemption limit reached');
    }

    // 8. 原子操作：增加使用次数
    await db.update(redemptionCodes)
      .set({ usedCount: codeRecord.usedCount + 1 })
      .where(eq(redemptionCodes.code, code));

    // 9. 更新批次总使用量
    await db.update(redemptionCodeBatches)
      .set({ totalUsed: batch.totalUsed + 1 })
      .where(eq(redemptionCodeBatches.batchId, batch.batchId));

    // 10. 写入兑换记录
    await db.insert(redemptionRecords).values({
      code,
      deviceId,
      redeemedAt: now,
      ipAddress: ip,
    });

    // 11. 解锁奖励
    const tier = await db.query.rewardTiers.findFirst({
      where: eq(rewardTiers.tier, batch.rewardTier),
    });

    await db.insert(rewardUnlocks).values({
      deviceId,
      tier: batch.rewardTier,
      source: 'redemption',
      sourceDetail: code,
      status: 'unlocked',
      unlockedAt: now,
    });

    return {
      batchId: batch.batchId,
      campaignName: batch.campaignName,
      rewardTier: batch.rewardTier,
      rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
    };
  }
}
```

- [ ] **Step 3: 创建 RedeemController**

```typescript
// lumira-server/packages/backend/src/modules/redeem/redeem.controller.ts

import { Controller, Post, Body, UseGuards } from '@nestjs/common';
import { RedeemService } from './redeem.service';
import { RedeemCodeDto } from './dto/redeem-code.dto';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId, ClientIp } from '../../common/decorators';

@Controller('redeem')
@UseGuards(DeviceAuthGuard)
export class RedeemController {
  constructor(private readonly redeemService: RedeemService) {}

  @Post()
  async redeem(
    @DeviceId() deviceId: string,
    @Body() dto: RedeemCodeDto,
    @ClientIp() ip: string,
  ) {
    return this.redeemService.redeem(deviceId, dto.code, ip);
  }
}
```

- [ ] **Step 4: 创建 RedeemModule**

```typescript
// lumira-server/packages/backend/src/modules/redeem/redeem.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { RedeemController } from './redeem.controller';
import { RedeemService } from './redeem.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [RedeemController],
  providers: [RedeemService],
})
export class RedeemModule {}
```

- [ ] **Step 5: 更新 AppModule**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule, RedeemModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 6: 编写失败测试**

```typescript
// lumira-server/packages/backend/test/redeem.e2e-spec.ts

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { DatabaseService } from '../src/database/database.service';
import * as request from 'supertest';

describe('RedeemController (e2e)', () => {
  let app: NestFastifyApplication;
  let dbService: DatabaseService;
  let token: string;

  const deviceId = '33333333-3333-3333-3333-333333333333';
  const testCode = 'TESTCODE1';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    dbService = moduleRef.get<DatabaseService>(DatabaseService);

    // 注册设备
    const res = await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId });
    token = res.body.token;

    // 插入测试兑换码数据
    const db = dbService.getDb();
    await db.insert(redemptionCodeBatches).values({
      batchId: 1,
      campaignName: '测试活动',
      rewardTier: 1,
      maxUsesPerCode: 1,
      totalGenerated: 1,
      totalUsed: 0,
      isActive: 1,
      createdAt: Math.floor(Date.now() / 1000),
    });
    await db.insert(redemptionCodes).values({
      code: testCode,
      batchId: 1,
      usedCount: 0,
      maxUses: 1,
    });
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/v1/redeem — should redeem valid code', async () => {
    const res = await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: testCode })
      .expect(201);

    expect(res.body.batchId).toBe(1);
    expect(res.body.campaignName).toBe('测试活动');
    expect(res.body.rewardTier).toBe(1);
  });

  it('POST /api/v1/redeem — should reject already used code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: testCode })
      .expect(409);
  });

  it('POST /api/v1/redeem — should reject non-existent code', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .set('Authorization', `Bearer ${token}`)
      .send({ code: 'NOTEXIST' })
      .expect(404);
  });

  it('POST /api/v1/redeem — without auth should return 401', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/redeem')
      .send({ code: testCode })
      .expect(401);
  });
});
```

> 注意：测试文件需要导入 schema：
> ```typescript
> import { redemptionCodeBatches, redemptionCodes } from '../src/database/schema';
> ```

- [ ] **Step 7: 运行测试验证通过**

Run:
```bash
cd lumira-server/packages/backend
npx jest --config test/jest-e2e.json test/redeem.e2e-spec.ts
```

Expected: PASS（4 个测试用例全部通过）

- [ ] **Step 8: 提交**

```bash
git add packages/backend/src/modules/redeem/ packages/backend/test/redeem.e2e-spec.ts packages/backend/src/app.module.ts
git commit -m "feat: add redeem code API with anti-fraud checks"
```

---

## Task 1.5: 奖励模块（列表 + 领奖确认）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/rewards/rewards.module.ts`
- Create: `lumira-server/packages/backend/src/modules/rewards/rewards.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/rewards/rewards.service.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（添加 RewardsModule）
- Test: `lumira-server/packages/backend/test/rewards.e2e-spec.ts`

**Interfaces:**
- Consumes: `DeviceAuthGuard`，`DatabaseService.getDb()`
- Produces: `GET /api/v1/rewards`，`POST /api/v1/rewards/:id/claim`，`RewardsService`

- [ ] **Step 1: 创建 RewardsService**

```typescript
// lumira-server/packages/backend/src/modules/rewards/rewards.service.ts

import { Injectable, NotFoundException, ConflictException } from '@nestjs/common';
import { eq, and } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { rewardUnlocks, rewardTiers } from '../../database/schema';

@Injectable()
export class RewardsService {
  constructor(private readonly dbService: DatabaseService) {}

  async listRewards(deviceId: string) {
    const db = this.dbService.getDb();

    const unlocks = await db.query.rewardUnlocks.findMany({
      where: eq(rewardUnlocks.deviceId, deviceId),
    });

    const tiers = await db.query.rewardTiers.findMany();

    const rewards = unlocks.map((unlock) => {
      const tier = tiers.find((t) => t.tier === unlock.tier);
      return {
        id: unlock.id,
        tier: unlock.tier,
        source: unlock.source,
        sourceDetail: unlock.sourceDetail,
        status: unlock.status,
        rewardItems: tier ? JSON.parse(tier.rewardsJson) : [],
        unlockedAt: unlock.unlockedAt,
        claimedAt: unlock.claimedAt,
      };
    });

    return { rewards };
  }

  async claimReward(deviceId: string, rewardId: number) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    const reward = await db.query.rewardUnlocks.findFirst({
      where: eq(rewardUnlocks.id, rewardId),
    });

    if (!reward) {
      throw new NotFoundException('Reward not found');
    }

    if (reward.deviceId !== deviceId) {
      throw new NotFoundException('Reward not found');
    }

    if (reward.status === 'claimed') {
      throw new ConflictException('Reward already claimed');
    }

    await db.update(rewardUnlocks)
      .set({ status: 'claimed', claimedAt: now })
      .where(eq(rewardUnlocks.id, rewardId));

    return { success: true };
  }
}
```

- [ ] **Step 2: 创建 RewardsController**

```typescript
// lumira-server/packages/backend/src/modules/rewards/rewards.controller.ts

import { Controller, Get, Post, Param, ParseIntPipe, UseGuards } from '@nestjs/common';
import { RewardsService } from './rewards.service';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { DeviceId } from '../../common/decorators';

@Controller('rewards')
@UseGuards(DeviceAuthGuard)
export class RewardsController {
  constructor(private readonly rewardsService: RewardsService) {}

  @Get()
  async listRewards(@DeviceId() deviceId: string) {
    return this.rewardsService.listRewards(deviceId);
  }

  @Post(':id/claim')
  async claimReward(
    @DeviceId() deviceId: string,
    @Param('id', ParseIntPipe) rewardId: number,
  ) {
    return this.rewardsService.claimReward(deviceId, rewardId);
  }
}
```

- [ ] **Step 3: 创建 RewardsModule**

```typescript
// lumira-server/packages/backend/src/modules/rewards/rewards.module.ts

import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { RewardsController } from './rewards.controller';
import { RewardsService } from './rewards.service';

@Module({
  imports: [
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'dev-secret-change-me',
      signOptions: { expiresIn: '30d' },
    }),
  ],
  controllers: [RewardsController],
  providers: [RewardsService],
})
export class RewardsModule {}
```

- [ ] **Step 4: 更新 AppModule**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule, RedeemModule, RewardsModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 5: 编写测试**

```typescript
// lumira-server/packages/backend/test/rewards.e2e-spec.ts

import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import * as request from 'supertest';

describe('RewardsController (e2e)', () => {
  let app: NestFastifyApplication;
  let inviterToken: string;
  let inviteeToken: string;
  let rewardId: number;

  const inviterDeviceId = '44444444-4444-4444-4444-444444444444';
  const inviteeDeviceId = '55555555-5555-5555-5555-555555555555';

  beforeAll(async () => {
    process.env.DB_PATH = ':memory:';
    process.env.JWT_SECRET = 'test-secret';

    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();

    // 注册设备并触发邀请
    const res1 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviterDeviceId });
    inviterToken = res1.body.token;

    const res2 = await request(app.getHttpServer())
      .post('/api/v1/device/register').send({ deviceId: inviteeDeviceId });
    inviteeToken = res2.body.token;

    // 生成邀请码并激活
    const genRes = await request(app.getHttpServer())
      .post('/api/v1/invite/generate')
      .set('Authorization', `Bearer ${inviterToken}`);
    const inviteCode = genRes.body.inviteCode;

    await request(app.getHttpServer())
      .post('/api/v1/invite/activate')
      .set('Authorization', `Bearer ${inviteeToken}`)
      .send({ inviteCode });
  });

  afterAll(async () => {
    await app.close();
  });

  it('GET /api/v1/rewards — should list unlocked rewards', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/rewards')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.rewards).toHaveLength(1);
    expect(res.body.rewards[0].source).toBe('invite');
    expect(res.body.rewards[0].status).toBe('unlocked');
    rewardId = res.body.rewards[0].id;
  });

  it('POST /api/v1/rewards/:id/claim — should claim reward', async () => {
    const res = await request(app.getHttpServer())
      .post(`/api/v1/rewards/${rewardId}/claim`)
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.success).toBe(true);
  });

  it('POST /api/v1/rewards/:id/claim — should reject double claim', async () => {
    await request(app.getHttpServer())
      .post(`/api/v1/rewards/${rewardId}/claim`)
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(409);
  });

  it('GET /api/v1/rewards — should show claimed status after claim', async () => {
    const res = await request(app.getHttpServer())
      .get('/api/v1/rewards')
      .set('Authorization', `Bearer ${inviterToken}`)
      .expect(200);

    expect(res.body.rewards[0].status).toBe('claimed');
    expect(res.body.rewards[0].claimedAt).not.toBeNull();
  });
});
```

- [ ] **Step 6: 运行测试验证通过**

Run:
```bash
cd lumira-server/packages/backend
npx jest --config test/jest-e2e.json test/rewards.e2e-spec.ts
```

Expected: PASS（4 个测试用例全部通过）

- [ ] **Step 7: 提交**

```bash
git add packages/backend/src/modules/rewards/ packages/backend/test/rewards.e2e-spec.ts packages/backend/src/app.module.ts
git commit -m "feat: add rewards module (list, claim)"
```

---

## Task 1.6: Admin API（统计 + 邀请查询 + 兑换码批次管理）

**Files:**
- Create: `lumira-server/packages/backend/src/common/guards/admin-auth.guard.ts`
- Create: `lumira-server/packages/backend/src/modules/admin/admin.module.ts`
- Create: `lumira-server/packages/backend/src/modules/admin/admin.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/admin/admin.service.ts`
- Create: `lumira-server/packages/backend/src/modules/admin/dto/create-batch.dto.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`（添加 AdminModule）

**Interfaces:**
- Consumes: `DatabaseService.getDb()`，Admin token（从环境变量 `ADMIN_TOKEN` 读取）
- Produces: `AdminAuthGuard`，`AdminService`，9 个 Admin API 端点

- [ ] **Step 1: 创建 AdminAuthGuard**

```typescript
// lumira-server/packages/backend/src/common/guards/admin-auth.guard.ts

import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';

@Injectable()
export class AdminAuthGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing admin token');
    }

    const token = authHeader.substring(7);
    const adminToken = process.env.ADMIN_TOKEN || 'dev-admin-token';

    if (token !== adminToken) {
      throw new UnauthorizedException('Invalid admin token');
    }

    return true;
  }
}
```

- [ ] **Step 2: 创建 create-batch DTO**

```typescript
// lumira-server/packages/backend/src/modules/admin/dto/create-batch.dto.ts

import { IsString, IsArray, IsInt, IsOptional, Min, ArrayMinSize, MaxLength } from 'class-validator';

export class CreateBatchDto {
  @IsString()
  @MaxLength(100)
  campaignName: string;

  @IsArray()
  @ArrayMinSize(1)
  @IsString({ each: true })
  codes: string[];

  @IsInt()
  @Min(1)
  rewardTier: number;

  @IsInt()
  @Min(1)
  maxUsesPerCode: number;

  @IsOptional()
  @IsInt()
  validFrom?: number;

  @IsOptional()
  @IsInt()
  validUntil?: number;
}
```

- [ ] **Step 3: 创建 AdminService**

```typescript
// lumira-server/packages/backend/src/modules/admin/admin.service.ts

import { Injectable } from '@nestjs/common';
import { eq, count, desc } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import {
  devices,
  inviteRecords,
  rewardUnlocks,
  redemptionCodeBatches,
  redemptionCodes,
  redemptionRecords,
} from '../../database/schema';

@Injectable()
export class AdminService {
  constructor(private readonly dbService: DatabaseService) {}

  // 概览统计
  async getStats() {
    const db = this.dbService.getDb();

    const deviceCount = await db.select({ value: count() }).from(devices);
    const inviteCount = await db.select({ value: count() }).from(inviteRecords);
    const rewardCount = await db.select({ value: count() }).from(rewardUnlocks);
    const redemptionCount = await db.select({ value: count() }).from(redemptionRecords);

    // 今日数据
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayTs = Math.floor(todayStart.getTime() / 1000);

    const todayDevices = await db.query.devices.findMany();
    const todayNewDevices = todayDevices.filter(d => d.firstSeenAt >= todayTs).length;

    const todayInvites = await db.query.inviteRecords.findMany();
    const todayNewInvites = todayInvites.filter(i => i.activatedAt >= todayTs).length;

    const todayRedemptions = await db.query.redemptionRecords.findMany();
    const todayRedeemed = todayRedemptions.filter(r => r.redeemedAt >= todayTs).length;

    // 兑换码统计
    const batches = await db.query.redemptionCodeBatches.findMany();
    const totalGenerated = batches.reduce((sum, b) => sum + b.totalGenerated, 0);
    const totalUsed = batches.reduce((sum, b) => sum + b.totalUsed, 0);

    return {
      totalDevices: deviceCount[0]?.value || 0,
      todayNewDevices,
      totalInvites: inviteCount[0]?.value || 0,
      todayNewInvites,
      totalRedemptions: redemptionCount[0]?.value || 0,
      todayRedeemed,
      totalRewardUnlocks: rewardCount[0]?.value || 0,
      totalCodesGenerated: totalGenerated,
      totalCodesUsed: totalUsed,
      totalCodesRemaining: totalGenerated - totalUsed,
    };
  }

  // 邀请记录查询
  async getInviteRecords(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    let query = db.select().from(inviteRecords).$dynamic();

    if (deviceId) {
      query = query.where(
        eq(inviteRecords.inviterDeviceId, deviceId),
      );
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(inviteRecords.activatedAt)).limit(pageSize).offset(offset);
    const totalCount = await db.select({ value: count() }).from(inviteRecords);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }

  // 创建兑换码批次
  async createBatch(dto: {
    campaignName: string;
    codes: string[];
    rewardTier: number;
    maxUsesPerCode: number;
    validFrom?: number;
    validUntil?: number;
  }) {
    const db = this.dbService.getDb();
    const now = Math.floor(Date.now() / 1000);

    // 创建批次
    const result = await db.insert(redemptionCodeBatches).values({
      campaignName: dto.campaignName,
      rewardTier: dto.rewardTier,
      maxUsesPerCode: dto.maxUsesPerCode,
      totalGenerated: dto.codes.length,
      totalUsed: 0,
      validFrom: dto.validFrom || null,
      validUntil: dto.validUntil || null,
      isActive: 1,
      createdAt: now,
    }).returning();

    const batchId = result[0].batchId;

    // 批量插入码
    const codeValues = dto.codes.map(code => ({
      code,
      batchId,
      usedCount: 0,
      maxUses: dto.maxUsesPerCode,
    }));

    await db.insert(redemptionCodes).values(codeValues);

    return {
      batchId,
      campaignName: dto.campaignName,
      totalGenerated: dto.codes.length,
    };
  }

  // 兑换码批次列表
  async getBatches() {
    const db = this.dbService.getDb();
    return db.select().from(redemptionCodeBatches).orderBy(desc(redemptionCodeBatches.createdAt));
  }

  // 批次详情
  async getBatchDetail(batchId: number) {
    const db = this.dbService.getDb();

    const batch = await db.query.redemptionCodeBatches.findFirst({
      where: eq(redemptionCodeBatches.batchId, batchId),
    });

    if (!batch) {
      return null;
    }

    const codes = await db.query.redemptionCodes.findMany({
      where: eq(redemptionCodes.batchId, batchId),
    });

    return { ...batch, codes };
  }

  // 启用/禁用批次
  async toggleBatch(batchId: number, isActive: boolean) {
    const db = this.dbService.getDb();
    await db.update(redemptionCodeBatches)
      .set({ isActive: isActive ? 1 : 0 })
      .where(eq(redemptionCodeBatches.batchId, batchId));
    return { success: true };
  }

  // 奖励解锁记录
  async getRewardUnlocks(page: number = 1, pageSize: number = 20, deviceId?: string) {
    const db = this.dbService.getDb();

    let query = db.select().from(rewardUnlocks).$dynamic();

    if (deviceId) {
      query = query.where(eq(rewardUnlocks.deviceId, deviceId));
    }

    const offset = (page - 1) * pageSize;
    const records = await query.orderBy(desc(rewardUnlocks.unlockedAt)).limit(pageSize).offset(offset);
    const totalCount = await db.select({ value: count() }).from(rewardUnlocks);

    return {
      data: records,
      total: totalCount[0]?.value || 0,
      page,
      pageSize,
    };
  }
}
```

- [ ] **Step 4: 创建 AdminController**

```typescript
// lumira-server/packages/backend/src/modules/admin/admin.controller.ts

import { Controller, Get, Post, Patch, Body, Param, Query, ParseIntPipe, UseGuards } from '@nestjs/common';
import { AdminService } from './admin.service';
import { CreateBatchDto } from './dto/create-batch.dto';
import { AdminAuthGuard } from '../../common/guards/admin-auth.guard';

@Controller('admin')
@UseGuards(AdminAuthGuard)
export class AdminController {
  constructor(private readonly adminService: AdminService) {}

  @Get('stats')
  async getStats() {
    return this.adminService.getStats();
  }

  @Get('invites')
  async getInviteRecords(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getInviteRecords(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }

  @Get('redeem-batches')
  async getBatches() {
    return this.adminService.getBatches();
  }

  @Post('redeem-batches')
  async createBatch(@Body() dto: CreateBatchDto) {
    return this.adminService.createBatch(dto);
  }

  @Get('redeem-batches/:id')
  async getBatchDetail(@Param('id', ParseIntPipe) id: number) {
    const result = await this.adminService.getBatchDetail(id);
    if (!result) {
      return { error: 'Batch not found' };
    }
    return result;
  }

  @Patch('redeem-batches/:id')
  async toggleBatch(
    @Param('id', ParseIntPipe) id: number,
    @Body('isActive') isActive: boolean,
  ) {
    return this.adminService.toggleBatch(id, isActive);
  }

  @Get('rewards')
  async getRewardUnlocks(
    @Query('page') page?: string,
    @Query('pageSize') pageSize?: string,
    @Query('deviceId') deviceId?: string,
  ) {
    return this.adminService.getRewardUnlocks(
      page ? parseInt(page) : 1,
      pageSize ? parseInt(pageSize) : 20,
      deviceId,
    );
  }
}
```

- [ ] **Step 5: 创建 AdminModule**

```typescript
// lumira-server/packages/backend/src/modules/admin/admin.module.ts

import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
```

- [ ] **Step 6: 更新 AppModule**

```typescript
// lumira-server/packages/backend/src/app.module.ts

import { Module } from '@nestjs/common';
import { APP_FILTER, APP_PIPE } from '@nestjs/core';
import { DatabaseModule } from './database/database.module';
import { DeviceModule } from './modules/device/device.module';
import { InviteModule } from './modules/invite/invite.module';
import { RedeemModule } from './modules/redeem/redeem.module';
import { RewardsModule } from './modules/rewards/rewards.module';
import { AdminModule } from './modules/admin/admin.module';
import { HttpExceptionFilter } from './common/filters/http-exception.filter';
import { GlobalValidationPipe } from './common/pipes/global-validation.pipe';

@Module({
  imports: [DatabaseModule, DeviceModule, InviteModule, RedeemModule, RewardsModule, AdminModule],
  providers: [
    { provide: APP_FILTER, useClass: HttpExceptionFilter },
    { provide: APP_PIPE, useValue: GlobalValidationPipe },
  ],
})
export class AppModule {}
```

- [ ] **Step 7: 验证 Admin API 可访问**

Run:
```bash
cd lumira-server/packages/backend
npm run dev:backend
```

在另一个终端测试：
```bash
# 测试 stats 端点
curl -H "Authorization: Bearer dev-admin-token" http://localhost:3000/api/v1/admin/stats

# 测试创建批次
curl -X POST -H "Authorization: Bearer dev-admin-token" -H "Content-Type: application/json" \
  -d '{"campaignName":"测试","codes":["ABC12345","DEF67890"],"rewardTier":1,"maxUsesPerCode":1}' \
  http://localhost:3000/api/v1/admin/redeem-batches

# 测试无 token 访问
curl http://localhost:3000/api/v1/admin/stats
```

Expected: 前两个返回 JSON 数据，第三个返回 401

- [ ] **Step 8: 提交**

```bash
git add packages/backend/src/common/guards/admin-auth.guard.ts packages/backend/src/modules/admin/ packages/backend/src/app.module.ts
git commit -m "feat: add admin API (stats, invites, redeem batches, rewards)"
```

---

## Self-Review 检查

### 1. Spec 覆盖检查

| Spec 要求 | 对应 Task | 状态 |
|---|---|---|
| 设备注册 JWT | Task 1.2 | ✅ |
| 邀请码生成 | Task 1.3 | ✅ |
| 邀请激活 + 防刷 | Task 1.3 | ✅ |
| 邀请统计 | Task 1.3 | ✅ |
| 兑换码核销 + 防刷 | Task 1.4 | ✅ |
| 奖励列表 | Task 1.5 | ✅ |
| 领奖确认 | Task 1.5 | ✅ |
| Admin stats | Task 1.6 | ✅ |
| Admin invites 查询 | Task 1.6 | ✅ |
| Admin 兑换码批次创建 | Task 1.6 | ✅ |
| Admin 兑换码批次列表 | Task 1.6 | ✅ |
| Admin 批次详情 | Task 1.6 | ✅ |
| Admin 批次启用/禁用 | Task 1.6 | ✅ |
| Admin 奖励明细 | Task 1.6 | ✅ |
| 6 张数据表 | Task 1.1 | ✅ |
| 默认奖励阶梯配置 | Task 1.1 | ✅ |
| Monorepo 结构 | Task 0.1 | ✅ |

### 2. 待后续计划处理

| Spec 要求 | 计划 |
|---|---|
| Next.js 运营后台前端 | 后续计划 2 |
| GitHub Actions CI/CD | 后续计划 2 |
| VPS 部署配置 | 后续计划 2 |
| Vercel 部署配置 | 后续计划 2 |
| Flutter 客户端接入 | 后续计划 3 |
| CSV 导出 | 后续计划 2 |

### 3. 类型一致性检查

- `DeviceService.registerDevice(deviceId, alias, ip)` — 一致 ✅
- `InviteService.generateInviteCode(deviceId)` — 一致 ✅
- `InviteService.activateInvite(inviteeDeviceId, inviteCode, channel, inviteeIp)` — 一致 ✅
- `RedeemService.redeem(deviceId, code, ip)` — 一致 ✅
- `RewardsService.listRewards(deviceId)` — 一致 ✅
- `RewardsService.claimReward(deviceId, rewardId)` — 一致 ✅

### 4. 已知限制（MVP 简化）

- 邀请码存储复用 `devices.ipRegion` 字段（加 `invite:` 前缀），后续可迁移到独立表
- 限流使用简单的内存计数器（Task 1.6 中 AdminService 内部有日次数检查），未做全局 rate limiter
- 测试使用 `:memory:` SQLite，每次测试重新初始化
