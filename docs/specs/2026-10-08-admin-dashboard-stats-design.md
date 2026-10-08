# 后台概览页数据统计优化设计

> 日期：2026-10-08
> 模块：后台管理（admin）+ 后端管理 API（backend）
> 状态：已确认方案，待实施

## 背景与目标

后台「概览」页（`lumira-server/packages/admin/src/app/dashboard/page.tsx`）当前仅展示 10 个通用计数，且「近 7 日趋势图」为占位空数据（后端无 `/admin/stats/trend` 端点）。

本次优化：
1. **实现未实现的趋势图**（修复占位）。
2. **新增多个有运营价值的统计维度**（活跃度、平台分布、用户画像、积分、内容健康度）。
3. 时间口径 **7 / 30 日可切换**（前端按钮）。

不新增数据库表、不新增迁移，全部基于现有表聚合。

## 数据来源（现有表）

| 维度 | 数据表 | 关键字段 |
| ---- | ------ | -------- |
| 活跃度/注册 | `devices` | firstSeenAt（注册）、lastSeenAt（活跃） |
| 邀请 | `invite_records` | activatedAt、status（pending/success）、achievedAt |
| 兑换 | `redemption_records` | redeemedAt |
| 奖励解锁 | `reward_unlocks` | unlockedAt |
| 平台 | `devices`、`user_profiles` | platform、gender、skillLevel、shootFrequency |
| 用户画像 | `user_profiles` | gender、skillLevel、shootFrequency |
| 积分 | `user_points`(balance/totalEarned/totalSpent)、`point_transactions`、`daily_sign_in_records`、`point_earn_events` | — |
| 内容健康度 | `templates`、`feedbacks`、`invite_records.success/pending`、`redemption_code_batches` | isActive、price、status |

## 后端改动（backend）

### 1. 增强 `AdminService.getStats()`（复用 `/admin/stats`，只增不破坏）

在现有返回之上追加字段：

```
dau                    今日活跃设备数（lastSeenAt >= 今日0点）
mau                    近30天活跃设备数
newDevicesThisMonth    本月新增设备数（firstSeenAt >= 当月1日）
platformBreakdown      [{ platform, count }]  按 platform 聚合，倒序
profileBreakdown       { gender:{k:v}, skillLevel:{k:v}, shootFrequency:{k:v} }
totalPointsEarned      累计积分发放
totalPointsSpent       累计积分消耗
totalPointsBalance     在库积分余额之和（可推导，也直接聚合）
todaySignIns           今日签到人次
todayPointEvents       今日积分事件数
totalTemplates         模板总数
activeTemplates        活跃模板数（isActive=1）
paidTemplates          付费模板数（price>0）
pendingFeedbacks       待处理反馈数（status=pending）
inviteSuccessRate      邀请达成率 = success / (success+pending) * 100
totalBatches           兑换码批次总数
```

### 2. 新增 `AdminService.getTrend(days)` + `GET /admin/stats/trend?days=7|30`

返回按天聚合序列：

```
{ days: [ { date:'MM-DD', newDevices, dau, invites, redemptions, rewardUnlocks } ] }
```

聚合口径（逐日）：
- `newDevices`：该日 `firstSeenAt` 区间
- `dau`：该日 `lastSeenAt` 区间
- `invites`：该日 `activatedAt` 区间
- `redemptions`：该日 `redeemedAt` 区间
- `rewardUnlocks`：该日 `unlockedAt` 区间

`days` 缺省 7，`days=30` 取近30日。无数据的日期补 0。

### Controller / DTO
- `@Get('stats/trend')`，`@Query('days')` 解析为 7 | 30（默认 7）。
- 路由注册在既有 `AdminController`，沿用 `AdminAuthGuard`。

## 前端改动（admin）

- **`types/admin.ts`**：扩展 `StatsResponse`（追加上述字段）；新增 `TrendResponse` / `TrendPoint`。
- **`lib/api.ts`**：
  - `getStats()` 复用（类型已扩展）
  - 新增 `getStatsTrend(days)` → `GET /stats/trend?days=`
- **`components/trend-chart.tsx`**：
  - 数据源扩展为 `TrendPoint`，主曲线：注册 / DAU / 邀请激活。
  - 顶部加 7 / 30 日切换按钮（client 组件，`useState` + 重新 fetch）。
- **`app/dashboard/page.tsx`**：
  - 保留原 2x2 + 1x3 卡片。
  - 新增「活跃度」卡组（DAU / MAU / 本月注册）。
  - 新增「平台分布 / 用户画像 / 积分健康 / 内容健康」区块。
  - 启动时并行拉取 `getStats()` + `getStatsTrend(7)`；切换天数时仅重拉趋势。

### 复用组件与展示
- 占比类（平台/画像）复用 `StatsCard` + 简单横向条形（CSS，不引入额外图表库）；趋势图沿用 `recharts`（已在用）。

## 边界与约束

- 纯新增字段与接口，向后兼容，不影响 App / 老后台。
- 无数据库迁移。
- 不采样的 counts 较多（约 20+ 个聚合），概览页为低频页面，性能可接受；如需优化后续可加缓存（登记 future-optimizations）。

## 测试 / 验证

- 后端 `getStats()` 与 `getStatsTrend()` 可本地起服务验证返回结构正确、7/30 聚合长度与值正确、日期补 0。
- 前端渲染无溢出、切换 7/30 图表刷新。

## 后续优化（登记 future-optimizations.md）

- 概览聚合较多，未来可加短 TTL 缓存或定时物化，降低拉取延迟。