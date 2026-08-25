# 积分经济体系优化 + 邀请有礼阶梯重设计 — 设计文档

> 日期：2026-08-25
> 状态：待实现（设计已与用户确认）
> 关联：`docs/specs/2026-08-21-invite-rewards-enhancement-design.md`（邀请功能基础）

## 1. 背景与目标

现有积分体系存在 4 类问题：

1. **签到与每日首拍"双份积分"重叠**：用户拍一张照实际到账 4 分（签到 +2 + 首拍 +2），但钱包页文案把签到描述成"每日首拍自动完成"，行为与心智不一致。
2. **邀请文案与实现不符**：钱包页写"邀请好友注册，双方各得积分"，但后端邀请只发模板/成就，从未发过积分。
3. **激励曲线粗糙**：等级奖励大部分等级恒 50；模板统一定价 100，无价值分层。
4. **透明度与风控缺失**：获取途径列表不全、流水不显示来源、挑战积分无每日上限、积分永不过期无通胀治理。

**目标**（已与用户确认）：
- 积分**只用于购买/解锁模板**，不新增其他消耗方式。
- 修复积分获取侧的机制重叠、文案不符、曲线粗糙、透明度与风控问题。
- 邀请有礼阶梯改为 **积分 + 解锁付费模板次数 + 成就** 三类奖励。

## 2. 已确认的产品定标

| 项 | 结论 |
|---|---|
| 邀请阶梯方案 | 方案A：每次邀请双方各 +30 积分（每日上限 90），里程碑 1/3/5/10 人 |
| 签到合并 | 合并为「每日首拍」单一事件 +4/天，连签第 7 天额外 +14 |
| 模板定价 | 分层三档：普通 80 / 精品 120 / 旗舰 160 |
| 等级奖励 | 档位递增：Lv2-4:30 / 5-7:60 / 8-10:100 / 11-13:150 / 14-16:200 / 17-19:300 / 20:600 |

## 3. 积分获取侧优化

### 3.1 签到与每日首拍合并

- **现状**：`capture_page` 首拍后分别调用 `signIn()`（发 2 分）与 `POST /points/earn {type:'shoot_daily'}`（发 2 分）。
- **改后**：`sign_in.service.ts` 的 `DAILY_BASE_POINTS` 由 `2` 改为 `4`；`capture_page` 移除对 `shoot_daily` 的独立 earn 调用（签到即含首拍奖励）。
- `points.service.earnEvent` 保留 `shoot_daily` 分支但**不再被调用**（避免线上已缓存/旧客户端报错，保持幂等逻辑不变）。
- 连签第 7 天奖励保持 `DAILY_BASE_POINTS + DAY_7_BONUS = 4 + 14 = 18`。
- 文案统一：钱包页签到卡显示"每日首拍自动签到 +4/天，连签 7 天额外 +14"。

### 3.2 挑战积分每日上限

- **现状**：`challenge` 每次 +5，按 challengeId 幂等，无每日总量上限。
- **改后**：`earnEvent` 的 `challenge` 分支在发分前先统计当天（UTC+8）该设备 `point_earn_events` 中 `type='challenge'` 的记录数，`>= 3` 则返回 `{ granted: false }`（每日最多 3 次挑战计分 = 15 分/天）。
- 依赖 `point_earn_events` 已建索引 `idx_point_earn_events_device(device_id, created_at DESC)`。

### 3.3 等级奖励曲线

后端 `LEVEL_REWARD_MAP` 与 Flutter `growth_models.dart` 的 `LEVEL_REWARD_MAP` 同步更新为档位制：

```ts
{ 2:30, 3:30, 4:30, 5:60, 6:60, 7:60, 8:100, 9:100, 10:100,
  11:150, 12:150, 13:150, 14:200, 15:200, 16:200, 17:300, 18:300, 19:300, 20:600 }
```

> 幂等性不变：按 `level_reward` 的 refId=level 幂等，已领取的等级不受影响。

### 3.4 获取途径列表补全（Flutter）

`points_earn_ways.dart` 补全为：
- 每日签到（每日首拍自动完成）：+4/天，连签 7 天额外 +14
- 每日首次分享：+2/天
- 完成挑战：+5/次（每日最多 3 次）
- 邀请好友：双方各 +30/次，按里程碑额外奖励
- 升级奖励：随等级递增

### 3.5 流水来源显示（Flutter）

`points_wallet_page.dart` 的 `_TxRow` 按后端 `type` 字段映射中文来源（每日签到/每日首拍/完成挑战/每日分享/邀请/兑换码/模板解锁/升级奖励/后台发放），替代通用"积分获得/积分消耗"。

## 4. 模板定价分层

- **体系**：三档定价 `普通 80 / 精品 120 / 旗舰 160`，作为后端 `template_prices` 与 Admin 配价口径。
- **数据调整**：新增 migration 将 `002_points.sql` 预留的 13 条模板价格（当前 100）按档位 UPDATE（见下），保持数据一致。
- **档位分配建议**（可按运营调整）：

| 档位 | 模板 id |
|---|---|
| 普通 80 | macro_flower、urban_architecture、dark_indoor_portrait、blue_night_portrait、purple_dusk_portrait |
| 精品 120 | film_vintage、neon_portrait、french_lazy_portrait、morandi_minimal_portrait、neon_city_portrait、y2k_portrait、anime_dream_portrait |
| 旗舰 160 | elegant_lady_portrait |

- **说明**：`srv_` 远程模板价格本就由 Admin 按 `template_prices` 配置，本次只需统一分档口径；本地内置模板价格由客户端上报，unlock 页展示价跟随后端 `price`。
- **不做**：本轮不对本地内置模板逐个重定价（其价格体系与后端解耦），仅统一后端预留模板分层。

## 5. 邀请有礼阶梯重设计（核心）

### 5.1 奖励构成（三类）

| 类型 | 语义 | 落地 |
|---|---|---|
| 积分 | 直接入账 | `earnPoints`，type=`invite` |
| 解锁付费模板次数 | 获得 N 次免费解锁额度，可在解锁页任选付费模板（不耗积分） | 新增 `user_points.free_unlock_count`，兑换时扣减 |
| 成就 | 荣誉徽章 | 写入 `reward_unlocks`（type=achievement），邀请页阶梯卡片展示 |

### 5.2 每次邀请奖励（即时）

- 邀请人每次邀请成功：**+30 积分**
- 被邀请人首次激活：**+30 积分**（"双方各得"）
- **每日邀请积分上限 90**（= 3 次）：当天第 4 次及以后邀请成功时，邀请关系照常记录、里程碑照常推进，但**不发即时积分**（发 0 分）。

### 5.3 累计里程碑（一次性，按 reward_tiers 配置）

| 档位 | 累计邀请 | 积分 | 解锁次数 | 成就 |
|---|---|---|---|---|
| Lv.1 | 1 | +20 | 1 | 成就「初露锋芒」 |
| Lv.2 | 3 | +80 | 1 | — |
| Lv.3 | 5 | +150 | 2 | 成就「人气达人」 |
| Lv.4 | 10 | +300 | 3 | 成就「社交之星」 |

里程碑积分为"达标时一次性额外发放"，与每次 +30 叠加。`rewards_json` 结构：

```json
[
  {"type":"points","value":20},
  {"type":"unlock_count","value":1},
  {"type":"achievement","id":"ach_invite_1","label":"初露锋芒"}
]
```

### 5.4 存量数据兼容

- `reward_tiers` 旧种子（1/3/5/10 → template/template_pack/achievement）通过 migration `UPDATE/REPLACE` 覆盖为新配置（旧 `reward_unlocks` 记录保留不动）。
- 旧配置已解锁的用户：`reward_unlocks` 已有记录不会重复发放（幂等逻辑不变）；已解锁的旧模板奖励不回收。
- 新配置上线后，里程碑积分/解锁次数按新规则发放。

## 6. 技术实现要点

### 6.1 数据库（migration `023_points_economy.sql`）

```sql
-- 1) 免费解锁次数
ALTER TABLE user_points ADD COLUMN free_unlock_count INT NOT NULL DEFAULT 0;

-- 2) 更新邀请奖励阶梯（覆盖旧种子；INSERT ... ON DUPLICATE KEY UPDATE）
--    四档：1/3/5/10 → 积分+解锁次数+成就

-- 3) 模板价格分层（UPDATE template_prices）
```

`schema.ts` 同步 `userPoints` 增加 `freeUnlockCount: int('free_unlock_count').notNull().default(0)`。

### 6.2 后端服务

**points.service.ts**：
- `LEVEL_REWARD_MAP` 档位化。
- `earnEvent`：challenge 加每日上限（当日 challenge 事件数 >=3 拒发）。
- 新增 `earnFreeUnlocks(deviceId, count, refId)`：事务内累加 `free_unlock_count` + 写流水（type=`invite` 或新类型 `free_unlock`）。
- `getBalance` 返回 `freeUnlockCount`；`spendPointsSync` 保持。
- 新增 `spendFreeUnlockSync(tx, deviceId, refId)`：校验 `free_unlock_count>0` 并扣减 1。

**templates.service.ts**：
- `exchange` 新增支付方式参数 `payBy: 'points' | 'free_unlock'`（默认 points）。
- `free_unlock` 路径：校验并扣 1 次解锁额度（`spendFreeUnlockSync`），不扣积分；`owned_templates.source = 'free_unlock'`；余额不足/无额度抛对应异常。
- `exchange` DTO 增加 `payBy` 可选字段。

**invite.service.ts**：
- `activateInvite` 内：每次邀请成功后——
  1. 计算当日邀请数，`<=3` 则 `earnPoints(inviter, 30, 'invite', inviteeId)` 与 `earnPoints(invitee, 30, 'invite', inviterId)`；超过则发 0 分（关系照常）。
  2. 按现有 `rewardUnlocks` 幂等逻辑检查新达成的里程碑，逐档发放：`points` → earnPoints；`unlock_count` → earnFreeUnlocks；`achievement` → 写 rewardUnlocks。
- `getInviteStats` 增加 `freeUnlockCount`、每日剩余可领积分邀请数等信息（供前端渲染）。

**points.controller.ts**：`POST /points/earn` 响应已含 granted/delta/balance，无需破坏性变更。

### 6.3 Flutter 端

**模型**：
- `PointsBalance` 增加 `freeUnlockCount`。
- `invite_models.dart` 的阶梯奖励支持 points/unlock_count/achievement 三类型渲染。

**页面**：
- `points_wallet_page.dart`：流水来源 label；余额卡可展示"免费解锁次数"。
- `points_earn_ways.dart`：补全途径。
- `invite_page.dart`：阶梯卡片动态渲染三类奖励；文案与后端一致（"双方各得积分"现已真实）。
- `templates_unlock_page.dart`：当 `freeUnlockCount > 0` 时，确认弹窗提供「消耗积分解锁」与「使用免费解锁次数」两个选项。

**growth_models.dart**：`LEVEL_REWARD_MAP` 档位化（与后端一致）。

### 6.4 Admin 后台
- `reward_tiers` 仍以种子/直改库维护，不新增配置 UI（沿用既有决策）。
- 模板价格分档口径写入文档/注释。

## 7. 测试与验收

### 后端
- 更新 `points.e2e-spec.ts`：challenge 每日上限（第 4 次返回 granted:false）；level_reward 档位曲线。
- 更新 `invite.e2e-spec.ts`：每次邀请双方各 30 分；每日第 4 次不发即时积分；里程碑发积分+解锁次数+成就；rewardUnlocks 幂等。
- 更新 `redeem.e2e-spec.ts` / `templates.e2e-spec.ts`：exchange 用 free_unlock 支付路径。
- `pnpm --filter @lumira/backend typecheck` + e2e 全绿。

### Flutter
- 更新对应 unit/widget 测试：流水来源 label、获取途径列表、freeUnlockCount 展示、邀请阶梯渲染。
- `flutter analyze` 0 错误；相关测试通过。

### 验收清单
1. 首拍后余额 +4（合并签到），连签第 7 天 +18。
2. 挑战每日最多 +15。
3. 升级奖励按新档位发放。
4. 邀请成功双方各 +30，每日 3 次封顶；里程碑 1/3/5/10 发放积分+解锁次数+成就。
5. 解锁页可用免费解锁次数解锁付费模板（不扣积分）。
6. 钱包页流水显示来源；获取途径列表完整。
7. 模板价格按 80/120/160 分档展示。

## 8. 范围与不做

- **不做**：新增积分消耗方式（去水印/皮肤/称号等）——积分仅用于购买模板。
- **不做**：积分过期/定期清零机制（保留长期余额；通胀治理靠挑战上限 + 邀请上限控制流入）。
- **不做**：邀请成就并入成长中心/挑战成就墙（本轮仅作为邀请页阶梯奖励展示）。
- **不做**：Admin 新增 reward_tiers 配置 UI。

## 9. 部署

- 改动集中在 `lumira-server/packages/backend/**`（migration + service + dto）与 `lumira_app_flutter/**`。
- 后端改动 commit 后 push `origin`(gitee) 与 `github`，触发 `backend-deploy.yml`；migration 在容器启动时由 `database.service` 自动执行。
- Flutter 端按惯例不自动部署，由用户指示构建发布。
