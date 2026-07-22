# 每日挑战增强实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为每日挑战模块添加 3 张卡牌翻面选 1 的趣味动画、本地题库 + 用户历史智能推荐、替换明日预览为本周日历/成就墙/拍摄技巧三个模块，接入 sqflite 持久化，确保所有功能可用并通过 HarmonyOS 模拟器测试。

**Architecture:** 数据层（题库 + DAO + Repository + Providers）→ UI 层（翻牌动画 + 3 个新模块 + 页面改造）。挑战题库按 7 分类分组（与模板 category 对齐），基于日期种子 + 用户拍摄画像智能推荐 3 张候选卡牌，sqflite 持久化挑战历史和翻牌状态。

**Tech Stack:** Flutter 3.x, Riverpod 2.x, sqflite, go_router, Dart 3.x

## Global Constraints

- 挑战题库分类复用模板的 7 值 category：`portrait`/`landscape`/`food`/`street`/`night`/`macro`/`still-life`
- 日期种子使用本地时区 `DateTime.now()`，不用 UTC
- 数据库版本从 v1 升级到 v2，`_onUpgrade` 需正确迁移
- 所有新 UI 组件需支持 4 种 UI 风格（neumorphic/flat/glass/female）和 8 种主题
- 翻牌动画用 `AnimatedBuilder` + `Matrix4.rotationY`，时长 600ms
- 保留现有 `MainChallenge`/`SubChallenge`/`StreakInfo`/`ChallengeDetail` 模型，移除 `TomorrowPreview`
- 所有图片资源使用 picsum.photos
- CSS/Dart 样式遵守项目新拟态规范（surface 色 + shadowConvex 双向阴影）

---

## File Structure

### 新增文件

| 文件 | 职责 |
|---|---|
| `lib/features/challenge/data/challenge_pool.dart` | 内置题库（static const，7 分类 × 5-8 题） |
| `lib/features/challenge/data/challenge_repository.dart` | 接口 + 本地实现（推荐算法 + 翻牌记录） |
| `lib/features/challenge/data/challenge_dao.dart` | sqflite DAO（challenge_history 表 CRUD） |
| `lib/features/challenge/data/challenge_providers.dart` | Riverpod providers |
| `lib/features/challenge/widgets/daily_flip_card.dart` | 3 张卡牌翻面选 1 动画组件 |
| `lib/features/challenge/widgets/weekly_calendar_card.dart` | 本周 7 天挑战日历 |
| `lib/features/challenge/widgets/achievement_wall_card.dart` | 挑战成就/荣誉墙 |
| `lib/features/challenge/widgets/challenge_tip_card.dart` | 拍摄技巧/提示卡 |
| `test/features/challenge/challenge_pool_test.dart` | 题库完整性测试 |
| `test/features/challenge/challenge_repository_test.dart` | 推荐算法测试 |
| `test/features/challenge/challenge_dao_test.dart` | DAO CRUD 测试 |

### 修改文件

| 文件 | 改动 |
|---|---|
| `lib/features/challenge/data/challenge_models.dart` | 新增 7 个模型类 |
| `lib/features/challenge/data/challenge_mock_data.dart` | 移除 TomorrowPreview 引用 |
| `lib/features/challenge/pages/challenge_page.dart` | 集成翻牌流程 + 3 个新模块 |
| `lib/features/challenge/pages/challenge_detail_page.dart` | 从 pool 动态生成详情 |
| `lib/core/db/tables.dart` | 新增 challenge_history 表定义 |
| `lib/core/db/database_provider.dart` | DB v2 升级 + challengeDaoProvider |
| `lib/core/db/dao/gallery_dao.dart` | 新增 countByCategory 方法 |
| `test/features/challenge/challenge_page_test.dart` | 更新测试适配翻牌流程 |
| `test/features/challenge/challenge_detail_page_test.dart` | 更新测试 |

### 删除文件

| 文件 | 原因 |
|---|---|
| `lib/features/challenge/widgets/tomorrow_preview_card.dart` | 明日预览模块移除 |

---

## Task 1: 扩展数据模型

**Files:**
- Modify: `lib/features/challenge/data/challenge_models.dart`

**Interfaces:**
- Produces: `ChallengePoolItem`, `ChallengeHistoryRecord`, `ChallengeAchievement`, `WeeklyCalendar`, `ChallengeTip`, `DailyChallengeState`, `UserShootingProfile`, `ChallengeCategory` 常量

- [ ] **Step 1: 在 challenge_models.dart 末尾新增模型类**

在文件末尾添加以下类（保持现有类不变）：

```dart
// === 每日挑战增强模型 ===

/// 挑战分类常量（与模板 category 对齐）
class ChallengeCategory {
  static const portrait = 'portrait';
  static const landscape = 'landscape';
  static const food = 'food';
  static const street = 'street';
  static const night = 'night';
  static const macro = 'macro';
  static const stillLife = 'still-life';

  static const all = [
    portrait, landscape, food, street, night, macro, stillLife,
  ];

  static String label(String category) {
    return switch (category) {
      portrait => '人像',
      landscape => '风光',
      food => '美食',
      street => '街拍',
      night => '夜景',
      macro => '微距',
      stillLife => '静物',
      _ => '未知',
    };
  }
}

/// 题库条目
class ChallengePoolItem {
  final String id;
  final String category;
  final String title;
  final String description;
  final int rewardXP;
  final String tip;
  final List<String> tags;

  const ChallengePoolItem({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.tip,
    this.tags = const [],
  });
}

/// 历史记录（对应 challenge_history 表）
class ChallengeHistoryRecord {
  final String id;
  final String date;
  final String challengeId;
  final String category;
  final String title;
  final int rewardXP;
  final ChallengeStatus status;
  final int selectedAt;
  final int? completedAt;
  final int? skippedAt;
  final bool isDaily;

  const ChallengeHistoryRecord({
    required this.id,
    required this.date,
    required this.challengeId,
    required this.category,
    required this.title,
    required this.rewardXP,
    required this.status,
    required this.selectedAt,
    this.completedAt,
    this.skippedAt,
    this.isDaily = false,
  });
}

/// 成就
class ChallengeAchievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final bool unlocked;
  final double progress;

  const ChallengeAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.unlocked,
    this.progress = 0,
  });
}

/// 本周日历
class WeeklyCalendar {
  final DateTime weekStart;
  final List<DailyStatus> days;

  const WeeklyCalendar({required this.weekStart, required this.days});
}

class DailyStatus {
  final DateTime date;
  final bool isToday;
  final ChallengeStatus status;

  const DailyStatus({
    required this.date,
    required this.isToday,
    required this.status,
  });
}

/// 拍摄技巧
class ChallengeTip {
  final String title;
  final String description;
  final IconData icon;
  final String category;

  const ChallengeTip({
    required this.title,
    required this.description,
    required this.icon,
    required this.category,
  });
}

/// 当日挑战状态
class DailyChallengeState {
  final bool needsFlip;
  final List<ChallengePoolItem>? candidates;
  final ChallengePoolItem? selected;

  const DailyChallengeState({
    required this.needsFlip,
    this.candidates,
    this.selected,
  });

  factory DailyChallengeState.needsFlipState(List<ChallengePoolItem> candidates) =>
      DailyChallengeState(needsFlip: true, candidates: candidates);

  factory DailyChallengeState.revealedState(ChallengePoolItem selected) =>
      DailyChallengeState(needsFlip: false, selected: selected);
}

/// 用户拍摄画像
class UserShootingProfile {
  final int totalPhotos;
  final Map<String, int> categoryCounts;
  final Set<String> triedCategories;
  final Set<String> untriedCategories;
  final String? topCategory;

  const UserShootingProfile({
    required this.totalPhotos,
    required this.categoryCounts,
    required this.triedCategories,
    required this.untriedCategories,
    this.topCategory,
  });
}
```

- [ ] **Step 2: 运行 analyze 验证语法**

Run: `flutter analyze lib/features/challenge/data/challenge_models.dart`
Expected: 无 error

- [ ] **Step 3: Commit**

```bash
git add lib/features/challenge/data/challenge_models.dart
git commit -m "feat(challenge): 扩展数据模型，新增题库/历史/成就/日历等模型"
```

---

## Task 2: 挑战题库

**Files:**
- Create: `lib/features/challenge/data/challenge_pool.dart`
- Test: `test/features/challenge/challenge_pool_test.dart`

**Interfaces:**
- Produces: `ChallengePool` 类，含 `static const List<ChallengePoolItem> all` 和 `static List<ChallengePoolItem> byCategory(String category)`

- [ ] **Step 1: 创建 challenge_pool.dart 题库文件**

创建 `lib/features/challenge/data/challenge_pool.dart`，包含 7 个分类各 6 个挑战（共 42 题）。每个挑战包含 id、category、title、description、rewardXP、tip、tags。

```dart
import 'challenge_models.dart';

/// 内置挑战题库
/// 按 7 个分类分组，每分类 6 题，共 42 题
class ChallengePool {
  static const List<ChallengePoolItem> all = [
    // === 人像 portrait ===
    ChallengePoolItem(
      id: 'portrait_001',
      category: ChallengeCategory.portrait,
      title: '拍一张窗边侧光人像',
      description: '利用窗户自然光，从侧面照射模特脸部，打造柔和的明暗对比',
      rewardXP: 50,
      tip: '让模特面朝窗户 45 度，光线从侧面打来形成伦勃朗光',
      tags: ['自然光', '侧光', '室内'],
    ),
    ChallengePoolItem(
      id: 'portrait_002',
      category: ChallengeCategory.portrait,
      title: '用逆光拍一张剪影人像',
      description: '在日落或强光源前拍摄人物剪影，强调轮廓线条',
      rewardXP: 60,
      tip: '对准亮部曝光，让人物完全变暗形成剪影',
      tags: ['逆光', '剪影', '创意'],
    ),
    ChallengePoolItem(
      id: 'portrait_003',
      category: ChallengeCategory.portrait,
      title: '拍摄一组表情对比照',
      description: '同一场景下拍摄模特 3 种不同情绪表情，展现情绪张力',
      rewardXP: 55,
      tip: '快速连拍捕捉自然表情变化，避免摆拍感',
      tags: ['情绪', '连拍', '对比'],
    ),
    ChallengePoolItem(
      id: 'portrait_004',
      category: ChallengeCategory.portrait,
      title: '拍一张黑白质感人像',
      description: '去除色彩干扰，专注于光影结构和面部纹理',
      rewardXP: 50,
      tip: '后期降低饱和度，提升对比度强化面部轮廓',
      tags: ['黑白', '质感', '后期'],
    ),
    ChallengePoolItem(
      id: 'portrait_005',
      category: ChallengeCategory.portrait,
      title: '利用镜子拍摄双人像',
      description: '通过镜面反射创作虚实结合的构图',
      rewardXP: 65,
      tip: '注意镜中与镜外人物的眼神方向，制造故事感',
      tags: ['镜面', '创意', '构图'],
    ),
    ChallengePoolItem(
      id: 'portrait_006',
      category: ChallengeCategory.portrait,
      title: '拍摄一组手部特写',
      description: '聚焦手部细节，通过手势讲述故事',
      rewardXP: 45,
      tip: '用大光圈虚化背景，突出手指线条和皮肤纹理',
      tags: ['特写', '细节', '大光圈'],
    ),

    // === 风光 landscape ===
    ChallengePoolItem(
      id: 'landscape_001',
      category: ChallengeCategory.landscape,
      title: '拍摄日落时分的云层层次',
      description: '捕捉黄金时刻天空的丰富色彩和云层纹理',
      rewardXP: 55,
      tip: '使用小光圈 f/8-f/11，保留云层高光细节',
      tags: ['日落', '黄金时刻', '云层'],
    ),
    ChallengePoolItem(
      id: 'landscape_002',
      category: ChallengeCategory.landscape,
      title: '用前景构图拍一张风景',
      description: '加入前景元素增强画面纵深感和层次',
      rewardXP: 50,
      tip: '低角度拍摄，用花草岩石做前景引导视线',
      tags: ['前景', '构图', '纵深'],
    ),
    ChallengePoolItem(
      id: 'landscape_003',
      category: ChallengeCategory.landscape,
      title: '雨天拍一张水墨感风景',
      description: '利用雨雾天气营造水墨画般的意境',
      rewardXP: 60,
      tip: '提高曝光补偿，后期降饱和度模拟水墨效果',
      tags: ['雨天', '意境', '水墨'],
    ),
    ChallengePoolItem(
      id: 'landscape_004',
      category: ChallengeCategory.landscape,
      title: '拍摄水面倒影构图',
      description: '利用平静水面创造对称镜像效果',
      rewardXP: 55,
      tip: '无风时拍摄，低角度贴近水面增强倒影',
      tags: ['倒影', '对称', '水面'],
    ),
    ChallengePoolItem(
      id: 'landscape_005',
      category: ChallengeCategory.landscape,
      title: '拍一张城市天际线',
      description: '在高处俯瞰城市建筑群轮廓',
      rewardXP: 50,
      tip: '黄昏蓝调时刻拍摄，天空与建筑层次分明',
      tags: ['城市', '天际线', '俯拍'],
    ),
    ChallengePoolItem(
      id: 'landscape_006',
      category: ChallengeCategory.landscape,
      title: '拍摄森林中的光斑',
      description: '捕捉树叶间漏下的丁达尔光束',
      rewardXP: 65,
      tip: '清晨雾气浓时拍摄，侧逆光角度捕捉光斑',
      tags: ['森林', '光斑', '雾气'],
    ),

    // === 美食 food ===
    ChallengePoolItem(
      id: 'food_001',
      category: ChallengeCategory.food,
      title: '俯拍一杯咖啡的拉花',
      description: '从正上方拍摄咖啡拉花图案',
      rewardXP: 45,
      tip: '保持手机水平，用自然光从侧面补光',
      tags: ['咖啡', '俯拍', '拉花'],
    ),
    ChallengePoolItem(
      id: 'food_002',
      category: ChallengeCategory.food,
      title: '侧光拍摄早餐的质感',
      description: '利用侧光突出食物的纹理和质感',
      rewardXP: 50,
      tip: '窗户旁 45 度侧光，突出面包酥脆感',
      tags: ['早餐', '侧光', '质感'],
    ),
    ChallengePoolItem(
      id: 'food_003',
      category: ChallengeCategory.food,
      title: '拍一张蒸汽升腾的热食',
      description: '捕捉食物热气蒸腾的瞬间',
      rewardXP: 60,
      tip: '逆光拍摄蒸汽更明显，深色背景突出烟缕',
      tags: ['蒸汽', '逆光', '热食'],
    ),
    ChallengePoolItem(
      id: 'food_004',
      category: ChallengeCategory.food,
      title: '拍摄一组色彩对比餐盘',
      description: '利用不同色系食材制造视觉冲击',
      rewardXP: 55,
      tip: '红绿对比或冷暖对比，俯拍展现色彩布局',
      tags: ['色彩', '对比', '俯拍'],
    ),
    ChallengePoolItem(
      id: 'food_005',
      category: ChallengeCategory.food,
      title: '拍一张手捧食物的温暖照',
      description: '加入人物手部增加食物的温暖感',
      rewardXP: 45,
      tip: '自然抓拍手部动作，避免僵硬摆拍',
      tags: ['手部', '温暖', '抓拍'],
    ),
    ChallengePoolItem(
      id: 'food_006',
      category: ChallengeCategory.food,
      title: '拍摄冰淇淋融化瞬间',
      description: '记录冰淇淋从固态到液态的变化过程',
      rewardXP: 65,
      tip: '连拍模式捕捉融化滴落的关键瞬间',
      tags: ['融化', '连拍', '创意'],
    ),

    // === 街拍 street ===
    ChallengePoolItem(
      id: 'street_001',
      category: ChallengeCategory.street,
      title: '拍一张路人的背影故事',
      description: '通过背影讲述路人的故事和情绪',
      rewardXP: 50,
      tip: '保持距离用长焦，抓拍自然的行走姿态',
      tags: ['背影', '故事', '长焦'],
    ),
    ChallengePoolItem(
      id: 'street_002',
      category: ChallengeCategory.street,
      title: '霓虹灯下拍一张街拍',
      description: '利用城市霓虹灯光作为主光源',
      rewardXP: 60,
      tip: '夜晚霓虹灯下，提高 ISO，利用灯光色彩',
      tags: ['霓虹', '夜景', '色彩'],
    ),
    ChallengePoolItem(
      id: 'street_003',
      category: ChallengeCategory.street,
      title: '雨天拍水洼倒影',
      description: '利用地面水洼创造倒影构图',
      rewardXP: 55,
      tip: '低角度贴近水洼，倒置手机拍摄效果更佳',
      tags: ['雨天', '倒影', '水洼'],
    ),
    ChallengePoolItem(
      id: 'street_004',
      category: ChallengeCategory.street,
      title: '拍摄路口的人流轨迹',
      description: '长曝光记录行人走动的轨迹',
      rewardXP: 65,
      tip: '快门 1-2 秒，固定手机，人群自然流动',
      tags: ['长曝光', '轨迹', '人流'],
    ),
    ChallengePoolItem(
      id: 'street_005',
      category: ChallengeCategory.street,
      title: '拍一张橱窗反射的街景',
      description: '利用玻璃橱窗反射创造双层画面',
      rewardXP: 55,
      tip: '斜 45 度拍摄，融合橱窗内外两个世界',
      tags: ['反射', '橱窗', '双层'],
    ),
    ChallengePoolItem(
      id: 'street_006',
      category: ChallengeCategory.street,
      title: '抓拍一个有趣的街头瞬间',
      description: '捕捉日常生活中幽默或戏剧性的瞬间',
      rewardXP: 50,
      tip: '预判场景，提前对焦，快速抓拍',
      tags: ['抓拍', '瞬间', '趣味'],
    ),

    // === 夜景 night ===
    ChallengePoolItem(
      id: 'night_001',
      category: ChallengeCategory.night,
      title: '长曝光拍车流光轨',
      description: '长曝光记录车灯轨迹',
      rewardXP: 65,
      tip: '快门 2-4 秒，找天桥或高处俯拍马路',
      tags: ['长曝光', '光轨', '车流'],
    ),
    ChallengePoolItem(
      id: 'night_002',
      category: ChallengeCategory.night,
      title: '拍一张月光下的建筑轮廓',
      description: '利用月光勾勒建筑剪影',
      rewardXP: 60,
      tip: '满月时拍摄，对建筑轮廓曝光',
      tags: ['月光', '轮廓', '建筑'],
    ),
    ChallengePoolItem(
      id: 'night_003',
      category: ChallengeCategory.night,
      title: '手持拍一张夜景人像',
      description: '利用城市灯光为人像补光',
      rewardXP: 55,
      tip: '找明亮橱窗或路灯旁，提高 ISO 到 1600',
      tags: ['夜景', '人像', '手持'],
    ),
    ChallengePoolItem(
      id: 'night_004',
      category: ChallengeCategory.night,
      title: '拍摄星空与地面景结合',
      description: '将星空与地面前景组合构图',
      rewardXP: 70,
      tip: '远离城市光污染，三脚架固定，30 秒曝光',
      tags: ['星空', '地面', '长曝光'],
    ),
    ChallengePoolItem(
      id: 'night_005',
      category: ChallengeCategory.night,
      title: '拍一张雨夜霓虹倒影',
      description: '雨夜地面湿润，霓虹倒影格外迷人',
      rewardXP: 60,
      tip: '低角度拍摄，同时收入霓虹和倒影',
      tags: ['雨夜', '霓虹', '倒影'],
    ),
    ChallengePoolItem(
      id: 'night_006',
      category: ChallengeCategory.night,
      title: '拍摄城市夜景全景',
      description: '用全景模式拍摄宽阔的城市夜景',
      rewardXP: 55,
      tip: '匀速移动手机，保持水平线一致',
      tags: ['全景', '城市', '夜景'],
    ),

    // === 微距 macro ===
    ChallengePoolItem(
      id: 'macro_001',
      category: ChallengeCategory.macro,
      title: '拍一朵花的微距细节',
      description: '放大拍摄花瓣纹理和花蕊结构',
      rewardXP: 50,
      tip: '用微距模式或外接镜头，稳定手持避免抖动',
      tags: ['花卉', '微距', '纹理'],
    ),
    ChallengePoolItem(
      id: 'macro_002',
      category: ChallengeCategory.macro,
      title: '拍摄水滴的折射效果',
      description: '捕捉水滴中倒映的微观世界',
      rewardXP: 65,
      tip: '在叶面或玻璃上滴水，逆光拍摄折射景象',
      tags: ['水滴', '折射', '逆光'],
    ),
    ChallengePoolItem(
      id: 'macro_003',
      category: ChallengeCategory.macro,
      title: '拍一只昆虫的复眼',
      description: '极近距离拍摄昆虫眼部细节',
      rewardXP: 70,
      tip: '清晨昆虫不活跃时拍摄，连拍多张选最佳',
      tags: ['昆虫', '复眼', '极限'],
    ),
    ChallengePoolItem(
      id: 'macro_004',
      category: ChallengeCategory.macro,
      title: '拍摄布料纤维的纹理',
      description: '放大拍摄不同材质的纤维结构',
      rewardXP: 45,
      tip: '侧光突出纤维立体感，避免反光',
      tags: ['纤维', '纹理', '材质'],
    ),
    ChallengePoolItem(
      id: 'macro_005',
      category: ChallengeCategory.macro,
      title: '拍一颗露珠在叶尖',
      description: '捕捉清晨露珠悬挂叶尖的瞬间',
      rewardXP: 55,
      tip: '逆光拍摄露珠透光，快门速度 1/500 以上',
      tags: ['露珠', '清晨', '逆光'],
    ),
    ChallengePoolItem(
      id: 'macro_006',
      category: ChallengeCategory.macro,
      title: '拍摄雪花的六角结构',
      description: '捕捉雪花独特的结晶图案',
      rewardXP: 75,
      tip: '黑色背景承接雪花，快速拍摄避免融化',
      tags: ['雪花', '结晶', '冬季'],
    ),

    // === 静物 still-life ===
    ChallengePoolItem(
      id: 'still-life_001',
      category: ChallengeCategory.stillLife,
      title: '拍一组复古物件的静物',
      description: '用旧物营造怀旧氛围的静物构图',
      rewardXP: 50,
      tip: '侧光突出物件质感，深色背景营造氛围',
      tags: ['复古', '静物', '侧光'],
    ),
    ChallengePoolItem(
      id: 'still-life_002',
      category: ChallengeCategory.stillLife,
      title: '窗光下拍一本书的质感',
      description: '利用窗光拍摄翻开的书本',
      rewardXP: 45,
      tip: '45 度侧光，突出纸张纹理和书页层次',
      tags: ['书本', '窗光', '质感'],
    ),
    ChallengePoolItem(
      id: 'still-life_003',
      category: ChallengeCategory.stillLife,
      title: '拍一杯水的折射光影',
      description: '利用光线穿过水杯的折射效果',
      rewardXP: 55,
      tip: '逆光拍摄，观察水杯形成的光影图案',
      tags: ['水杯', '折射', '光影'],
    ),
    ChallengePoolItem(
      id: 'still-life_004',
      category: ChallengeCategory.stillLife,
      title: '拍摄一组极简桌面静物',
      description: '用 2-3 件物品打造极简构图',
      rewardXP: 50,
      tip: '留白是关键，物品之间留出呼吸空间',
      tags: ['极简', '桌面', '留白'],
    ),
    ChallengePoolItem(
      id: 'still-life_005',
      category: ChallengeCategory.stillLife,
      title: '拍一组旧照片的怀旧组合',
      description: '用老照片营造时光感静物',
      rewardXP: 55,
      tip: '叠加旧物（怀表、信件）增强故事感',
      tags: ['怀旧', '旧照', '故事'],
    ),
    ChallengePoolItem(
      id: 'still-life_006',
      category: ChallengeCategory.stillLife,
      title: '拍摄玻璃器皿的通透感',
      description: '利用光线穿透玻璃展现透明质感',
      rewardXP: 60,
      tip: '逆光侧逆光，深色背景突出玻璃轮廓',
      tags: ['玻璃', '通透', '逆光'],
    ),
  ];

  /// 按分类获取题库
  static List<ChallengePoolItem> byCategory(String category) {
    return all.where((item) => item.category == category).toList();
  }

  /// 按 id 获取
  static ChallengePoolItem? byId(String id) {
    for (final item in all) {
      if (item.id == id) return item;
    }
    return null;
  }
}
```

- [ ] **Step 2: 创建测试文件 challenge_pool_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_pool.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';

void main() {
  group('ChallengePool', () {
    test('每分类至少 5 题', () {
      for (final cat in ChallengeCategory.all) {
        final items = ChallengePool.byCategory(cat);
        expect(items.length, greaterThanOrEqualTo(5),
            reason: '$cat 分类至少 5 题，实际 ${items.length}');
      }
    });

    test('所有 id 唯一', () {
      final ids = ChallengePool.all.map((e) => e.id).toSet();
      expect(ids.length, ChallengePool.all.length, reason: 'id 不唯一');
    });

    test('总题数 >= 35', () {
      expect(ChallengePool.all.length, greaterThanOrEqualTo(35));
    });

    test('byId 正确返回', () {
      final item = ChallengePool.byId('portrait_001');
      expect(item, isNotNull);
      expect(item!.category, ChallengeCategory.portrait);
    });

    test('byId 返回 null for 不存在的 id', () {
      expect(ChallengePool.byId('nonexistent'), isNull);
    });

    test('所有 rewardXP > 0', () {
      for (final item in ChallengePool.all) {
        expect(item.rewardXP, greaterThan(0), reason: '${item.id} rewardXP 应 > 0');
      }
    });
  });
}
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/features/challenge/challenge_pool_test.dart`
Expected: 6 tests passed

- [ ] **Step 4: Commit**

```bash
git add lib/features/challenge/data/challenge_pool.dart test/features/challenge/challenge_pool_test.dart
git commit -m "feat(challenge): 新增 42 题挑战题库，按 7 分类分组"
```

---

## Task 3: 数据库表 + DAO

**Files:**
- Modify: `lib/core/db/tables.dart`
- Modify: `lib/core/db/database_provider.dart`
- Create: `lib/features/challenge/data/challenge_dao.dart`
- Test: `test/features/challenge/challenge_dao_test.dart`

**Interfaces:**
- Consumes: `ChallengeHistoryRecord`, `ChallengeStatus` from Task 1
- Produces: `ChallengeDao` 类，`challengeDaoProvider`

- [ ] **Step 1: 在 tables.dart 添加 challenge_history 表定义**

在 `tables.dart` 的现有表定义后添加：

```dart
class ChallengeHistoryTable {
  static const name = 'challenge_history';

  static const colId = 'id';
  static const colDate = 'date';
  static const colChallengeId = 'challenge_id';
  static const colCategory = 'category';
  static const colTitle = 'title';
  static const colRewardXp = 'reward_xp';
  static const colStatus = 'status';
  static const colSelectedAt = 'selected_at';
  static const colCompletedAt = 'completed_at';
  static const colSkippedAt = 'skipped_at';
  static const colIsDaily = 'is_daily';

  static const createSql = '''
    CREATE TABLE $name (
      $colId TEXT PRIMARY KEY,
      $colDate TEXT NOT NULL,
      $colChallengeId TEXT NOT NULL,
      $colCategory TEXT NOT NULL,
      $colTitle TEXT NOT NULL,
      $colRewardXp INTEGER NOT NULL,
      $colStatus TEXT NOT NULL,
      $colSelectedAt INTEGER NOT NULL,
      $colCompletedAt INTEGER,
      $colSkippedAt INTEGER,
      $colIsDaily INTEGER NOT NULL DEFAULT 0
    )
  ''';

  static const indexDateSql = 'CREATE INDEX idx_challenge_history_date ON $name ($colDate DESC)';
  static const indexCategorySql = 'CREATE INDEX idx_challenge_history_category ON $name ($colCategory)';
}
```

- [ ] **Step 2: 在 database_provider.dart 中升级 DB 版本到 2**

找到 `_kDbVersion` 常量，从 `1` 改为 `2`。

在 `_onCreate` 方法中，在现有建表语句后添加：

```dart
await db.execute(ChallengeHistoryTable.createSql);
await db.execute(ChallengeHistoryTable.indexDateSql);
await db.execute(ChallengeHistoryTable.indexCategorySql);
```

在 `_onUpgrade` 方法中添加迁移逻辑：

```dart
if (oldVersion < 2) {
  await db.execute(ChallengeHistoryTable.createSql);
  await db.execute(ChallengeHistoryTable.indexDateSql);
  await db.execute(ChallengeHistoryTable.indexCategorySql);
}
```

添加 `challengeDaoProvider`：

```dart
final challengeDaoProvider = FutureProvider<ChallengeDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ChallengeDao(db);
});
```

确保 import 了 `tables.dart` 和 `challenge_dao.dart`。

- [ ] **Step 3: 创建 challenge_dao.dart**

```dart
import 'package:sqflite/sqflite.dart';
import '../../../core/db/tables.dart';
import 'challenge_models.dart';

class ChallengeDao {
  final Database _db;
  ChallengeDao(this._db);

  Future<void> insert(ChallengeHistoryRecord record) async {
    await _db.insert(ChallengeHistoryTable.name, {
      ChallengeHistoryTable.colId: record.id,
      ChallengeHistoryTable.colDate: record.date,
      ChallengeHistoryTable.colChallengeId: record.challengeId,
      ChallengeHistoryTable.colCategory: record.category,
      ChallengeHistoryTable.colTitle: record.title,
      ChallengeHistoryTable.colRewardXp: record.rewardXP,
      ChallengeHistoryTable.colStatus: record.status.name,
      ChallengeHistoryTable.colSelectedAt: record.selectedAt,
      ChallengeHistoryTable.colCompletedAt: record.completedAt,
      ChallengeHistoryTable.colSkippedAt: record.skippedAt,
      ChallengeHistoryTable.colIsDaily: record.isDaily ? 1 : 0,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateStatus(String id, ChallengeStatus status, {int? timestamp}) async {
    final map = {ChallengeHistoryTable.colStatus: status.name};
    if (status == ChallengeStatus.done && timestamp != null) {
      map[ChallengeHistoryTable.colCompletedAt] = timestamp;
    } else if (status == ChallengeStatus.pending && timestamp != null) {
      map[ChallengeHistoryTable.colSkippedAt] = timestamp;
    }
    await _db.update(ChallengeHistoryTable.name, map,
        where: '${ChallengeHistoryTable.colId} = ?', whereArgs: [id]);
  }

  Future<ChallengeHistoryRecord?> getDailyByDate(String date) async {
    final rows = await _db.query(ChallengeHistoryTable.name,
        where: '${ChallengeHistoryTable.colDate} = ? AND ${ChallengeHistoryTable.colIsDaily} = 1',
        whereArgs: [date], limit: 1);
    if (rows.isEmpty) return null;
    return _rowToRecord(rows.first);
  }

  Future<List<ChallengeHistoryRecord>> getWeeklyHistory(String startDate, String endDate) async {
    final rows = await _db.query(ChallengeHistoryTable.name,
        where: '${ChallengeHistoryTable.colDate} >= ? AND ${ChallengeHistoryTable.colDate} <= ?',
        whereArgs: [startDate, endDate],
        orderBy: '${ChallengeHistoryTable.colDate} ASC');
    return rows.map(_rowToRecord).toList();
  }

  Future<int> countCompleted() async {
    final rows = await _db.rawQuery(ChallengeHistoryTable.name,
        columns: ['COUNT(*) as cnt'],
        where: '${ChallengeHistoryTable.colStatus} = ?',
        whereArgs: ['done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> countByCategory(String category) async {
    final rows = await _db.rawQuery(ChallengeHistoryTable.name,
        columns: ['COUNT(*) as cnt'],
        where: '${ChallengeHistoryTable.colCategory} = ? AND ${ChallengeHistoryTable.colStatus} = ?',
        whereArgs: [category, 'done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> countDistinctCompletedCategories() async {
    final rows = await _db.rawQuery(ChallengeHistoryTable.name,
        columns: ['COUNT(DISTINCT ${ChallengeHistoryTable.colCategory}) as cnt'],
        where: '${ChallengeHistoryTable.colStatus} = ?',
        whereArgs: ['done']);
    return rows.first['cnt'] as int? ?? 0;
  }

  ChallengeHistoryRecord _rowToRecord(Map<String, Object?> row) {
    return ChallengeHistoryRecord(
      id: row[ChallengeHistoryTable.colId] as String,
      date: row[ChallengeHistoryTable.colDate] as String,
      challengeId: row[ChallengeHistoryTable.colChallengeId] as String,
      category: row[ChallengeHistoryTable.colCategory] as String,
      title: row[ChallengeHistoryTable.colTitle] as String,
      rewardXP: row[ChallengeHistoryTable.colRewardXp] as int,
      status: ChallengeStatus.values.firstWhere(
        (e) => e.name == row[ChallengeHistoryTable.colStatus],
      ),
      selectedAt: row[ChallengeHistoryTable.colSelectedAt] as int,
      completedAt: row[ChallengeHistoryTable.colCompletedAt] as int?,
      skippedAt: row[ChallengeHistoryTable.colSkippedAt] as int?,
      isDaily: (row[ChallengeHistoryTable.colIsDaily] as int) == 1,
    );
  }
}
```

- [ ] **Step 4: 创建 DAO 测试 challenge_dao_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_dao.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late ChallengeDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, v) async {
      await db.execute(ChallengeHistoryTable.createSql);
      await db.execute(ChallengeHistoryTable.indexDateSql);
      await db.execute(ChallengeHistoryTable.indexCategorySql);
    });
    dao = ChallengeDao(db);
  });

  tearDown(() => db.close());

  test('insert and getDailyByDate', () async {
    final record = ChallengeHistoryRecord(
      id: 'test_001',
      date: '2026-07-21',
      challengeId: 'portrait_001',
      category: ChallengeCategory.portrait,
      title: '测试挑战',
      rewardXP: 50,
      status: ChallengeStatus.pending,
      selectedAt: DateTime(2026, 7, 21).millisecondsSinceEpoch,
      isDaily: true,
    );
    await dao.insert(record);
    final result = await dao.getDailyByDate('2026-07-21');
    expect(result, isNotNull);
    expect(result!.title, '测试挑战');
    expect(result.isDaily, isTrue);
  });

  test('getDailyByDate returns null for missing date', () async {
    final result = await dao.getDailyByDate('1999-01-01');
    expect(result, isNull);
  });

  test('updateStatus', () async {
    final record = ChallengeHistoryRecord(
      id: 'test_002',
      date: '2026-07-21',
      challengeId: 'landscape_001',
      category: ChallengeCategory.landscape,
      title: '测试',
      rewardXP: 55,
      status: ChallengeStatus.pending,
      selectedAt: DateTime(2026, 7, 21).millisecondsSinceEpoch,
      isDaily: true,
    );
    await dao.insert(record);
    await dao.updateStatus('test_002', ChallengeStatus.done,
        timestamp: DateTime(2026, 7, 21, 12).millisecondsSinceEpoch);
    final result = await dao.getDailyByDate('2026-07-21');
    expect(result!.status, ChallengeStatus.done);
    expect(result.completedAt, isNotNull);
  });

  test('countCompleted', () async {
    await dao.insert(ChallengeHistoryRecord(
      id: 'c1', date: '2026-07-20', challengeId: 'p1',
      category: 'portrait', title: 't1', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'c2', date: '2026-07-21', challengeId: 'p2',
      category: 'landscape', title: 't2', rewardXP: 55,
      status: ChallengeStatus.pending, selectedAt: 0, isDaily: true));
    final count = await dao.countCompleted();
    expect(count, 1);
  });

  test('countByCategory', () async {
    await dao.insert(ChallengeHistoryRecord(
      id: 'c3', date: '2026-07-20', challengeId: 'p1',
      category: ChallengeCategory.portrait, title: 't1', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'c4', date: '2026-07-19', challengeId: 'p2',
      category: ChallengeCategory.portrait, title: 't2', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'c5', date: '2026-07-18', challengeId: 'l1',
      category: ChallengeCategory.landscape, title: 't3', rewardXP: 55,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    expect(await dao.countByCategory(ChallengeCategory.portrait), 2);
    expect(await dao.countByCategory(ChallengeCategory.landscape), 1);
    expect(await dao.countByCategory(ChallengeCategory.food), 0);
  });

  test('getWeeklyHistory', () async {
    await dao.insert(ChallengeHistoryRecord(
      id: 'w1', date: '2026-07-20', challengeId: 'p1',
      category: 'portrait', title: 't1', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'w2', date: '2026-07-22', challengeId: 'p2',
      category: 'landscape', title: 't2', rewardXP: 55,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    final results = await dao.getWeeklyHistory('2026-07-19', '2026-07-21');
    expect(results.length, 1);
    expect(results.first.id, 'w1');
  });

  test('countDistinctCompletedCategories', () async {
    await dao.insert(ChallengeHistoryRecord(
      id: 'd1', date: '2026-07-20', challengeId: 'p1',
      category: ChallengeCategory.portrait, title: 't1', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'd2', date: '2026-07-19', challengeId: 'p2',
      category: ChallengeCategory.landscape, title: 't2', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    await dao.insert(ChallengeHistoryRecord(
      id: 'd3', date: '2026-07-18', challengeId: 'p3',
      category: ChallengeCategory.portrait, title: 't3', rewardXP: 50,
      status: ChallengeStatus.done, selectedAt: 0, isDaily: true));
    final count = await dao.countDistinctCompletedCategories();
    expect(count, 2);
  });
}
```

- [ ] **Step 5: 运行 DAO 测试**

Run: `flutter test test/features/challenge/challenge_dao_test.dart`
Expected: 7 tests passed

- [ ] **Step 6: Commit**

```bash
git add lib/core/db/tables.dart lib/core/db/database_provider.dart lib/features/challenge/data/challenge_dao.dart test/features/challenge/challenge_dao_test.dart
git commit -m "feat(challenge): 新增 challenge_history 表 + ChallengeDao"
```

---

## Task 4: GalleryDao 扩展 + ChallengeRepository

**Files:**
- Modify: `lib/core/db/dao/gallery_dao.dart`
- Create: `lib/features/challenge/data/challenge_repository.dart`
- Test: `test/features/challenge/challenge_repository_test.dart`

**Interfaces:**
- Consumes: `ChallengePool`, `ChallengeDao`, `GalleryDao`, `ChallengePoolItem`, `UserShootingProfile`
- Produces: `ChallengeRepository` 接口 + `LocalChallengeRepository` 实现

- [ ] **Step 1: 在 gallery_dao.dart 新增 countByCategory 方法**

在 `GalleryDao` 类中添加方法（通过 JOIN scenes 表的 related_category 聚合）：

```dart
/// 按拍摄目标分类统计照片数（通过 scene_id JOIN scenes.related_category）
Future<Map<String, int>> countByCategory() async {
  final rows = await _db.rawQuery('''
    SELECT s.related_category AS category, COUNT(*) AS cnt
    FROM gallery_items g
    LEFT JOIN scenes s ON g.scene_id = s.id
    WHERE s.related_category IS NOT NULL
    GROUP BY s.related_category
  ''');
  final result = <String, int>{};
  for (final row in rows) {
    final cat = row['category'] as String?;
    final cnt = row['cnt'] as int? ?? 0;
    if (cat != null) result[cat] = cnt;
  }
  return result;
}
```

- [ ] **Step 2: 创建 challenge_repository.dart**

```dart
import 'dart:math';
import '../../../core/db/dao/gallery_dao.dart';
import 'challenge_pool.dart';
import 'challenge_models.dart';
import 'challenge_dao.dart';

abstract class ChallengeRepository {
  Future<List<ChallengePoolItem>> getDailyCandidates();
  Future<void> recordDailySelection(ChallengePoolItem selected);
  Future<ChallengePoolItem?> getTodayChallenge();
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory();
  Future<List<ChallengeAchievement>> getAchievements();
  ChallengeTip getTipForCategory(String category);
  List<SubChallenge> getSubChallenges(String dailyCategory);
}

class LocalChallengeRepository implements ChallengeRepository {
  final ChallengeDao _challengeDao;
  final GalleryDao _galleryDao;
  final DateTime Function() _now;

  LocalChallengeRepository({
    required ChallengeDao challengeDao,
    required GalleryDao galleryDao,
    DateTime Function()? now,
  })  : _challengeDao = challengeDao,
        _galleryDao = galleryDao,
        _now = now ?? DateTime.now;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _dailySeed(DateTime date) =>
      date.year * 10000 + date.month * 100 + date.day;

  @override
  Future<List<ChallengePoolItem>> getDailyCandidates() async {
    final now = _now();
    final seed = _dailySeed(now);
    final random = Random(seed);

    final profile = await _buildProfile();
    final categories = _selectCategories(profile, random);

    return categories.map((cat) {
      final pool = ChallengePool.byCategory(cat);
      final idx = random.nextInt(pool.length);
      return pool[idx];
    }).toList();
  }

  Future<UserShootingProfile> _buildProfile() async {
    final categoryCounts = await _galleryDao.countByCategory();
    final totalPhotos = categoryCounts.values.fold(0, (a, b) => a + b);
    final tried = categoryCounts.keys.where((c) => (categoryCounts[c] ?? 0) > 0).toSet();
    final untried = ChallengeCategory.all.where((c) => !tried.contains(c)).toSet();
    String? topCat;
    int maxCount = 0;
    categoryCounts.forEach((cat, cnt) {
      if (cnt > maxCount) {
        maxCount = cnt;
        topCat = cat;
      }
    });
    return UserShootingProfile(
      totalPhotos: totalPhotos,
      categoryCounts: categoryCounts,
      triedCategories: tried,
      untriedCategories: untried,
      topCategory: topCat,
    );
  }

  List<String> _selectCategories(UserShootingProfile profile, Random random) {
    final all = List<String>.from(ChallengeCategory.all);
    all.shuffle(random);

    final result = <String>[];

    if (profile.totalPhotos < 5) {
      // 新用户：均匀随机
      result.addAll(all.take(3));
      return result;
    }

    // 有偏好用户：60% untried, 40% tried
    final untried = profile.untriedCategories.toList()..shuffle(random);
    final tried = profile.triedCategories.toList()..shuffle(random);

    // 60% 概率优先 untried
    while (result.length < 3) {
      if (untried.isNotEmpty && (result.length < 2 || random.nextDouble() < 0.6)) {
        result.add(untried.removeAt(0));
      } else if (tried.isNotEmpty) {
        result.add(tried.removeAt(0));
      } else if (untried.isNotEmpty) {
        result.add(untried.removeAt(0));
      } else {
        break;
      }
    }

    // 不足 3 个时从 all 补
    if (result.length < 3) {
      for (final cat in all) {
        if (result.length >= 3) break;
        if (!result.contains(cat)) result.add(cat);
      }
    }

    return result.take(3).toList();
  }

  @override
  Future<void> recordDailySelection(ChallengePoolItem selected) async {
    final now = _now();
    final record = ChallengeHistoryRecord(
      id: '${_formatDate(now)}_${selected.id}',
      date: _formatDate(now),
      challengeId: selected.id,
      category: selected.category,
      title: selected.title,
      rewardXP: selected.rewardXP,
      status: ChallengeStatus.pending,
      selectedAt: now.millisecondsSinceEpoch,
      isDaily: true,
    );
    await _challengeDao.insert(record);
  }

  @override
  Future<ChallengePoolItem?> getTodayChallenge() async {
    final today = _formatDate(_now());
    final record = await _challengeDao.getDailyByDate(today);
    if (record == null) return null;
    return ChallengePool.byId(record.challengeId);
  }

  @override
  Future<List<ChallengeHistoryRecord>> getWeeklyHistory() async {
    final now = _now();
    // 计算本周一
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final startDate = _formatDate(weekStart);
    final endDate = _formatDate(now);
    return _challengeDao.getWeeklyHistory(startDate, endDate);
  }

  @override
  Future<List<ChallengeAchievement>> getAchievements() async {
    final completedCount = await _challengeDao.countCompleted();
    final distinctCategories = await _challengeDao.countDistinctCompletedCategories();
    final portraitCount = await _challengeDao.countByCategory(ChallengeCategory.portrait);
    final landscapeCount = await _challengeDao.countByCategory(ChallengeCategory.landscape);

    return [
      ChallengeAchievement(
        id: 'first_challenge',
        title: '初出茅庐',
        description: '完成第 1 个挑战',
        icon: Icons.flag_outlined,
        unlocked: completedCount >= 1,
        progress: (completedCount / 1).clamp(0, 1),
      ),
      ChallengeAchievement(
        id: 'streak_7',
        title: '七日坚持',
        description: '连续打卡 7 天',
        icon: Icons.local_fire_department_outlined,
        unlocked: false, // TODO: 从 user_progress 读取 streak
        progress: 0,
      ),
      ChallengeAchievement(
        id: 'streak_15',
        title: '半月之星',
        description: '连续打卡 15 天',
        icon: Icons.star_outline,
        unlocked: false,
        progress: 0,
      ),
      ChallengeAchievement(
        id: 'explorer_3',
        title: '探索者',
        description: '尝试 3 个不同分类',
        icon: Icons.explore_outlined,
        unlocked: distinctCategories >= 3,
        progress: (distinctCategories / 3).clamp(0, 1),
      ),
      ChallengeAchievement(
        id: 'explorer_all',
        title: '全领域',
        description: '尝试全部 7 个分类',
        icon: Icons.category_outlined,
        unlocked: distinctCategories >= 7,
        progress: (distinctCategories / 7).clamp(0, 1),
      ),
      ChallengeAchievement(
        id: 'portrait_master',
        title: '人像大师',
        description: '完成 10 个人像挑战',
        icon: Icons.face_outlined,
        unlocked: portraitCount >= 10,
        progress: (portraitCount / 10).clamp(0, 1),
      ),
      ChallengeAchievement(
        id: 'landscape_master',
        title: '风光达人',
        description: '完成 10 个风光挑战',
        icon: Icons.landscape_outlined,
        unlocked: landscapeCount >= 10,
        progress: (landscapeCount / 10).clamp(0, 1),
      ),
      ChallengeAchievement(
        id: 'completed_50',
        title: '百折不挠',
        description: '累计完成 50 个挑战',
        icon: Icons.emoji_events_outlined,
        unlocked: completedCount >= 50,
        progress: (completedCount / 50).clamp(0, 1),
      ),
    ];
  }

  @override
  ChallengeTip getTipForCategory(String category) {
    return switch (category) {
      ChallengeCategory.portrait => ChallengeTip(
          title: '人像光影秘籍',
          description: '利用 45 度侧光打造伦勃朗光效果，让面部更有立体感',
          icon: Icons.face_retouching_natural_outlined,
          category: category),
      ChallengeCategory.landscape => ChallengeTip(
          title: '风光构图法则',
          description: '三分法 + 前景引导线，让风景照片层次分明',
          icon: Icons.landscape_outlined,
          category: category),
      ChallengeCategory.food => ChallengeTip(
          title: '美食拍摄技巧',
          description: '自然侧光 + 浅景深，突出食物质感和色彩',
          icon: Icons.restaurant_outlined,
          category: category),
      ChallengeCategory.street => ChallengeTip(
          title: '街拍心法',
          description: '预判场景，提前对焦，捕捉决定性瞬间',
          icon: Icons.directions_walk_outlined,
          category: category),
      ChallengeCategory.night => ChallengeTip(
          title: '夜景曝光指南',
          description: '三脚架 + 长曝光，或高 ISO + 大光圈手持',
          icon: Icons.nightsight_outlined,
          category: category),
      ChallengeCategory.macro => ChallengeTip(
          title: '微距对焦技巧',
          description: '手动对焦更精准，连拍多张选最清晰的',
          icon: Icons.center_focus_strong_outlined,
          category: category),
      ChallengeCategory.stillLife => ChallengeTip(
          title: '静物布光法',
          description: '单侧光 + 反光板补暗部，营造立体感',
          icon: Icons.collections_outlined,
          category: category),
      _ => ChallengeTip(
          title: '通用拍摄技巧',
          description: '注意光线方向和构图，多拍多练',
          icon: Icons.camera_alt_outlined,
          category: category),
    };
  }

  @override
  List<SubChallenge> getSubChallenges(String dailyCategory) {
    // 从其他分类中选 2 个作为附加挑战
    final otherCategories = ChallengeCategory.all.where((c) => c != dailyCategory).toList();
    final now = _now();
    final random = Random(_dailySeed(now) + 1);
    otherCategories.shuffle(random);

    final subChallenges = <SubChallenge>[];
    for (final cat in otherCategories.take(2)) {
      final pool = ChallengePool.byCategory(cat);
      final item = pool[random.nextInt(pool.length)];
      subChallenges.add(SubChallenge(
        id: item.id,
        title: item.title,
        icon: _categoryIcon(cat),
        status: ChallengeStatus.pending,
        progressCurrent: 0,
        progressTotal: 1,
        rewardXP: (item.rewardXP * 0.6).round(),
        tags: [ChallengeTag(label: ChallengeCategory.label(cat), color: _tagColor(cat))],
      ));
    }
    return subChallenges;
  }

  IconData _categoryIcon(String category) {
    return switch (category) {
      ChallengeCategory.portrait => Icons.face_outlined,
      ChallengeCategory.landscape => Icons.landscape_outlined,
      ChallengeCategory.food => Icons.restaurant_outlined,
      ChallengeCategory.street => Icons.directions_walk_outlined,
      ChallengeCategory.night => Icons.nightsight_outlined,
      ChallengeCategory.macro => Icons.center_focus_strong_outlined,
      ChallengeCategory.stillLife => Icons.collections_outlined,
      _ => Icons.help_outline,
    };
  }

  ChallengeTagColor _tagColor(String category) {
    return switch (category) {
      ChallengeCategory.portrait => ChallengeTagColor.gold,
      ChallengeCategory.landscape => ChallengeTagColor.green,
      ChallengeCategory.food => ChallengeTagColor.red,
      _ => ChallengeTagColor.gold,
    };
  }
}
```

- [ ] **Step 3: 创建 repository 测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_repository.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_dao.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_models.dart';
import 'package:lumira_app_flutter/features/challenge/data/challenge_pool.dart';
import 'package:lumira_app_flutter/core/db/dao/gallery_dao.dart';
import 'package:lumira_app_flutter/core/db/tables.dart';

void main() {
  late Database db;
  late LocalChallengeRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, v) async {
      await db.execute(ChallengeHistoryTable.createSql);
      await db.execute(ChallengeHistoryTable.indexDateSql);
      await db.execute(ChallengeHistoryTable.indexCategorySql);
      // 建 scenes + gallery_items 表用于 JOIN
      await db.execute('''
        CREATE TABLE scenes (
          id TEXT PRIMARY KEY,
          related_category TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE gallery_items (
          id TEXT PRIMARY KEY,
          scene_id TEXT,
          created_at INTEGER
        )
      ''');
    });
    final challengeDao = ChallengeDao(db);
    final galleryDao = GalleryDao(db);
    repo = LocalChallengeRepository(
      challengeDao: challengeDao,
      galleryDao: galleryDao,
      now: () => DateTime(2026, 7, 21, 10),
    );
  });

  tearDown(() => db.close());

  group('getDailyCandidates', () {
    test('新用户返回 3 张候选卡牌', () async {
      final candidates = await repo.getDailyCandidates();
      expect(candidates.length, 3);
      // 3 张 category 互不相同
      final cats = candidates.map((c) => c.category).toSet();
      expect(cats.length, 3);
    });

    test('同一天多次调用结果一致（日期种子）', () async {
      final c1 = await repo.getDailyCandidates();
      final c2 = await repo.getDailyCandidates();
      expect(c1.map((e) => e.id).toList(), c2.map((e) => e.id).toList());
    });

    test('不同日期结果不同', () async {
      final repo2 = LocalChallengeRepository(
        challengeDao: ChallengeDao(db),
        galleryDao: GalleryDao(db),
        now: () => DateTime(2026, 7, 22, 10),
      );
      final c1 = await repo.getDailyCandidates();
      final c2 = await repo2.getDailyCandidates();
      expect(c1.map((e) => e.id).toList(), isNot(c2.map((e) => e.id).toList()));
    });
  });

  group('recordDailySelection & getTodayChallenge', () {
    test('记录并读取当日挑战', () async {
      final item = ChallengePool.all.first;
      await repo.recordDailySelection(item);
      final today = await repo.getTodayChallenge();
      expect(today, isNotNull);
      expect(today!.id, item.id);
    });

    test('未翻牌时 getTodayChallenge 返回 null', () async {
      final today = await repo.getTodayChallenge();
      expect(today, isNull);
    });
  });

  group('getAchievements', () {
    test('空历史时所有成就未解锁', () async {
      final achievements = await repo.getAchievements();
      expect(achievements.length, 8);
      expect(achievements.every((a) => !a.unlocked), isTrue);
    });

    test('完成 1 个挑战后初出茅庐解锁', () async {
      final item = ChallengePool.all.first;
      await repo.recordDailySelection(item);
      // 手动标记完成
      final record = await ChallengeDao(db).getDailyByDate('2026-07-21');
      await ChallengeDao(db).updateStatus(record!.id, ChallengeStatus.done,
          timestamp: DateTime.now().millisecondsSinceEpoch);

      final achievements = await repo.getAchievements();
      final first = achievements.firstWhere((a) => a.id == 'first_challenge');
      expect(first.unlocked, isTrue);
    });
  });

  group('getTipForCategory', () {
    test('每个分类都有 tip', () {
      for (final cat in ChallengeCategory.all) {
        final tip = repo.getTipForCategory(cat);
        expect(tip.title, isNotEmpty);
        expect(tip.description, isNotEmpty);
      }
    });
  });

  group('getSubChallenges', () {
    test('返回 2 个附加挑战，分类与主挑战不同', () {
      final subs = repo.getSubChallenges(ChallengeCategory.portrait);
      expect(subs.length, 2);
      expect(subs.every((s) => !s.tags.any((t) => t.label == '人像')), isTrue);
    });
  });
}
```

- [ ] **Step 4: 运行测试**

Run: `flutter test test/features/challenge/challenge_repository_test.dart`
Expected: 8 tests passed

- [ ] **Step 5: Commit**

```bash
git add lib/core/db/dao/gallery_dao.dart lib/features/challenge/data/challenge_repository.dart test/features/challenge/challenge_repository_test.dart
git commit -m "feat(challenge): 新增 GalleryDao.countByCategory + LocalChallengeRepository"
```

---

## Task 5: Providers + UI 组件 + 页面改造

> 此 Task 较大，使用 subagent 并行实现。分为 5 个独立子任务：
> 1. Providers
> 2. 翻牌动画组件
> 3. 本周日历 + 成就墙 + 拍摄技巧组件
> 4. ChallengePage 改造
> 5. ChallengeDetailPage 改造 + 移除 TomorrowPreviewCard + 更新测试

- [ ] **Step 1: 创建 challenge_providers.dart**

创建 `lib/features/challenge/data/challenge_providers.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import 'challenge_dao.dart';
import 'challenge_repository.dart';
import 'challenge_models.dart';

final challengeRepositoryProvider = FutureProvider<ChallengeRepository>((ref) async {
  final challengeDao = await ref.watch(challengeDaoProvider.future);
  final galleryDao = await ref.watch(galleryDaoProvider.future);
  return LocalChallengeRepository(challengeDao: challengeDao, galleryDao: galleryDao);
});

final dailyChallengeStateProvider = FutureProvider<DailyChallengeState>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final today = await repo.getTodayChallenge();
  if (today != null) {
    return DailyChallengeState.revealedState(today);
  }
  final candidates = await repo.getDailyCandidates();
  return DailyChallengeState.needsFlipState(candidates);
});

final weeklyCalendarProvider = FutureProvider<List<ChallengeHistoryRecord>>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  return repo.getWeeklyHistory();
});

final challengeAchievementsProvider = FutureProvider<List<ChallengeAchievement>>((ref) async {
  final repo = await ref.watch(challengeRepositoryProvider.future);
  return repo.getAchievements();
});

final challengeTipProvider = FutureProvider<ChallengeTip>((ref) async {
  final state = await ref.watch(dailyChallengeStateProvider.future);
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final category = state.selected?.category ?? ChallengeCategory.portrait;
  return repo.getTipForCategory(category);
});

final subChallengesProvider = FutureProvider<List<SubChallenge>>((ref) async {
  final state = await ref.watch(dailyChallengeStateProvider.future);
  final repo = await ref.watch(challengeRepositoryProvider.future);
  final category = state.selected?.category ?? ChallengeCategory.portrait;
  return repo.getSubChallenges(category);
});
```

- [ ] **Step 2: 创建 4 个 UI 组件文件**

使用 subagent 并行创建：
- `daily_flip_card.dart` - 3 张卡牌翻面选 1 动画
- `weekly_calendar_card.dart` - 本周 7 天日历
- `achievement_wall_card.dart` - 成就墙网格
- `challenge_tip_card.dart` - 拍摄技巧卡

每个组件需：
- 支持 4 种 UI 风格 + 8 种主题
- 使用 NeuCard 包装
- 遵循项目新拟态规范

- [ ] **Step 3: 改造 challenge_page.dart**

使用 subagent 实现完整页面改造：
- 集成翻牌流程（dailyChallengeStateProvider）
- 替换明日预览为 3 个新模块
- 移除 TomorrowPreviewCard 引用
- 保留主挑战卡 + 附加挑战 + 连续打卡

- [ ] **Step 4: 改造 challenge_detail_page.dart + 移除 TomorrowPreviewCard + 更新测试**

使用 subagent 实现：
- 从 ChallengePool 动态生成详情
- 删除 tomorrow_preview_card.dart
- 更新 challenge_page_test.dart 和 challenge_detail_page_test.dart

- [ ] **Step 5: 运行全部测试**

Run: `flutter test`
Expected: All tests passed

- [ ] **Step 6: 运行 analyze**

Run: `flutter analyze --no-pub`
Expected: 0 error/warning

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat(challenge): 集成翻牌动画+本周日历+成就墙+拍摄技巧，接入真实数据"
```

---

## Task 6: HarmonyOS 模拟器测试

**Files:**
- 无代码修改，使用 HarmonyOS MCP 工具测试

- [ ] **Step 1: 构建 APK**

Run: `flutter build apk --debug`
Expected: 构建成功

- [ ] **Step 2: 安装到 HarmonyOS 模拟器**

使用 harmonyos_install_app MCP 工具安装 APK

- [ ] **Step 3: 启动应用并测试翻牌流程**

使用 harmonyos_launch_app + harmonyos_screenshot 验证：
1. 进入挑战页 → 截图验证翻牌界面
2. 点击 1 张卡牌 → 截图验证翻牌动画
3. 翻牌完成 → 截图验证主挑战卡
4. 滚动查看本周日历、成就墙、拍摄技巧
5. 进入挑战详情页 → 截图验证
6. 返回挑战页 → 验证不重复翻牌

- [ ] **Step 4: 测试主题/UI 风格切换**

在设置页切换不同主题和 UI 风格，回到挑战页截图验证视觉一致性

- [ ] **Step 5: 记录测试结果**

汇总截图和测试发现的问题，如有 bug 则修复后重新测试
