# 统一「拍摄打卡」体系重构设计

> 日期：2026-08-17
> 状态：待评审
> 涉及：lumira_app_flutter（Flutter 客户端）

## 1. 背景与问题

当前 App 内存在多处「打卡」相关功能，底层数据源割裂、数字互相矛盾，且存在硬编码 mock 与算法缺陷：

| # | 位置 | 组件 | 当前数据源 | 问题 |
|---|---|---|---|---|
| 1 | 首页 | StreakCard | 挑战历史（`homeStreakProvider`） | 跨周断签 bug；纯展示无点击 |
| 2 | 挑战页 | FlipStreakBar（进度条） | 挑战历史（`weeklyHistoryProvider`） | 与首页打卡数字不一致 |
| 3 | 挑战页 | StreakCard | **硬编码 mock**（`StreakInfo(currentStreak: 1, ...)`） | 假数据，与 #2 重复 |
| 4 | 拍摄日记 | 连续打卡 banner | 照片记录（`diaryStreakProvider`） | 与首页/挑战页数字不一致 |
| 5 | 积分钱包 | SignInCard（每日签到按钮） | 后端签到表 | 激励「点按钮」而非核心行为「拍摄」 |

**核心痛点**：
1. **同一概念、多套数字**：用户会在首页、日记、钱包看到三个互相打架的「连续 N 天」。
2. **激励错位**：签到激励「点按钮」，而 App 核心动作是「拍摄」。
3. **挑战页打卡是假数据 + 重复展示**。
4. **跨周断签**：`homeStreakProvider` 基于 `getWeeklyHistory()`（仅本周一至今），上周连续记录导致跨周连续天数被截断。

## 2. 目标

把全 App 的「打卡」统一为 **「拍摄打卡」**：以「当天有照片（`gallery_items`）」为唯一事实源，首页、挑战页、拍摄日记三处展示**同一套数字**；将「每日签到」改为「首拍自动签到」；「探店打卡」更名为「探店足迹」。彻底解决多数字打架、激励错位、假数据与跨周 bug。

## 3. 关键决策（用户已确认）

1. **打卡定义**：以「当天有照片」为准（`gallery_items`），而非完成挑战。
2. **打卡文案**：「连续打卡」→ **「连续拍摄」**。
3. **首页卡片交互**：可点击，跳转**拍摄日记页**（`RouteNames.galleryDiary`）。
4. **钱包签到**：移除「立即签到」按钮，改为**首拍自动签到**（拍摄成功后自动触发后端签到，幂等）。
5. **挑战页**：移除底部硬编码 mock StreakCard；保留 FlipStreakBar（改用拍摄打卡数据）；补充**挑战规则说明卡** + **挑战成就墙**。
6. **探店打卡**：可见文案统一为「探店足迹」。

## 4. 架构

```
gallery_items（唯一事实源：当天有照片 = 当天打卡）
        │
        ├──▶ 共享拍摄打卡计算（连续天数 + 本周 7 天状态 + 今日是否已拍）
        │         ├──▶ 首页 StreakCard（可点击 → 拍摄日记页）
        │         ├──▶ 挑战页 FlipStreakBar（连续拍摄 N 天 + 本周 x/7）
        │         └──▶ 拍摄日记 banner（保持不变，天然同源）
        │
拍摄成功（capture_page）──▶ 首拍自动签到（POST /sign-in，幂等）──▶ 积分钱包展示
```

- **新增/复用**：统一计算逻辑放在 `gallery/providers/` 下的共享 Provider（复用 `diaryStreakProvider` 同源思路），供首页与挑战页引用。
- **数据流向**：`capture_page.dart` 落库成功 → invalidate 打卡相关 Provider → 首页/挑战页/日记自动刷新。

## 5. 改动清单

### 5.1 首页连续拍摄卡（StreakCard）

**文件**：
- 修改：`lumira_app_flutter/lib/features/home/widgets/streak_card.dart`
- 修改：`lumira_app_flutter/lib/features/home/data/home_providers.dart`
- 修改：`lumira_app_flutter/lib/features/home/pages/home_page.dart`（如涉及点击）

**改动**：
1. `homeStreakProvider` 数据源从 `ChallengeRepository.getWeeklyHistory()` 切换为 `GalleryDao.getAll()`（或 `getByDateRange`），计算：
   - 连续天数：从今天往回数，今天已拍则从今天起算；否则从昨天起算（保持现有「已连续」语义）。
   - 本周 7 天状态：每天是否有照片。
   - **修复跨周断签**：使用全量照片记录而非仅本周。
2. 卡片文案「连续打卡」→「连续拍摄」。
3. 卡片整体可点击，跳转 `RouteNames.galleryDiary`。
4. 删除对 `challenge_providers.dart` / `challenge_models.dart` 的依赖（不再依赖挑战历史）。

### 5.2 挑战页打卡

**文件**：
- 修改：`lumira_app_flutter/lib/features/challenge/pages/challenge_page.dart`
- 修改：`lumira_app_flutter/lib/features/challenge/widgets/flip_summary_widgets.dart`

**改动**：
1. 移除 `challenge_page.dart` 中硬编码 mock 的底部 StreakCard（约 L476-487）。
2. `FlipStreakBar` 数据源从 `weeklyHistoryProvider` 切换为共享拍摄打卡数据：
   - 文案「连续打卡 N 天」→「连续拍摄 N 天」。
   - 「本周 x/7」改为「本周拍摄 x/7」。
3. 在移除位置补充：
   - **挑战规则说明卡**：静态文案（每日翻牌机制、XP 奖励、打卡重置规则）。
   - **挑战成就墙**：复用 `challengeAchievementsProvider` + `AchievementWallCard`，其中 `streak_7`/`streak_15` 的解锁条件从「挑战完成」改为「连续拍摄天数」。
4. 新增共享打卡 Provider 供挑战页引用（见 5.4）。

### 5.3 首拍自动签到 + 积分钱包

**文件**：
- 修改：`lumira_app_flutter/lib/features/capture/pages/capture_page.dart`
- 修改：`lumira_app_flutter/lib/features/points/pages/points_wallet_page.dart`
- 修改：`lumira_app_flutter/lib/features/sign_in/data/sign_in_repository.dart`（如需补充「今日已签到」语义）

**改动**：
1. `capture_page.dart` 落库成功后，若今日尚未自动签到，则调用 `SignInRepository.signIn()`（fire-and-forget，失败静默，绝不阻塞拍照；参照现有 `_earnDailyShootPoints` 模式）。
2. `points_wallet_page.dart` 的 SignInCard：
   - 移除「立即签到」按钮与手动签到交互。
   - 改为展示「今日首拍自动签到」状态 + 连签天数（读 `SignInStatus`）。
3. 注意：`gallery_edit_page.dart` 的「另存为」插入**不**触发签到（那是编辑，不是拍摄）。

### 5.4 共享拍摄打卡 Provider

**文件**：
- 修改：`lumira_app_flutter/lib/features/gallery/providers/gallery_diary_providers.dart`（新增共享计算）

**改动**：在 gallery providers 中新增一个共享 Provider（如 `shootingCheckinProvider`），返回：
```dart
class ShootingCheckin {
  final int streakDays;          // 连续拍摄天数
  final List<WeekDay> weekDays;  // 本周 7 天状态
  final bool shotToday;          // 今日是否已拍
}
```
- 首页 `homeStreakProvider` 与挑战页 `FlipStreakBar` 都引用它。
- `diaryStreakProvider` / `diaryMonthlyStatsProvider` 逻辑保持一致（同源，天然一致）。

### 5.5 探店打卡 → 探店足迹

**文件**：
- 修改：`lumira_app_flutter/lib/features/checkin/pages/checkin_edit_page.dart` 等（可见文案残留「打卡」处）
- 修改：`lumira_app_flutter/lib/features/checkin/widgets/checkin_common.dart`（如含「打卡」文案）

**改动**：统一用户可见文案为「探店足迹」/「记录足迹」/「编辑足迹」。数据库表名、路由 key、类名等**内部标识不改**（避免大范围破坏性改动），仅改 UI 文案。

### 5.6 挑战成就墙（数据层微调）

**文件**：
- 修改：`lumira_app_flutter/lib/features/challenge/data/challenge_repository.dart`

**改动**：`getAchievements()` 中 `streak_7` / `streak_15` 的解锁判定与 progress 改为基于「连续拍摄天数」（需注入共享打卡计算结果，或由 Provider 层转换）。

## 6. 错误处理与边界

- **首拍自动签到**：网络失败静默（不影响拍照）；重复调用由后端 409 幂等兜底；客户端用本地标志避免同一会话重复调用。
- **打卡 Provider 为空**：`gallery_items` 无数据时，返回 `ShootingCheckin(streakDays: 0, weekDays: 全未拍, shotToday: false)`，UI 用空态兜底（沿用现有 `HomeStreakStatus.empty` 模式）。
- **跨周断签**：连续天数基于全量照片记录计算，不再受「本周」范围限制。

## 7. 不在本次范围

- 不改后端签到逻辑（`sign-in.service.ts` 已幂等，保持）。
- 不改「探店打卡」的数据库结构 / 路由名 / 类名，仅改可见文案。
- 挑战页「完成挑战 = 拿 XP」的既有机制保留（只是不再作为打卡数字依据）。

## 8. 验收标准

1. 首页、挑战页 FlipStreakBar、拍摄日记三处的「连续 N 天 / 本周 x/7」数字完全一致。
2. 首页连续拍摄卡可点击，跳转拍摄日记页。
3. 连续跨周时天数不被截断（上周连续 + 本周连续 = 连续相加）。
4. 挑战页无硬编码打卡数据，成就墙中连续拍摄类成就随实际连续天数解锁。
5. 钱包页无「立即签到」按钮；拍照后自动完成当日签到（有网时），离线时静默失败不报错。
6. 「探店打卡」相关用户可见文案全部为「探店足迹」。
