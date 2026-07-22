# 如画 Lumira 轻量服务器设计文档

> 文档版本：v1.0
> 创建日期：2026-07-22
> 文档类型：服务器端设计规格
> 配套设计文档：`2026-07-06-lumira-v2-features-design.md`

---

## 0. 设计目标

### 0.1 解决的核心问题

| 功能 | 离线方案痛点 | 服务器方案解决 |
|---|---|---|
| 邀请好友 | ① deviceTag 可伪造刷单（密钥硬编码在 App 中，反编译即暴露）<br>② 邀请关系不可溯源（无法做渠道效果分析）<br>③ 用户需手动"二次回传"（漏斗断裂） | ① 服务端限流 + 设备指纹 + IP 去重<br>② 全链路记录 `inviter → invitee → channel → activated_at`<br>③ 新设备首次联网激活自动归因，零用户操作 |
| 兑换码 | ① 一码多设备无限使用<br>② 必须发版才能更新码库（运营周期 1-2 周）<br>③ 依赖客户端系统时间，可改时间激活过期码 | ① 服务端原子扣减，全局唯一计数<br>② 后台一键发码，App 立即生效<br>③ 服务端权威时间 |

### 0.2 设计原则

| 原则 | 说明 |
|---|---|
| **轻量优先** | 仅做"邀请好友 + 兑换码"两个功能，不做用户账号、不做社交、不做模板市场 |
| **设备即用户** | 不引入手机号/邮箱注册体系，设备 UUID 作为用户身份标识 |
| **离线共存** | 服务器为可选增强层。未联网时 App 仍可正常使用全部拍摄/模板功能 |
| **可观察** | 运营后台提供足量统计维度，不依赖第三方分析工具 |
| **单机可扛** | 单台 VPS + SQLite 支撑到 DAU 5000 以内无需架构变更 |

---

## 1. 技术栈

| 层 | 选型 | 版本参考 | 理由 |
|---|---|---|---|
| 运行时 | Node.js | ≥ 18 LTS | 生态成熟，前端团队无缝上手 |
| 框架 | NestJS + @nestjs/platform-fastify | NestJS 10.x / Fastify 4.x | 模块化架构（Module/Controller/Service/DTO），维护成本低；Fastify 底层性能优于 Express |
| 数据库 | SQLite（better-sqlite3） | better-sqlite3 11.x | 零配置，单文件，备份即复制。后续量起可平滑迁移 PostgreSQL（NestJS + Drizzle 只需改连接串） |
| ORM | Drizzle ORM | 0.38+ | 类型安全、无运行时开销、SQLite 原生支持、迁移 CLI 内置 |
| 认证 | 设备 JWT（jsonwebtoken） | — | 设备 UUID 签发 JWT，无 Refresh Token 机制（设备 ID 永不过期，JWT 30 天有效） |
| 校验 | class-validator + class-transformer | — | NestJS 生态标准，配合 DTO 做入参校验 |
| 部署 | Nginx + PM2 + Ubuntu 22.04 VPS | PM2 5.x | 经典组合，SSL 终止 + 反向代理 + 进程守护 |
| 后台前端 | Next.js 14 (App Router) | Next.js 14+ / React 18+ | 全栈框架，与服务端共享受益类型；通过 Vercel 部署 |
| Monorepo 管理 | npm workspaces | — | 原生支持，零额外依赖；`packages/{backend,admin,shared}` 三层隔离 |
| CI/CD | GitHub Actions | — | 两套独立流水线：后端 → VPS (rsync + PM2 restart)，后台 → Vercel |

---

## 2. 数据模型（6 张表）

### 2.1 devices（设备登记表）

```sql
CREATE TABLE devices (
  device_id    TEXT PRIMARY KEY,            -- 客户端首次启动生成的 UUID
  alias        TEXT,                        -- 用户可选昵称
  first_seen_at INTEGER NOT NULL,           -- 首次注册时间（Unix 时间戳）
  last_seen_at  INTEGER NOT NULL,           -- 最后活跃时间
  ip_region     TEXT                        -- 注册时 IP 归属地（可选）
);
```

### 2.2 invite_records（邀请关系表 — 核心溯源）

```sql
CREATE TABLE invite_records (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  inviter_device_id TEXT NOT NULL REFERENCES devices(device_id),
  invitee_device_id TEXT NOT NULL UNIQUE REFERENCES devices(device_id),
  invite_code       TEXT NOT NULL,           -- 实际使用的邀请码
  channel           TEXT NOT NULL DEFAULT 'direct',  -- 'direct' | 'share_card' | 'qrcode'
  activated_at      INTEGER NOT NULL,
  inviter_ip        TEXT,                    -- 邀请人 IP（防刷日志）
  invitee_ip        TEXT                     -- 被邀请人 IP
);
CREATE INDEX idx_invite_records_inviter ON invite_records(inviter_device_id);
CREATE INDEX idx_invite_records_code ON invite_records(invite_code);
```

### 2.3 reward_tiers（奖励阶梯配置）

```sql
CREATE TABLE reward_tiers (
  tier             INTEGER PRIMARY KEY,     -- 1, 2, 3, ...
  required_invites INTEGER NOT NULL,         -- 达到此阶梯需要的有效邀请数
  rewards_json     TEXT NOT NULL DEFAULT '[]', -- JSON 数组：[{ type: 'template', id: 'xxx', label: 'xxx' }]
  is_active        INTEGER NOT NULL DEFAULT 1
);
```

### 2.4 reward_unlocks（奖励解锁记录）

```sql
CREATE TABLE reward_unlocks (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id       TEXT NOT NULL REFERENCES devices(device_id),
  tier            INTEGER NOT NULL REFERENCES reward_tiers(tier),
  source          TEXT NOT NULL,              -- 'invite' | 'redemption'
  source_detail   TEXT,                       -- 如果是兑换码，记录具体 code；如果是邀请，记录 invite_record_id
  status          TEXT NOT NULL DEFAULT 'unlocked', -- 'unlocked' | 'claimed'
  unlocked_at     INTEGER NOT NULL,
  claimed_at      INTEGER
);
CREATE INDEX idx_reward_unlocks_device ON reward_unlocks(device_id);
```

### 2.5 redemption_code_batches（兑换码批次）

```sql
CREATE TABLE redemption_code_batches (
  batch_id         INTEGER PRIMARY KEY AUTOINCREMENT,
  campaign_name    TEXT NOT NULL,             -- 活动名（如"暑期福利"）
  reward_tier      INTEGER NOT NULL REFERENCES reward_tiers(tier),
  max_uses_per_code INTEGER NOT NULL DEFAULT 1,
  total_generated  INTEGER NOT NULL,
  total_used       INTEGER NOT NULL DEFAULT 0,
  valid_from       INTEGER,                   -- NULL 表示立即生效
  valid_until      INTEGER,                   -- NULL 表示永不过期
  is_active        INTEGER NOT NULL DEFAULT 1,
  created_at       INTEGER NOT NULL
);

-- 码列表单独存为 JSON 文件或单独表以提高查询效率
CREATE TABLE redemption_codes (
  code             TEXT PRIMARY KEY,          -- 实际码字符串
  batch_id         INTEGER NOT NULL REFERENCES redemption_code_batches(batch_id),
  used_count       INTEGER NOT NULL DEFAULT 0,
  max_uses         INTEGER NOT NULL DEFAULT 1
);
CREATE INDEX idx_redemption_codes_batch ON redemption_codes(batch_id);
```

### 2.6 redemption_records（兑换记录）

```sql
CREATE TABLE redemption_records (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  code          TEXT NOT NULL REFERENCES redemption_codes(code),
  device_id     TEXT NOT NULL REFERENCES devices(device_id),
  redeemed_at   INTEGER NOT NULL,
  ip_address    TEXT
);
CREATE INDEX idx_redemption_records_code ON redemption_records(code);
CREATE INDEX idx_redemption_records_device ON redemption_records(device_id);
```

### 2.7 数据关系总图

```
devices ──┬── invite_records (作为 inviter)  ← 邀请关系溯源
          ├── invite_records (作为 invitee)
          ├── reward_unlocks                     ← 奖励归属
          └── redemption_records                ← 兑换记录

redemption_code_batches ─── redemption_codes ─── redemption_records
                              （批次→码→使用记录）

reward_tiers ─── reward_unlocks                   ← 奖励阶梯定义
```

---

## 3. API 接口规范

### 3.1 通用约定

- 基础路径：`/api/v1`
- 请求/响应体：JSON（Content-Type: application/json）
- 认证：除注册外，所有请求需在 `Authorization` 头携带 `Bearer {JWT}`
- 错误响应格式：`{ code: number, message: string }`

### 3.2 设备注册

```typescript
POST /api/v1/device/register

请求体: {
  deviceId: string       // 客户端生成的 UUID v4
}

成功响应 201: {
  token: string          // JWT, 有效期 30 天
  isNewDevice: boolean   // 是否首次注册
}

错误: 409 — deviceId 已被注册（直接返回已有 token 即可登录）
```

**说明**：首次注册即创建设备记录。已注册设备重复调用直接返回已有 JWT（幂等），确保用户卸载重装场景不丢失数据。

### 3.3 邀请码生成

```typescript
POST /api/v1/invite/generate

请求体: (空，从 JWT 解析 device_id)

成功响应 201: {
  inviteCode: string     // 6 位字母数字组合，如 "A7K3M9"
}
```

**说明**：
- 每个设备仅生成一个固定邀请码（首次调用生成，后续调用返回已有码）
- 邀请码格式：6 位大写字母 + 数字，排除 O/0/I/1 防混淆，约 7.3 亿种组合
- 邀请码生成算法：`nanoid(6, 'ABCDEFGHJKMNPQRSTUVWXYZ23456789')`

### 3.4 激活邀请

```typescript
POST /api/v1/invite/activate

请求体: {
  inviteCode: string     // 邀请人的 6 位码
  channel?: string       // 'direct' | 'share_card' | 'qrcode', 默认 'direct'
}

成功响应 201: {
  inviterDeviceId: string
  tierReached: number | null       // 本次激活后邀请人达到的阶梯
  rewards: { tier: number, items: any[] } | null
}

错误: 400 — 无效邀请码
      409 — 该设备已激活过邀请（一机仅可激活一次）
      429 — 激活太频繁
```

**校验规则**：
1. 邀请码存在且 `inviter_device_id !== 当前设备 ID`（自邀拦截）
2. 当前设备未激活过任何邀请
3. 当前 `invite_records` 表中 `inviter_device_id` 为被邀请人的记录不存在（防回流）
4. 通过后：写入 `invite_records` → 重新计算邀请人的累计邀请数 → 检查是否达到新的奖励阶梯 → 若达到则写入 `reward_unlocks`

### 3.5 邀请统计

```typescript
GET /api/v1/invite/stats

成功响应 200: {
  totalInvites: number
  currentTier: number
  nextTier: { tier: number, requiredInvites: number, rewards: any[] } | null
  unlockedRewards: { id: number, tier: number, status: string, ... }[]
}
```

### 3.6 兑换码核销

```typescript
POST /api/v1/redeem

请求体: {
  code: string           // 兑换码字符串
}

成功响应 201: {
  batchId: number
  campaignName: string
  rewardTier: number
  rewardItems: any[]
}

错误: 400 — 码格式无效
      404 — 码不存在
      410 — 码已过期
      409 — 已达使用次数上限 / 该设备已兑过此码
      429 — 兑换太频繁
```

**核销校验流程**：
1. 码存在 + 码所在批次 `is_active = 1`
2. 如批次有 `valid_from/valid_until`，检查服务端时间是否在有效期内
3. `redemption_codes.used_count < redemption_codes.max_uses`
4. 该 `device_id` 未在此 `code` 的 `redemption_records` 中出现过
5. 单设备当日全局兑换次数 ≤ 3 次（防刷）
6. 以上通过 → `redemption_codes.used_count += 1` → 写入 `redemption_records` → 写入 `reward_unlocks`

### 3.7 奖励列表

```typescript
GET /api/v1/rewards

成功响应 200: {
  rewards: {
    id: number
    tier: number
    source: 'invite' | 'redemption'
    status: 'unlocked' | 'claimed'
    rewardItems: any[]
    unlockedAt: number
  }[]
}
```

### 3.8 领奖确认

```typescript
POST /api/v1/rewards/:id/claim

成功响应 200: {
  success: true
}

错误: 404 — 奖励记录不存在
      409 — 已领取 / 不属于该设备
```

**说明**：`claim` 是一个"用户已确认收到"的标记，标记后前端不再提示"新奖励待领取"。非关键操作，即使 `claim` 失败也不影响奖励实际解锁。

### 3.9 运营后台 API（Phase 1-2 按需添加）

后台 API 与客户端 API 共用同一 NestJS 应用，通过前缀 `/api/v1/admin/` 区分，使用独立的后台管理员 JWT（硬编码 token，非设备 JWT）。

| 端点 | 方法 | 说明 | 优先级 |
|---|---|---|---|
| `/admin/stats` | GET | 概览统计（设备数、邀请数、兑换数、趋势） | P1 |
| `/admin/invites` | GET | 邀请记录分页查询，支持 device_id/时间/渠道筛选 | P1 |
| `/admin/invites/export` | GET | 导出邀请记录 CSV | P2 |
| `/admin/redeem-batches` | GET | 兑换码批次列表 | P2 |
| `/admin/redeem-batches` | POST | 创建新批次 | P2 |
| `/admin/redeem-batches/:id` | PATCH | 启用/禁用批次 | P2 |
| `/admin/redeem-batches/:id` | GET | 批次详情（含码列表及使用情况） | P2 |
| `/admin/redeem-batches/:id/export` | GET | 导出该批次兑换明细 CSV | P2 |
| `/admin/rewards` | GET | 奖励解锁记录查询 | P2 |

> **关于"收益"统计**：当前 MVP 无支付体系，收益数据 == 0。未来若接入付费模板/积分商城，可新增 `orders` 表 + 对应 API，后台 Dashboard 自动纳入收入统计。

---

## 4. Monorepo 目录结构

```
lumira-server/                          # 仓库根目录
├── .github/
│   └── workflows/
│       ├── deploy-backend.yml          # 后端 CI/CD（测试→构建→rsync→PM2 重启）
│       └── deploy-admin.yml            # 后台 CI/CD（测试→构建→Vercel 部署）
├── packages/
│   ├── shared/                         # 共享 TypeScript 类型（API 请求/响应 DTO）
│   │   ├── src/
│   │   │   └── types/
│   │   │       ├── device.ts
│   │   │       ├── invite.ts
│   │   │       ├── redeem.ts
│   │   │       └── rewards.ts
│   │   ├── package.json                # name: @lumira/shared
│   │   └── tsconfig.json
│   ├── backend/                        # NestJS + Fastify（部署到自有 VPS）
│   │   ├── src/
│   │   │   ├── main.ts                 # NestFactory.create(AppModule, new FastifyAdapter())
│   │   │   ├── app.module.ts
│   │   │   ├── common/
│   │   │   │   ├── guards/
│   │   │   │   │   └── device-auth.guard.ts
│   │   │   │   ├── decorators/
│   │   │   │   │   └── device.decorator.ts
│   │   │   │   ├── filters/
│   │   │   │   │   └── http-exception.filter.ts
│   │   │   │   └── pipes/
│   │   │   │       └── validation.pipe.ts
│   │   │   ├── modules/
│   │   │   │   ├── device/
│   │   │   │   │   ├── device.module.ts
│   │   │   │   │   ├── device.controller.ts
│   │   │   │   │   ├── device.service.ts
│   │   │   │   │   └── dto/
│   │   │   │   │       └── register-device.dto.ts
│   │   │   │   ├── invite/
│   │   │   │   │   ├── invite.module.ts
│   │   │   │   │   ├── invite.controller.ts
│   │   │   │   │   ├── invite.service.ts
│   │   │   │   │   └── dto/
│   │   │   │   │       ├── generate-invite.dto.ts
│   │   │   │   │       └── activate-invite.dto.ts
│   │   │   │   ├── redeem/
│   │   │   │   │   ├── redeem.module.ts
│   │   │   │   │   ├── redeem.controller.ts
│   │   │   │   │   ├── redeem.service.ts
│   │   │   │   │   └── dto/
│   │   │   │   │       └── redeem-code.dto.ts
│   │   │   │   └── rewards/
│   │   │   │       ├── rewards.module.ts
│   │   │   │       ├── rewards.controller.ts
│   │   │   │       ├── rewards.service.ts
│   │   │   │       └── dto/
│   │   │   │           └── claim-reward.dto.ts
│   │   │   ├── database/
│   │   │   │   ├── database.module.ts
│   │   │   │   ├── database.service.ts
│   │   │   │   └── migrations/
│   │   │   │       └── 001_init.sql
│   │   │   └── shared/
│   │   │       ├── invite-code.generator.ts
│   │   │       └── rate-limiter.ts
│   │   ├── test/
│   │   ├── package.json                # name: @lumira/backend
│   │   └── tsconfig.json
│   └── admin/                          # Next.js 后台（部署到 Vercel）
│       ├── src/
│       │   ├── app/
│       │   │   ├── layout.tsx          # 全局布局（侧边栏导航）
│       │   │   ├── page.tsx            # 重定向到 /dashboard
│       │   │   ├── dashboard/
│       │   │   │   └── page.tsx        # 概览统计
│       │   │   ├── invites/
│       │   │   │   └── page.tsx        # 邀请记录列表
│       │   │   ├── redeem-batches/
│       │   │   │   ├── page.tsx        # 兑换码批次列表
│       │   │   │   └── new/page.tsx    # 创建新批次
│       │   │   └── rewards/
│       │   │       └── page.tsx        # 奖励明细
│       │   ├── components/
│       │   │   ├── Sidebar.tsx
│       │   │   ├── StatsCard.tsx
│       │   │   └── CsvExportButton.tsx
│       │   └── lib/
│       │       ├── api.ts              # 调用后端 API 的客户端
│       │       └── types.ts            # 从 @lumira/shared 导入
│       ├── package.json                # name: @lumira/admin
│       ├── next.config.js
│       └── tsconfig.json
├── package.json                        # 根配置（workspaces: [packages/*]）
├── .gitignore
└── README.md
```

---

## 5. 部署架构

```
┌──────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
│               lumira-server (Monorepo)                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ packages/     │  │ packages/    │  │ packages/    │          │
│  │ backend       │  │ admin        │  │ shared       │          │
│  │ (NestJS+Fast) │  │ (Next.js)    │  │ (类型定义)    │          │
│  └──────┬───────┘  └──────┬───────┘  └──────────────┘          │
│         │                 │                                      │
│    Push main         Push main                                   │
│         │                 │                                      │
│         ▼                 ▼                                      │
│  ┌─────────────┐   ┌─────────────┐                              │
│  │ GitHub       │   │ GitHub      │                              │
│  │ Actions      │   │ Actions     │                              │
│  │ deploy-     │   │ deploy-     │                              │
│  │ backend.yml  │   │ admin.yml   │                              │
│  └──────┬───────┘   └──────┬───────┘                              │
│         │                  │                                      │
└──────────────────────────────────────────────────────────────────┘
         │                  │
         ▼                  ▼
┌─────────────────┐  ┌─────────────────┐
│  自有 VPS        │  │   Vercel        │
│  ┌─────────────┐ │  │ ┌─────────────┐│
│  │ Nginx (443) │ │  │ │ admin.      ││
│  │   ↓         │ │  │ │ lumira.app  ││
│  │ PM2 +       │ │  │ │ (Next.js)   ││
│  │ NestJS      │ │  │ └─────────────┘│
│  │   ↓         │ │  └─────────────────┘
│  │ SQLite      │ │
│  │ (data/*.db) │ │
│  │   ↓         │ │        App (Flutter)
│  │ crontab 备份│ │           ↓
│  └─────────────┘ │     HTTPS /api/*
│  │  /backups/    │           │
│  └───────────────┘           ▼
│                     ┌─────────────────┐
│                     │  如画 Lumira App  │
│                     │  (设备端)        │
│                     └─────────────────┘
│
│ 后台访问链路：
│ 运营人员 → https://admin.lumira.app → Vercel (Next.js)
│   → Next.js Server Component 调用后端 API → VPS (NestJS)
└───────────────────────────────────────────────
```

## 6. 运营后台功能规格

### 6.1 概览 Dashboard

```
┌───────────────────────────────────────────────┐
│  ┌─────────┐ ┌─────────┐ ┌────────┐ ┌──────┐  │
│  │ 累计设备  │ │ 今日新增  │ │ 累计邀请 │ │今日  │  │
│  │  1,234   │ │   12    │ │   567  │ │  3  │  │
│  ├─────────┤ ├─────────┤ ├────────┤ ├──────┤  │
│  │  ↑8.2%  │ │ 昨日 +5  │ │ ↑15.3% │ │昨日  │  │
│  │   vs 上周 │ │         │ │ vs 上周 │ │  +2  │  │
│  └─────────┘ └─────────┘ └────────┘ └──────┘  │
│                                                 │
│  近 7 日设备注册趋势 / 邀请激活趋势（折线图）      │
│  ┌─────────────────────────────────────────┐   │
│  │         📈 图表区域                      │   │
│  └─────────────────────────────────────────┘   │
│                                                 │
│  ┌──────────┐ ┌──────────┐ ┌────────────┐     │
│  │  兑换码   │ │  奖励解锁  │ │  兑换码     │     │
│  │  总使用量  │ │  总数     │ │  剩余可用    │     │
│  │    120    │ │    230   │ │    85      │     │
│  └──────────┘ └──────────┘ └────────────┘     │
└───────────────────────────────────────────────┘
```

### 6.2 邀请管理

- **表格列**：邀请人 device_id → 被邀请人 device_id → 邀请码 → 渠道 → 激活时间 → IP
- **筛选条件**：device_id 搜索、渠道筛选、时间范围选择
- **操作**：导出 CSV

### 6.3 兑换码管理

**创建批次表单：**

| 字段 | 类型 | 说明 |
|---|---|---|
| Campaign 名称 | 文本 | 运营标识（如"双十一福利"） |
| 兑换码列表 | 文本域 / 文件上传 | 每行一个码，或上传 .txt/.csv |
| 关联奖励阶梯 | 下拉选择 | 从 `reward_tiers` 中选择 |
| 每码最大使用次数 | 数字 | 默认 1 |
| 有效期起止 | 日期时间选择 | 可选 |

**批次列表：**

- 表格列：批次名 → 总量 → 已用 → 剩余 → 有效期 → 状态 → 操作
- 操作：查看详情（该批次下所有码的兑换明细）、禁用/启用

### 6.4 奖励明细

- 表格列：设备 ID → 奖励名称 → 来源（邀请/兑换）→ 关联码/邀请人 → 解锁时间 → 领奖状态
- 筛选：来源筛选、领奖状态筛选
- 操作：导出 CSV

---

## 7. 安全设计

### 7.1 防刷限流（内存级别，单机适用）

| 限流规则 | 阈值 | 范围 |
|---|---|---|
| 设备注册 | 100 次/天/IP | IP |
| 邀请激活 | 20 次/天/IP | IP |
| 兑换码核销 | 10 次/天/IP + 3 次/天/设备 | IP + device_id |
| 通用 API | 100 次/分钟/IP | IP |

### 7.2 兑换码格式

- 8 位大写字母 + 数字，排除 O/0/I/1
- 单批次支持 1 ~ 10,000 个码
- 码库大小：`(24+8)^8 ≈ 3.7 × 10^13` 种组合，暴力枚举不可行
- 固定长度前缀 + 随机后缀，支持按批次前缀级联删除

### 7.3 数据安全

- SQLite 文件 `chmod 600`，仅 root 和 app 用户可读
- 每日 crontab 备份到 `/backups/`，保留 30 天
- JWT Secret 通过环境变量注入，不硬编码
- 邀请码仅存明文（非敏感信息），兑换码存明文（依赖服务端限流防刷）

---

## 8. GitHub CI/CD（持续部署）

### 8.1 后端流水线 `deploy-backend.yml`

```yaml
name: Deploy Backend

on:
  push:
    branches: [main]
    paths:
      - 'packages/backend/**'
      - 'packages/shared/**'
      - 'package.json'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 18

      - run: npm ci
        working-directory: packages/backend

      - run: npm run build
        working-directory: packages/backend

      - run: npm test
        working-directory: packages/backend

      # 将构建产物同步到 VPS
      - name: Sync to VPS
        uses: easingthemes/ssh-deploy@v4
        with:
          ssh-private-key: ${{ secrets.VPS_SSH_KEY }}
          remote-host: ${{ secrets.VPS_HOST }}
          remote-user: ${{ secrets.VPS_USER }}
          source: 'packages/backend/'
          target: '/opt/lumira-server/packages/backend/'

      - name: Install deps & restart
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.VPS_HOST }}
          username: ${{ secrets.VPS_USER }}
          key: ${{ secrets.VPS_SSH_KEY }}
          script: |
            cd /opt/lumira-server/packages/backend
            npm ci --production
            pm2 restart lumira-server
```

### 8.2 后台流水线 `deploy-admin.yml`

```yaml
name: Deploy Admin Panel

on:
  push:
    branches: [main]
    paths:
      - 'packages/admin/**'
      - 'packages/shared/**'
      - 'package.json'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: 18

      - run: npm ci
        working-directory: packages/admin

      - run: npm run build
        working-directory: packages/admin

      # 部署到 Vercel
      - name: Deploy to Vercel
        uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
          working-directory: packages/admin
```

**CI/CD 前置条件：**

| 密钥 | 说明 |
|---|---|
| `VPS_SSH_KEY` | VPS 的 SSH 私钥 |
| `VPS_HOST` | VPS IP 或域名 |
| `VPS_USER` | SSH 用户名（建议使用非 root 用户） |
| `VERCEL_TOKEN` | Vercel 个人访问令牌 |
| `VERCEL_ORG_ID` | Vercel 组织 ID |
| `VERCEL_PROJECT_ID` | Vercel 项目 ID |

---

## 9. VPS 部署指南（仅后端）

### 9.1 服务端部署（一次性初始化）

```bash
# 1. 安装 Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

# 2. 安装 PM2
npm install -g pm2

# 3. 安装 SQLite
sudo apt install -y sqlite3

# 4. 创建目录
mkdir -p /opt/lumira-server/packages/backend
mkdir -p /opt/lumira-server/data
mkdir -p /backups

# 5. 配置 Nginx 反向代理（仅 API，后台在 Vercel）
cat > /etc/nginx/sites-available/lumira-api << 'EOF'
server {
    listen 443 ssl;
    server_name api.lumira.app;

    ssl_certificate /etc/letsencrypt/live/api.lumira.app/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.lumira.app/privkey.pem;

    # CORS 头（允许 Vercel 上的后台跨域调用）
    add_header Access-Control-Allow-Origin https://admin.lumira.app;
    add_header Access-Control-Allow-Methods 'GET, POST, PATCH';
    add_header Access-Control-Allow-Headers 'Content-Type, Authorization';

    location /api/ {
        proxy_pass http://127.0.0.1:3000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

# 6. 启用站点并申请 HTTPS
ln -s /etc/nginx/sites-available/lumira-api /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.lumira.app
```

### 9.2 SQLite 备份 crontab

```bash
# 每日凌晨 3:00 备份，保留 30 天
echo "0 3 * * * cp /opt/lumira-server/data/lumira.db /backups/lumira-$(date +\%Y\%m\%d).db" | crontab -
echo "0 4 * * * find /backups -name 'lumira-*.db' -mtime +30 -delete" | crontab -
```

### 9.3 PM2 维护命令

```bash
pm2 status                          # 查看状态
pm2 logs lumira-server              # 查看日志
pm2 restart lumira-server           # 重启
pm2 save                            # 保存进程列表
pm2 startup                         # 开机自启
```

### 9.4 Vercel 端配置（一次性）

1. 在 Vercel Dashboard 创建新项目，导入 `packages/admin/` 目录
2. 配置环境变量（Dashboard → Settings → Environment Variables）：

| 变量 | 说明 |
|---|---|
| `NEXT_PUBLIC_API_BASE_URL` | `https://api.lumira.app/api/v1` |
| `ADMIN_TOKEN` | 后台管理员的 JWT Secret（与后端 `ADMIN_JWT_SECRET` 一致） |

3. 第一次 CI/CD 触发前，手动跑一次 `vercel deploy` 完成项目初始化，获取 `VERCEL_PROJECT_ID`

---

## 10. 客户端接入方案

### 10.1 网络请求封装（Flutter 侧）

```typescript
// 新增项目文件夹: lib/services/remote/
// remote_service.dart — HTTP 客户端封装
// remote_config.dart — 服务器 URL 配置
// invite_remote_service.dart — 邀请/兑换 API 调用
// rewards_remote_service.dart — 奖励 API 调用
// device_auth_service.dart — 设备注册 + JWT 管理
```

**关键流程**：

```
App 启动
  └── 检查本地是否存有 JWT
        ├── 有 → 直接使用（请求失败 401 时重新注册）
        └── 无 → 读取本地设备 UUID → POST /device/register → 存 JWT
                到本地 secure storage / SharedPreferences
```

**网络策略**：
- 所有请求使用 `try-catch` + 超时（5 秒）
- **请求失败绝不阻塞用户操作**（App 核心功能全部离线可用）
- 仅在用户进入"邀请有礼"页 / "输入兑换码"时发起网络请求
- 失败时显示 Toast "网络连接失败，请稍后重试"

### 10.2 与现有离线方案的关系

| 场景 | 处理策略 |
|---|---|
| 联网成功 | 使用服务端数据（优先），服务端数据覆盖本地 mock |
| 网络请求失败 | 降级到离线本地校验方案（使用已有 mock UI + toast 提示） |
| 从未联网 | 完全离线，与现有行为一致 |

---

## 11. 迭代路径

### Phase 1 — MVP（2 周）

- 后端：6 张表建表 + 7 个 API 端点 + JWT 鉴权 + 内存限流
- 客户端：设备注册 + 邀请码生成/激活 + 兑换码核销 + 奖励列表拉取
- 后台：仅概览 Dashboard + 邀请记录查询

### Phase 2 — 运营增强（+1 周）

- 后台：兑换码批次管理 + 奖励明细
- 后端：邀请码渠道标记、兑换码批次管理 API
- 客户端：邀请分享卡片（系统分享面板）、二维码邀请

### Phase 3 — 规模化（按需）

- SQLite → PostgreSQL 迁移
- 内存限流 → Redis 限流
- 单机 → 多实例水平扩展
- 运营后台添加权限管理

---

## 12. 附录：与现有项目的边界

| 问 | 答 |
|---|---|
| 服务器代码放在哪个工程？ | 独立仓库 `/lumira-server/`，不与 `lumira-app/` 或 `lumira_app_flutter/` 混在一起 |
| 客户端新增的代码放在哪？ | `lumira_app_flutter/lib/services/remote/` 目录统一管理网络层 |
| 离线方案代码是否要删？ | 不删。离线 mock 作为服务端不可用的降级体验保留 |
| 当前 mock 数据改不改？ | 不改。网络请求成功时替换 mock 数据，失败时仍用 mock |
| 运营后台前端谁写？ | 与主 App 同一前端团队（Next.js），可独立开发部署 |
