# Fix Task 7: 一次性消费防竞态改用 isNull()

独立验证已确认 bug：`drizzle-orm@0.38` 的 `eq(left, right)` 编译为 `` `${left} = ${right}` ``（见 node_modules 里 `sql/expressions/conditions.js`，第 20-22 行），对 null 没有特判，`eq(consumedAt, null)` 会渲染成 `consumed_at = ?`（参数 NULL）。在 MySQL 中 `col = NULL` 恒为假，匹配 0 行 → 消费 UPDATE 是空操作，同一 OTP 可被重复消费/重放。

正确做法：用 drizzle 显式的 `isNull(column)` 生成 `IS NULL`。

## 修改点 1：account.service.ts 两处消费条件

文件：`d:\app\projects\photo_post\lumira-server\packages\backend\src\modules\account\account.service.ts`

- import 增加 `isNull`：`import { and, eq, desc, isNull } from 'drizzle-orm';`
- `bindEmail` 内消费 UPDATE（当前约第 107-109 行）：
  ```ts
  await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
    .where(and(eq(accountOtp.id, otp!.id), isNull(accountOtp.consumedAt)));
  ```
- `recoverByEmail` 内消费 UPDATE（当前约第 143-145 行）：
  ```ts
  await db.update(accountOtp).set({ consumedAt: Math.floor(Date.now() / 1000) })
    .where(and(eq(accountOtp.id, otp!.id), isNull(accountOtp.consumedAt)));
  ```

> 如 ts-jest 对 `isNull` 报「ReferenceError: isNull is not defined」，这是 import 绑定问题，不是 isolatedModules 本身——确认 import 写的是 `import { isNull } from 'drizzle-orm'`（注意 drizzle-orm 的 index 会 re-export 所有 sql/expressions）。若仍报错，改用 `import { isNull } from 'drizzle-orm/sql/expressions/conditions'` 并说明。**不要**回退到 `eq(col, null)`。

## 修改点 2：e2e 补充「重复消费被拒绝」断言

文件：`d:\app\projects\photo_post\lumira-server\packages\backend\test\account.e2e-spec.ts`

在「email bind / recover 成功闭环」用例内，bind 成功后追加：用**同一 code** 再次 bind（同 device + 同 email + 同 code）应返回 400（验证码已使用，因为 consumedAt 已被置位）：

```ts
// 同一 code 二次 bind 应因已消费被拒（一次性消费）
await request(app.getHttpServer())
  .post('/api/v1/account/email/bind')
  .set('Authorization', `Bearer ${freshToken}`)
  .send({ email, code })
  .expect(400);
```

> 注意：请在 bind 完成、recover 开始之前的合适位置插入。若与既有断言冲突（如 freshToken 在该点仍有效），调整顺序。同样地，可在 recover 成功后对同一 code 二次 recover 断言 400。

## 校验

```bash
cd lumira-server/packages/backend
$env:DB_NAME='lumira_test'; $env:DB_PORT='3308'
pnpm test:e2e -- account.e2e-spec
pnpm test
```
Expected：account.e2e-spec 全绿（含新增重放断言）、内部单测 4/4 全绿。

## 提交 + 推送

```bash
git add lumira-server/packages/backend/src/modules/account/account.service.ts lumira-server/packages/backend/test/account.e2e-spec.ts
git commit -m "fix(account): use isNull for one-time OTP consume to prevent replay"
git push origin master; git push github master
```
双端推送为硬要求（AGENTS.md）。只提交这两个文件，工作区其他未提交改动（其他 agent 的 Flutter 改动）**不要**加进来。工作目录：`d:\app\projects\photo_post`。