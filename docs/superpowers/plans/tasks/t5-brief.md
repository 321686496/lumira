# Task 5: AccountService 单测（恢复密钥 + recover-by-qr）

**Files:**
- Create: `lumira-server/packages/backend/src/modules/account/hash.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.service.ts`
- Create: `lumira-server/packages/backend/src/modules/account/account.service.spec.ts`

**Interfaces:**
- Consumes: `devices.recoverySecretHash`/`recoverySecretCreatedAt`/`sessionEpoch`；node `crypto`.
- Produces: `AccountService` 方法 `rotateRecoverySecret(deviceId)` / `recoverByQr(secret)`（Task 6 继续加 OTP 方法、Task 7 controller 复用）。

## Step 1: 写失败单测

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

## Step 2: 跑单测确认失败

```bash
cd lumira-server/packages/backend
pnpm test -- account.service.spec
```
Expected: FAIL（模块/文件不存在）。

## Step 3: 实现 AccountService（QR 部分）

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

> 注意：不要实现 Task 6 的 OTP 方法（sendEmailCode/bindEmail/recoverByEmail），也不要注入 MailService——那是下一个任务的范围。本任务只做 QR 两方法 + hash 纯函数 + 单测。

## Step 5: 跑单测通过

```bash
cd lumira-server/packages/backend
pnpm test -- account.service.spec
```
Expected: PASS（4 个 hash 用例）。

## Step 6: 提交

```bash
git add lumira-server/packages/backend/src/modules/account/hash.ts lumira-server/packages/backend/src/modules/account/account.service.ts lumira-server/packages/backend/src/modules/account/account.service.spec.ts
git commit -m "feat(account): add sha256 utilities and QR recovery secret service"
```
（不要 push——controller 会统一推送。如存在未推送说明则忽略。）

## 全局约束提醒

- 本项目无独立 mock 库，单测聚焦纯函数 hash.ts。
- AccountService 依赖 DatabaseService.getDb()，它使用真实 MySQL；本任务单测只测纯函数，不实例化 AccountService。若实例化会导致 DB 依赖，避免之。
- Drizzle `devices` 表（`src/database/schema.ts`）已含 `recoverySecretHash`/`recoverySecretCreatedAt`/`sessionEpoch` 字段（Task 1 已迁移）。
- 工作目录：`d:\app\projects\photo_post`