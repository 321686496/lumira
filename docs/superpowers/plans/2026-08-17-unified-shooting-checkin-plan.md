# 统一「拍摄打卡」体系重构实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use `subagent-driven-development` (recommended) or `executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将全 App 的打卡统一为「拍摄打卡」（当天有照片 = 打卡），修复跨周断签 bug，首页可点击跳转，挑战页移除假数据并补充规则说明 + 成就墙，首拍自动签到，探店文案统一为「探店足迹」。

**Architecture:** 在 `gallery_diary_providers.dart` 中新增共享 `shootingCheckinProvider`，基于 `GalleryDao.getAll()` 计算连续天数 + 本周状态；首页 `homeStreakProvider` 改为依赖此共享 Provider；挑战页 FlipStreakBar 同样依赖它；移除挑战页底部硬编码 mock StreakCard，补充「挑战规则说明卡」；`capture_page.dart` 落库成功后自动触发签到（幂等）；积分钱包移除「立即签到」按钮；探店可见文案改为「探店足迹」。

**Tech Stack:** Flutter 3.7.12 + Dart 2.19.6 + flutter_riverpod 2.3.6 + sqflite

## Global Constraints

- 不修改后端代码（`sign-in.service.ts` 保持现有幂等）
- 仅修改用户可见文案，不修改数据库表名 / 路由 key / 类名（避免破坏性改动）
- 保持当前渐变风格、圆角卡片设计一致性
- 摄影编辑页「另存为」插入不算新拍摄，不触发自动签到
- 挑战成就 `streak_7` / `streak_15` 改为基于连续拍摄天数解锁

---

## Task 1: 新增共享拍摄打卡 Provider

**Files:**
- Modify: `lumira_app_flutter/lib/features/gallery/providers/gallery_diary_providers.dart`

**Interfaces:**
- Consumes: `galleryDaoProvider`（已有）
- Produces:
  ```dart
  class ShootingCheckin {
    final int streakDays;          // 连续拍摄天数
    final List<WeekDay> weekDays;  // 本周 7 天状态（周一至周日，与首页现有 WeekDay 兼容）
    final bool shotToday;          // 今日是否已拍摄
  }

  final shootingCheckinProvider = FutureProvider<ShootingCheckin>((ref) async { ... });
  ```

- [ ] **Step 1: 引入 WeekDay 定义**

将首页 `WeekDay` 定义（复用现有结构）复制到本文件顶部：
```dart
/// 本周某一天打卡状态（与首页 HomeStreakStatus 结构对齐）
class WeekDay {
  final String label;
  final bool done;
  final bool today;

  const WeekDay({required this.label, required this.done, required this.today});
}

/// 统一拍摄打卡状态
class ShootingCheckin {
  final int streakDays;
  final List<WeekDay> weekDays;
  final bool shotToday;

  const ShootingCheckin({
    required this.streakDays,
    required this.weekDays,
    required this.shotToday,
  });

  static const empty = ShootingCheckin(
    streakDays: 0,
    weekDays: [
      WeekDay(label: '一', done: false, today: false),
      WeekDay(label: '二', done: false, today: false),
      WeekDay(label: '三', done: false, today: false),
      WeekDay(label: '四', done: false, today: false),
      WeekDay(label: '五', done: false, today: false),
      WeekDay(label: '六', done: false, today: false),
      WeekDay(label: '日', done: false, today: false),
    ],
    shotToday: false,
  );
}
```

- [ ] **Step 2: 实现计算逻辑**

```dart
final shootingCheckinProvider = FutureProvider<ShootingCheckin>((ref) async {
  final dao = await ref.watch(galleryDaoProvider.future);
  final records = await dao.getAll();

  // 格式化日期工具函数
  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // 构建已拍摄日期集合
  final shotDates = <String>{};
  for (final r in records) {
    final dt = DateTime.fromMillisecondsSinceEpoch(r.createdAt);
    shotDates.add(_formatDate(dt));
  }

  // 计算本周 7 天状态（周一到周日）
  final now = DateTime.now();
  final dayOfWeek = now.weekday; // 1=Mon..7=Sun
  final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: dayOfWeek - 1));
  final today = DateTime(now.year, now.month, now.day);
  final todayStr = _formatDate(today);
  const labels = ['一', '二', '三', '四', '五', '六', '日'];

  final weekDays = <WeekDay>[];
  for (var i = 0; i < 7; i++) {
    final d = monday.add(Duration(days: i));
    final ds = _formatDate(d);
    weekDays.add(WeekDay(
      label: labels[i],
      done: shotDates.contains(ds),
      today: ds == todayStr,
    ));
  }

  // 计算连续拍摄天数：从今天往回数，今天已拍则从今天起算；否则从昨天往回数
  int streak = 0;
  if (shotDates.contains(todayStr)) {
    streak = 1;
    var cursor = today.subtract(const Duration(days: 1));
    while (shotDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  } else {
    final yesterday = today.subtract(const Duration(days: 1));
    var cursor = yesterday;
    while (shotDates.contains(_formatDate(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
  }

  return ShootingCheckin(
    streakDays: streak,
    weekDays: weekDays,
    shotToday: shotDates.contains(todayStr),
  );
});
```

- [ ] **Step 4: 保持原有 `diaryStreakProvider` / `diaryMonthlyStatsProvider` 兼容**

现有 `diaryStreakProvider` 计算逻辑不变（与新 Provider 同源，天然一致），无需修改。

- [ ] **Step 5: Commit**

```bash
git add lib/features/gallery/providers/gallery_diary_providers.dart
git commit -m "feat(gallery): add shared shootingCheckinProvider for unified checkin"
```

**Expected commit:** 新增 ~100 行代码，无破坏性改动。

---

## Task 2: 首页 StreakCard 改造（文案 + 点击 + 数据源切换）

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/data/home_providers.dart`
- Modify: `lumira_app_flutter/lib/features/home/widgets/streak_card.dart`
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart`

**Interfaces:**
- Consumes: `shootingCheckinProvider`（Task 1 产物）
- Produces: 首页卡片可点击跳转 `RouteNames.galleryDiary`

- [ ] **Step 1: 修改 `homeStreakProvider` 数据源切换**

```dart
final homeStreakProvider = FutureProvider<HomeStreakStatus>((ref) async {
  final checkin = await ref.watch(shootingCheckinProvider.future);
  // 直接复用 shootingCheckin 的 weekDays 与 streakDays
  return HomeStreakStatus(
    streakDays: checkin.streakDays,
    weekDays: checkin.weekDays
        .map((wd) => WeekDay(
              label: wd.label,
              done: wd.done,
              today: wd.today,
            ))
        .toList(),
  );
});
```

删除原方法中基于 `ChallengeRepository.getWeeklyHistory()` 的所有代码；删除对 `challenge_providers.dart` / `challenge_models.dart` 的 import。

- [ ] **Step 2: 修改 StreakCard 文案 + 添加点击跳转**

在 `StreakCard` 外层包 `GestureDetector`：

```dart
class StreakCard extends ConsumerWidget {
  const StreakCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final asyncStreak = ref.watch(homeStreakProvider);

    final streak = asyncStreak.valueOrNull ?? HomeStreakStatus.empty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () {
          GoRouter.of(context).push(RouteNames.galleryDiary);
        },
        behavior: HitTestBehavior.opaque,
        child: NeuCard(
          // ... 其余代码不变，仅修改文本
          children: [
            // ...
                Text(
                  '连续拍摄', // 原文字为 '连续打卡'
                  style: TextStyle(...),
                ),
            // ...
          ],
        ),
      ),
    );
  }
}
```

修改 `'连续打卡'` → `'连续拍摄'`。

- [ ] **Step 3: 增加 `GoRouter` / `RouteNames` import**

在 `streak_card.dart` 顶部添加：
```dart
import 'package:go_router/go_router.dart';
import '../../../core/router/route_names.dart';
```

- [ ] **Step 4: 运行 flutter analyze 检查编译错误**

```bash
flutter analyze lib/features/home/
```

预期：无错误。

- [ ] **Step 5: Commit**

```bash
git add lib/features/home/data/home_providers.dart lib/features/home/widgets/streak_card.dart
git commit -m "feat(home): switch homeStreakProvider to shootingCheckin, add tap to jump to diary"
```

---

## Task 3: 挑战页 FlipStreakBar 数据源切换 + 文案修改

**Files:**
- Modify: `lumira_app_flutter/lib/features/challenge/widgets/flip_summary_widgets.dart`

**Interfaces:**
- Consumes: `shootingCheckinProvider`（Task 1 产物）
- Produces: 挑战页进度条使用统一拍摄数据，文案改为「连续拍摄 N 天」

- [ ] **Step 1: 修改 `FlipStreakBar` build 方法数据源**

原 `weeklyHistoryProvider` 引用替换为 `shootingCheckinProvider`：

```dart
class FlipStreakBar extends ConsumerWidget {
  const FlipStreakBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final checkinAsync = ref.watch(shootingCheckinProvider);

    return checkinAsync.when(
      loading: () => _SkeletonBar(tokens: tokens),
      error: (_, __) => _SkeletonBar(tokens: tokens),
      data: (checkin) {
        // 本周完成数 = 本周已拍天数
        final weeklyDone = checkin.weekDays.where((d) => d.done).length;
        const weeklyTotal = 7;
        final progress = (weeklyDone / weeklyTotal).clamp(0.0, 1.0);

        final tipMessage = _buildTipMessage(checkin.streakDays, weeklyDone);

        return NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.local_fire_department_outlined,
                      size: 18, color: tokens.brand),
                  const SizedBox(width: 6),
                  Text(
                    '连续拍摄 ${checkin.streakDays} 天', // 原：连续打卡
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '本周拍摄 $weeklyDone/$weeklyTotal', // 原：本周 x/7
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              // ... 进度条代码不变
```

删除原 `_computeStreak` 方法（不再需要基于挑战历史计算）。删除 `weeklyHistoryProvider` import。增加 `shootingCheckinProvider` import。

- [ ] **Step 2: 修改 `_buildTipMessage` 文案**

```dart
String _buildTipMessage(int streak, int weeklyDone) {
  if (streak == 0) return '今天拍摄一张照片开启打卡'; // 原：今天翻牌并完成挑战开启打卡
  if (streak >= 7) return '已坚持一周，再接再厉！';
  final remain = 7 - streak;
  return '再坚持 $remain 天获得额外 50 XP';
}
```

修改骨架屏文字：

```dart
Text(
  '连续拍摄 - 天', // 原：连续打卡 - 天
  ...
),
```

- [ ] **Step 3: 增加需要的 imports**

在文件顶部添加：
```dart
import '../../gallery/providers/gallery_diary_providers.dart';
```

- [ ] **Step 4: 运行 flutter analyze 检查**

```bash
flutter analyze lib/features/challenge/widgets/flip_summary_widgets.dart
```

预期：无错误。

- [ ] **Step 5: Commit**

```bash
git add lib/features/challenge/widgets/flip_summary_widgets.dart
git commit -m "feat(challenge): switch FlipStreakBar to shootingCheckin, update copy"
```

---

## Task 4: 挑战页移除假 StreakCard，补充挑战规则说明卡

**Files:**
- Modify: `lumira_app_flutter/lib/features/challenge/pages/challenge_page.dart`
- Create: `lumira_app_flutter/lib/features/challenge/widgets/challenge_rules_card.dart` (新文件)

**Interfaces:**
- Produces: `ChallengeRulesCard` 静态说明卡片，插入在 `AchievementWallCard` 上方（原 StreakCard 位置）

当前挑战页布局（约 line 460-490）：
```
...
const SizedBox(height: 32),
// 5. 拍摄技巧
FadeUp(child: ChallengeTipCard()),
const SizedBox(height: 32),
// 6. 假 StreakCard（移除）
FadeUp(child: StreakCard(...)) → 删除此块
替换为：
const SizedBox(height: 32),
// 6. 挑战规则说明
FadeUp(
  delay: const Duration(milliseconds: 480),
  child: ChallengeRulesCard(),
),
const SizedBox(height: 16),
// 7. 挑战成就墙（保留，顺序后移一位）
...
```

- [ ] **Step 1: 创建 `ChallengeRulesCard`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';

/// 挑战规则说明卡
class ChallengeRulesCard extends ConsumerWidget {
  const ChallengeRulesCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '挑战规则',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _RuleItem(
            number: '1',
            text: '每天进入挑战页会随机翻出 3 道选题，选一道开始拍摄',
            tokens: tokens,
          ),
          const SizedBox(height: 8),
          _RuleItem(
            number: '2',
            text: '完成挑战可获得对应 XP，连续拍摄 7/15 天解锁额外成就',
            tokens: tokens,
          ),
          const SizedBox(height: 8),
          _RuleItem(
            number: '3',
            text: 'XP 累计提升等级，等级越高解锁更多拍摄套件',
            tokens: tokens,
          ),
        ],
      ),
    );
  }
}

class _RuleItem extends StatelessWidget {
  final String number;
  final String text;
  final ThemeTokens tokens;

  const _RuleItem({
    required this.number,
    required this.text,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: tokens.brand,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: 修改 `challenge_page.dart` import 与布局**

添加 import：
```dart
import '../widgets/challenge_rules_card.dart';
```

删除底部硬编码 StreakCard（约 L475-487，位于「拍摄技巧」之后）：
```dart
// 删除整个 FadeUp 包裹的 StreakCard
// FadeUp(...) { const StreakCard(...) }
```

在原 StreakCard 位置（「拍摄技巧」之后）插入 `ChallengeRulesCard`：
```dart
const SizedBox(height: 32),
// 挑战规则说明
const FadeUp(
  delay: Duration(milliseconds: 480),
  child: ChallengeRulesCard(),
),
```
> 注意：挑战成就墙 `AchievementWallCard` 已在更上方（「荣誉墙」section，约 L447-459）展示，无需重复添加。规则卡放在底部原 StreakCard 位置即可。

删除文件顶部 `import '../widgets/streak_card.dart';`（不再需要）。

- [ ] **Step 3: 检查 compile**

```bash
flutter analyze lib/features/challenge/pages/challenge_page.dart lib/features/challenge/widgets/challenge_rules_card.dart
```

预期：无错误。

- [ ] **Step 4: Commit**

```bash
git add lib/features/challenge/pages/challenge_page.dart
git add lib/features/challenge/widgets/challenge_rules_card.dart
git commit -m "feat(challenge): remove mock StreakCard, add ChallengeRulesCard"
```

---

## Task 5: 挑战成就 `streak_7`/`streak_15` 按连续拍摄天数更新进度

**Files:**
- Modify: `lumira_app_flutter/lib/features/challenge/data/challenge_repository.dart`

**Interfaces:**
- Consumes: `galleryDao` (已有)
- Produces: `streak_7` / `streak_15` 解锁状态基于 `shootingCheckin.streakDays`

- [ ] **Step 1: 修改 `getAchievements()` 方法**

在 `getAchievements()` 开头增加：
```dart
// 获取连续拍摄天数（需要从 galleryDao 计算）
final allPhotos = await galleryDao.getAll();
final shotDates = <String>{};
for (final p in allPhotos) {
  final dt = DateTime.fromMillisecondsSinceEpoch(p.createdAt);
  final ds = '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  shotDates.add(ds);
}
// 计算连续天数
int currentStreak = 0;
final today = DateTime.now();
final todayStr = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
if (shotDates.contains(todayStr)) {
  currentStreak = 1;
  var cursor = today.subtract(const Duration(days: 1));
  while (shotDates.contains('${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}')) {
    currentStreak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
} else {
  final yesterday = today.subtract(const Duration(days: 1));
  var cursor = yesterday;
  while (shotDates.contains('${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}-${cursor.day.toString().padLeft(2, '0')}')) {
    currentStreak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
}
```

修改 `streak_7` 和 `streak_15` 两行：

```dart
ChallengeAchievement(id: 'streak_7', title: '七日坚持', description: '连续拍摄 7 天', icon: Icons.local_fire_department_outlined, unlocked: currentStreak >= 7, progress: (currentStreak / 7).clamp(0.0, 1.0)),
ChallengeAchievement(id: 'streak_15', title: '半月之星', description: '连续拍摄 15 天', icon: Icons.star_outline, unlocked: currentStreak >= 15, progress: (currentStreak / 15).clamp(0.0, 1.0)),
```

原代码这两项是 `unlocked: false, progress: 0`，替换为上述。

**注意**：description 文字也从 `连续打卡` → `连续拍摄`。

- [ ] **Step 2: 检查 import / 语法**

确认已引入 `galleryDao`（构造函数中已有 `required this.galleryDao`），无需新增依赖。

- [ ] **Step 3: 运行 analyze**

```bash
flutter analyze lib/features/challenge/data/challenge_repository.dart
```

预期：无错误。

- [ ] **Step 4: Commit**

```bash
git add lib/features/challenge/data/challenge_repository.dart
git commit -m "feat(challenge): update streak_7/streak_15 achievements based on shooting streak"
```

---

## Task 6: 首拍自动签到（capture_page 落库后自动调用）

**Files:**
- Modify: `lumira_app_flutter\lib\features\capture\pages\capture_page.dart`

**Interfaces:**
- Consumes: `signInRepositoryProvider` (已有)
- Behavior: 拍照成功落库到 gallery 后，如果今日还没自动签到过，则调用 `signIn()`，fire-and-forget，失败静默不阻塞拍照流程。

- [ ] **Step 1: 在 `_CapturePageState` 添加状态标志**

在 class 开头添加：

```dart
bool _dailyAutoSignInDone = false; // 同一会话避免重复调用
```

- [ ] **Step 2: 在落库成功后添加自动签到逻辑**

找到 `capture_page.dart` 约 L715-727（落库成功后，在 `_dailyShootEarned` 之后）：

```dart
        // 每日首次拍摄积分（后台幂等；失败静默，绝不阻塞拍照流程）
        if (!_dailyShootEarned) {
          _dailyShootEarned = true;
          _earnDailyShootPoints();
        }

        // === 自动签到：每日首拍自动触发 ===
        if (!_dailyAutoSignInDone) {
          _dailyAutoSignInDone = true;
          _autoSignIn();
        }
```

- [ ] **Step 3: 实现 `_autoSignIn()` 方法**

```dart
Future<void> _autoSignIn() async {
  try {
    final repo = await ref.read(signInRepositoryProvider.future);
    await repo.signIn();
    // 签到成功后刷新状态
    ref.invalidate(signInRepositoryProvider);
    ref.invalidate(pointsRepositoryProvider);
    debugPrint('[auto-signin] daily first shoot auto signin success');
  } catch (e) {
    // 网络错误 / 重复签到都静默，绝不阻塞拍照
    debugPrint('[auto-signin] auto signin failed (silent): $e');
  }
}
```

- [ ] **Step 4: 添加需要的 imports**

在文件顶部添加：

```dart
import '../../sign_in/data/sign_in_repository.dart';
import '../../points/data/points_repository.dart';
```

- [ ] **Step 5: 检查编译**

```bash
flutter analyze lib/features/capture/pages/capture_page.dart
```

预期：无错误。

- [ ] **Step 6: Commit**

```bash
git add lib/features/capture/pages/capture_page.dart
git commit -m "feat(capture): add automatic sign-in on daily first shoot"
```

---

## Task 7: 积分钱包 SignInCard 移除手动签到按钮

**Files:**
- Modify: `lumira_app_flutter/lib/features/points/pages/points_wallet_page.dart`

**Changes:** 移除 `_onSignIn()` 方法、移除「立即签到」按钮，改为纯展示当前签到状态。

- [ ] **Step 1: 修改 `_SignInCard` build 方法**

原 `_SignInCard` 底部有按钮，改为：

```dart
Widget build(BuildContext context) {
  // ...
  return NeuCard(...
    // ... 删除 ElevatedButton，替换为状态文字行：
    const SizedBox(height: 12),
    Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          status.signedToday
              ? '今日已自动签到（当日首拍）'
              : '今日未拍摄，拍摄后自动签到',
          style: TextStyle(
            fontSize: 13,
            color: status.signedToday ? tokens.success : tokens.textSecondary,
          ),
        ),
        Text(
          '连签 ${status.consecutiveDays} 天',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: tokens.brand,
          ),
        ),
      ],
    ),
  );
}
```

删除 `signingIn` 状态、删除 `_onSignIn` 回调参数、删除 ElevatedButton 相关代码。

删除文件中 `_onSignIn()` 方法整个函数。

删除 `bool _signingIn` 状态变量声明。

删除所有调用 `_onSignIn` 的地方。

- [ ] **Step 2: 修改文案说明**

在 `_EarnWaysCard` 中，「每日签到」说明改为：

```dart
_EarnWay(Icons.calendar_today_outlined, '每日签到', '+2 积分/天，连签 7 天额外 +14（每日首拍自动完成）'),
```

原：`+2 积分/天，连签 7 天额外 +14` → 添加括号说明。

- [ ] **Step 3: 运行 analyze**

```bash
flutter analyze lib/features/points/pages/points_wallet_page.dart
```

预期：无错误。

- [ ] **Step 4: Commit**

```bash
git add lib/features/points/pages/points_wallet_page.dart
git commit -m "feat(points): remove manual sign-in button, show auto sign-in status"
```

---

## Task 8: 探店打卡可见文案统一改为「探店足迹」

**Files:**
- Modify: `lumira_app_flutter/lib/features/checkin/pages/checkin_edit_page.dart`
- Modify: `lumira_app_flutter/lib/features/checkin/pages/checkin_list_page.dart`
- Modify: `lumira_app_flutter/lib/core/utils/time_format.dart` (注释仅)

**Changes:** 仅修改用户可见文字，不修改类名、表名、路由。

- [ ] **Step 1: `checkin_list_page.dart` 可见文案修改**

搜索所有可见文字「打卡」替换为「足迹」：
- AppBar title: `'探店打卡'` → `'探店足迹'`
- 分享文案：`'探店：${record.name}\n'` → `'探店足迹：${record.name}\n'`
- 空状态：`'还没有探店打卡'` → `'还没有探店足迹'`

- [ ] **Step 2: `checkin_edit_page.dart` 修改**

- AppBar title: `isEdit ? '编辑打卡' : '新增打卡'` → `isEdit ? '编辑足迹' : '记录探店'`
- Fab: `'保存打卡'` → `'保存足迹'`

- [ ] **Step 3: `time_format.dart` 注释修改**

注释：`/// 格式化日期为 "M月D日"（探店打卡等场景）` → `/// 格式化日期为 "M月D日"（探店足迹等场景）`

- [ ] **Step 4: 检查**

```bash
flutter analyze lib/features/checkin/ lib/core/utils/time_format.dart
```

预期：无错误（仅改字符串文字）。

- [ ] **Step 5: Commit**

```bash
git add lib/features/checkin/pages/checkin_edit_page.dart lib/features/checkin/pages/checkin_list_page.dart lib/core/utils/time_format.dart
git commit -m "refactor(checkin): rename visible text from 探店打卡 to 探店足迹"
```

---

## 完成后检查清单

- [ ] **全项目 flutter analyze 无错误**
- [ ] 所有任务已完成勾选
- [ ] 测试：首页连续拍摄数字、挑战页进度条数字、日记 banner 数字三者一致
- [ ] 测试：跨周连续不截断
- [ ] 测试：首拍自动签到成功，重复拍不会重复签到
- [ ] 测试：挑战成就墙 `streak_7`/`streak_15` 进度正确
