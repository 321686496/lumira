# Task 6 报告：AccountService 邮箱 OTP（send-code / bind / recover-by-email）

**状态：DONE**

## 实现内容

仅修改 `lumira-server/packages/backend/src/modules/account/account.service.ts`，未创建任何 module/controller（Task 7 职责）。

1. **Import 更新**
   - `drizzle-orm` 增加 `and`、`desc`（保留原有 `eq`）。
   - `../../database/schema` 增加 `accountOtp`（保留 `devices`）。
   - `./hash` 增加 `generateOtp`（保留 `sha256Hex`、`generateSecret`）。
   - 新增 `import { MailService } from './mail.service';`。
   - 新增常量 `OTP_TTL_SECONDS`(600)、`OTP_SEND_COOLDOWN`(60)、`OTP_MAX_ATTEMPTS`(5)。

2. **Constructor 注入**：新增 `private readonly mailService: MailService` 参数。

3. **新增方法**
   - `private latestOtp(email, purpose)`：按 id 倒序取该邮箱+purpose 最新一条 OTP。
   - `async sendEmailCode(email, purpose)`：邮箱格式校验 → 冷却期校验 → `generateOtp()` → 写库（存 SHA-256 哈希）→ `mailService.sendCode` → 返回 `{ sent: true }`。
   - `async bindEmail(deviceId, email, code)`：校验 OTP → 一次性消费 → 更新 `devices.email / emailVerifiedAt`。
   - `private validateOtp(...)`：错误/不匹配/已使用/已过期/超次数/错误码校验，错误校验 fire-and-forget 增加 attempts。
   - `async recoverByEmail(email, code)`：校验 OTP → 消费 → 按 email 唯一索引定位 device → `sessionEpoch + 1` 使旧 token 失效 → 返回 deviceId。

## 与 brief 的偏差（必要修正）

brief Step 2 中 `validateOtp` 的参数类型为 `{ purpose: string; ... }`（含未使用的 `purpose`、缺失 `id`）。但 `validateOtp` 实现与调用方 (`bindEmail`/`recoverByEmail` 的 `otp!.id`) 都实际使用了 `id`。为通过 tsc，将类型改为 `{ id: number; email; codeHash; expiresAt; consumedAt; attempts }`，并移除未使用的 `purpose`（符合 brief 注）。
> 若 `id` 未纳入类型，`pnpm build` 会报 `TS2339: Property 'id' does not exist`。

## 测试 / 类型检查结果

- `pnpm test`：Pass，4/4（account hash utils 四个用例，未实例化 AccountService）。
- `npx tsc -p tsconfig.json --noEmit`：**不可用**（backend 包内未安装 typescript，npx 提示找不到 tsc；tsc 被提升到 monorepo root）。
- `pnpm build`（`tsc -p tsconfig.build.json`）：**Pass**，exit 0，编译无错误。

## 文件变更

- 修改：`lumira-server/packages/backend/src/modules/account/account.service.ts`（+91/−4），含末尾换行符（trailing newline）。

## 提交

- `fefe75d` `feat(account): email OTP send/bind/recover with rate-limit and one-time consume`
- 仅提交该文件，未 push。

## 自检

- 构造注入顺序与 brief 一致（dbService、mailService）。
- `latestOtp` 返回行含 id/codeHash/expiresAt/consumedAt/attempts，满足 `validateOtp` 入参。
- `recoverByEmail` 依赖 devices.email 唯一索引（schema 已确认 `uq_devices_email`），至多一条。
- mailService.sendCode 为 `Promise<void>`，dev 模式无 SMTP 时仅日志、视为成功。