# 经验模块完善设计（真实数据 + 多来源经验 + 升级积分奖励）

日期：2026-08-19
状态：待评审

## 背景与目标

当前经验（XP）仅「完成每日挑战」会累加，且等级用写死的 `xp ~/ 500 + 1`，称号硬编码。经验来源单一、
非真实数据、无来源明细，升级也没有积分奖励。

目标：
1. 经验改为**真实数据**：从各模块的完成事件中取真实经验。
2. **多来源获取经验**：每日首拍、完成挑战、学习课程、每日首享。
3. **到达指定等级自动获得积分奖励**（幂等，一级只发一次）。

## 经验台账模型（选定：台账 + 实时汇总）

新增本地表 `xp_events`（单行真实数据源），等级 = `SUM(xp_events.amount)`：

```sql
CREATE TABLE xp_events (
  id         TEXT PRIMARY KEY,        -- "{source}:{refId}"
  source     TEXT NOT NULL,           -- 'shoot_daily' | 'challenge' | 'course' | 'share'
  amount     INTEGER NOT NULL,        -- 本次获得经验
  ref_id     TEXT NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE UNIQUE INDEX uq_xp_events_source_ref ON xp_events(source, ref_id);
```

- 幂等：`UNIQUE(source, ref_id)`，同一来源同一事件只记一次。
- 每日首拍 / 每日首享的 `ref_id` 用 **UTC+8 自然日**字符串（与后端积分幂等口径一致，避免时区不一致重复/漏发）。

## 各模块经验来源（真实数据埋点）

| 来源 | 触发点 | 数值 | refId |
|---|---|---|---|
| 每日首拍 | `capture_page.dart` 保存照片成功后（与现有积分 `shoot_daily` 同处） | 每天首次 +10 | UTC+8 日期串 |
| 完成挑战 | `challenge_confirm_page.dart`（原直接改 `user_progress.xp`，改为写台账） | 各挑战 `rewardXP`（沿用真实值） | 挑战 id |
| 学习课程 | `academy_repository.dart` 完成课程（status=completed）处 | 每课 `rewardXP`（真实值 50–200） | courseId |
| 每日首享 | `main.dart` / `share_reporter` 分享成功后 | 每天首次 +20 | UTC+8 日期串 |

经验值等同于真实来源，台账户不会重复累计（幂等）。

## 阶梯等级表（取代 `xp~/500+1`）

| 等级 | 所需总XP | 称号 |
|---|---|---|
| Lv.1 | 0 | 初学者 |
| Lv.2 | 100 | 入门学徒 |
| Lv.3 | 300 | 进阶学徒 |
| Lv.4 | 600 | 熟练学徒 |
| Lv.5 | 1000 | 摄影新手 |
| Lv.6 | 1500 | 摄影爱好者 |
| Lv.7 | 2200 | 摄影达人 |
| Lv.8 | 3000 | 构图能手 |
| Lv.9 | 4000 | 光影大师 |
| Lv.10 | 5500 | 摄影专家 |
| Lv.11 | 7500 | 摄影艺术家 |
| Lv.12 | 10000 | 视觉创作者 |

计算：遍历阈值表求当前等级与下一级；`xpToNextLevel = 下一级阈值 - 总XP`。

## 升级积分奖励（每级小奖 + 里程碑，数值 ×5 后）

`levelReward(level)`：
- Lv.2=25、Lv.3=25、Lv.4=50、Lv.5=100
- 里程碑 Lv.10=250、Lv.15=150、Lv.20=500
- 其余每级（Lv.6–9、11–14、16–19）= 50

### 后端（积分）
`points.service.ts` 新增事件类型 `level_reward`：
- `PointTransactionType` 联合类型加入 `'level_reward'`。
- 后端内置 `LEVEL_REWARD_MAP: Record<number, number>`（即上表），作为积分真值源。
- `earnEvent(type='level_reward', refId=等级字符串)`：查 map，无则抛 `BadRequestException`；
  幂等由 `point_earn_events` 的 UNIQUE(device, type, ref_id) 保证（一级只发一次，重复返回 `granted:false`）。
- 其余代码路径（余额 upsert / 流水 / 广播）复用现有 `earnEvent` 事务。

### 前端（领取）
- 本地新增状态 `user_progress.xp_reward_claimed_level INTEGER DEFAULT 0`（已领取到几级）。
- 每次加经验后重算等级；对 `(claimedLevel, newLevel]` 区间内**存在奖励配置的等级**逐个调用
  `pointsRepository.earn(type:'level_reward', refId:'$level')`：
  - 成功（granted 或已 granted）→ 该级加入已领取状态。
  - **失败（离线/网络）→ 该级保持未领取，下次进入成长中心或任何加经验动作时重试**，避免丢奖。
- 领取成功且余额到账后，Toast 提示「升级奖励 +N 积分」。
- 只把领取成功的等级更新 `claimedLevel`（max），未领取的等级不清。

## 迁移（SQLite v24 → v25）

- 版本提升 `_kDbVersion = 25`。
- `_onCreate`：新增 `xp_events` 表建表（含唯一索引）。
- `_onUpgrade` 增加 `if (oldVersion < 25)` 段：
  1. 建 `xp_events` 表。
  2. `_addColumnIfNotExists(user_progress, xp_reward_claimed_level, 'INTEGER NOT NULL DEFAULT 0')`。
  3. **回填真实历史数据**（老用户也能看到真实经验，不生搬静态值）：
     - `challenge_history`（`status='done'`）→ `source='challenge'`, `amount=reward_xp`, `ref_id=id`。
     - `academy_learning_trajectory` 已完成课程 → `source='course'`, `amount=该课 rewardXP`, `ref_id=course_id`；
       课程的 `rewardXP` 从 `academy_content.dart` 各课程集合构建 `id→rewardXP` 映射查询，找不到的跳过（避免虚增）。
     - 回填使用 `INSERT OR IGNORE` 保证幂等。
  - 失败静默回退，不阻塞启动（沿用现有模式）。

## GrowthDao / 模型改造

- `getTotalXP()`：改为 `SELECT SUM(amount) FROM xp_events`（原 challenge 求和降级移除，因 v25 后表必存在）。
- `getLevel()` / `getLevelName()`：改用阶梯阈值表。
- 新增 `getXpBreakdown()`：按 `source` 分组求和，返回各来源经验，供来源明细卡。
- `GrowthSummary` 增加字段：`xpToNextLevel`（用阈值表）、`levelName`（用阈值表），必要时补 `nextLevelName`。
- `getAchievements()` 保持现有逻辑；`ach_level_5` 解锁判定改用真实等级。

## UI（成长中心）

- 等级区改用阶梯称号与进度（仍展示总 XP / 距下一级）。
- **新增「经验来源明细」卡**：按来源列出「每日首拍 / 完成挑战 / 学习课程 / 每日首享」各项经验与占比，
  直观体现真实数据；来源为空不展示该行。

## 测试

- `test/core/db/growth_dao_test.dart`：
  - 台账求和 → 等级（阈值表边界：0/99/100/300/…）；`xpToNextLevel` 计算；`getXpBreakdown` 聚合。
  - 幂等：同一 source+ref 重复 award 不重复累加。
  - 回填：从 challenge_history / academy 轨迹生成的台账求和正确。
- v25 迁移测试：`test/core/db/migration_v25_test.dart`（表存在、唯一索引、回填正确）。
- 后端：`points.e2e-spec.ts` 增加 `level_reward` 用例（首次发放 / 重复幂等 / 无效等级 400）。
- 前端领取逻辑：单元测试覆盖「在线成功、离线保留下次重试、只更新已领取 max」。

## 验收标准

1. 拍摄首张、完成挑战、学完课程、首次分享分别产生经验，且各只算一次（幂等）。
2. 成长中心等级/称号/进度由真实台账计算，来源明细卡展示各模块真实经验。
3. 达到配置等级（2/3/4/5/10/15/20…）自动获得对应积分，重复不重复发放；离线不丢奖，联网后补发。
4. 老用户升级/迁移后经验曲线不跳变（真实回填）。
5. 后端 `POST /points/earn` 支持 `level_reward`，无效等级返回 400。