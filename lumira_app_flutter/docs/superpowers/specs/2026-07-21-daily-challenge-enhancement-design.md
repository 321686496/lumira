# 每日挑战增强设计

> 日期：2026-07-21
> 状态：待审核

## 一、背景与目标

当前每日挑战模块存在以下问题：

1. **一进入就展示**：用户进入挑战页立即看到所有挑战内容，缺乏随机性和仪式感
2. **明日挑战预览无价值**：`tomorrow_preview_card` 只是一个模糊遮罩 + "明日揭晓" badge，不提供实际功能
3. **纯 Mock 静态数据**：所有数据来自 `ChallengeMockData` 静态常量，无持久化、无异步、无状态管理
4. **功能不完整**：`_goAllTomorrow()` 和 `getDetailById()` 都是 mock 占位

### 目标

- 添加 3 张卡牌翻面选 1 的趣味动画，每天首次进入触发
- 移除明日挑战预览，替换为：本周挑战日历 + 挑战成就/荣誉墙 + 挑战技巧/拍摄提示
- 接入本地题库 + 用户历史，基于拍摄偏好智能推荐
- 确保所有功能可用，通过 HarmonyOS 模拟器测试

## 二、整体流程

```
用户进入挑战页
  ├─ 当天首次进入（sqflite 记录 last_flip_date != today）
  │   → 展示翻牌界面（3 张背面朝上的卡牌）
  │   → 用户点击 1 张 → 翻牌动画揭示今日挑战
  │   → 点击"开始挑战" → 进入正常挑战页
  │
  └─ 当天已翻过（last_flip_date == today）
      → 直接展示正常挑战页（含已揭开的今日挑战）
```

正常挑战页结构（自上而下）：

1. 主挑战卡（今日翻牌选中的挑战）
2. 附加挑战（2 个子挑战）
3. **本周挑战日历**（替换原明日预览）
4. **挑战成就/荣誉墙**
5. **挑战技巧/拍摄提示**
6. 连续打卡卡（保留）

## 三、挑战题库设计

### 3.1 分类体系

与模板的 7 值 `category` 对齐，确保"挑战 → 模板 → 场景"分类轴统一：

| category 值 | 中文标签 |
|---|---|
| `portrait` | 人像 |
| `landscape` | 风光 |
| `food` | 美食 |
| `street` | 街拍 |
| `night` | 夜景 |
| `macro` | 微距 |
| `still-life` | 静物 |

### 3.2 题库结构

```dart
class ChallengePoolItem {
  final String id;              // 如 'portrait_001'
  final String category;        // 7 分类之一
  final String title;           // 如 '拍一张窗边侧光人像'
  final String description;     // 详细描述
  final int rewardXP;           // 奖励 XP
  final String tip;             // 拍摄技巧提示
  final List<String> tags;      // 标签
}
```

每个分类内置 5-8 个挑战，共约 40-50 题。题库为 `static const`，内置于代码中（与模板 mock 数据一致的方式）。

### 3.3 题库示例

- `portrait`：「拍一张窗边侧光人像」「用逆光拍一张剪影人像」「拍摄一组表情对比照」
- `landscape`：「拍摄日落时分的云层层次」「用前景构图拍一张风景」「雨天拍一张水墨感风景」
- `food`：「俯拍一杯咖啡的拉花」「侧光拍摄早餐的质感」「拍一张蒸汽升腾的热食」
- `street`：「拍一张路人的背影故事」「霓虹灯下拍一张街拍」「雨天拍水洼倒影」
- `night`：「长曝光拍车流光轨」「拍一张月光下的建筑轮廓」「手持拍一张夜景人像」
- `macro`：「拍一朵花的微距细节」「拍摄水滴的折射效果」「拍一只昆虫的复眼」
- `still-life`：「拍一组复古物件的静物」「窗光下拍一本书的质感」「拍一杯水的折射光影」

## 四、智能推荐算法

### 4.1 用户画像计算

通过 `GalleryDao` 查询 `gallery_items` 表，按 `scene_id` 关联场景的 `relatedCategory` 聚合：

```dart
class UserShootingProfile {
  final int totalPhotos;
  final Map<String, int> categoryCounts;  // category → 拍摄数
  final Set<String> triedCategories;       // 拍过的分类
  final Set<String> untriedCategories;     // 从未拍过的分类
  final String topCategory;                // 最常拍分类
}
```

### 4.2 推荐策略

| 用户类型 | 策略 |
|---|---|
| 新用户（totalPhotos < 5） | 7 分类均匀随机，引导探索 |
| 有偏好用户 | 60% 概率从 untriedCategories 选（拓展），40% 从 triedCategories 选（强化） |
| 当日已完成某分类挑战 | 该分类降权 |

### 4.3 3 张候选卡牌生成

1. 基于推荐策略选出 3 个不同的 category
2. 每个分类内用日期种子 + category 索引伪随机选 1 个挑战
3. 返回 3 张候选卡牌（`List<ChallengePoolItem>`，长度 3，category 互不相同）

### 4.4 日期种子

```dart
// 基于 YYYY-MM-DD 生成种子，确保同一天结果一致
int _dailySeed(DateTime date) {
  return date.year * 10000 + date.month * 100 + date.day;
}
```

## 五、数据层架构

### 5.1 新增文件

```
lib/features/challenge/data/
├── challenge_pool.dart           # 内置题库（static const）
├── challenge_repository.dart     # 接口 + 本地实现（推荐算法）
├── challenge_dao.dart            # sqflite 持久化
├── challenge_providers.dart      # Riverpod providers
└── challenge_models.dart         # 扩展现有模型（已存在，需修改）
```

### 5.2 数据库表

新建 `challenge_history` 表（在 `tables.dart` 中定义，`database_provider.dart` 中建表）：

```sql
CREATE TABLE challenge_history (
  id TEXT PRIMARY KEY,            -- challenge_id
  date TEXT NOT NULL,             -- YYYY-MM-DD
  challenge_id TEXT NOT NULL,     -- 题库中的 id
  category TEXT NOT NULL,         -- 7 分类之一
  title TEXT NOT NULL,            -- 挑战标题（快照）
  reward_xp INTEGER NOT NULL,     -- 奖励 XP（快照）
  status TEXT NOT NULL,           -- 'pending' / 'completed' / 'skipped'
  selected_at INTEGER NOT NULL,   -- 翻牌时间戳
  completed_at INTEGER,           -- 完成时间戳（nullable）
  skipped_at INTEGER,             -- 跳过时间戳（nullable）
  is_daily INTEGER NOT NULL DEFAULT 0  -- 1=每日主挑战, 0=附加挑战
)
```

索引：
- `idx_challenge_history_date` ON `date` DESC
- `idx_challenge_history_category` ON `category`

数据库版本从 1 升级到 2，`_onUpgrade` 中执行建表语句。

### 5.3 ChallengeDao

```dart
class ChallengeDao {
  Future<void> insertDailyChallenge(ChallengeHistoryRecord record);
  Future<void> updateStatus(String id, ChallengeStatus status);
  Future<ChallengeHistoryRecord?> getDailyChallengeByDate(String date);
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory(String startDate, String endDate);
  Future<List<ChallengeHistoryRecord>> getAllHistory({int? limit});
  Future<int> countByCategory(String category);
  Future<int> countCompleted();
  Future<int> countDistinctCategories();
}
```

### 5.4 ChallengeRepository

```dart
abstract class ChallengeRepository {
  /// 获取当日 3 张候选挑战卡牌
  Future<List<ChallengePoolItem>> getDailyCandidates();

  /// 记录用户翻牌选择
  Future<void> recordDailySelection(ChallengePoolItem selected);

  /// 获取当日已选挑战（null 表示今天还没翻牌）
  Future<ChallengePoolItem?> getTodayChallenge();

  /// 获取本周历史
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory();

  /// 获取成就列表
  Future<List<ChallengeAchievement>> getAchievements();

  /// 获取与指定分类相关的拍摄技巧
  ChallengeTip getTipForCategory(String category);

  /// 获取附加挑战（2 个，基于当日主挑战的分类补充）
  List<SubChallenge> getSubChallenges(String dailyCategory);
}

class LocalChallengeRepository implements ChallengeRepository {
  // 基于 ChallengePool + ChallengeDao + GalleryDao 实现
}
```

### 5.5 Providers

```dart
// 当日挑战状态（候选/已选/未翻牌）
final dailyChallengeStateProvider = FutureProvider<DailyChallengeState>((ref) async {...});

// 本周日历
final weeklyCalendarProvider = FutureProvider<WeeklyCalendar>((ref) async {...});

// 成就列表
final challengeAchievementsProvider = FutureProvider<List<ChallengeAchievement>>((ref) async {...});

// 拍摄技巧
final challengeTipProvider = Provider<ChallengeTip>((ref) {...});

// 附加挑战
final subChallengesProvider = FutureProvider<List<SubChallenge>>((ref) async {...});

// 连续打卡
final streakInfoProvider = FutureProvider<StreakInfo>((ref) async {...});
```

## 六、UI 组件设计

### 6.1 翻牌动画组件 `DailyFlipCard`

```
lib/features/challenge/widgets/daily_flip_card.dart
```

**结构**：
- 3 张卡牌水平排列（小屏可垂直滚动）
- 每张卡牌背面：新拟态凸起阴影 + 问号/品牌 logo + "点击翻开"
- 点击后：该张翻转 180°（AnimatedBuilder + Matrix4.rotationY，时长 600ms）
- 翻转正面：挑战标题、分类标签、奖励 XP、"开始挑战"按钮
- 其余 2 张：淡出 + 缩小消失（FadeTransition + ScaleTransition）

**状态**：
```dart
enum FlipState { idle, flipping, revealed }
```

**交互**：
- idle 状态：3 张卡牌均可点击，带轻微 hover/tap 缩放
- flipping 状态：禁用所有点击
- revealed 状态：仅显示选中的 1 张，底部"开始挑战"按钮

### 6.2 本周挑战日历 `WeeklyCalendarCard`

```
lib/features/challenge/widgets/weekly_calendar_card.dart
```

**结构**：
- 7 天横向排列（周一~周日）
- 每天显示：星期缩写 + 状态图标（✓已完成 / ●今日 / —未开始）
- 今日高亮（brand 色边框）
- 底部进度条："本周已完成 X/7 天"

### 6.3 挑战成就/荣誉墙 `AchievementWallCard`

```
lib/features/challenge/widgets/achievement_wall_card.dart
```

**成就定义**（static const，约 8-12 个）：

| 成就 | 条件 | 图标 |
|---|---|---|
| 初出茅庐 | 完成第 1 个挑战 | flag |
| 七日坚持 | 连续打卡 7 天 | local_fire_department |
| 半月之星 | 连续打卡 15 天 | star |
| 探索者 | 尝试 3 个不同分类 | explore |
| 全领域 | 尝试全部 7 个分类 | category |
| 人像大师 | 完成 10 个人像挑战 | face |
| 风光达人 | 完成 10 个风光挑战 | landscape |
| 百折不挠 | 累计完成 50 个挑战 | emoji_events |

**结构**：
- 网格布局（3 列），每个成就一个圆形徽章
- 已解锁：彩色 + 光效
- 未解锁：灰色 + 锁图标

### 6.4 挑战技巧/拍摄提示 `ChallengeTipCard`

```
lib/features/challenge/widgets/challenge_tip_card.dart
```

**结构**：
- 与当日主挑战分类相关的拍摄技巧
- 图标 + 标题 + 描述
- "了解更多"链接（跳转对应分类的模板列表）

## 七、页面改造

### 7.1 ChallengePage 改造

```dart
class ChallengePage extends ConsumerStatefulWidget { ... }

class _ChallengePageState extends ConsumerState<ChallengePage> {
  @override
  Widget build(BuildContext context) {
    final dailyState = ref.watch(dailyChallengeStateProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 背景装饰
          ...,

          SafeArea(
            child: dailyState.when(
              loading: () => _LoadingView(),
              error: (e, st) => _ErrorView(e),
              data: (state) {
                if (state.needsFlip) {
                  return _FlipCardView(candidates: state.candidates!);
                }
                return _ChallengeContentView(state: state);
              },
            ),
          ),

          // TabBar
          Positioned(bottom: 0, child: FloatingTabBar(active: 'challenge')),
        ],
      ),
    );
  }
}
```

### 7.2 _FlipCardView

全屏翻牌界面：
- 顶部标题："翻开今日挑战"
- 中间：3 张候选卡牌
- 底部：跳过按钮（"暂不翻牌"→ 直接进入挑战页用默认挑战）

### 7.3 _ChallengeContentView

正常挑战页（翻牌后或当天已翻过）：
- ListView：主挑战卡 → 附加挑战 → 本周日历 → 成就墙 → 拍摄技巧 → 连续打卡

## 八、模型扩展

### 8.1 修改 challenge_models.dart

新增：
- `ChallengePoolItem` - 题库条目
- `ChallengeHistoryRecord` - 历史记录
- `ChallengeAchievement` - 成就
- `WeeklyCalendar` - 本周日历
- `ChallengeTip` - 拍摄技巧
- `DailyChallengeState` - 当日状态（needsFlip / candidates / selected）
- `UserShootingProfile` - 用户拍摄画像

废弃/移除：
- `TomorrowPreview` 及相关 mock 数据（移除 tomorrow_preview_card.dart）

### 8.2 保留的模型

- `MainChallenge` - 保留，但改为从 `ChallengePoolItem` 转换生成
- `SubChallenge` - 保留，附加挑战继续使用
- `StreakInfo` - 保留，从 `user_progress` 表读取
- `ChallengeDetail` - 保留，从 `ChallengePoolItem` 动态生成
- `ChallengeTag` / `ChallengeStatus` - 保留

## 九、测试计划

### 9.1 单元测试

- `challenge_pool_test.dart` - 题库完整性（每分类至少 5 题、id 唯一）
- `challenge_repository_test.dart` - 推荐算法（新用户/有偏好用户/日期种子一致性）
- `challenge_dao_test.dart` - CRUD 操作

### 9.2 Widget 测试

- `daily_flip_card_test.dart` - 翻牌动画状态机（idle → flipping → revealed）
- `weekly_calendar_card_test.dart` - 7 天渲染、今日高亮
- `achievement_wall_card_test.dart` - 已解锁/未解锁渲染
- 更新 `challenge_page_test.dart` - 翻牌流程、跨主题/风格

### 9.3 集成测试（HarmonyOS 模拟器）

- 进入挑战页 → 翻牌 → 查看主挑战
- 查看本周日历、成就墙、拍摄技巧
- 进入挑战详情页 → 返回
- 切换主题/UI 风格验证视觉一致性

## 十、文件清单

### 新增文件（约 12 个）

```
lib/features/challenge/data/challenge_pool.dart
lib/features/challenge/data/challenge_repository.dart
lib/features/challenge/data/challenge_dao.dart
lib/features/challenge/data/challenge_providers.dart
lib/features/challenge/widgets/daily_flip_card.dart
lib/features/challenge/widgets/weekly_calendar_card.dart
lib/features/challenge/widgets/achievement_wall_card.dart
lib/features/challenge/widgets/challenge_tip_card.dart
test/features/challenge/challenge_pool_test.dart
test/features/challenge/challenge_repository_test.dart
test/features/challenge/challenge_dao_test.dart
test/features/challenge/daily_flip_card_test.dart
```

### 修改文件（约 8 个）

```
lib/features/challenge/data/challenge_models.dart          # 新增模型
lib/features/challenge/data/challenge_mock_data.dart       # 移除 TomorrowPreview，保留兼容
lib/features/challenge/pages/challenge_page.dart           # 集成翻牌 + 新模块
lib/features/challenge/pages/challenge_detail_page.dart    # 从 pool 动态生成详情
lib/core/db/tables.dart                                    # 新增 challenge_history 表
lib/core/db/database_provider.dart                         # DB v2 升级 + DAO provider
test/features/challenge/challenge_page_test.dart           # 更新测试
test/features/challenge/challenge_detail_page_test.dart    # 更新测试
```

### 删除文件（1 个）

```
lib/features/challenge/widgets/tomorrow_preview_card.dart  # 移除
```

## 十一、风险与约束

1. **DB 版本升级**：从 v1 → v2，需确保 `_onUpgrade` 迁移正确，不破坏现有数据
2. **GalleryDao 扩展**：需新增 `countByCategory` 方法（通过 scene_id JOIN scenes.related_category 聚合），可能影响性能
3. **翻牌动画性能**：3D 翻转在低端设备上可能卡顿，需测试并准备 fallback（2D 翻转）
4. **题库规模**：40-50 题需要手动编写，确保质量和多样性
5. **日期时区**：日期种子使用本地时区（`DateTime.now()`），不使用 UTC，确保"一天"与用户感知一致
