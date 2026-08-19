# Task 6: AccountService 邮箱 OTP（send-code / bind / recover-by-email）

**Files:**
- Modify: `lumira-server/packages/backend/src/modules/account/account.service.ts`

**Interfaces:**
- Consumes: `accountOtp` 表（Task 1 已建）、`MailService`（Task 4 已有）、`hash.generateOtp`（Task 5）、`devices.email/emailVerifiedAt/sessionEpoch`。
- Produces: `sendEmailCode(email, purpose)` / `bindEmail(deviceId, email, code)` / `recoverByEmail(email, code)`。

> OTP 逻辑将在 Task 7 e2e 中端到端验证；本任务仅实现方法，可不写单测（AccountService 强依赖 DB，单测聚焦纯函数已在 Task 5 完成）。

## Step 1: 实现 OTP 方法（追加到 AccountService）

在 `account.service.ts` 顶部 import 增加 `accountOtp`、`and`、`desc`，并注入 `MailService`；追加：

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

## Step 2: bindEmail / recoverByEmail 实现

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

校验函数（同时供 recover 用）：

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

> 注意：`validateOtp` 的 `otp` 参数类型包含 `purpose`，但实现中并未使用 `opurpose`——这是 brief 原文。你可以保留该字段在类型中（无害），但如 linter 因未使用 `purpose` 字段报错，可移除类型中的 `purpose` 字段。`latestOtp` 返回的对象已携带 `id`、`email`、`codeHash`、`expiresAt`、`consumedAt`、`attempts`。

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

> 因邮箱唯一索引，`eq(devices.email, email)` 至多一条。

## Step 3: 更新 constructor 注入 MailService

将 `AccountService` 构造函数改为：

```ts
constructor(
  private readonly dbService: DatabaseService,
  private readonly mailService: MailService,
) {}
```

确认 `MailService` 已 import（`./mail.service`）。`MailService` 的 `sendCode(email, code)` 在未配置 SMTP 时走 dev 模式仅 `console.log`，方法返回 `Promise<void>`。

## Step 4: 提交

```bash
git add lumira-server/packages/backend/src/modules/account/account.service.ts
git commit -m "feat(account): email OTP send/bind/recover with rate-limit and one-time consume"
```
不要 push。工作目录：`d:\app\projects\photo_post`。运行 `cd lumira-server/packages/backend && pnpm test`（现有 4 个 hash 用例应仍通过，因为 AccountService 未被单测实例化）确保未破坏。若编译层面有 type error（因 MailService constructor 无参数、AccountModule 尚不存在所以本文件暂不会被 Nest 实例化，仅 tsc 校验），需确保 `pnpm build` 或 `npx tsc -p tsconfig.json --noEmit` 通过。