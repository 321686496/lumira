# Task 7 一次性 OTP 消费防✗重放修复报告

## 结论
**DONE** — 一次性 OTP 消费改用 `isNull()`，防止同一验证码被重放。已提交并双端推送。

## Bug 根因
`drizzle-orm@0.38` 的 `eq(col, null)` 渲染为 `col = ?`（参数 NULL）。在 MySQL 中 `col = NULL` 恒为 FALSE，消费 UPDATE 匹配 0 行 → 空操作 → OTP 未被置位 consumedAt → 可重复消费/重放。

## 修改点

### 修改点 1：`lumira-server/packages/backend/src/modules/account/account.service.ts`
- 改用 `isNull(accountOtp.consumedAt)`，应用到 `bindEmail`（.where 约 110 行）与 `recoverByEmail`（约 146 行）两处消费 UPDATE。
- **import 处理（踩坑记录）**：`import { isNull } from 'drizzle-orm'` 在 ts-jest 运行时报 `ReferenceError: isNull is not defined`（index 未按预期 re-export 该运行时绑定）。依 brief 回退方案，改为
  ```ts
  import { isNull } from 'drizzle-orm/sql/expressions/conditions';
  ```
  已验证 `conditions.cjs` 内 `isNull` 存在且导出。**未回退**到 `eq(col, null)`。

> ⚠️ 修复期间两次观察到 `account.service.ts` 的改动被外部回退（import 与 recover 处 revert 回 `eq(col,null)`），已三次重新应用。怀疑有 IDE 格式化/并发进程干预；提交前已复核 grep 确认 3 处 `isNull`（1 导入 + 2 使用）均就位。当前提交内容完整。

### 修改点 2：`lumira-server/packages/backend/test/account.e2e-spec.ts`
- 在「email bind / recover 成功闭环」用例、bind 成功之后、recover 之前插入同一 code 二次 bind 断言：
  ```ts
  // 同一 code 二次 bind 应因已消费被拒（一次性消费）
  await request(app.getHttpServer())
    .post('/api/v1/account/email/bind')
    .set('Authorization', `Bearer ${freshToken}`)
    .send({ email, code })
    .expect(400);
  ```
  bind 成功后 consumedAt 已置位 → 二次 bind 命中 `验证码已使用` → 400。

## 校验结果
- `pnpm test:e2e -- account.e2e-spec`：**PASS，6/6**（含新增重放断言）。
- `pnpm test`（内部单测）：**PASS，4/4**。
- 环境：`DB_NAME=lumira_test`、`DB_PORT=3308`。

## 提交与推送
- Commit：`4b97a19` `fix(account): use isNull for one-time OTP consume to prevent replay`
- 仅提交 2 文件：`account.service.ts` + `account.e2e-spec.ts`（未纳入任何 Flutter 工作区改动）。
- Push：
  - `origin`（gitee `huangh-gitee/photo_post`）`d4a0fa9..4b97a19` ✅
  - `github`（`321686496/lumira`）`d4a0fa9..4b97a19` ✅

## 顾虑
1. `isNull` 从 `drizzle-orm/sql/expressions/conditions` 深路径导入（非 index）。这是当前 node_modules 解析下的稳定做法，但依赖内部路径，升级 drizzle 时需留意。
2. 本会话内 `account.service.ts` 改动两次被外部回退，后续 agent 操作该文件时需复查。