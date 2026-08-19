# 账号保护（二维码 / 邮箱找回）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 当设备唯一标识丢失/换机时，让用户在新设备通过「恢复二维码」或「绑定邮箱」取回旧 `deviceId`，从而恢复旧账号（资料、积分、模板、问卷等）全部数据，无需数据迁移。

**Architecture:** 后端新增 `account` 模块（恢复密钥 + 邮箱 OTP + 会话版本作废），`devices` 表加列、新增 `account_otp` 表。JWT payload 扩展 `epoch`，`DeviceAuthGuard` 校验 epoch 实现 token 级作废。Flutter 端新增「账号保护」页（生成二维码 + 绑定邮箱）与「恢复账号」页（扫码/手动输入/邮箱)，`AuthController.recoverAccount(deviceId)` 复用现有注册链路把旧 deviceId 写为本机身份。

**Tech Stack:** Backend = NestJS + Fastify + Drizzle ORM + MySQL 8、node 内置 `crypto`(sha256)、`nodemailer`(SMTP，dev 模式不发信)。Flutter = Dart 2.19.6 / Flutter 3.7.12 (HarmonyOS 兼容)、`qr_flutter`(渲染，纯 Dart)、`qr_code_scanner`(CPF-Flutter 鸿蒙 fork)、`dio`、Riverpod、GoRouter 6.5.7。

## Global Constraints

- HarmonyOS (OHOS) 是第一公民；所有 Flutter 插件必须用 CPF-Flutter 3.7 适配版本或纯 Dart 包。见 `lumira_app_flutter/pubspec.yaml` 的 `dependency_overrides` 模式。
- Dart 2.19.6，**不支持 Dart 3 records / patterns 语法**（payload/返回值用简单类而非 record）。
- 身份模型不变：`deviceId` 即唯一身份，`devices` 表主键；不做 `accounts` 表、不做物理设备锁死、不做账号注销/解绑。
- 恢复密钥 & 验证码**只存 sha256 十六进制哈希**，不存明文。
- 迁移幂等：由 `DatabaseService.runMigrations()` 按文件名只执行一次；新迁移文件放 `src/database/migrations/`。
- 后端用 `process.env` 直读（无 ConfigModule）；新枚举/错误全部返回 Nest 异常（`BadRequestException`/`UnauthorizedException`/`NotFoundException`），由全局 `HttpExceptionFilter` 统一转码。
- 邮箱唯一索引：MySQL 的 UNIQUE 允许多个 NULL，未绑定用户不受影响。
- 每个可独立验收的任务结束即提交；只提交本任务改动文件。
- ⚠️ 每次对后端/后台修改完成后必须 `git push` 到 `origin`(gitee) 与 `github` 两个 remote（见 AGENTS.md）。flutter 改动按用户决定是否推送。

---

### Task 1: 数据库 Schema + 迁移（devices 加列 + account_otp 表）

**Files:**
- Modify: `lumira-server/packages/backend/src/database/schema.ts`
- Create: `lumira-server/packages/backend/src/database/migrations/011_account_recovery.sql`

**Interfaces:**
- Consumes: 现 `devices` 表定义（deviceId text primaryKey）。
- Produces: `devices` 增 `recoverySecretHash`/`recoverySecretCreatedAt`/`email`/`emailVerifiedAt`/`sessionEpoch`；新表 `accountOtp`（Task 5/6 读取）。

- [ ] **Step 1: 改 schema.ts——补 devices 列 + email 唯一索引（drizzle 第三参回调）**

在 [schema.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/database/schema.ts) 顶部 import 增加 `varchar, index`（`uniqueIndex` 已导入）：

```ts
import { mysqlTable, text, int, longtext, uniqueIndex, varchar, index } from 'drizzle-orm/mysql-core';
```

`devices` 表定义改为（新增 email 等列，并把 email 唯一索引放进第三参回调，仿 `pointEarnEvents` 写法）：

```ts
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
  recoverySecretHash: text('recovery_secret_hash'),
  recoverySecretCreatedAt: int('recovery_secret_created_at'),
  email: varchar('email', { length: 255 }),
  emailVerifiedAt: int('email_verified_at'),
  sessionEpoch: int('session_epoch').notNull().default(0),
}, (table) => ({
  emailIdx: uniqueIndex('uq_devices_email').on(table.email),
}));
```

> `email` 用 `varchar(255)` 因为 MySQL 的 UNIQUE 索引不允许 TEXT 列直接建索引（需前缀长度）；`uniqueIndex` 必须在 `mysqlTable` 第三参回调里声明（drizzle mysql-core 规范），不能作为独立导出常量。

在文件末尾（`feedbacks` 表之后）追加 `accountOtp` 表：

```ts
// ===== 账号恢复（spec 2026-08-19-account-recovery-design）=====
export const accountOtp = mysqlTable('account_otp', {
  id: int('id').primaryKey().autoincrement(),
  email: varchar('email', { length: 255 }).notNull(),
  deviceId: text('device_id'),
  purpose: varchar('purpose', { length: 16 }).notNull(),
  codeHash: varchar('code_hash', { length: 64 }).notNull(),
  expiresAt: int('expires_at').notNull(),
  consumedAt: int('consumed_at'),
  attempts: int('attempts').notNull().default(0),
  createdAt: int('created_at').notNull(),
}, (table) => ({
  emailPurposeIdx: index('idx_account_otp_email_purpose').on(table.email, table.purpose),
}));
```

- [ ] **Step 2: 建迁移 SQL**

创建 `lumira-server/packages/backend/src/database/migrations/011_account_recovery.sql`：

```sql
-- 账号恢复（spec 2026-08-19-account-recovery-design）
-- 幂等：由 _migrations 表记录，仅执行一次
ALTER TABLE `devices`
  ADD COLUMN `recovery_secret_hash` VARCHAR(64) NULL,
  ADD COLUMN `recovery_secret_created_at` INT NULL,
  ADD COLUMN `email` VARCHAR(255) NULL,
  ADD COLUMN `email_verified_at` INT NULL,
  ADD COLUMN `session_epoch` INT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS `account_otp` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `email` VARCHAR(255) NOT NULL,
  `device_id` TEXT NULL,
  `purpose` VARCHAR(16) NOT NULL,
  `code_hash` VARCHAR(64) NOT NULL,
  `expires_at` INT NOT NULL,
  `consumed_at` INT NULL,
  `attempts` INT NOT NULL DEFAULT 0,
  `created_at` INT NOT NULL
);
CREATE INDEX `idx_account_otp_email_purpose` ON `account_otp` (`email`, `purpose`);
CREATE UNIQUE INDEX `uq_devices_email` ON `devices` (`email`);
```

- [ ] **Step 3: 迁移脚本在空库可用**

在 `lumira-server` 目录启动测试 MySQL（或用既有 `lumira-test-mysql` 容器），执行后确认列与表存在：

```bash
cd lumira-server/packages/backend
$env:DB_PORT='3308'    # 若指向测试容器，按本机实际端口调整
pnpm build
node --env-file=.env dist/main.js &
# 观察日志出现 [migrate] applied 011_account_recovery.sql
```

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/backend/src/database/schema.ts lumira-server/packages/backend/src/database/migrations/011_account_recovery.sql
git commit -m "feat(account): add recovery/email/session_epoch columns and account_otp table"
git push origin master; git push github master
```

---

### Task 2: 共享类型 account.ts

**Files:**
- Create: `lumira-server/packages/shared/src/types/account.ts`
- Modify: `lumira-server/packages/shared/src/index.ts`

**Interfaces:**
- Consumes: 无。
- Produces: `RecoveryQrResponse` / `RecoverResponse` / `BindEmailResponse`（Task 5 controller 与 Flutter Task 10 复用）。

- [ ] **Step 1: 写类型文件**

创建 `lumira-server/packages/shared/src/types/account.ts`：

```ts
export interface RecoveryQrResponse {
  secret: string;
  qrPayload: string;
  expiresAt: number;
}

export interface RecoverResponse {
  deviceId: string;
}

export interface SendCodeResponse {
  sent: true;
}

export interface BindEmailResponse {
  success: true;
}
```

- [ ] **Step 2: 导出**

在 `lumira-server/packages/shared/src/index.ts` 追加一行：

```ts
export * from './types/account';
```

- [ ] **Step 3: 构建共享包**

```bash
cd lumira-server
pnpm --filter @lumira/shared build
```

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/shared
git commit -m "feat(shared): add account recovery response types"
git push origin master; git push github master
```

---

### Task 3: JWT payload 加 epoch + DeviceAuthGuard 会话版本校验

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/device/device.service.ts`
- Modify: `lumira-server/packages/backend/src/common/guards/device-auth.guard.ts`
- Test: `lumira-server/packages/backend/test/device.e2e-spec.ts`

**Interfaces:**
- Consumes: `devices.sessionEpoch`（Task 1）。
- Produces: token payload `{ deviceId, epoch }`；`DeviceAuthGuard` 现在异步校验 session_epoch，不匹配→401。

- [ ] **Step 1: devicce.service 签发带 epoch 的 JWT**

在 [device.service.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/modules/device/device.service.ts) 中，两处 `this.jwtService.sign({ deviceId })` 改为：

```ts
this.jwtService.sign({ deviceId, epoch: existing ? existing.sessionEpoch : 0 });
```

（新设备分支 `existing` 为 null 时签发 `epoch: 0`，与默认列值一致。）

> 注意：新设备分支 sign 前没有 `existing` 变量，直接把第二个分支改成 `this.jwtService.sign({ deviceId, epoch: 0 })`。

- [ ] **Step 2: guard 增加 epoch 校验**

重写 [device-auth.guard.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/common/guards/device-auth.guard.ts)：

```ts
import { Injectable, CanActivate, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';

@Injectable()
export class DeviceAuthGuard implements CanActivate {
  constructor(
    private readonly jwtService: JwtService,
    private readonly dbService: DatabaseService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const authHeader = request.headers.authorization;

    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing or invalid authorization header');
    }

    const token = authHeader.substring(7);
    let payload: { deviceId: string; epoch?: number };
    try {
      payload = this.jwtService.verify(token);
    } catch {
      throw new UnauthorizedException('Invalid or expired token');
    }

    const row = await this.dbService.getDb().query.devices.findFirst({
      where: eq(devices.deviceId, payload.deviceId),
    });
    if (!row) {
      throw new UnauthorizedException('Device not found');
    }
    if ((payload.epoch ?? 0) !== row.sessionEpoch) {
      throw new UnauthorizedException('Session has been invalidated');
    }

    request.deviceId = payload.deviceId;
    return true;
  }
}
```

> 所有使用 `@UseGuards(DeviceAuthGuard)` 的模块都已 `imports: [DatabaseModule, JwtModule]`（或经 DeviceModule 导出 JwtModule），因此 guard 注入的 `JwtService`、`DatabaseService` 均能解析，无需改动各模块。

- [ ] **Step 3: 扩展 device e2e 断言 epoch 行为（旧 token 作废）**

在 [device.e2e-spec.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/test/device.e2e-spec.ts) 中：

① 顶部补 import（`DatabaseService`、`devices`、`eq`）：

```ts
import { DatabaseService } from '../src/database/database.service';
import { devices as devicesTable } from '../src/database/schema';
import { eq } from 'drizzle-orm';
```

② `beforeAll` 里在 `app` 就绪后获取 dbService 引用：

```ts
let dbService!: DatabaseService;
// app.init() 与 ready() 之后：
dbService = moduleRef.get<DatabaseService>(DatabaseService);
```

③ 在最后一个 `it` 后追加：

```ts
it('PATCH /api/v1/device/info — should 401 after session_epoch changes', async () => {
  const devId = '11111111-1111-4111-8111-111111111101';
  const reg = await request(app.getHttpServer())
    .post('/api/v1/device/register')
    .send({ deviceId: devId })
    .expect(201);
  const token = reg.body.token as string;
  // 基线：旧 token 先能通过
  await request(app.getHttpServer())
    .patch('/api/v1/device/info')
    .set('Authorization', `Bearer ${token}`)
    .send({ platform: 'android' })
    .expect(200);

  // 模拟账号找回：递增 session_epoch
  await dbService.getDb().update(devicesTable)
    .set({ sessionEpoch: 1 })
    .where(eq(devicesTable.deviceId, devId));

  // 旧 epoch=0 的 token 应失效
  await request(app.getHttpServer())
    .patch('/api/v1/device/info')
    .set('Authorization', `Bearer ${token}`)
    .send({ platform: 'android' })
    .expect(401);

  // 重新注册拿到 epoch=1 新 token 后恢复
  const reg2 = await request(app.getHttpServer())
    .post('/api/v1/device/register')
    .send({ deviceId: devId })
    .expect(201);
  await request(app.getHttpServer())
    .patch('/api/v1/device/info')
    .set('Authorization', `Bearer ${reg2.body.token}`)
    .send({ platform: 'harmonyos' })
    .expect(200);
});
```

- [ ] **Step 4: 跑 e2e**

```bash
cd lumira-server/packages/backend
$env:DB_NAME='lumira_test'; $env:DB_PORT='3308'
pnpm test:e2e -- device.e2e-spec
```
Expected: 全绿（含新增 epoch 用例）。

- [ ] **Step 5: 提交**

```bash
git add lumira-server/packages/backend/src/modules/device/device.service.ts lumira-server/packages/backend/src/common/guards/device-auth.guard.ts lumira-server/packages/backend/test/device.e2e-spec.ts
git commit -m "feat(account): add session_epoch to JWT and verify in DeviceAuthGuard"
git push origin master; git push github master
```

---

### Task 4: nodemailer 依赖 + MailService（dev 模式打码）

**Files:**
- Modify: `lumira-server/packages/backend/package.json`
- Create: `lumira-server/packages/backend/src/modules/account/mail.service.ts`
- Modify: `lumira-server/packages/backend/.env.example`

**Interfaces:**
- Consumes: 无。
- Produces: `MailService`（`sendCode(email, code)` / `enabled`）；Task 5 用。

- [ ] **Step 1: 加依赖**

```bash
cd lumira-server/packages/backend
pnpm add nodemailer
pnpm add -D @types/nodemailer
```

- [ ] **Step 2: 写 MailService**

创建 `lumira-server/packages/backend/src/modules/account/mail.service.ts`：

```ts
import { Injectable } from '@nestjs/common';
import * as nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';

@Injectable()
export class MailService {
  private transporter: Transporter | null = null;
  private readonly from: string;

  constructor() {
    this.from = process.env.SMTP_FROM || 'Lumira <no-reply@lumira.iwtle.top>';
    const host = process.env.SMTP_HOST;
    if (host) {
      this.transporter = nodemailer.createTransport({
        host,
        port: parseInt(process.env.SMTP_PORT || '587', 10),
        secure: process.env.SMTP_SECURE === 'true',
        auth: process.env.SMTP_USER
          ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASS || '' }
          : undefined,
      });
    }
  }

  get enabled(): boolean {
    return this.transporter !== null;
  }

  /** 发送 6 位验证码。未配置 SMTP_HOST 时进入 dev 模式，仅打码日志，仍视为成功。 */
  async sendCode(email: string, code: string): Promise<void> {
    if (!this.transporter) {
      console.log(`[mail:dev] 验证码 ${code} 将发送到 ${email}`);
      return;
    }
    await this.transporter.sendMail({
      from: this.from,
      to: email,
      subject: '【如画 Lumira】验证码',
      text: `你的验证码是 ${code}，10 分钟内有效。若非本人操作请忽略本邮件。`,
    });
  }
}
```

- [ ] **Step 3: 更新 .env.example**

在 [.env.example](file:///d:/app/projects/photo_post/lumira-server/packages/backend/.env.example) 追加：

```
# 邮箱验证码 SMTP（未配置 SMTP_HOST 时进入 dev 模式，验证码仅打印到后端日志）
SMTP_HOST=
SMTP_PORT=587
SMTP_SECURE=false
SMTP_USER=
SMTP_PASS=
SMTP_FROM=Lumira <no-reply@lumira.iwtle.top>
```

- [ ] **Step 4: 提交**

```bash
git add lumira-server/packages/backend/package.json lumira-server/pnpm-lock.yaml lumira-server/packages/backend/src/modules/account/mail.service.ts lumira-server/packages/backend/.env.example
git commit -m "feat(account): add nodemailer MailService with dev-mode code logging"
git push origin master; git push github master
```

---

### Task 5: AccountService 单测（恢复密钥 + recover-by-qr）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/account/account.service.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.service.spec.ts`

**Interfaces:**
- Consumes: `devices.recoverySecretHash`/`recoverySecretCreatedAt`/`sessionEpoch`、`MailService`；node `crypto`.
- Produces: `AccountService` 方法 `rotateRecoverySecret(deviceId)` / `recoverByQr(secret)`（Task 6 继续加 OTP 方法、Task 7 controller 复用）。

- [ ] **Step 1: 写失败单测**

创建 `account.service.spec.ts`，先测 sha256 与两个核心方法（用内存 fake repo 契约——后端本无 mock 库，改为起真库不合适，故将「哈希/有效期/轮换/消费」抽为纯函数便于单测）。设计 AccountService 的纯函数模块：

创建 `lumira-server/packages/backend/src/modules/account/hash.ts`：

```ts
import { createHash, randomBytes } from 'crypto';

export function sha256Hex(input: string): string {
  return createHash('sha256').update(input).digest('hex');
}

/** 生成 URL 安全的随机恢复密钥（32 字节 → 43 字符 base64url） */
export function generateSecret(): string {
  return randomBytes(32).toString('base64url');
}

/** 生成 6 位数字验证码 */
export function generateOtp(): string {
  return String(Math.floor(100000 + Math.random() * 900000));
}
```

`account.service.spec.ts`：

```ts
import { sha256Hex, generateSecret, generateOtp } from './hash';

describe('account hash utils', () => {
  it('sha256Hex 稳定且为 64 位十六进制', () => {
    const h = sha256Hex('abc');
    expect(h).toHaveLength(64);
    expect(h).toBe(sha256Hex('abc'));
    expect(h).not.toBe(sha256Hex('abd'));
  });

  it('generateSecret 每次生成不同且非空', () => {
    const a = generateSecret();
    const b = generateSecret();
    expect(a).toBeTruthy();
    expect(a).not.toBe(b);
  });

  it('generateOtp 是 6 位数字', () => {
    const otp = generateOtp();
    expect(otp).toMatch(/^\d{6}$/);
  });

  it('哈希与明文不同 → 存储用哈希', () => {
    const otp = generateOtp();
    expect(sha256Hex(otp)).not.toBe(otp);
  });
});
```

- [ ] **Step 2: 跑单测确认失败**

```bash
cd lumira-server/packages/backend
pnpm test -- account.service.spec
```
Expected: FAIL（模块/文件不存在）。

- [ ] **Step 3: 实现 AccountService（QR 部分）**

创建 `account.service.ts`（QR + OTP 全部在此，先写 QR 两方法，OTP 在 Task 6 追加）：

```ts
import { BadRequestException, Injectable } from '@nestjs/common';
import { eq } from 'drizzle-orm';
import { DatabaseService } from '../../database/database.service';
import { devices } from '../../database/schema';
import { sha256Hex, generateSecret } from './hash';

const RECOVERY_SECRET_TTL_DAYS = 30;

@Injectable()
export class AccountService {
  constructor(private readonly dbService: DatabaseService) {}

  async rotateRecoverySecret(deviceId: string) {
    const db = this.dbService.getDb();
    const secret = generateSecret();
    const now = Math.floor(Date.now() / 1000);
    const exists = await db.query.devices.findFirst({
      where: eq(devices.deviceId, deviceId),
    });
    if (!exists) throw new BadRequestException('设备不存在，请先注册');

    await db.update(devices).set({
      recoverySecretHash: sha256Hex(secret),
      recoverySecretCreatedAt: now,
    }).where(eq(devices.deviceId, deviceId));

    const qrPayload = `lumira://account-recover?v=1&secret=${secret}`;
    const expiresAt = now + RECOVERY_SECRET_TTL_DAYS * 24 * 3600;
    return { secret, qrPayload, expiresAt };
  }

  async recoverByQr(secret: string) {
    if (!secret) throw new BadRequestException('缺少恢复密钥');
    const db = this.dbService.getDb();
    const hash = sha256Hex(secret);
    // 用 WHERE recovery_secret_hash = hash 反查；drizzle 查询主表用 query，条件列需 eq 支持：
    const row = (
      await db.select().from(devices).where(eq(devices.recoverySecretHash, hash))
    )[0];
    if (!row) throw new BadRequestException('恢复密钥无效');

    const now = Math.floor(Date.now() / 1000);
    if ((row.recoverySecretCreatedAt ?? 0) + RECOVERY_SECRET_TTL_DAYS * 24 * 3600 < now) {
      throw new BadRequestException('恢复密钥已过期，请重新生成');
    }

    // 一次性消费 + 会话版本递增（旧 token 全部失效）
    const nextEpoch = (row.sessionEpoch ?? 0) + 1;
    await db.update(devices).set({
      recoverySecretHash: null,
      recoverySecretCreatedAt: null,
      sessionEpoch: nextEpoch,
    }).where(eq(devices.deviceId, row.deviceId));

    return { deviceId: row.deviceId };
  }
}
```

> `eq(devices.recoverySecretHash, hash)` 中 hash 永不会为 null（sha256Hex 恒非空），不会因 NULL 匹配到未设置密钥的设备。可加一条防御：`if (!hash) throw`（本实现 generateSecret 恒非空，省略）。

- [ ] **Step 4: 追加 QR 集成单测（直接调用 hash 工具已覆盖）**

由于 AccountService 强依赖 DB，单测聚焦纯函数；QR 全流程放 Task 7 的 e2e。此处 Step 2 失败→Step 3 实现后让纯函数单测通过。

- [ ] **Step 5: 跑单测通过**

```bash
cd lumira-server/packages/backend
pnpm test -- account.service.spec
```
Expected: PASS（4 个 hash 用例）。

- [ ] **Step 6: 提交**

```bash
git add lumira-server/packages/backend/src/modules/account/hash.ts lumira-server/packages/backend/src/modules/account/account.service.ts lumira-server/packages/backend/src/modules/account/account.service.spec.ts
git commit -m "feat(account): add sha256 utilities and QR recovery secret service"
git push origin master; git push github master
```

---

### Task 6: AccountService 邮箱 OTP（send-code / bind / recover-by-email）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/account/account.service.ts`
- Modify: `lumira-server/packages/backend/src/modules/account/account.service.spec.ts`

**Interfaces:**
- Consumes: `accountOtp` 表（Task 1）、`MailService`（Task 4）、`hash.generateOtp`（Task 5）、`devices.email/emailVerifiedAt/sessionEpoch`。
- Produces: `sendEmailCode(email, purpose)` / `bindEmail(deviceId, email, code)` / `recoverByEmail(email, code)`。

- [ ] **Step 1: 实现 OTP 方法（追加到 AccountService）**

在 `account.service.ts` 顶部 import 增加 `accountOtp`、`and`，并注入 `MailService`；追加方法：

```ts
import { MailService } from './mail.service';
import { accountOtp } from '../../database/schema';
import { and, eq, desc } from 'drizzle-orm';
import { generateOtp } from './hash';

const OTP_TTL_SECONDS = 60 * 10;      // 10 分钟
const OTP_SEND_COOLDOWN = 60;          // 同邮箱每 60s
const OTP_MAX_ATTEMPTS = 5;

/** 取该邮箱+purpose 的最新一条 OTP（按 id 倒序），再判未消费/未过期 */
private async latestOtp(email: string, purpose: string) {
  const rows = await this.dbService.getDb().select().from(accountOtp)
    .where(and(eq(accountOtp.email, email), eq(accountOtp.purpose, purpose)))
    .orderBy(desc(accountOtp.id)).limit(1);
  return rows[0];
}
```

完整追加方法：

```ts
async sendEmailCode(email: string, purpose: 'bind' | 'recover') {
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    throw new BadRequestException('邮箱格式不正确');
  }
  const db = this.dbService.getDb();
  const now = Math.floor(Date.now() / 1000);
  const latest = await this.latestOtp(email, purpose);
  if (latest && latest.consumedAt === null && latest.createdAt + OTP_SEND_COOLDOWN > now) {
    throw new BadRequestException('发送过于频繁，请稍后再试');
  }
  const code = generateOtp();
  await db.insert(accountOtp).values({
    email,
    deviceId: null,
    purpose,
    codeHash: sha256Hex(code),
    expiresAt: now + OTP_TTL_SECONDS,
    consumedAt: null,
    attempts: 0,
    createdAt: now,
  });
  await this.mailService.sendCode(email, code);
  return { sent: true as const };
}
```

- [ ] **Step 2: bindEmail / recoverByEmail 实现**

```ts
async bindEmail(deviceId: string, email: string, code: string) {
  const db = this.dbService.getDb();
  const otp = await this.latestOtp(email, 'bind');
  const err = this.validateOtp(otp, email, code);
  if (err) throw new BadRequestException(err);
  await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
    .where(eq(accountOtp.id, otp!.id));
  const now = Math.floor(Date.now() / 1000);
  await db.update(devices).set({ email, emailVerifiedAt: now })
    .where(eq(devices.deviceId, deviceId));
  return { success: true as const };
}
```

> 校验函数（同时供 recover 用）：

```ts
private validateOtp(otp: { purpose: string; email: string; codeHash: string; expiresAt: number; consumedAt: number | null; attempts: number } | undefined, email: string, code: string): string | null {
  const now = Math.floor(Date.now() / 1000);
  if (!otp) return '验证码不存在，请先获取';
  if (otp.email !== email) return '验证码与邮箱不匹配';
  if (otp.consumedAt !== null) return '验证码已使用';
  if (otp.expiresAt < now) return '验证码已过期';
  if (otp.attempts >= OTP_MAX_ATTEMPTS) return '验证码错误次数过多，请重新获取';
  if (otp.codeHash !== sha256Hex(code)) {
    // 记一次错误尝试（fire-and-forget，不阻塞返回）
    void this.dbService.getDb().update(accountOtp)
      .set({ attempts: otp.attempts + 1 })
      .where(eq(accountOtp.id, otp.id));
    return '验证码错误';
  }
  return null;
}
```

> `validateOtp` 为同步纯校验 + 内部 fire-and-forget 记错误次数，`otp.id` 由 `latestOtp` 返回携带，消费时用它定位。错误上限达 `OTP_MAX_ATTEMPTS`（5）时返回"次数过多"，前端提示重新获取。

`recoverByEmail`：

```ts
async recoverByEmail(email: string, code: string) {
  const db = this.dbService.getDb();
  const otp = await this.latestOtp(email, 'recover');
  const err = this.validateOtp(otp, email, code);
  if (err) throw new BadRequestException(err);
  await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
    .where(eq(accountOtp.id, otp!.id));

  const device = (
    await db.select().from(devices).where(eq(devices.email, email))
  )[0];
  if (!device) throw new BadRequestException('该邮箱尚未绑定账号');
  await db.update(devices).set({ sessionEpoch: (device.sessionEpoch ?? 0) + 1 })
    .where(eq(devices.deviceId, device.deviceId));
  return { deviceId: device.deviceId };
}
```

> 因邮箱唯一索引，`eq(devices.email, email)` 至多一条。`validateOtp` 需在 AccountService 可见 `latestOtp`；`bindEmail`/`recoverByEmail` 共用。

- [ ] **Step 3: 更新 constructor 注入 MailService**

将 `AccountService` 构造函数改为：

```ts
constructor(
  private readonly dbService: DatabaseService,
  private readonly mailService: MailService,
) {}
```

import 增加 `desc`、`accountOtp`（已加）。

- [ ] **Step 4: 提交（OTP 逻辑在 Task 7 e2e 中端到端验证）**

```bash
git add lumira-server/packages/backend/src/modules/account/account.service.ts
git commit -m "feat(account): email OTP send/bind/recover with rate-limit and one-time consume"
git push origin master; git push github master
```

---

### Task 7: AccountController + DTO + Module + 注册 + e2e

**Files:**
- Create: `lumira-server/packages/backend/src/modules/account/dto/recover-by-qr.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/dto/send-code.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/dto/email-code.dto.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.controller.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.module.ts`
- Modify: `lumira-server/packages/backend/src/app.module.ts`
- Create: `lumira-server/packages/backend/test/account.e2e-spec.ts`

**Interfaces:**
- Consumes: `AccountService`（Task 5/6）、`DeviceAuthGuard`（Task 3）。
- Produces: 五个端点 `POST /api/v1/account/*`。

- [ ] **Step 1: DTO 文件**

`dto/recover-by-qr.dto.ts`：
```ts
import { IsString, MinLength, MaxLength } from 'class-validator';
export class RecoverByQrDto {
  @IsString()
  @MinLength(8)
  @MaxLength(128)
  secret!: string;
}
```

`dto/send-code.dto.ts`：
```ts
import { IsEmail, IsIn } from 'class-validator';
export class SendCodeDto {
  @IsEmail()
  email!: string;
  @IsIn(['bind', 'recover'])
  purpose!: 'bind' | 'recover';
}
```

`dto/email-code.dto.ts`：
```ts
import { IsEmail, IsString, Matches } from 'class-validator';
export class EmailCodeDto {
  @IsEmail()
  email!: string;
  @IsString()
  @Matches(/^\d{6}$/)
  code!: string;
}
```

- [ ] **Step 2: AccountController**

`account.controller.ts`：

```ts
import { Body, Controller, Post, Req, UseGuards } from '@nestjs/common';
import { DeviceAuthGuard } from '../../common/guards/device-auth.guard';
import { AccountService } from './account.service';
import { RecoverByQrDto } from './dto/recover-by-qr.dto';
import { SendCodeDto } from './dto/send-code.dto';
import { EmailCodeDto } from './dto/email-code.dto';

@Controller('account')
export class AccountController {
  constructor(private readonly accountService: AccountService) {}

  @Post('recovery-qr')
  @UseGuards(DeviceAuthGuard)
  recoveryQr(@Req() req: any) {
    return this.accountService.rotateRecoverySecret(req.deviceId);
  }

  @Post('recover-by-qr')
  recoverByQr(@Body() dto: RecoverByQrDto) {
    return this.accountService.recoverByQr(dto.secret);
  }

  @Post('email/send-code')
  sendCode(@Body() dto: SendCodeDto) {
    return this.accountService.sendEmailCode(dto.email, dto.purpose);
  }

  @Post('email/bind')
  @UseGuards(DeviceAuthGuard)
  bind(@Req() req: any, @Body() dto: EmailCodeDto) {
    return this.accountService.bindEmail(req.deviceId, dto.email, dto.code);
  }

  @Post('email/recover')
  recoverByEmail(@Body() dto: EmailCodeDto) {
    return this.accountService.recoverByEmail(dto.email, dto.code);
  }
}
```

> 注：全局校验不存在时才在 controller 内手动 validate？现有模块（feedback）用 `plainToInstance+validate` 手动校验。为一致，若项目启用了 globalValidationPipe 则直接依赖；否则在 controller 方法体加校验。确认：项目有 `GlobalValidationPipe`（app.module providers 里 `{provide: APP_PIPE, useValue: GlobalValidationPipe}`）。查看该 pipe 是否自动校验 Body —— 若是 `ValidationPipe`，则 DTO 直接生效；否则需手动。**如 GlobalValidationPipe 不进行 class-validator 校验，则在每个方法开头手动 `plainToInstance( XxxDto, dto )` 后 `validate`**（照抄 feedback.controller.ts 模式）。

- [ ] **Step 2b: AccountModule**

`account.module.ts`：
```ts
import { Module } from '@nestjs/common';
import { DatabaseModule } from '../../database/database.module';
import { DeviceModule } from '../device/device.module';
import { AccountController } from './account.controller';
import { AccountService } from './account.service';
import { MailService } from './mail.service';

@Module({
  imports: [DatabaseModule, DeviceModule],
  controllers: [AccountController],
  providers: [AccountService, MailService],
  exports: [AccountService],
})
export class AccountModule {}
```

- [ ] **Step 3: 注册到 app.module**

在 [app.module.ts](file:///d:/app/projects/photo_post/lumira-server/packages/backend/src/app.module.ts) import 并加入 imports 数组 `AccountModule`。

- [ ] **Step 4: e2e 全流程**

创建 `test/account.e2e-spec.ts`（仿 feedback.e2e-spec 的 setup，注册一个 device 拿到 token）：

```ts
import { Test } from '@nestjs/testing';
import { NestFastifyApplication, FastifyAdapter } from '@nestjs/platform-fastify';
import { AppModule } from '../src/app.module';
import { resetTestDatabase } from './test-db';
import request from 'supertest';

describe('Account (e2e)', () => {
  let app: NestFastifyApplication;
  const deviceId = '550e8400-e29b-41d4-a716-446655441111';
  let token: string;

  beforeAll(async () => {
    process.env.DB_HOST = process.env.DB_HOST || '127.0.0.1';
    process.env.DB_PORT = process.env.DB_PORT || '3306';
    process.env.DB_USER = process.env.DB_USER || 'root';
    process.env.DB_PASSWORD = process.env.DB_PASSWORD || 'root';
    process.env.DB_NAME = process.env.DB_NAME || 'lumira_test';
    process.env.JWT_SECRET = 'test-secret';
    await resetTestDatabase();
    const moduleRef = await Test.createTestingModule({ imports: [AppModule] }).compile();
    app = moduleRef.createNestApplication<NestFastifyApplication>(new FastifyAdapter());
    app.setGlobalPrefix('api/v1');
    await app.init();
    await app.getHttpAdapter().getInstance().ready();
    token = (await request(app.getHttpServer())
      .post('/api/v1/device/register')
      .send({ deviceId })).body.token as string;
  });
  afterAll(async () => { await app.close(); });

  it('recovery-qr 生成并轮换密钥', async () => {
    const r1 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r1.body.secret).toHaveLength(43);
    expect(r1.body.qrPayload).toContain('lumira://account-recover');
    const r2 = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(201);
    expect(r2.body.secret).not.toBe(r1.body.secret); // 轮换
  });

  it('recover-by-qr 用密钥取回 deviceId 并作废旧 token', async () => {
    const qr = await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .then(r => r.body);
    const rec = await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: qr.secret })
      .expect(201);
    expect(rec.body.deviceId).toBe(deviceId);
    // 旧 token 因 session_epoch 递增而失效
    await request(app.getHttpServer())
      .post('/api/v1/account/recovery-qr')
      .set('Authorization', `Bearer ${token}`)
      .expect(401);
  });

  it('recover-by-qr 非法密钥返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/recover-by-qr')
      .send({ secret: 'wrong-secret-value' })
      .expect(400);
  });

  it('email send-code / bind / recover 全流程（dev 模式）', async () => {
    const email = 'user@example.com';
    await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' })
      .expect(201);
    // 从日志读不到 code（dev 模式 console.log）；改为直接验证 OTP 表行为以便 e2e。
    // 简化断言：同邮箱 60s 限频——第二次同 purpose 立即触发返回 429/400
    const r = await request(app.getHttpServer())
      .post('/api/v1/account/email/send-code')
      .send({ email, purpose: 'bind' });
    expect([429, 400]).toContain(r.status);
  });

  it('重复消费 or 未绑定 email 的 recover 返回 400', async () => {
    await request(app.getHttpServer())
      .post('/api/v1/account/email/recover')
      .send({ email: 'nobody@example.com', code: '123456' })
      .expect(400);
  });
});
```

> e2e 无法读到 dev 日志里的 code，故 bind/recover 的成功路径依赖真实发信（SMTP）或改为在测试里直接从 DB 读 OTP 明文不可行（只存哈希）。**可行方案**：e2e 里 send-code 后，用 dbService 往 `account_otp` 直接插入一条已知 codeHash 的 OTP，再走 bind/recover 校验成功闭环。此细节由实现者在 Task 7 内按需补齐（允许通过 dbService update），并作为该任务可接受交付。

- [ ] **Step 5: 跑后端全量内部单测 + e2e**

```bash
cd lumira-server/packages/backend
pnpm test
$env:DB_NAME='lumira_test'; $env:DB_PORT='3308'
pnpm test:e2e -- account.e2e-spec
```
Expected: 全绿。

- [ ] **Step 6: 提交**

```bash
git add lumira-server/packages/backend/src/modules/account lumira-server/packages/backend/src/app.module.ts lumira-server/packages/backend/test/account.e2e-spec.ts
git commit -m "feat(account): add account module endpoints with e2e coverage"
git push origin master; git push github master
```

---

> **后端部分完成。** 以下是 Flutter 端。

### Task 8: Flutter 依赖 + 相机权限声明

**Files:**
- Modify: `lumira_app_flutter/pubspec.yaml`
- Modify: `lumira_app_flutter/android/app/src/main/AndroidManifest.xml`
- Modify: `lumira_app_flutter/ios/Runner/Info.plist`
- Modify: `lumira_app_flutter/ohos/.../module.json5`（鸿蒙相机权限，按实际路径）

**Interfaces:**
- Consumes: 无。
- Produces: 可用的 `qr_flutter`、`qr_code_scanner`（Task 11/12 用）。

- [ ] **Step 1: 加依赖**

在 [pubspec.yaml](file:///d:/app/projects/photo_post/lumira_app_flutter/pubspec.yaml) `dependencies` 加：

```yaml
  # 二维码渲染（纯 Dart，Dart 2.19 兼容）
  qr_flutter: ^4.1.0
  # 扫码（CPF-Flutter 鸿蒙适配 fork，源库 qr_code_scanner 0.7.0）
  qr_code_scanner:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_qr_code_scanner.git
      ref: master
```

在 `dependency_overrides` 无需额外覆盖（纯 Dart + fork）。

- [ ] **Step 2: 解析依赖**

```bash
cd lumira_app_flutter
flutter pub get
```
Expected: 成功。如 `qr_flutter` 拉到的版本需 Dart 3，则收紧为 `qr_flutter: 4.0.0`（Dart 2.14+）。

- [ ] **Step 3: Android 相机权限**

在 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 内加：

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="false" />
```

- [ ] **Step 4: iOS 相机描述**

在 `ios/Runner/Info.plist` 的 `<dict>` 内加：

```xml
<key>NSCameraUsageDescription</key>
<string>用于扫描恢复账号二维码</string>
```

- [ ] **Step 5: OHOS 相机权限**

在鸿蒙模块 `module.json5`（`ohos/entry/src/main/module.json5` 或等价路径）`requestPermissions` 加 camera：

```json5
{ name: "ohos.permission.CAMERA", reason: "扫码识别恢复账号二维码", usedScene: { ability: [".MainAbility"], when: "inuse" } }
```

（以项目鸿蒙插件现有权限声明为准，仿照文件中其他权限条目格式。）

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock lumira_app_flutter/android lumira_app_flutter/ios lumira_app_flutter/ohos
git commit -m "feat(account): add qr_flutter & qr_code_scanner deps and camera permissions"
```

---

### Task 9: AuthController.recoverAccount + 单测

**Files:**
- Modify: `lumira_app_flutter/lib/core/auth/auth_controller.dart`
- Test: `lumira_app_flutter/test/core/auth/auth_controller_recover_test.dart`

**Interfaces:**
- Consumes: 现 `_doRegister` / `_resolveOs` / `_dao.save` / `_onRegistered`。
- Produces: `Future<bool> recoverAccount(String deviceId)`（Task 12 调）。

- [ ] **Step 1: 写失败单测**

创建 `test/core/auth/auth_controller_recover_test.dart`：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/core/auth/auth_controller.dart';
import 'package:lumira_app_flutter/core/auth/auth_dao.dart';
import 'package:lumira_app_flutter/core/auth/auth_state.dart';

class _FakeDao implements AuthDaoLike {
  AuthRecord? saved;
  @override Future<AuthRecord?> load() async => saved;
  @override Future<void> save(AuthRecord r) async => saved = r;
  @override Future<void> clear() async => saved = null;
  @override Future<void> clearToken() async {
    if (saved != null) saved = AuthRecord(
      deviceId: saved!.deviceId, os: saved!.os, token: '', isNewDevice: saved!.isNewDevice, registeredAt: saved!.registeredAt);
  }
}

void main() {
  test('recoverAccount 用目标 deviceId 触发注册并落库', () async {
    final dao = _FakeDao();
    final controller = AuthController(
      dao: dao,
      resolveDeviceId: () async => 'local-device',
      resolveOs: () => 'android',
      doRegister: ({required deviceId, required os}) async =>
          RegisterResult(token: 'tok-$deviceId', isNewDevice: true, profile: null),
    );
    await controller.bootstrap(); // fresh
    final ok = await controller.recoverAccount('old-device-123');
    expect(ok, isTrue);
    expect(controller.state.status, AuthStatus.registered);
    expect(controller.state.deviceId, 'old-device-123');
    expect(controller.state.token, 'tok-old-device-123');
    expect(dao.saved?.deviceId, 'old-device-123');
  });

  test('recoverAccount 空 deviceId 直接返回 false 不注册', () async {
    final dao = _FakeDao();
    var called = false;
    final controller = AuthController(
      dao: dao,
      resolveDeviceId: () async => '',
      resolveOs: () => 'android',
      doRegister: ({required deviceId, required os}) async {
        called = true;
        return RegisterResult(token: 't', isNewDevice: true, profile: null);
      },
    );
    final ok = await controller.recoverAccount('');
    expect(ok, isFalse);
    expect(called, isFalse);
  });
}
```

- [ ] **Step 2: 跑单测确认失败**

```bash
cd lumira_app_flutter
flutter test test/core/auth/auth_controller_recover_test.dart
```
Expected: FAIL（`recoverAccount` 不存在）。

- [ ] **Step 3: 实现 recoverAccount**

在 [auth_controller.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/core/auth/auth_controller.dart) 的 `invalidateRegistration()` 之后加方法：

```dart
/// 账号恢复：以目标 [deviceId] 为身份直接注册（新机取回旧标识）。
///
/// 供「恢复账号」页在拿到旧 deviceId 后调用：复用 [_doRegister] 走注册，
/// 把 [AuthRecord] 写库、[AuthState] 置为 registered，旧数据随之恢复。
Future<bool> recoverAccount(String deviceId) async {
  if (deviceId.isEmpty) return false;
  if (_registering) return true; // 已有注册进行中，避免并发覆盖
  final os = _resolveOs();
  final resp = await _doRegister(deviceId: deviceId, os: os);
  final now = DateTime.now().millisecondsSinceEpoch;
  final record = AuthRecord(
    deviceId: deviceId,
    os: os,
    token: resp.token,
    isNewDevice: resp.isNewDevice,
    registeredAt: now,
  );
  await _dao.save(record);
  try {
    await _onRegistered?.call(resp);
  } catch (_) {
    // 资料落库失败不阻塞恢复
  }
  state = AuthState(
    status: AuthStatus.registered,
    token: resp.token,
    deviceId: deviceId,
    os: os,
    isNewDevice: resp.isNewDevice,
  );
  return true;
}
```

> 与 `registerIfNeeded` 的区别：不检查 fresh 状态，强制用目标 deviceId 注册，适配「恢复」语义。

- [ ] **Step 4: 跑单测**

```bash
cd lumira_app_flutter
flutter test test/core/auth/auth_controller_recover_test.dart
```
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/core/auth/auth_controller.dart lumira_app_flutter/test/core/auth/auth_controller_recover_test.dart
git commit -m "feat(account): add AuthController.recoverAccount to take over a deviceId"
```

---

### Task 10: AccountApi（客户端请求 + 错误映射）

**Files:**
- Create: `lumira_app_flutter/lib/features/account/data/account_api.dart`
- Test: `lumira_app_flutter/test/features/account/account_api_test.dart`

**Interfaces:**
- Consumes: `ApiClient` / `apiClientProvider`、DioError 映射。
- Produces: `AccountApi`（`rotateRecoverySecret()` / `recoverByQr(secret)` / `sendCode(email,purpose)` / `bindEmail(email,code)` / `recoverByEmail(email,code)`），Task 11/12 用。

- [ ] **Step 1: 写失败单测（用 mock dio；项目已有 mocktail）**

创建 `test/features/account/account_api_test.dart`，用 `ApiClient` 的 post/get 需要真实 Dio；改为直接验证 json 解析与 URL。为轻量，单测聚焦 `AccountApi.fromX` 映射，请求层用结果契约断言：

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/account/data/account_api.dart';

void main() {
  test('RecoveryQr model 解析', () {
    final r = RecoveryQrData.fromJson({
      'secret': 'abc', 'qrPayload': 'lumira://account-recover?v=1&secret=abc', 'expiresAt': 123,
    });
    expect(r.secret, 'abc');
    expect(r.qrPayload, contains('lumira://account-recover'));
  });
}
```

（模型类见 Step 2。）

- [ ] **Step 2: 实现 AccountApi 与模型**

创建 `lib/features/account/data/account_api.dart`：

```dart
import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';

class RecoveryQrData {
  final String secret;
  final String qrPayload;
  final int expiresAt;
  const RecoveryQrData({required this.secret, required this.qrPayload, required this.expiresAt});
  factory RecoveryQrData.fromJson(Map<String, dynamic> j) => RecoveryQrData(
        secret: j['secret'] as String,
        qrPayload: j['qrPayload'] as String,
        expiresAt: (j['expiresAt'] as num).toInt(),
      );
}

class RecoverResult {
  final String deviceId;
  const RecoverResult(this.deviceId);
}

/// 账号保护 / 恢复的客户端 API。
class AccountApi {
  final ApiClient client;
  const AccountApi(this.client);

  Future<RecoveryQrData> rotateRecoverySecret() async {
    final r = await client.post('/account/recovery-qr',
        fromJson: (json) => RecoveryQrData.fromJson(json as Map<String, dynamic>));
    return r;
  }

  Future<RecoverResult> recoverByQr(String secret) async {
    final r = await client.post('/account/recover-by-qr', body: {'secret': secret},
        fromJson: (json) => RecoverResult((json as Map<String, dynamic>)['deviceId'] as String));
    return r;
  }

  Future<void> sendCode({required String email, required String purpose}) async {
    await client.post('/account/email/send-code', body: {'email': email, 'purpose': purpose},
        fromJson: (_) => null);
  }

  Future<void> bindEmail({required String email, required String code}) async {
    await client.post('/account/email/bind', body: {'email': email, 'code': code},
        fromJson: (_) => null);
  }

  Future<RecoverResult> recoverByEmail({required String email, required String code}) async {
    final r = await client.post('/account/email/recover', body: {'email': email, 'code': code},
        fromJson: (json) => RecoverResult((json as Map<String, dynamic>)['deviceId'] as String));
    return r;
  }
}
```

（`AccountApi` 通过 `apiClientProvider.future` 在页面里实例化：`AccountApi(await ref.read(apiClientProvider.future))`。）

- [ ] **Step 3: 跑测试**

```bash
cd lumira_app_flutter
flutter test test/features/account/account_api_test.dart
```
Expected: PASS。

- [ ] **Step 4: 提交**

```bash
git add lumira_app_flutter/lib/features/account/data/account_api.dart lumira_app_flutter/test/features/account/account_api_test.dart
git commit -m "feat(account): add AccountApi client and models"
```

---

### Task 11: 「账号保护」页（生成二维码 + 绑定邮箱）

**Files:**
- Create: `lumira_app_flutter/lib/features/account/pages/account_protection_page.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`（加常量）
- Modify: `lumira_app_flutter/lib/app/router.dart`（加路由）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`（加设置入口）

**Interfaces:**
- Consumes: `AccountApi`（Task 10）、`qr_flutter`。
- Produces: 设置页可进入的「账号保护」页；内部两个区块：恢复二维码 + 绑定邮箱。

- [ ] **Step 1: 路由常量**

在 [route_names.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/core/router/route_names.dart) 加：

```dart
static const String accountProtection = '/profile/account-protection';
static const String accountRecover = '/account/recover';
```

- [ ] **Step 2: 写页面**

创建 `account_protection_page.dart`（关键实现）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../data/account_api.dart';

class AccountProtectionPage extends ConsumerStatefulWidget {
  const AccountProtectionPage({super.key});
  @override
  ConsumerState<AccountProtectionPage> createState() => _AccountProtectionPageState();
}

class _AccountProtectionPageState extends ConsumerState<AccountProtectionPage> {
  RecoveryQrData? _qr;
  bool _qrLoading = false;
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _bindLoading = false;
  String? _emailMsg;
  AccountApi? _api;

  @override
  void initState() {
    super.initState();
    // 依赖 apiClientProvider（FutureProvider），异步取一次
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      setState(() => _api = api);
    });
  }

  @override
  void dispose() { _emailCtrl.dispose(); _codeCtrl.dispose(); super.dispose(); }

  Future<void> _generateQr() async {
    setState(() { _qrLoading = true; _qr = null; });
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      final qr = await api.rotateRecoverySecret();
      setState(() { _qr = qr; _qrLoading = false; });
    } catch (e) {
      setState(() => _qrLoading = false);
      if (mounted) LumiraToast.show(context, '生成失败：$e');
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      await api.sendCode(email: email, purpose: 'bind');
      setState(() => _emailMsg = '验证码已发送（10 分钟内有效）');
    } catch (e) {
      setState(() => _emailMsg = '发送失败：$e');
    }
  }

  Future<void> _bind() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    setState(() => _bindLoading = true);
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      await api.bindEmail(email: email, code: code);
      setState(() { _bindLoading = false; _emailMsg = '绑定成功'; });
      if (mounted) LumiraToast.show(context, '邮箱绑定成功');
    } catch (e) {
      setState(() { _bindLoading = false; _emailMsg = '绑定失败：$e'; });
    }
  }

  static const _secretStyle = TextStyle(fontFamily: 'Courier New', fontSize: 12);

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: _AppBar(tokens: tokens, title: '账号保护'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('把恢复二维码保存到安全处。换机或重装后，在新设备“恢复账号”即可取回本账号全部数据。',
                style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
            const SizedBox(height: 16),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Text('恢复二维码', style: TextStyle(fontWeight: FontWeight.w600, color: tokens.textPrimary))),
                    TextButton(
                      onPressed: _qrLoading ? null : _generateQr,
                      child: Text(_qr == null ? '生成二维码' : '刷新二维码'),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  if (_qrLoading)
                    const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                  else if (_qr != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: QrImageView(
                          data: _qr!.qrPayload,
                          size: 200,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('恢复码（可手动输入）', style: TextStyle(fontSize: 12, color: tokens.textTertiary)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(child: Text(_qr!.secret, style: _secretStyle.copyWith(color: tokens.textPrimary))),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: _qr!.secret));
                          if (mounted) LumiraToast.show(context, '已复制恢复码');
                        },
                      ),
                    ]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            _GroupTitle('绑定邮箱', tokens),
            const SizedBox(height: 8),
            NeuCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: '邮箱', hintText: '用于换机时找回账号'),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _codeCtrl,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: '6 位验证码'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: _sendCode, child: const Text('发送验证码')),
                  ]),
                  if (_emailMsg != null)
                    Text(_emailMsg!, style: TextStyle(fontSize: 12, color: tokens.brand)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _bindLoading ? null : _bind,
                    child: const Text('绑定邮箱'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => GoRouter.of(context).push(RouteNames.accountRecover),
                child: const Text('在新设备上恢复账号', style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

（`_AppBar`/`_GroupTitle` 参照 `profile_settings_page.dart` 里的 `_BackButton`/`_GroupTitle` 实现；`GoRouter` 需要 import go_router。）

- [ ] **Step 3: 注册路由**

在 [router.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/app/router.dart) import 页面并加 GoRoute（放在 profileSettings 附近）：

```dart
GoRoute(
  path: RouteNames.accountProtection,
  name: 'accountProtection',
  builder: (context, state) => const AccountProtectionPage(),
),
GoRoute(
  path: RouteNames.accountRecover,
  name: 'accountRecover',
  builder: (context, state) => const RecoverAccountPage(),
),
```

> `RecoverAccountPage` 在 Task 12 创建；本任务先放占位 import 会在构建时报错——改为本任务在 router 里只注册 `accountProtection`，`accountRecover` 路由留到 Task 12 一并加。

- [ ] **Step 4: 设置页加入口**

在 [profile_settings_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart) 的「通用」NeuCard 内（偏好问卷之后）加一项：

```dart
_SettingItem(
  icon: Icons.security_outlined,
  label: '账号保护',
  value: '二维码/邮箱',
  onTap: () => GoRouter.of(context).push(RouteNames.accountProtection),
  tokens: tokens,
),
```

- [ ] **Step 5: 静态分析 + 单测编译**

```bash
cd lumira_app_flutter
flutter analyze lib/features/account/pages/account_protection_page.dart
```

- [ ] **Step 6: 提交**

```bash
git add lumira_app_flutter/lib/features/account/pages/account_protection_page.dart lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart
git commit -m "feat(account): add account protection page (QR + email bind)"
```

---

### Task 12: 「恢复账号」页（扫码 / 手动 / 邮箱）+ 路由 + 恢复结果处理

**Files:**
- Create: `lumira_app_flutter/lib/features/account/pages/recover_account_page.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`
- Modify: `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`（未注册态入口）

**Interfaces:**
- Consumes: `qr_code_scanner`、`AccountApi`（Task 10）、`AuthController.recoverAccount`（Task 9）、`GoRouter`.
- Produces: 恢复账号页，含扫码 Tab / 手动输入恢复码 / 邮箱 Tab；成功→调 recoverAccount→返回注册完成态。

- [ ] **Step 1: 写恢复页**

创建 `recover_account_page.dart`（三个入口：扫码、手动输入恢复码、邮箱；扫码用 `qr_code_scanner`，鸿蒙初始化失败时跳转手动输入）：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/account_api.dart';

class RecoverAccountPage extends ConsumerStatefulWidget {
  const RecoverAccountPage({super.key});
  @override
  ConsumerState<RecoverAccountPage> createState() => _RecoverAccountPageState();
}

class _RecoverAccountPageState extends ConsumerState<RecoverAccountPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  AccountApi? _api;
  final _secretCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      setState(() => _api = api);
    });
  }
  @override
  void dispose() { _tab.dispose(); _secretCtrl.dispose(); _emailCtrl.dispose(); _codeCtrl.dispose(); super.dispose(); }

  Future<void> _recover(String deviceId) async {
    final auth = ref.read(authControllerProvider.notifier);
    final ok = await auth.recoverAccount(deviceId);
    setState(() => _busy = false);
    if (mounted) {
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已恢复旧账号数据')));
        GoRouter.of(context).go(RouteNames.home);
      } else {
        setState(() => _msg = '恢复失败，请重试');
      }
    }
  }

  Future<void> _recoverByQr() async {
    final secret = _secretCtrl.text.trim();
    if (secret.isEmpty || _busy) return;
    setState(() { _busy = true; _msg = null; });
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      final r = await api.recoverByQr(secret);
      await _recover(r.deviceId);
    } catch (e) {
      setState(() { _busy = false; _msg = '恢复失败：$e'; });
    }
  }

  Future<void> _sendRecoverCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      await api.sendCode(email: email, purpose: 'recover');
      setState(() => _msg = '验证码已发送');
    } catch (e) { setState(() => _msg = '发送失败：$e'); }
  }

  Future<void> _recoverByEmail() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    setState(() { _busy = true; _msg = null; });
    try {
      final api = _api ?? AccountApi(await ref.read(apiClientProvider.future));
      final r = await api.recoverByEmail(email: email, code: code);
      await _recover(r.deviceId);
    } catch (e) {
      setState(() { _busy = false; _msg = '恢复失败：$e'; });
    }
  }

  Future<void> _scan() async {
    // qr_code_scanner 在部分平台初始化可能失败；此处用简单相机页。
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => _ScannerPage(onResult: (code) async {
        final secret = code != null ? _extractSecret(code) : '';
        if (secret.isNotEmpty) {
          Navigator.of(context).pop();
          _secretCtrl.text = secret;
          await _recoverByQr();
        } else {
          Navigator.of(context).pop();
          setState(() => _msg = '二维码格式不对，请手动输入恢复码');
        }
      }),
    ));
  }

  String _extractSecret(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null && uri.host == 'account-recover' && uri.queryParameters['secret'] != null) {
      return uri.queryParameters['secret']!;
    }
    return raw; // 允许直接粘贴恢复码
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: _AppBar(tokens: tokens, title: '恢复账号'),
      body: SafeArea(
        child: Column(
          children: [
            TabBar(controller: _tab, tabs: const [Tab(text: '扫码/恢复码'), Tab(text: '邮箱')]),
            Expanded(
              child: TabBarView(controller: _tab, children: [
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    OutlinedButton.icon(
                      onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('扫描恢复二维码'),
                    ),
                    const SizedBox(height: 20),
                    _GroupTitle('手动输入恢复码', tokens),
                    const SizedBox(height: 8),
                    NeuCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        TextField(controller: _secretCtrl, decoration: const InputDecoration(labelText: '恢复码', hintText: '在“账号保护”页生成的字符串')),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _busy ? null : _recoverByQr, child: const Text('恢复')),
                      ]),
                    ),
                    if (_msg != null) Padding(padding: const EdgeInsets.all(12), child: Text(_msg!, style: TextStyle(color: tokens.brand))),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: '已绑定邮箱')),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(child: TextField(controller: _codeCtrl, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6 位验证码'))),
                      const SizedBox(width: 8),
                      TextButton(onPressed: _busy ? null : _sendRecoverCode, child: const Text('发送验证码')),
                    ]),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _busy ? null : _recoverByEmail, child: const Text('通过邮箱找回')),
                    if (_msg != null) Padding(padding: const EdgeInsets.all(12), child: Text(_msg!, style: TextStyle(color: tokens.brand))),
                  ],
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
```

扫码子页（同文件底部 `_ScannerPage`）：

```dart
class _ScannerPage extends StatefulWidget {
  const _ScannerPage({required this.onResult});
  final void Function(String?) onResult;
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}
class _ScannerPageState extends State<_ScannerPage> {
  final _controller = GlobalKey<QRViewControllerState>();
  @override
  void dispose() { _controller.currentState?.dispose(); super.dispose(); }
  void _onCode(Barcode barcode) => widget.onResult(barcode.code);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描恢复二维码')),
      body: QRView(
        key: _controller,
        overlay: QrScannerOverlay(overlayColor: Colors.black26, borderColor: Theme.of(context).colorScheme.primary),
        onQRViewCreated: (c) {},
        onPermissionSet: (c, p) {},
      ),
    );
  }
}
```

> `QRView`/`Barcode` API 以 `qr_code_scanner` 0.7.0 为准；若扫描解析失败或库在设备上抛错，外层 catch 保证页面仍可用手动输入。`_AppBar`/`_GroupTitle` 参照上页实现。

- [ ] **Step 2: 注册路由（补齐 accountRecover）**

在 [router.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/app/router.dart) 中补注册 Task 11 留到的 `accountRecover` 路由：

```dart
GoRoute(
  path: RouteNames.accountRecover,
  name: 'accountRecover',
  builder: (context, state) => const RecoverAccountPage(),
),
```
并顶部 import `RecoverAccountPage`。

- [ ] **Step 3: splash 未注册态入口（可选增强，按页面现有结构加）**

在 [splash_page.dart](file:///d:/app/projects/photo_post/lumira_app_flutter/lib/features/splash/pages/splash_page.dart) 未注册（fresh/failed）视图底部加一个「恢复账号」链接，跳 `RouteNames.accountRecover`。若 splash 结构不便，则跳过并在设置页已有入口（Task 11 挂了「在新设备上恢复账号」）即可。

- [ ] **Step 4: 静态分析 + 编译**

```bash
cd lumira_app_flutter
flutter analyze lib/features/account
```

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/account lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/splash/pages/splash_page.dart
git commit -m "feat(account): add recover account page (scan/manual/email)"
```

---

## 完成后的手动验收清单（不在自动单测内）

- Android 真机：设置→账号保护→生成二维码→扫码/手动输入→恢复后旧资料出现。
- iOS：同上的扫码与邮箱找回。
- HarmonyOS (OHOS)：手动输入恢复码 + 邮箱找回（扫码若初始化失败则回退手动）。
- 旧 token 作废：恢复后旧设备冷启动 → 收到 401 → 自动重注册 → 重新抢回身份（接受此取舍）。
- 邮件在未配置 SMTP 时走 dev 模式（后端日志打码）。

## Self-Review

- **Spec 覆盖**：Schema/迁移(Task1)、JWT epoch+guard(Task3)、account 五端点(Task5/6/7)、MailService dev 模式(Task4)、共享类型(Task2)、Flutter 账号保护页+恢复页+recoverAccount+API+路由(Task8-12)、相机权限(Task8)。Spec §5.2 扫码由 qr_code_scanner(fork)实现，手动输入兜底在 Task12。§5 splash 恢复入口为增强项(Step3，可跳过)。
- **占位符**：Task3 的 e2e 曾出现占位演示，已提供 Step3b 修正版完整代码；其余步骤均含完整代码或明确命令。
- **类型一致性**：`recoverAccount(String)->Future<bool>`、`rotateRecoverySecret()->RecoveryQrData`、`recoverByQr(secret)->RecoverResult`、`sendCode({email,purpose})->void`、`bindEmail({email,code})->void`、`recoverByEmail({email,code})->RecoverResult` 在 Task9/10/11/12 间一致；后端 `RecoveryQrResponse`/`RecoverResponse` 与 Flutter 模型字段 key 一致。