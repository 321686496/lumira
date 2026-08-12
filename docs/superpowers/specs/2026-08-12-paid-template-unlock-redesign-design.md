# 付费模板解锁机制改造设计

- 日期：2026-08-12
- 状态：已确认
- 范围：Flutter 主项目（`lumira_app_flutter/`）+ 后端（`lumira-server/packages/backend/` + `packages/shared/`）

## 1. 背景与目标

当前付费模板解锁页存在"看广告解锁 / 分享 / 拍摄 5 张"等**演示假实现**（仅本地 toast + 定时器，不持久化），以及一个价格**硬编码 ¥3.00** 的"直接购买"入口，与后端真实积分价格脱节。用户购买记录虽已落库（`owned_templates` + `point_transactions`），但内置模板（本地定义）无法通过 `POST /templates/exchange` 完成积分兑换——后端 `exchange` 只查 `template_prices` 表，内置模板无定价记录会直接 404。

**目标：**

1. 付费模板解锁方式收敛为两种真实方式：**积分购买**、**兑换码兑换**。
2. 移除看广告解锁与 ¥3.00 付费解锁（假实现）。
3. "分享给好友"入口保留，点击跳转**邀请有礼页**（引导赚积分 / 兑换模板）。
4. 为系统内置的 13 个付费模板各定一个积分价（20/40/60 三档），用户后续可在 Flutter 端随时调整，**调价即时生效**。
5. 用户购买模板数据记录到后端（现有 `owned_templates` + `point_transactions` 已满足，无需新增表）。

## 2. 现状梳理

### 2.1 模板体系

| 模板类型 | 定义位置 | id 形态 | 定价 |
|---|---|---|---|
| 内置模板（29 个） | Flutter `TemplateRegistry`（`lib/features/capture/data/template_registry.dart`），每个模板文件第 16 行 `price:` | 如 `film_vintage`（无前缀） | 13 个付费当前为 3 积分；16 个免费为 0 |
| 远程模板 | 后端 `templates` 表（Admin 创建） | `srv_` + nanoid(12) | `templates.price` + `template_prices.price_credits`（双写） |

内置模板**不在后端**（纯本地定义，sqflite 种子 `is_builtin=1`），不参与 `/templates/list` 同步。

### 2.2 现有后端能力（已满足，无需重复建设）

- `POST /templates/exchange`：积分兑换模板（查 `template_prices` → 扣积分 → 写 `owned_templates` source=`points` → 写流水 type=`exchange_template`）。**当前不支持无定价记录的模板（内置模板）。**
- `POST /redeem`：兑换码兑换（发积分 + 模板所有权，source=`redemption`）。✅ 保留不变。
- `GET /templates/owned`：已拥有模板列表（Flutter 端 `ownedTemplateIdsProvider` 内存缓存）。✅
- 积分体系：`user_points`（balance）、`point_transactions`（流水）、`point_earn_events`（事件幂等）。✅
- 积分获取：每日签到 2 分、每日首拍 2 分、挑战 5 分、邀请奖励、兑换码奖励。

### 2.3 现有 Flutter 解锁页（`templates_unlock_page.dart`）

5 种解锁方式：看广告（假）、分享（假）、拍摄 5 张（假）、兑换码（真）、¥3.00 直接购买（调 `exchange` 但价格硬编码）。

### 2.4 价格显示矛盾

详情页价格来源优先级：mock `details`（`templates_browse_mock_data.dart`）> `TemplateRegistry` > 远程。mock 中存在旧视觉规格残留价格（12/18/24），部分与 registry 冲突（如 `golden_landscape` mock=18 / registry=0），导致同一模板列表页与详情页价格不一致。

## 3. 方案总览

```
解锁页（templates_unlock_page.dart）
├── 积分购买（真实）  → POST /templates/exchange { templateId, priceCredits }
├── 兑换码兑换（真实）→ POST /redeem { code }
└── 分享给好友（改造）→ 跳转 /profile/invite（邀请有礼页）
```

- 移除：看广告解锁、拍摄 5 张、¥3.00 直接购买。
- 内置模板价格以**客户端上报为准**（用户调 Flutter 端 `price` 即时生效）；远程 `srv_` 模板仍以后端 `template_prices` 为准（防篡改，价格由 Admin 控制）。

## 4. 后端改造

### 4.1 `POST /templates/exchange` 支持内置模板

文件：`lumira-server/packages/backend/src/modules/templates/templates.service.ts`（`exchange` 方法，约 57-106 行）、`templates.controller.ts`、`packages/shared/src/types/points.ts`（`ExchangeTemplateRequest`）。

**请求体新增可选字段：**

```ts
interface ExchangeTemplateRequest {
  templateId: string;
  priceCredits?: number; // 客户端上报的积分价格，内置模板必填（≥1）
}
```

**定价逻辑（按 templateId 前缀区分）：**

1. **`srv_` 前缀（远程模板）**：查 `template_prices`（isActive=1）→ 有记录用记录价；无记录抛 `NotFoundException('Template not available for exchange')`（保持现状，防篡改）。
2. **非 `srv_` 前缀（内置模板）**：使用客户端上报的 `priceCredits`，校验 `Number.isInteger(priceCredits) && priceCredits >= 1`，否则抛 `BadRequestException`。同时 **UPSERT 写入 `template_prices`**（`isActive=1`，`updatedAt=now`），记录该内置模板定价（供 Admin / prices 接口可见）。

**后续逻辑不变：** 幂等检查（已拥有抛 `ConflictException`）→ `pointsService.spendPoints(deviceId, price, 'exchange_template', templateId)`（余额不足抛 400）→ 写 `owned_templates`（source=`points`，sourceDetail=`credits:{price}`）→ 返回 `{ success, templateId, spentCredits, balance }`。

> 安全性说明：内置模板价格由客户端上报，攻击者理论上可将上报价改低以减少积分消耗。这是纯积分制（无真实货币）下的取舍；远程模板仍由后端定价，不受影响。

### 4.2 其他后端改动

- `packages/shared/src/types/points.ts`：`ExchangeTemplateRequest` 增加 `priceCredits?: number`。
- 无 schema / 迁移改动（`owned_templates`、`point_transactions`、`template_prices` 均已存在）。

## 5. Flutter 端改造

### 5.1 内置模板定价（20/40/60 三档）

文件：`lib/features/capture/data/templates/*.dart`（13 个付费模板，每个第 16 行 `price:`）。

| 档位 | 积分 | 模板 id |
|---|---|---|
| 基础 | 20 | `film_vintage`、`macro_flower`、`neon_portrait`、`urban_architecture` |
| 进阶 | 40 | `blue_night_portrait`、`dark_indoor_portrait`、`anime_dream_portrait`、`french_lazy_portrait`、`y2k_portrait`、`neon_city_portrait` |
| 高级 | 60 | `elegant_lady_portrait`、`morandi_minimal_portrait`、`purple_dusk_portrait` |

用户后续调整价格 = 直接改对应模板文件的 `price` 字段，**无需改后端**（exchange 以客户端上报为准）。

### 5.2 mock 数据价格统一（`templates_browse_mock_data.dart`）

- `details` / `allTemplates` 中与 TemplateRegistry 同 id 的模板，价格改为与 registry 一致（消除详情页与列表页价格不一致）。
- 旧视觉规格残留、不在 registry 的 mock 模板（如 `custom_golden_landscape`、`landscape_panorama`、`night_neon`、`still_life_warm` 等）：仅当 id 与 registry 付费模板重合时才同步价格；否则保持现状（超出本次范围，不处理旧 mock 残留模板的增删）。

### 5.3 解锁页改造（`templates_unlock_page.dart`）

- **移除**：看广告解锁（`_onWatchAd` + 对应 option）、拍摄 5 张（`_onGoCapture` + 对应 option）、¥3.00 直接购买（`_onPurchase` 中的 ¥3.00 硬编码与 `_PayPopupContent` 的 ¥ 展示）。
- **新增"积分购买"入口**：
  - 显示真实积分价格（来自路由参数 `price`，由详情页传入）。
  - 点击 → 确认弹窗（"消耗 X 积分解锁该模板"，替代原 `_PayPopupContent` 的 ¥3.00 文案）→ 调 `repo.exchange(templateId, priceCredits: price)` → 成功后 `ref.invalidate(ownedTemplatesLoaderProvider)` + toast "消耗 X 积分，余额 Y"。
- **改造"分享给好友"**：点击跳转邀请有礼页（`RouteNames.profileInvite`，`GoRouter.push`），文案改为"邀请好友赚积分 / 解锁模板"。
- **保留"兑换码兑换"**（`_onInputCode`）不变。
- 路由参数：`/templates/unlock?templateId=xxx&price=xxx`（新增 `price` 参数）。

### 5.4 详情页改造（`templates_detail_page.dart`）

- 价格展示 `¥X` / `精选 ¥X` → **"X 积分"**。
- CTA `购买 ¥X` → **"X 积分解锁"**；锁定卡 `¥$price 永久解锁` → `$price 积分解锁`。
- 跳转解锁页时传入 `price` 参数。

### 5.5 Repository 改造

- `lib/features/templates/data/owned_templates_repository.dart`：`exchange(templateId, {int? priceCredits})` 增加可选 `priceCredits`，请求体透传。

## 6. 数据流（改造后）

```
积分购买（内置模板）：
详情页（price 来自 TemplateRegistry/mock）→ 解锁页 → POST /templates/exchange
  { templateId: 'film_vintage', priceCredits: 20 }
→ 后端：非 srv_ → 校验 priceCredits ≥ 1 → UPSERT template_prices(20)
  → spendPoints(-20) → owned_templates(source='points') → 返回 { balance }
→ Flutter：invalidate owned → 详情页变已解锁

积分购买（远程模板）：
同上，但后端以 template_prices 记录为准（priceCredits 被忽略/校验一致性）

兑换码兑换：不变（POST /redeem → 积分 + owned_templates source='redemption'）
```

## 7. 错误处理

| 场景 | 处理 |
|---|---|
| 内置模板 `priceCredits` 缺失 / < 1 / 非整数 | 400 BadRequest |
| 远程模板无定价记录 | 404 Template not available for exchange（现状） |
| 已拥有该模板 | 409 Conflict（现状） |
| 积分余额不足 | 400 Insufficient points balance（现状） |

## 8. 验证方式

1. 后端：`pnpm --filter @lumira/backend typecheck` + e2e 测试（`exchange` 内置模板用例：正常兑换、余额不足、重复兑换、priceCredits 校验）。
2. Flutter：`flutter analyze`。
3. 手动：内置付费模板详情页显示积分价 → 解锁页仅剩 3 种入口 → 积分购买成功 → 详情页解锁 → owned 接口返回记录；积分流水出现 `exchange_template` 负向记录。

## 9. 不做的事（Out of Scope）

- 不新增"看广告 / 拍摄 / 分享得积分"等真实积分机制（仅保留跳转邀请页入口）。
- 不新增购买记录查看页面（Admin 后台已有积分流水 / owned 数据可查，用户确认"现有记录够用"）。
- 不清理旧 mock 残留模板（`custom_golden_landscape` 等）的增删，仅统一与 registry 重合的价格。
- 不改造兑换码批次 Admin 界面。
