# 账号保护：二维码 / 邮箱 找回账号 设计文档

> **日期**：2026-08-19
> **范围**：Flutter 客户端（`lumira_app_flutter/`）+ 后端（`lumira-server/packages/backend/`）+ 共享类型（`lumira-server/packages/shared/`）

## 1. 目标

解决「设备唯一标识（deviceId）无法稳定获取/换机/恢复出厂设置」时用户数据丢失问题：
当设备标识拿不到稳定值、或用户换了设备，可通过**保存的恢复二维码**或**绑定邮箱**在**新设备**上取回旧账号的数据。

核心思路（用户拍板，刻意保持简单）：

> 找回 = 新设备用「恢复凭证」（二维码密钥 或 邮箱验证码）证明自己有权拿到旧账号的唯一标识（`deviceId`），
> 然后**把旧 `deviceId` 直接当作本机身份写入**。之后所有请求都以旧 `deviceId` 发出，后端按 `deviceId` 查询，
> 旧数据（资料、积分、模板、问卷等）自然全部回来。**无需任何数据迁移。**

## 2. 背景与现状

- 身份模型：`deviceId` 即唯一身份，`devices` 表主键；`user_profiles`、`user_points`、`owned_templates`、
  `questionnaire_records`、`reward_unlocks`、`point_transactions` 等全部以 `deviceId` 为主键/外键。
- JWT：payload 仅 `{ deviceId }`，`expiresIn: 30d`，签名密钥 `JWT_SECRET`。鉴权守卫 `DeviceAuthGuard` 只验签，
  不做会话版本判断。
- 目前**没有**账号 / 邮箱 / 恢复机制 / 发信服务。
- 迁移：`DatabaseService.runMigrations()` 按 `database/migrations/*.sql` 文件名幂等执行。
- 环境变量：后端直接用 `process.env`（无 ConfigModule），例如 `DB_*`、`JWT_SECRET`。

## 3. 设计决策（已与用户确认）

| 决策点 | 结论 |
|---|---|
| 二维码内容 | **恢复密钥**（随机串，服务端只存哈希，可作废旧码）。不直接放 `deviceId`，防止捡码即登录。 |
| 找回后原设备 | 仅 **token 级作废**：找回时给该 `deviceId` 的会话版本号 +1，旧 token 立即失效。**不锁死**旧设备重新注册（旧设备重开会重新注册抢回身份 —— 这是刻意接受的取舍）。 |
| 整体模型 | 不引入 `accounts` 表 / physical_key / 数据迁移。身份仍是 `deviceId`。 |

## 4. 后端设计

### 4.1 Schema 变更（新增迁移 SQL `database/migrations/0NNN-account-recovery.sql`）

`devices` 表新增列：

| 列 | 类型 | 说明 |
|---|---|---|
| `recovery_secret_hash` | VARCHAR(64) NULL | 恢复密钥的 sha256 十六进制哈希。任意时刻每设备一个当前有效密钥；重新生成即轮换。 |
| `recovery_secret_created_at` | INT NULL | 生成时间，用于有效期判定（默认 30 天）。 |
| `email` | VARCHAR(255) NULL | 绑定的邮箱（找回反查用）。 |
| `email_verified_at` | INT NULL | 绑定验证时间。 |
| `session_epoch` | INT **NOT NULL DEFAULT 0** | 会话版本号，用于 token 级作废。 |

索引：`email` 建唯一索引（`UNIQUE`，MySQL 允许多个 NULL，不影响未绑定用户的注册）。
新增表 `account_otp`：

| 列 | 类型 | 说明 |
|---|---|---|
| `id` | INT AUTO_INCREMENT PK | |
| `email` | VARCHAR(255) NOT NULL | 收码邮箱。 |
| `device_id` | TEXT NULL | bind 时为请求方 deviceId；recover 时由邮箱反查后回填，可空。 |
| `purpose` | VARCHAR(16) NOT NULL | `'bind'`（当前设备绑邮箱）或 `'recover'`（新设备找回）。 |
| `code_hash` | VARCHAR(64) NOT NULL | 6 位验证码的 sha256。 |
| `expires_at` | INT NOT NULL | 有效期（10 分钟）。 |
| `consumed_at` | INT NULL | 已消费时间（一次性）。 |
| `created_at` | INT NOT NULL | |

索引：`(email, purpose)`。

### 4.2 JWT 与守卫（token 级作废）

- JWT payload 扩展为 `{ deviceId, epoch }`，`epoch = device.session_epoch`（新设备 0）。
  - `registerDevice`：新设备签发 `epoch: 0`；已存在则用 `existing.sessionEpoch`。
- `DeviceAuthGuard` 增加会话版本校验：
  - 注入 `DatabaseService`，`canActivate` 改为 `async`。
  - 验签后按 `payload.deviceId` 查 `devices.session_epoch`；若 `payload.epoch !== device.session_epoch`（或设备不存在）→ 抛 `UnauthorizedException`（401）。
  - 401 会触发 App 已有的 `invalidateRegistration()` → 清 token → 重注册拿新 token（现有自愈流程，无需改 Flutter 鉴权）。

### 4.3 新增 `account` 模块

模块文件：`src/modules/account/`（controller / service / dto / module），依赖 `DatabaseModule`、`DeviceModule`（复用注册与 epoch 管理）、`JwtModule`。

端点（BASE 为 `/api/v1` 前缀）：

| 方法/路径 | 鉴权 | 入参 | 出参 | 说明 |
|---|---|---|---|---|
| POST `/account/recovery-qr` | DeviceAuthGuard | 无 | `{ secret, qrPayload, expiresAt }` | 生成/轮换恢复密钥。`qrPayload = "lumira://account-recover?v=1&secret=<secret>"`。App 用 `qr_flutter` 渲染二维码。 |
| POST `/account/recover-by-qr` | 无 | `{ secret }` | `{ deviceId }` | 校验密钥 → 命中设备 → 消费（清 hash）→ `session_epoch+1` → 返回旧 `deviceId`；密钥过期则 404/400。 |
| POST `/account/email/send-code` | 无 | `{ email, purpose }` | `{ sent: true }` | 生成 6 位码入库并发送。**限频**：同邮箱每 60s 一次。`purpose ∈ {bind, recover}`。 |
| POST `/account/email/bind` | DeviceAuthGuard | `{ email, code }` | `{ success: true }` | 校验 `bind` 型 OTP 对应本设备 → 写入 `devices.email`、`email_verified_at`。 |
| POST `/account/email/recover` | 无 | `{ email, code }` | `{ deviceId }` | 校验 `recover` 型 OTP → 按 email 反查设备 → `session_epoch+1` → 返回旧 `deviceId`。 |

> 找回端点**不接收** `newDeviceId`：采用简单模型（不做物理设备锁死），App 只需拿回旧 `deviceId` 写入本地即可。刻意省略。

### 4.4 邮件发送 `MailService`

- 使用 `nodemailer`（新增依赖），传输配置读环境变量：`SMTP_HOST` `SMTP_PORT` `SMTP_USER` `SMTP_PASS` `SMTP_FROM` `SMTP_SECURE`。
- **未配置 `SMTP_HOST` 时进入 dev 模式**：不真发信，把验证码 `console.log` 到后端日志并照样返回成功 —— 保证本地/CI 可用。
- 生产部署需在服务器 `.env` 补 `SMTP_*`（写进 `.env.example` 与部署文档）。

### 4.5 安全要点

- 恢复密钥 & 验证码均只存 **sha256 哈希**，DB 泄露也无法直接使用。
- 恢复密钥有效期 30 天，可随时在「账号保护」页重新生成（轮换=旧密钥作废）。
- OTP 一次性（`consumed_at`）、10 分钟过期、每邮箱限频、验证错误尝试上限（如 5 次后锁定该 OTP）。
- `email` 唯一索引保证一个邮箱只对应一个 `deviceId`。

## 5. Flutter 端设计

新增依赖：`qr_flutter`（渲染）、`mobile_scanner`（扫码）。鸿蒙下扫码可用性存疑 → 提供**手动输入恢复码**兜底。

### 5.1 「账号保护」页（已登录设备，从资料/设置进入）

- 区块一「恢复二维码」：按钮「生成/刷新二维码」→ 调 `POST /account/recovery-qr` → `qr_flutter` 渲染 `qrPayload`；下方展示 `secret` 文本 + 「复制」，供手动输入。
- 区块二「绑定邮箱」：邮箱输入框 →「发送验证码」→ 6 位输入 →「绑定」→ 成功提示。

### 5.2 「恢复账号」入口（新设备）

- 在 splash 未注册态与「设置」提供「恢复账号」入口，页面两个 Tab：
  - **扫码**：`mobile_scanner` 全屏扫描 → 解析 `qrPayload` → 取出 `secret` → `recover-by-qr`。
  - **邮箱**：邮箱 → 发送验证码 → 6 位 → `email/recover`。
  - 附「手动输入恢复码」。
- 成功回调：拿到旧 `deviceId` → `AuthController.recoverAccount(deviceId)`：直接以旧 `deviceId` 走注册（复用现有 `doRegister` 注入函数），`AuthDao.save` 写库，状态置 registered → 旧数据出现。

### 5.3 复用现有链路

- 找回成功后**不改** 启动注册/Riverpod provider 结构，仅多一个「带目标 deviceId 注册」入口。
- 401→重注册自愈已存在，session_epoch 作废后由它自发收敛。

## 6. 数据流速览

- 二维码：旧设备生成密钥→用户保存二维码 → 新设备扫码/输入密钥 → `recover-by-qr(secret)` → 返回 `oldDeviceId` → App 写入本地 → 注册 → 旧数据。
- 邮箱：旧设备绑邮箱（send-code→bind）→ 新设备输入邮箱→send-code→输入验证码→`email/recover` → 返回 `oldDeviceId` → 同上。

## 7. 错误处理

- 密钥错误/过期、验证码错误/过期/超限、邮箱未绑定 → 明确业务错误码与中文提示。
- 同一设备既有 QR 又绑邮箱：都以当前 `devices` 行状态为准，两者可共存。
- SMTP 未配置：dev 模式仍返回成功（日志打码），不影响本地/CI。

## 8. 明确不做（Out of Scope）

- 物理设备锁死（找回后旧设备重新注册即抢回身份 —— 已接受）。
- 真实账号体系（用户名/密码、多端并发登录管理）。
- 账号注销 / 解绑。

## 9. 涉及文件

**后端**
- 新增：`src/modules/account/{account.module.ts, account.controller.ts, account.service.ts, dto/*, mail.service.ts}`、`src/database/migrations/0NNN-account-recovery.sql`
- 修改：`src/database/schema.ts`（devices/account_otp 结构）、`src/common/guards/device-auth.guard.ts`（epoch 校验）、`src/modules/device/device.module.ts`（导出/共享供 guard 用 DB——视 DI 需要）、`src/modules/device/device.service.ts`（JWT payload 加 epoch）、`package.json`（nodemailer）、`.env.example`、`../shared` 类型

**Flutter**
- 新增：`lib/features/account/pages/account_protection_page.dart`、`lib/features/account/recovery/`（扫码/邮箱/手动恢复页）、`lib/features/account/data/account_api.dart`
- 修改：`lib/core/auth/auth_controller.dart`（`recoverAccount`）、`lib/app/router.dart`、splash 恢复入口、`lib/core/config/app_config.dart`（如有需）、`pubspec.yaml`（qr_flutter, mobile_scanner）、Android/iOS/OHOS 相机权限声明

## 10. 测试策略

- 后端单测：密钥生成/轮换/哈希、OTP 生成/校验/过期/限频/消费、`recover-by-qr` 与 `email/recover` 的成功与各失败分支、`session_epoch` 递增、guard 的 epoch 不匹配→401。
- 后端 e2e：五个端点全流程（含 SMTP dev 模式）。
- 共享类型：`RegisterDeviceResponse` 相关新类型。
- Flutter 单测：`recoverAccount` 写入记录并触发注册、`AccountApi` 请求/错误映射。
- 迁移：`0NNN-account-recovery.sql` 在空库与已建库上可重复执行（幂等，由 `runMigrations` 保证）。