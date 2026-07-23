# 摄影美学院功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将摄影美学院从 profile 模块拆出为独立 `features/academy/` 模块，实现 16 课课程学习、8 张知识卡片、实战作业三大子功能，SQLite 持久化学习进度。

**Architecture:** 分层架构 data（models → mock_data → dao → repository）→ providers（Riverpod）→ widgets → pages。DAO 使用 sqflite，数据库版本 2→3 迁移。页面使用 ConsumerWidget + themeTokensProvider，路由使用 GoRouter。

**Tech Stack:** Flutter 3.7 / Dart 2.19、flutter_riverpod 2.3.6、go_router 6.5.7、sqflite（CPF-Flutter 鸿蒙适配版）、file_picker 8.0.6、sqflite_common_ffi（测试用）

## Global Constraints

- **代码位置**：`lumira_app_flutter/lib/features/academy/`（所有新文件）
- **导入风格**：相对路径导入（如 `../../../core/db/database_provider.dart`），不用 `package:` 导入项目代码
- **主题访问**：`ref.watch(themeTokensProvider)` 返回 `ThemeTokens`（与 profile_academy_detail_page.dart 一致）
- **数据库**：sqflite 原生插件（CPF-Flutter 鸿蒙适配版），`getDatabasesPath()` 获取路径
- **数据库迁移**：非 destructive（不 DROP TABLE），`_onUpgrade` 用 `if (oldVersion < N)` 分支
- **表名常量**：在 `academy_dao.dart` 内定义 `AcademyTables` 类（与 `ChallengeHistoryTable` 模式一致）
- **DAO 注册**：在 `database_provider.dart` 中注册 `academyDaoProvider`
- **Provider 模式**：`FutureProvider<T>` + `ref.watch(xxxProvider.future)` 链式调用
- **Repository 模式**：抽象接口 + `Local*Repository` 具体实现，`_now` 注入可测试性
- **图片 URL**：`https://picsum.photos/seed/{seed}/{w}/{h}`
- **相册选择**：使用已有依赖 `file_picker`（不新增 `image_picker`）
- **路由参数**：query params（如 `?academyId=xxx`），与现有路由一致
- **UI 组件**：复用 `NeuCard`、`LumiraNav`、`LumiraButton`、`FadeUp`、`GlassBackground`、`FloatingTabBar`
- **测试**：DAO 测试用 `sqflite_common_ffi` + `:memory:` DB，UI 测试用 widget test

---

## File Structure

```
lumira_app_flutter/lib/features/academy/
├── data/
│   ├── academy_models.dart            ← Task 1: 数据模型 + 枚举
│   ├── academy_mock_data.dart         ← Task 2: 16 课 + 8 知识卡片 mock 数据
│   ├── academy_dao.dart               ← Task 3: SQLite DAO + AcademyTables 常量
│   └── academy_repository.dart        ← Task 4: Repository 抽象 + 本地实现
├── providers/
│   └── academy_providers.dart         ← Task 5: Riverpod providers
├── widgets/
│   ├── academy_progress_ring.dart     ← Task 6: 进度环（CustomPainter）
│   ├── academy_overview_card.dart     ← Task 7: 学习概览卡
│   ├── academy_level_selector.dart    ← Task 8: 难度等级选择器
│   ├── academy_course_card.dart       ← Task 9: 课程卡片
│   └── academy_knowledge_card.dart    ← Task 10: 知识卡片
└── pages/
    ├── academy_page.dart              ← Task 11: 学院首页
    ├── academy_detail_page.dart       ← Task 12: 课程详情页
    ├── academy_assignment_page.dart   ← Task 13: 实战作业页
    └── academy_knowledge_page.dart    ← Task 14: 知识卡片详情页
```

修改的现有文件：
- `lumira_app_flutter/lib/core/db/database_provider.dart` — Task 3: 版本升级 + DAO 注册
- `lumira_app_flutter/lib/core/router/route_names.dart` — Task 15: 新增路由常量
- `lumira_app_flutter/lib/app/router.dart` — Task 15: 更新路由引用
- `lumira_app_flutter/lib/features/templates/pages/templates_page.dart` — Task 15: 新增学院入口卡片
- `lumira_app_flutter/lib/features/capture/pages/capture_page.dart` — Task 13: 添加 returnResult 模式

删除的文件：
- `lumira_app_flutter/lib/features/profile/pages/profile_academy_page.dart` — Task 15
- `lumira_app_flutter/lib/features/profile/pages/profile_academy_detail_page.dart` — Task 15

清理的文件：
- `lumira_app_flutter/lib/features/profile/data/profile_content_mock_data.dart` — Task 15: 移除 academy 相关数据（LessonSection/CompareCell/PracticeTag/RecommendTemplate 及 lesson* 字段）

---

## Task 1: 数据模型

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/data/academy_models.dart`

**Interfaces:**
- Produces: `AcademyLevel`、`AcademyTopic`、`CourseStatus`、`AssignmentStatus` 枚举；`AcademyCourse`、`AcademyCourseDetail`、`KnowledgeCard`、`AcademyAssignment`、`AssignmentSubmission`、`AcademyOverview`、`CourseProgress` 类；`LessonSection`、`CompareCell`、`PracticeTag`、`RecommendTemplate`（从 profile 迁移）

- [ ] **Step 1: 创建 academy_models.dart**

```dart
import 'package:flutter/material.dart';

// === 枚举 ===

enum AcademyLevel { beginner, intermediate, advanced }

enum AcademyTopic { portrait, landscape, stillLife, street }

enum CourseStatus { notStarted, inProgress, completed }

enum AssignmentStatus { notSubmitted, submitted, reviewed }

// === 扩展方法：枚举转字符串与标签 ===

extension AcademyLevelExt on AcademyLevel {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case AcademyLevel.beginner: return '入门基础';
      case AcademyLevel.intermediate: return '进阶技巧';
      case AcademyLevel.advanced: return '高级创作';
    }
  }
}

extension AcademyTopicExt on AcademyTopic {
  String get name => toString().split('.').last;
  String get label {
    switch (this) {
      case AcademyTopic.portrait: return '人像';
      case AcademyTopic.landscape: return '风光';
      case AcademyTopic.stillLife: return '静物';
      case AcademyTopic.street: return '街头';
    }
  }
}

extension CourseStatusExt on CourseStatus {
  String get name => toString().split('.').last;
  static CourseStatus fromName(String? s) {
    switch (s) {
      case 'in_progress': return CourseStatus.inProgress;
      case 'completed': return CourseStatus.completed;
      default: return CourseStatus.notStarted;
    }
  }
}

extension AssignmentStatusExt on AssignmentStatus {
  String get name => toString().split('.').last;
  static AssignmentStatus fromName(String? s) {
    switch (s) {
      case 'submitted': return AssignmentStatus.submitted;
      case 'reviewed': return AssignmentStatus.reviewed;
      default: return AssignmentStatus.notSubmitted;
    }
  }
}

// === 从 profile_content_mock_data.dart 迁移的模型 ===

/// 摄影学院课程章节
class LessonSection {
  final String title;
  final List<String> paragraphs;
  const LessonSection({required this.title, required this.paragraphs});
}

/// 对比卡片（academy-detail 用）
class CompareCell {
  final String iconName;
  final String name;
  final String desc;
  final String tagText;
  final String tagColor;
  const CompareCell({
    required this.iconName,
    required this.name,
    required this.desc,
    required this.tagText,
    required this.tagColor,
  });
}

/// 实战练习标签
class PracticeTag {
  final String iconName;
  final String label;
  final String color;
  const PracticeTag({
    required this.iconName,
    required this.label,
    required this.color,
  });
}

/// 推荐模板
class RecommendTemplate {
  final String imageUrl;
  final String name;
  final String desc;
  final String badge;
  const RecommendTemplate({
    required this.imageUrl,
    required this.name,
    required this.desc,
    required this.badge,
  });
}

// === 核心数据类 ===

/// 课程元数据（列表展示）
class AcademyCourse {
  final String id;
  final int lessonNumber;
  final String title;
  final AcademyLevel level;
  final AcademyTopic topic;
  final String coverImage;
  final String meta; // 如 "8分钟 · 进阶入门"
  final List<String> tags;
  final int rewardXP;

  const AcademyCourse({
    required this.id,
    required this.lessonNumber,
    required this.title,
    required this.level,
    required this.topic,
    required this.coverImage,
    required this.meta,
    this.tags = const [],
    this.rewardXP = 50,
  });
}

/// 课程详情（完整内容）
class AcademyCourseDetail {
  final AcademyCourse course;
  final String heroImage;
  final List<LessonSection> sections;
  final String tipCardTitle;
  final String tipCardParagraph;
  final String tipCardImage;
  final List<CompareCell> compareCells;
  final String practiceTitle;
  final String practiceParagraph;
  final List<PracticeTag> practiceTags;
  final List<String> tips;
  final RecommendTemplate? recommendTemplate;
  final List<String> knowledgeCardIds; // 关联知识卡片 ID
  final AcademyAssignment? assignment;

  const AcademyCourseDetail({
    required this.course,
    required this.heroImage,
    required this.sections,
    required this.tipCardTitle,
    required this.tipCardParagraph,
    required this.tipCardImage,
    required this.compareCells,
    required this.practiceTitle,
    required this.practiceParagraph,
    required this.practiceTags,
    required this.tips,
    this.recommendTemplate,
    this.knowledgeCardIds = const [],
    this.assignment,
  });
}

/// 美学知识卡片
class KnowledgeCard {
  final String id;
  final AcademyTopic topic;
  final String title;
  final String subtitle;
  final String coverImage;
  final String body; // 卡片正文
  final List<String> keyPoints; // 关键要点

  const KnowledgeCard({
    required this.id,
    required this.topic,
    required this.title,
    required this.subtitle,
    required this.coverImage,
    required this.body,
    this.keyPoints = const [],
  });
}

/// 作业定义
class AcademyAssignment {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final List<String> requirements; // 作业要求
  final int rewardXP;

  const AcademyAssignment({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    this.requirements = const [],
    this.rewardXP = 100,
  });
}

/// 作业提交记录
class AssignmentSubmission {
  final String id;
  final String assignmentId;
  final String courseId;
  final String? photoPath; // 本地照片路径
  final String? photoUrl; // 网络照片 URL
  final String? note; // 用户备注
  final AssignmentStatus status;
  final int? score; // 评分 0-100
  final String? feedback; // 反馈
  final int submittedAt;

  const AssignmentSubmission({
    required this.id,
    required this.assignmentId,
    required this.courseId,
    this.photoPath,
    this.photoUrl,
    this.note,
    required this.status,
    this.score,
    this.feedback,
    required this.submittedAt,
  });
}

/// 学习概览
class AcademyOverview {
  final int streakDays; // 连续学习天数
  final int completedCourses; // 已完成课程数
  final int totalCourses; // 总课程数
  final int totalXP; // 累计 XP
  final String? nextCourseId; // 推荐下一课 ID
  final String? nextCourseTitle; // 推荐下一课标题

  const AcademyOverview({
    required this.streakDays,
    required this.completedCourses,
    required this.totalCourses,
    required this.totalXP,
    this.nextCourseId,
    this.nextCourseTitle,
  });

  double get completionRate =>
      totalCourses > 0 ? completedCourses / totalCourses : 0;
}

/// 课程进度记录（持久化）
class CourseProgress {
  final String courseId;
  final CourseStatus status;
  final int progressPercent;
  final int? startedAt;
  final int? completedAt;
  final int? lastViewedAt;

  const CourseProgress({
    required this.courseId,
    required this.status,
    required this.progressPercent,
    this.startedAt,
    this.completedAt,
    this.lastViewedAt,
  });
}
```

- [ ] **Step 2: 运行 analyze 验证无语法错误**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/data/academy_models.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_models.dart
git commit -m "feat(academy): add data models for academy feature"
```

---

## Task 2: Mock 数据

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/data/academy_mock_data.dart`

**Interfaces:**
- Consumes: `AcademyCourse`、`AcademyCourseDetail`、`KnowledgeCard`、`AcademyAssignment` from Task 1
- Produces: `AcademyMockData` 静态类，提供 `courses`、`getCourseDetail(id)`、`knowledgeCards`、`getAssignment(courseId)`

- [ ] **Step 1: 创建 academy_mock_data.dart — 课程矩阵 + 知识卡片 + 2 个完整课程详情示例**

```dart
import 'academy_models.dart';

/// 学院 mock 数据
/// 16 课按难度×主题矩阵组织，8 张知识卡片
class AcademyMockData {
  AcademyMockData._();

  // === 16 课课程矩阵（列表元数据） ===
  static const courses = <AcademyCourse>[
    // 入门（6 课）
    AcademyCourse(
      id: 'course_01', lessonNumber: 1, title: '找到你的最佳角度',
      level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
      coverImage: 'https://picsum.photos/seed/academy_01/400/600',
      meta: '8分钟 · 入门', tags: ['角度', '人像'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_02', lessonNumber: 2, title: '光线基础',
      level: AcademyLevel.beginner, topic: AcademyTopic.portrait,
      coverImage: 'https://picsum.photos/seed/academy_02/400/600',
      meta: '10分钟 · 入门', tags: ['光线', '侧光'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_03', lessonNumber: 3, title: '构图三分法',
      level: AcademyLevel.beginner, topic: AcademyTopic.landscape,
      coverImage: 'https://picsum.photos/seed/academy_03/400/600',
      meta: '8分钟 · 入门', tags: ['构图', '三分法'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_04', lessonNumber: 4, title: '黄金时段',
      level: AcademyLevel.beginner, topic: AcademyTopic.landscape,
      coverImage: 'https://picsum.photos/seed/academy_04/400/600',
      meta: '6分钟 · 入门', tags: ['日落', '柔光'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_05', lessonNumber: 5, title: '俯拍平铺',
      level: AcademyLevel.beginner, topic: AcademyTopic.stillLife,
      coverImage: 'https://picsum.photos/seed/academy_05/400/600',
      meta: '7分钟 · 入门', tags: ['俯拍', '静物'], rewardXP: 50,
    ),
    AcademyCourse(
      id: 'course_06', lessonNumber: 6, title: '决定性瞬间',
      level: AcademyLevel.beginner, topic: AcademyTopic.street,
      coverImage: 'https://picsum.photos/seed/academy_06/400/600',
      meta: '9分钟 · 入门', tags: ['街拍', '抓拍'], rewardXP: 50,
    ),
    // 进阶（6 课）
    AcademyCourse(
      id: 'course_07', lessonNumber: 7, title: '伦勃朗光',
      level: AcademyLevel.intermediate, topic: AcademyTopic.portrait,
      coverImage: 'https://picsum.photos/seed/academy_07/400/600',
      meta: '12分钟 · 进阶', tags: ['布光', '伦勃朗'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_08', lessonNumber: 8, title: '情绪表达',
      level: AcademyLevel.intermediate, topic: AcademyTopic.portrait,
      coverImage: 'https://picsum.photos/seed/academy_08/400/600',
      meta: '10分钟 · 进阶', tags: ['情绪', '人像'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_09', lessonNumber: 9, title: '引导线构图',
      level: AcademyLevel.intermediate, topic: AcademyTopic.landscape,
      coverImage: 'https://picsum.photos/seed/academy_09/400/600',
      meta: '11分钟 · 进阶', tags: ['构图', '引导线'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_10', lessonNumber: 10, title: '布光法',
      level: AcademyLevel.intermediate, topic: AcademyTopic.stillLife,
      coverImage: 'https://picsum.photos/seed/academy_10/400/600',
      meta: '13分钟 · 进阶', tags: ['布光', '静物'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_11', lessonNumber: 11, title: '色彩搭配',
      level: AcademyLevel.intermediate, topic: AcademyTopic.stillLife,
      coverImage: 'https://picsum.photos/seed/academy_11/400/600',
      meta: '10分钟 · 进阶', tags: ['色彩', '搭配'], rewardXP: 80,
    ),
    AcademyCourse(
      id: 'course_12', lessonNumber: 12, title: '街头光影',
      level: AcademyLevel.intermediate, topic: AcademyTopic.street,
      coverImage: 'https://picsum.photos/seed/academy_12/400/600',
      meta: '11分钟 · 进阶', tags: ['光影', '街拍'], rewardXP: 80,
    ),
    // 高级（4 课）
    AcademyCourse(
      id: 'course_13', lessonNumber: 13, title: '风格化人像',
      level: AcademyLevel.advanced, topic: AcademyTopic.portrait,
      coverImage: 'https://picsum.photos/seed/academy_13/400/600',
      meta: '15分钟 · 高级', tags: ['风格', '人像'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_14', lessonNumber: 14, title: '黑白风光',
      level: AcademyLevel.advanced, topic: AcademyTopic.landscape,
      coverImage: 'https://picsum.photos/seed/academy_14/400/600',
      meta: '14分钟 · 高级', tags: ['黑白', '风光'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_15', lessonNumber: 15, title: '极简静物',
      level: AcademyLevel.advanced, topic: AcademyTopic.stillLife,
      coverImage: 'https://picsum.photos/seed/academy_15/400/600',
      meta: '12分钟 · 高级', tags: ['极简', '静物'], rewardXP: 120,
    ),
    AcademyCourse(
      id: 'course_16', lessonNumber: 16, title: '街头叙事',
      level: AcademyLevel.advanced, topic: AcademyTopic.street,
      coverImage: 'https://picsum.photos/seed/academy_16/400/600',
      meta: '16分钟 · 高级', tags: ['叙事', '街拍'], rewardXP: 120,
    ),
  ];

  /// 按 ID 获取课程元数据
  static AcademyCourse? getCourse(String courseId) {
    for (final c in courses) {
      if (c.id == courseId) return c;
    }
    return null;
  }

  /// 按等级筛选课程
  static List<AcademyCourse> getCoursesByLevel(AcademyLevel? level) {
    if (level == null) return courses;
    return courses.where((c) => c.level == level).toList();
  }

  // === 8 张知识卡片 ===
  static const knowledgeCards = <KnowledgeCard>[
    KnowledgeCard(
      id: 'kc_01', topic: AcademyTopic.portrait,
      title: '三分法则', subtitle: '构图的核心法则',
      coverImage: 'https://picsum.photos/seed/kc_01/400/300',
      body: '将画面分为九宫格，把主体放在交叉点或线条上，能创造出平衡而富有张力的构图。这是摄影最基础也最实用的构图法则。',
      keyPoints: ['将画面横竖各分三等分', '主体放在交叉点上', '地平线对齐水平三分线'],
    ),
    KnowledgeCard(
      id: 'kc_02', topic: AcademyTopic.portrait,
      title: '黄金时刻', subtitle: '一天中最美的光线',
      coverImage: 'https://picsum.photos/seed/kc_02/400/300',
      body: '日出后和日落前的一小时，光线柔和、色温暖黄，是拍摄人像和风光的最佳时段。此时的光线角度低，能产生长长的阴影和丰富的纹理。',
      keyPoints: ['日出后1小时内', '日落前1小时内', '色温约 3200K-4500K'],
    ),
    KnowledgeCard(
      id: 'kc_03', topic: AcademyTopic.landscape,
      title: '引导线', subtitle: '用线条引导视线',
      coverImage: 'https://picsum.photos/seed/kc_03/400/300',
      body: '道路、河流、栏杆、树列等线条元素可以将观者的视线引导至画面主体，增强照片的纵深感和叙事性。',
      keyPoints: ['寻找自然或人造线条', '线条应指向主体', '可使用汇聚线增强透视'],
    ),
    KnowledgeCard(
      id: 'kc_04', topic: AcademyTopic.landscape,
      title: '前景层次', subtitle: '让风景有深度',
      coverImage: 'https://picsum.photos/seed/kc_04/400/300',
      body: '在画面中加入前景元素（如岩石、花朵、树枝），可以建立近-中-远三层结构，让二维照片呈现三维空间感。',
      keyPoints: ['寻找前景元素', '建立三层结构', '使用小光圈保证景深'],
    ),
    KnowledgeCard(
      id: 'kc_05', topic: AcademyTopic.stillLife,
      title: '侧光布光', subtitle: '静物的立体感密码',
      coverImage: 'https://picsum.photos/seed/kc_05/400/300',
      body: '从物体侧面 45-90 度角打光，能产生明暗对比，突出物体的质感和立体感。这是静物摄影最常用的布光方式。',
      keyPoints: ['光源在侧面 45-90 度', '暗部可用反光板补光', '注意阴影方向'],
    ),
    KnowledgeCard(
      id: 'kc_06', topic: AcademyTopic.stillLife,
      title: '色彩理论', subtitle: '配色让画面更高级',
      coverImage: 'https://picsum.photos/seed/kc_06/400/300',
      body: '互补色（如蓝-橙、红-绿）能产生强烈对比，同类色（如棕-米-橙）则营造和谐感。掌握色彩搭配能让照片视觉层次更丰富。',
      keyPoints: ['互补色产生对比', '同类色营造和谐', '控制色彩数量在 3-4 种'],
    ),
    KnowledgeCard(
      id: 'kc_07', topic: AcademyTopic.street,
      title: '决定性瞬间', subtitle: '布列松的街拍哲学',
      coverImage: 'https://picsum.photos/seed/kc_07/400/300',
      body: '在街拍中，形态、姿态、光线和情绪在某一刻完美结合的瞬间就是"决定性瞬间"。预判场景、提前对焦、快速反应是捕捉它的关键。',
      keyPoints: ['预判场景发展', '提前设定对焦和曝光', '反应要快但不慌'],
    ),
    KnowledgeCard(
      id: 'kc_08', topic: AcademyTopic.street,
      title: '光影对比', subtitle: '用明暗讲故事',
      coverImage: 'https://picsum.photos/seed/kc_08/400/300',
      body: '在街拍中寻找光与影的交界，将主体放在亮处或暗处，利用强烈的明暗对比营造戏剧感和神秘感。',
      keyPoints: ['寻找光影交界线', '主体放在亮处', '暗部保留细节但不抢戏'],
    ),
  ];

  /// 按 ID 获取知识卡片
  static KnowledgeCard? getKnowledgeCard(String cardId) {
    for (final kc in knowledgeCards) {
      if (kc.id == cardId) return kc;
    }
    return null;
  }

  /// 按主题筛选知识卡片
  static List<KnowledgeCard> getKnowledgeCardsByTopic(AcademyTopic? topic) {
    if (topic == null) return knowledgeCards;
    return knowledgeCards.where((kc) => kc.topic == topic).toList();
  }

  // === 课程详情 ===
  // 每课包含：章节、TipCard、对比网格、实战练习、小贴士、推荐模板、关联知识卡片、作业

  /// 课程详情 map（key = courseId）
  static final Map<String, AcademyCourseDetail> _courseDetails = {
    'course_01': AcademyCourseDetail(
      course: courses[0],
      heroImage: 'https://picsum.photos/seed/academy_01_hero/800/450',
      sections: [
        LessonSection(title: '为什么角度很重要', paragraphs: [
          '同样的场景、同样的光线，仅仅因为拍摄角度的不同，照片效果可能天差地别。找到你身上最自信的角度，是出片的第一步。',
          '每个人的脸型、身材比例不同，适合的角度也不同。但有一些通用法则可以让你快速找到自己的「最佳出片位」。',
        ]),
        LessonSection(title: '俯拍 vs 平拍', paragraphs: ['两种最常见角度的效果对比：']),
        LessonSection(title: '小贴士', paragraphs: []),
      ],
      tipCardTitle: '45度角拍摄',
      tipCardParagraph: '微微侧身45度，下巴略微前伸，可以让脸部轮廓更立体。这个角度适合绝大多数脸型，尤其对圆脸非常友好。',
      tipCardImage: 'https://picsum.photos/seed/academy_01_tip/800/450',
      compareCells: [
        CompareCell(iconName: 'arrow_down', name: '俯拍', desc: '相机在眼睛上方，从上往下拍。显脸小、显头身比好。', tagText: '推荐', tagColor: 'green'),
        CompareCell(iconName: 'arrows_left_right', name: '平拍', desc: '相机与眼睛平齐。真实还原，适合证件照、正面照。', tagText: '中性', tagColor: 'gold'),
      ],
      practiceTitle: '试试这个练习',
      practiceParagraph: '打开如画，选择「街拍回眸」模板，在自然光下尝试俯拍角度，拍摄3张不同角度的照片。',
      practiceTags: [
        PracticeTag(iconName: 'camera', label: '街拍', color: 'gold'),
        PracticeTag(iconName: 'sun', label: '自然光', color: 'green'),
        PracticeTag(iconName: 'arrow_down', label: '俯拍', color: 'red'),
      ],
      tips: ['手机举高15-30cm，微微俯拍效果最好', '避免完全正面，微微转头更自然', '利用窗光，侧光拍出脸部立体感'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'https://picsum.photos/seed/academy_01_rec/400/600',
        name: '街拍回眸', desc: '试试用「街拍回眸」拍摄', badge: '免费',
      ),
      knowledgeCardIds: ['kc_01'],
      assignment: AcademyAssignment(
        id: 'asg_01', courseId: 'course_01',
        title: '拍摄你的最佳角度',
        description: '使用俯拍角度拍摄一张人像照片，注意光线方向和背景简洁度。',
        requirements: ['俯拍角度（相机高于眼睛）', '自然侧光', '背景简洁'],
        rewardXP: 100,
      ),
    ),
    'course_07': AcademyCourseDetail(
      course: courses[6],
      heroImage: 'https://picsum.photos/seed/academy_07_hero/800/450',
      sections: [
        LessonSection(title: '什么是伦勃朗光', paragraphs: [
          '伦勃朗光得名于荷兰画家伦勃朗，特点是脸部一侧受光、另一侧形成三角形光斑。这种布光方式能让面部产生强烈的明暗对比，营造出戏剧性和立体感。',
          '伦勃朗光的核心是光源位于人物的侧前方约 45 度角，高于头顶，光线向下投射。在受光面颊上会形成一个倒三角形光斑。',
        ]),
        LessonSection(title: '如何实现伦勃朗光', paragraphs: ['自然光和人造光都可以实现伦勃朗光：']),
        LessonSection(title: '注意事项', paragraphs: []),
      ],
      tipCardTitle: '窗光伦勃朗',
      tipCardParagraph: '让模特侧对窗户（45度角），窗户光线从斜上方投射。调整模特位置直到暗面出现三角形光斑。使用白色反光板微微补光暗部。',
      tipCardImage: 'https://picsum.photos/seed/academy_07_tip/800/450',
      compareCells: [
        CompareCell(iconName: 'sun', name: '自然光', desc: '利用窗户侧光，成本低、光线柔和自然。', tagText: '推荐', tagColor: 'green'),
        CompareCell(iconName: 'lightbulb', name: '人造光', desc: '使用LED灯精确控制角度和强度，适合室内棚拍。', tagText: '专业', tagColor: 'gold'),
      ],
      practiceTitle: '伦勃朗光实战',
      practiceParagraph: '在窗边让模特侧坐，调整位置观察面部三角形光斑，拍摄3张不同曝光的伦勃朗光人像。',
      practiceTags: [
        PracticeTag(iconName: 'sun', label: '窗光', color: 'green'),
        PracticeTag(iconName: 'face', label: '人像', color: 'gold'),
        PracticeTag(iconName: 'lightbulb', label: '侧光', color: 'red'),
      ],
      tips: ['光源角度约45度，高于头顶', '暗面三角形光斑是标志', '不要过度补光，保留明暗对比'],
      recommendTemplate: RecommendTemplate(
        imageUrl: 'https://picsum.photos/seed/academy_07_rec/400/600',
        name: '复古胶片人像', desc: '用「复古胶片人像」拍摄伦勃朗光', badge: '免费',
      ),
      knowledgeCardIds: ['kc_01', 'kc_02'],
      assignment: AcademyAssignment(
        id: 'asg_07', courseId: 'course_07',
        title: '伦勃朗光人像',
        description: '利用窗光拍摄一张伦勃朗光人像照片，确保暗面出现三角形光斑。',
        requirements: ['侧光45度角', '面部三角形光斑', '保留明暗对比'],
        rewardXP: 150,
      ),
    ),
    // 其余 14 课详情按相同结构编写。
    // 每课包含：sections（2-3 个章节）、tipCard、compareCells（2 个）、
    // practiceCard、tips（3 条）、recommendTemplate、knowledgeCardIds、assignment。
    // 使用 picsum.photos 图片，seed 格式：academy_{NN}_{type}。
    // 以下为各课内容要点：
    //
    // course_02 光线基础：章节=光线三要素(方向/强度/色温), 侧光vs逆光, 小贴士;
    //   tipCard=侧光的魅力; compareCells=侧光/逆光; tags=光线/自然光/侧光;
    //   knowledgeCardIds=['kc_02']; assignment=侧光人像练习
    //
    // course_03 构图三分法：章节=三分法原理, 横竖三分法应用, 小贴士;
    //   tipCard=地平线位置; compareCells=居中构图/三分构图; tags=构图/风景/三分法;
    //   knowledgeCardIds=['kc_01','kc_03']; assignment=三分法风景练习
    //
    // course_04 黄金时段：章节=为什么黄金时段最美, 光线特点, 小贴士;
    //   tipCard=逆光剪影; compareCells=正午硬光/黄金时段柔光; tags=日落/逆光/柔光;
    //   knowledgeCardIds=['kc_02']; assignment=黄金时段拍摄练习
    //
    // course_05 俯拍平铺：章节=俯拍的优势, 平铺构图法, 小贴士;
    //   tipCard=留白与对称; compareCells=侧拍/俯拍; tags=俯拍/静物/平铺;
    //   knowledgeCardIds=['kc_05']; assignment=俯拍静物练习
    //
    // course_06 决定性瞬间：章节=什么是决定性瞬间, 预判与等待, 小贴士;
    //   tipCard=提前对焦; compareCells=摆拍/抓拍; tags=街拍/抓拍/瞬间;
    //   knowledgeCardIds=['kc_07']; assignment=街拍决定性瞬间练习
    //
    // course_08 情绪表达：章节=情绪与表情, 眼神的力量, 小贴士;
    //   tipCard=环境与情绪; compareCells=微笑/沉思; tags=情绪/人像/眼神;
    //   knowledgeCardIds=['kc_01']; assignment=情绪人像练习
    //
    // course_09 引导线构图：章节=引导线的类型, 汇聚线与透视, 小贴士;
    //   tipCard=多重引导线; compareCells=无引导线/有引导线; tags=构图/引导线/透视;
    //   knowledgeCardIds=['kc_03','kc_04']; assignment=引导线风光练习
    //
    // course_10 布光法：章节=三点布光法, 主光与辅光, 小贴士;
    //   tipCard=单灯布光; compareCells=平光/立体光; tags=布光/静物/主光;
    //   knowledgeCardIds=['kc_05']; assignment=三点布光静物练习
    //
    // course_11 色彩搭配：章节=色彩三要素, 互补与同类色, 小贴士;
    //   tipCard=莫兰迪色系; compareCells=高饱和/低饱和; tags=色彩/搭配/莫兰迪;
    //   knowledgeCardIds=['kc_06']; assignment=色彩搭配静物练习
    //
    // course_12 街头光影：章节=光影的戏剧性, 明暗对比, 小贴士;
    //   tipCard=隧道光; compareCells=柔光/硬光; tags=光影/街拍/对比;
    //   knowledgeCardIds=['kc_07','kc_08']; assignment=街头光影练习
    //
    // course_13 风格化人像：章节=什么是风格化, 色调与情绪, 小贴士;
    //   tipCard=胶片色调; compareCells=自然风格/风格化; tags=风格/人像/色调;
    //   knowledgeCardIds=['kc_01','kc_06']; assignment=风格化人像练习
    //
    // course_14 黑白风光：章节=为什么用黑白, 去色后的结构, 小贴士;
    //   tipCard=高反差黑白; compareCells=彩色/黑白; tags=黑白/风光/反差;
    //   knowledgeCardIds=['kc_03','kc_04']; assignment=黑白风光练习
    //
    // course_15 极简静物：章节=少即是多, 负空间, 小贴士;
    //   tipCard=单一主体; compareCells=复杂构图/极简构图; tags=极简/静物/留白;
    //   knowledgeCardIds=['kc_05','kc_06']; assignment=极简静物练习
    //
    // course_16 街头叙事：章节=用照片讲故事, 环境与人物, 小贴士;
    //   tipCard=系列照片; compareCells=单张/系列; tags=叙事/街拍/系列;
    //   knowledgeCardIds=['kc_07','kc_08']; assignment=街头叙事系列练习
  };

  /// 获取课程详情
  static AcademyCourseDetail? getCourseDetail(String courseId) {
    return _courseDetails[courseId];
  }

  /// 获取课程作业
  static AcademyAssignment? getAssignment(String courseId) {
    return _courseDetails[courseId]?.assignment;
  }

  // === 作业提交后的 mock 评分 ===

  /// 生成 70-94 随机评分
  static int generateScore() => 70 + DateTime.now().millisecond % 25;

  /// 根据评分生成反馈文案
  static String generateFeedback(int score) {
    if (score >= 90) return '非常出色的作品！构图精准，光影运用到位，继续保持。';
    if (score >= 80) return '很好的尝试！整体完成度高，细节上可以再打磨。';
    if (score >= 70) return '不错的开始！建议多关注光线方向和构图平衡。';
    return '继续练习，多观察多拍摄，你会越来越好。';
  }
}
```

**实现说明：** 上述代码中注释标注的 14 课详情需要按相同结构填充。每课包含 `AcademyCourseDetail` 的所有必填字段。`sections` 每课 2-3 个 `LessonSection`，`compareCells` 每课 2 个，`tips` 每课 3 条，`practiceTags` 每课 3 个。图片 URL 使用 `https://picsum.photos/seed/academy_{NN}_{type}/{w}/{h}` 格式。每课必须包含 `assignment` 字段。

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/data/academy_mock_data.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_mock_data.dart
git commit -m "feat(academy): add 16-course mock data and 8 knowledge cards"
```

---

## Task 3: SQLite Schema + DAO

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/data/academy_dao.dart`
- Modify: `lumira_app_flutter/lib/core/db/database_provider.dart` — 版本 2→3，注册 academyDaoProvider，_onCreate 新增 3 表，_onUpgrade 新增 v3 分支

**Interfaces:**
- Consumes: `Database` from sqflite, `CourseProgress`、`AssignmentSubmission` from Task 1
- Produces: `AcademyDao` class with CRUD methods; `AcademyTables` constants class; `academyDaoProvider`

- [ ] **Step 1: 创建 academy_dao.dart**

```dart
import 'package:sqflite/sqflite.dart';

import 'academy_models.dart';

/// 学院相关表名与列名常量
class AcademyTables {
  AcademyTables._();

  // === academy_course_progress ===
  static const courseProgress = 'academy_course_progress';
  static const cpColCourseId = 'course_id';
  static const cpColStatus = 'status';
  static const cpColProgressPercent = 'progress_percent';
  static const cpColStartedAt = 'started_at';
  static const cpColCompletedAt = 'completed_at';
  static const cpColLastViewedAt = 'last_viewed_at';

  static const cpCreateSql = '''
    CREATE TABLE IF NOT EXISTS $courseProgress (
      $cpColCourseId TEXT PRIMARY KEY,
      $cpColStatus TEXT NOT NULL DEFAULT 'not_started',
      $cpColProgressPercent INTEGER NOT NULL DEFAULT 0,
      $cpColStartedAt INTEGER,
      $cpColCompletedAt INTEGER,
      $cpColLastViewedAt INTEGER
    )
  ''';

  // === academy_assignment_submission ===
  static const assignmentSubmission = 'academy_assignment_submission';
  static const asColId = 'id';
  static const asColAssignmentId = 'assignment_id';
  static const asColCourseId = 'course_id';
  static const asColPhotoPath = 'photo_path';
  static const asColPhotoUrl = 'photo_url';
  static const asColNote = 'note';
  static const asColStatus = 'status';
  static const asColScore = 'score';
  static const asColFeedback = 'feedback';
  static const asColSubmittedAt = 'submitted_at';

  static const asCreateSql = '''
    CREATE TABLE IF NOT EXISTS $assignmentSubmission (
      $asColId TEXT PRIMARY KEY,
      $asColAssignmentId TEXT UNIQUE,
      $asColCourseId TEXT NOT NULL,
      $asColPhotoPath TEXT,
      $asColPhotoUrl TEXT,
      $asColNote TEXT,
      $asColStatus TEXT NOT NULL DEFAULT 'not_submitted',
      $asColScore INTEGER,
      $asColFeedback TEXT,
      $asColSubmittedAt INTEGER NOT NULL
    )
  ''';

  // === academy_knowledge_favorite ===
  static const knowledgeFavorite = 'academy_knowledge_favorite';
  static const kfColCardId = 'card_id';
  static const kfColFavoritedAt = 'favorited_at';

  static const kfCreateSql = '''
    CREATE TABLE IF NOT EXISTS $knowledgeFavorite (
      $kfColCardId TEXT PRIMARY KEY,
      $kfColFavoritedAt INTEGER NOT NULL
    )
  ''';
}

/// 学院 DAO
class AcademyDao {
  final Database _db;
  AcademyDao(this._db);

  // === 课程进度 ===

  Future<CourseProgress?> getProgress(String courseId) async {
    final rows = await _db.query(
      AcademyTables.courseProgress,
      where: '${AcademyTables.cpColCourseId} = ?',
      whereArgs: [courseId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToProgress(rows.first);
  }

  Future<List<CourseProgress>> getAllProgress() async {
    final rows = await _db.query(AcademyTables.courseProgress);
    return rows.map(_rowToProgress).toList();
  }

  Future<void> upsertProgress(String courseId, CourseStatus status, int percent, {int? startedAt, int? completedAt, int? lastViewedAt}) async {
    await _db.insert(
      AcademyTables.courseProgress,
      {
        AcademyTables.cpColCourseId: courseId,
        AcademyTables.cpColStatus: status.name,
        AcademyTables.cpColProgressPercent: percent,
        AcademyTables.cpColStartedAt: startedAt,
        AcademyTables.cpColCompletedAt: completedAt,
        AcademyTables.cpColLastViewedAt: lastViewedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> countCompleted() async {
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AcademyTables.courseProgress} WHERE ${AcademyTables.cpColStatus} = ?',
      ['completed'],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  Future<int> sumRewardXP(List<String> completedCourseIds) async {
    if (completedCourseIds.isEmpty) return 0;
    final placeholders = List.filled(completedCourseIds.length, '?').join(',');
    final rows = await _db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${AcademyTables.courseProgress} WHERE ${AcademyTables.cpColCourseId} IN ($placeholders) AND ${AcademyTables.cpColStatus} = ?',
      [...completedCourseIds, 'completed'],
    );
    return rows.first['cnt'] as int? ?? 0;
  }

  CourseProgress _rowToProgress(Map<String, Object?> row) {
    return CourseProgress(
      courseId: row[AcademyTables.cpColCourseId] as String,
      status: CourseStatusExt.fromName(row[AcademyTables.cpColStatus] as String?),
      progressPercent: row[AcademyTables.cpColProgressPercent] as int? ?? 0,
      startedAt: row[AcademyTables.cpColStartedAt] as int?,
      completedAt: row[AcademyTables.cpColCompletedAt] as int?,
      lastViewedAt: row[AcademyTables.cpColLastViewedAt] as int?,
    );
  }

  // === 作业提交 ===

  Future<AssignmentSubmission?> getSubmission(String assignmentId) async {
    final rows = await _db.query(
      AcademyTables.assignmentSubmission,
      where: '${AcademyTables.asColAssignmentId} = ?',
      whereArgs: [assignmentId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _rowToSubmission(rows.first);
  }

  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) async {
    final rows = await _db.query(
      AcademyTables.assignmentSubmission,
      where: '${AcademyTables.asColCourseId} = ?',
      whereArgs: [courseId],
      orderBy: '${AcademyTables.asColSubmittedAt} DESC',
    );
    return rows.map(_rowToSubmission).toList();
  }

  Future<void> upsertSubmission(AssignmentSubmission submission) async {
    await _db.insert(
      AcademyTables.assignmentSubmission,
      {
        AcademyTables.asColId: submission.id,
        AcademyTables.asColAssignmentId: submission.assignmentId,
        AcademyTables.asColCourseId: submission.courseId,
        AcademyTables.asColPhotoPath: submission.photoPath,
        AcademyTables.asColPhotoUrl: submission.photoUrl,
        AcademyTables.asColNote: submission.note,
        AcademyTables.asColStatus: submission.status.name,
        AcademyTables.asColScore: submission.score,
        AcademyTables.asColFeedback: submission.feedback,
        AcademyTables.asColSubmittedAt: submission.submittedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  AssignmentSubmission _rowToSubmission(Map<String, Object?> row) {
    return AssignmentSubmission(
      id: row[AcademyTables.asColId] as String,
      assignmentId: row[AcademyTables.asColAssignmentId] as String,
      courseId: row[AcademyTables.asColCourseId] as String,
      photoPath: row[AcademyTables.asColPhotoPath] as String?,
      photoUrl: row[AcademyTables.asColPhotoUrl] as String?,
      note: row[AcademyTables.asColNote] as String?,
      status: AssignmentStatusExt.fromName(row[AcademyTables.asColStatus] as String?),
      score: row[AcademyTables.asColScore] as int?,
      feedback: row[AcademyTables.asColFeedback] as String?,
      submittedAt: row[AcademyTables.asColSubmittedAt] as int,
    );
  }

  // === 知识卡片收藏 ===

  Future<bool> isCardFavorited(String cardId) async {
    final rows = await _db.query(
      AcademyTables.knowledgeFavorite,
      where: '${AcademyTables.kfColCardId} = ?',
      whereArgs: [cardId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> getFavoriteCardIds() async {
    final rows = await _db.query(AcademyTables.knowledgeFavorite);
    return rows.map((r) => r[AcademyTables.kfColCardId] as String).toSet();
  }

  Future<void> addFavorite(String cardId, int timestamp) async {
    await _db.insert(
      AcademyTables.knowledgeFavorite,
      {AcademyTables.kfColCardId: cardId, AcademyTables.kfColFavoritedAt: timestamp},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String cardId) async {
    await _db.delete(
      AcademyTables.knowledgeFavorite,
      where: '${AcademyTables.kfColCardId} = ?',
      whereArgs: [cardId],
    );
  }
}
```

- [ ] **Step 2: 修改 database_provider.dart — 版本升级 + DAO 注册 + 迁移**

在 `database_provider.dart` 中做以下修改：

1. 版本常量 `_kDbVersion = 2` 改为 `_kDbVersion = 3`
2. 新增 import：`import '../../features/academy/data/academy_dao.dart';`
3. 在 `_onCreate` 方法中，`await db.execute(ChallengeHistoryTable.indexCategorySql);` 之后，新增 3 张 academy 表的创建：

```dart
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
```

4. 在 `_onUpgrade` 方法中，新增 `if (oldVersion < 3)` 分支：

```dart
  if (oldVersion < 3) {
    await db.execute(AcademyTables.cpCreateSql);
    await db.execute(AcademyTables.asCreateSql);
    await db.execute(AcademyTables.kfCreateSql);
  }
```

5. 在 `challengeDaoProvider` 之后，新增 `academyDaoProvider`：

```dart
final academyDaoProvider = FutureProvider<AcademyDao>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return AcademyDao(db);
});
```

- [ ] **Step 3: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/data/academy_dao.dart lib/core/db/database_provider.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_dao.dart lumira_app_flutter/lib/core/db/database_provider.dart
git commit -m "feat(academy): add SQLite DAO and db v3 migration"
```

---

## Task 4: Repository

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/data/academy_repository.dart`

**Interfaces:**
- Consumes: `AcademyDao` from Task 3, `AcademyMockData` from Task 2, `AcademyCourse`/`AcademyCourseDetail`/`KnowledgeCard`/`AcademyAssignment`/`AssignmentSubmission`/`AcademyOverview`/`CourseProgress` from Task 1
- Produces: `AcademyRepository` abstract class + `LocalAcademyRepository` concrete class

- [ ] **Step 1: 创建 academy_repository.dart**

```dart
import 'dart:math';

import 'academy_dao.dart';
import 'academy_mock_data.dart';
import 'academy_models.dart';

abstract class AcademyRepository {
  // 课程数据
  List<AcademyCourse> getCourses({AcademyLevel? level, AcademyTopic? topic});
  AcademyCourse? getCourse(String courseId);
  AcademyCourseDetail? getCourseDetail(String courseId);
  AcademyAssignment? getAssignment(String courseId);

  // 学习进度
  Future<AcademyOverview> getOverview();
  Future<CourseProgress?> getProgress(String courseId);
  Future<void> markStarted(String courseId);
  Future<void> updateProgress(String courseId, int percent);
  Future<void> markCompleted(String courseId);
  Future<int> getStreakDays();

  // 作业
  Future<AssignmentSubmission?> getSubmission(String assignmentId);
  Future<void> submitAssignment(AssignmentSubmission submission);
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId);

  // 知识卡片
  List<KnowledgeCard> getKnowledgeCards({AcademyTopic? topic});
  KnowledgeCard? getKnowledgeCard(String cardId);
  Future<bool> isCardFavorited(String cardId);
  Future<void> toggleFavorite(String cardId);
  Future<Set<String>> getFavoriteCardIds();
}

class LocalAcademyRepository implements AcademyRepository {
  final AcademyDao _dao;
  final DateTime Function() _now;

  LocalAcademyRepository({
    required AcademyDao dao,
    DateTime Function()? now,
  })  : _dao = dao,
        _now = now ?? DateTime.now;

  String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  List<AcademyCourse> getCourses({AcademyLevel? level, AcademyTopic? topic}) {
    var result = AcademyMockData.courses;
    if (level != null) {
      result = result.where((c) => c.level == level).toList();
    }
    if (topic != null) {
      result = result.where((c) => c.topic == topic).toList();
    }
    return result;
  }

  @override
  AcademyCourse? getCourse(String courseId) =>
      AcademyMockData.getCourse(courseId);

  @override
  AcademyCourseDetail? getCourseDetail(String courseId) =>
      AcademyMockData.getCourseDetail(courseId);

  @override
  AcademyAssignment? getAssignment(String courseId) =>
      AcademyMockData.getAssignment(courseId);

  @override
  Future<AcademyOverview> getOverview() async {
    final completedCount = await _dao.countCompleted();
    final allProgress = await _dao.getAllProgress();
    final streakDays = await getStreakDays();

    // 计算 XP：已完成课程的 rewardXP 之和
    int totalXP = 0;
    final completedIds = allProgress
        .where((p) => p.status == CourseStatus.completed)
        .map((p) => p.courseId)
        .toList();
    for (final id in completedIds) {
      final course = AcademyMockData.getCourse(id);
      if (course != null) totalXP += course.rewardXP;
    }

    // 推荐下一课：第一个未完成的课程
    String? nextId;
    String? nextTitle;
    for (final course in AcademyMockData.courses) {
      final progress = allProgress.firstWhere(
        (p) => p.courseId == course.id,
        orElse: () => const CourseProgress(
          courseId: '',
          status: CourseStatus.notStarted,
          progressPercent: 0,
        ),
      );
      if (progress.status != CourseStatus.completed) {
        nextId = course.id;
        nextTitle = course.title;
        break;
      }
    }

    return AcademyOverview(
      streakDays: streakDays,
      completedCourses: completedCount,
      totalCourses: AcademyMockData.courses.length,
      totalXP: totalXP,
      nextCourseId: nextId,
      nextCourseTitle: nextTitle,
    );
  }

  @override
  Future<CourseProgress?> getProgress(String courseId) =>
      _dao.getProgress(courseId);

  @override
  Future<void> markStarted(String courseId) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.inProgress,
      existing?.progressPercent ?? 0,
      startedAt: existing?.startedAt ?? now,
      lastViewedAt: now,
    );
  }

  @override
  Future<void> updateProgress(String courseId, int percent) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.inProgress,
      percent,
      startedAt: existing?.startedAt ?? now,
      lastViewedAt: now,
    );
  }

  @override
  Future<void> markCompleted(String courseId) async {
    final now = _now().millisecondsSinceEpoch;
    final existing = await _dao.getProgress(courseId);
    await _dao.upsertProgress(
      courseId,
      CourseStatus.completed,
      100,
      startedAt: existing?.startedAt ?? now,
      completedAt: now,
      lastViewedAt: now,
    );
  }

  @override
  Future<int> getStreakDays() async {
    // 简化实现：基于最后查看课程的日期计算连续天数
    final allProgress = await _dao.getAllProgress();
    if (allProgress.isEmpty) return 0;

    // 按日期排序去重
    final dates = <String>{};
    for (final p in allProgress) {
      if (p.lastViewedAt != null) {
        dates.add(_formatDate(DateTime.fromMillisecondsSinceEpoch(p.lastViewedAt!)));
      }
    }
    if (dates.isEmpty) return 0;

    // 从今天往回数连续天数
    int streak = 0;
    var checkDate = _now();
    while (dates.contains(_formatDate(checkDate))) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // === 作业 ===

  @override
  Future<AssignmentSubmission?> getSubmission(String assignmentId) =>
      _dao.getSubmission(assignmentId);

  @override
  Future<void> submitAssignment(AssignmentSubmission submission) async {
    await _dao.upsertSubmission(submission);
  }

  @override
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId) =>
      _dao.getCourseSubmissions(courseId);

  // === 知识卡片 ===

  @override
  List<KnowledgeCard> getKnowledgeCards({AcademyTopic? topic}) =>
      AcademyMockData.getKnowledgeCardsByTopic(topic);

  @override
  KnowledgeCard? getKnowledgeCard(String cardId) =>
      AcademyMockData.getKnowledgeCard(cardId);

  @override
  Future<bool> isCardFavorited(String cardId) =>
      _dao.isCardFavorited(cardId);

  @override
  Future<void> toggleFavorite(String cardId) async {
    final isFav = await _dao.isCardFavorited(cardId);
    if (isFav) {
      await _dao.removeFavorite(cardId);
    } else {
      await _dao.addFavorite(cardId, _now().millisecondsSinceEpoch);
    }
  }

  @override
  Future<Set<String>> getFavoriteCardIds() => _dao.getFavoriteCardIds();
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/data/academy_repository.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/data/academy_repository.dart
git commit -m "feat(academy): add repository with local implementation"
```

---

## Task 5: Providers

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/providers/academy_providers.dart`

**Interfaces:**
- Consumes: `academyDaoProvider` from Task 3, `LocalAcademyRepository` from Task 4
- Produces: All Riverpod providers for academy feature

- [ ] **Step 1: 创建 academy_providers.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/academy_repository.dart';
import '../data/academy_models.dart';
import '../data/academy_mock_data.dart';

// === DAO & Repository ===

final academyRepositoryProvider = FutureProvider<AcademyRepository>((ref) async {
  final dao = await ref.watch(academyDaoProvider.future);
  return LocalAcademyRepository(dao: dao);
});

// === 课程数据 ===

/// 按等级筛选课程（null = 全部）
final coursesProvider = Provider.family<List<AcademyCourse>, AcademyLevel?>((ref, level) {
  // 同步访问 mock 数据，无需 async
  return AcademyMockData.courses
      .where((c) => level == null || c.level == level)
      .toList();
});

/// 课程详情
final courseDetailProvider = Provider.family<AcademyCourseDetail?, String>((ref, courseId) {
  return AcademyMockData.getCourseDetail(courseId);
});

// === 学习进度 ===

/// 学习概览
final academyOverviewProvider = FutureProvider<AcademyOverview>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getOverview();
});

/// 单课进度
final courseProgressProvider = FutureProvider.family<CourseProgress?, String>((ref, courseId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getProgress(courseId);
});

// === 作业 ===

/// 作业提交记录
final assignmentSubmissionProvider = FutureProvider.family<AssignmentSubmission?, String>((ref, assignmentId) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getSubmission(assignmentId);
});

// === 知识卡片 ===

/// 知识卡片列表
final knowledgeCardsProvider = Provider<List<KnowledgeCard>>((ref) {
  return AcademyMockData.knowledgeCards;
});

/// 收藏卡片 ID 集合
final favoriteCardIdsProvider = FutureProvider<Set<String>>((ref) async {
  final repo = await ref.watch(academyRepositoryProvider.future);
  return repo.getFavoriteCardIds();
});

// === 状态变更通知器 ===

/// 操作后刷新用的状态
class AcademyActionState {
  final int version;
  const AcademyActionState(this.version);
}

final academyActionsProvider = StateNotifierProvider<AcademyActionNotifier, AcademyActionState>((ref) {
  return AcademyActionNotifier(ref);
});

class AcademyActionNotifier extends StateNotifier<AcademyActionState> {
  final Ref _ref;
  AcademyActionNotifier(this._ref) : super(const AcademyActionState(0));

  Future<void> markStarted(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.markStarted(courseId);
    _refresh();
  }

  Future<void> markCompleted(String courseId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.markCompleted(courseId);
    _refresh();
  }

  Future<void> submitAssignment(AssignmentSubmission submission) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.submitAssignment(submission);
    _refresh();
  }

  Future<void> toggleFavorite(String cardId) async {
    final repo = await _ref.read(academyRepositoryProvider.future);
    await repo.toggleFavorite(cardId);
    _refresh();
  }

  void _refresh() {
    state = AcademyActionState(state.version + 1);
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/providers/academy_providers.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/providers/academy_providers.dart
git commit -m "feat(academy): add Riverpod providers"
```

---

## Task 6: 进度环 Widget

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/widgets/academy_progress_ring.dart`

**Interfaces:**
- Produces: `AcademyProgressRing` widget (CustomPainter)

- [ ] **Step 1: 创建 academy_progress_ring.dart**

```dart
import 'dart:math';
import 'package:flutter/material.dart';

/// 圆形进度环（CustomPainter）
class AcademyProgressRing extends StatelessWidget {
  const AcademyProgressRing({
    super.key,
    required this.progress, // 0.0 - 1.0
    required this.size,
    this.strokeWidth = 6,
    this.ringColor,
    this.backgroundColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color? ringColor;
  final Color? backgroundColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              ringColor: ringColor ?? const Color(0xFFC9A96E),
              backgroundColor: backgroundColor ?? Colors.white.withOpacity(0.12),
            ),
          ),
          if (child != null) child!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color ringColor;
  final Color backgroundColor;

  _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.ringColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // 背景环
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = backgroundColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // 进度弧
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2, // 从顶部开始
        2 * pi * progress,
        false,
        Paint()
          ..color = ringColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      progress != oldDelegate.progress ||
      ringColor != oldDelegate.ringColor ||
      backgroundColor != oldDelegate.backgroundColor;
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/widgets/academy_progress_ring.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/widgets/academy_progress_ring.dart
git commit -m "feat(academy): add progress ring widget"
```

---

## Task 7: 学习概览卡 Widget

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/widgets/academy_overview_card.dart`

**Interfaces:**
- Consumes: `AcademyOverview` from Task 1, `AcademyProgressRing` from Task 6, `themeTokensProvider`, `NeuCard`
- Produces: `AcademyOverviewCard` widget

- [ ] **Step 1: 创建 academy_overview_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/academy_models.dart';
import 'academy_progress_ring.dart';

/// 学习概览卡：进度环 + 连续天数 + XP + 推荐下一课
class AcademyOverviewCard extends ConsumerWidget {
  const AcademyOverviewCard({super.key, required this.overview});

  final AcademyOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return NeuCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // 左侧：进度环
          AcademyProgressRing(
            progress: overview.completionRate,
            size: 72,
            ringColor: tokens.brand,
            backgroundColor: tokens.divider,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${(overview.completionRate * 100).round()}%',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                  ),
                ),
                Text(
                  '完成',
                  style: TextStyle(fontSize: 10, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // 右侧：统计信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.local_fire_department_outlined, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('${overview.streakDays} 天', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                    const SizedBox(width: 12),
                    Icon(Icons.bolt_outlined, size: 16, color: tokens.brand),
                    const SizedBox(width: 4),
                    Text('${overview.totalXP} XP', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${overview.completedCourses}/${overview.totalCourses} 课已完成',
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
                if (overview.nextCourseTitle != null) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      final id = overview.nextCourseId;
                      if (id != null) {
                        GoRouter.of(context).push(
                          RouteNames.build(RouteNames.profileAcademyDetail, {RouteNames.paramAcademyId: id}),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.play_circle_outlined, size: 16, color: tokens.brandText),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '继续：${overview.nextCourseTitle}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: tokens.brandText),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/widgets/academy_overview_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/widgets/academy_overview_card.dart
git commit -m "feat(academy): add overview card widget"
```

---

## Task 8: 难度等级选择器 Widget

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/widgets/academy_level_selector.dart`

**Interfaces:**
- Consumes: `AcademyLevel` from Task 1, `themeTokensProvider`
- Produces: `AcademyLevelSelector` widget

- [ ] **Step 1: 创建 academy_level_selector.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/academy_models.dart';

/// 难度等级横向选择器（pill 样式）
class AcademyLevelSelector extends ConsumerWidget {
  const AcademyLevelSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AcademyLevel? selected; // null = 全部
  final ValueChanged<AcademyLevel?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    final items = <_LevelItem>[
      _LevelItem(level: null, label: '全部'),
      _LevelItem(level: AcademyLevel.beginner, label: AcademyLevel.beginner.label),
      _LevelItem(level: AcademyLevel.intermediate, label: AcademyLevel.intermediate.label),
      _LevelItem(level: AcademyLevel.advanced, label: AcademyLevel.advanced.label),
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = item.level == selected;
          return GestureDetector(
            onTap: () => onChanged(item.level),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? tokens.brand : tokens.surface,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(
                  color: isSelected ? tokens.brand : tokens.divider,
                  width: 1,
                ),
              ),
              child: Text(
                item.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? tokens.textInverse : tokens.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LevelItem {
  final AcademyLevel? level;
  final String label;
  const _LevelItem({required this.level, required this.label});
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/widgets/academy_level_selector.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/widgets/academy_level_selector.dart
git commit -m "feat(academy): add level selector widget"
```

---

## Task 9: 课程卡片 Widget

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/widgets/academy_course_card.dart`

**Interfaces:**
- Consumes: `AcademyCourse`、`CourseStatus` from Task 1, `themeTokensProvider`, `NeuCard`
- Produces: `AcademyCourseCard` widget

- [ ] **Step 1: 创建 academy_course_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/academy_models.dart';

/// 课程卡片（用于课程网格）
class AcademyCourseCard extends ConsumerWidget {
  const AcademyCourseCard({
    super.key,
    required this.course,
    required this.status,
    required this.onTap,
  });

  final AcademyCourse course;
  final CourseStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return GestureDetector(
      onTap: onTap,
      child: NeuCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面图
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Image.network(
                      course.coverImage,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(Icons.image_outlined, color: tokens.textTertiary),
                      ),
                    ),
                  ),
                ),
                // 状态角标
                if (status != CourseStatus.notStarted)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: status == CourseStatus.completed
                            ? tokens.success
                            : tokens.brand,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            status == CourseStatus.completed
                                ? Icons.check_circle
                                : Icons.play_circle_outline,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            status == CourseStatus.completed ? '已完成' : '学习中',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 课号角标
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      '第${course.lessonNumber}课',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
            // 标题与 meta
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.title,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    course.meta,
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: course.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(fontSize: 10, color: tokens.brandText),
                      ),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/widgets/academy_course_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/widgets/academy_course_card.dart
git commit -m "feat(academy): add course card widget"
```

---

## Task 10: 知识卡片 Widget

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/widgets/academy_knowledge_card.dart`

**Interfaces:**
- Consumes: `KnowledgeCard` from Task 1, `themeTokensProvider`, `NeuCard`
- Produces: `AcademyKnowledgeCard` widget

- [ ] **Step 1: 创建 academy_knowledge_card.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../data/academy_models.dart';

/// 知识卡片（横向滑动展示用）
class AcademyKnowledgeCard extends ConsumerWidget {
  const AcademyKnowledgeCard({
    super.key,
    required this.card,
    required this.isFavorited,
    required this.onTap,
    required this.onFavorite,
  });

  final KnowledgeCard card;
  final bool isFavorited;
  final VoidCallback onTap;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(right: 12),
        child: NeuCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 封面图
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(
                        card.coverImage,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: tokens.surfaceAlt,
                          child: Icon(Icons.image_outlined, color: tokens.textTertiary),
                        ),
                      ),
                    ),
                  ),
                  // 主题标签
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(
                        card.topic.label,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                      ),
                    ),
                  ),
                  // 收藏按钮
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: onFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isFavorited ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: isFavorited ? Colors.redAccent : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              // 标题与副标题
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.title,
                      style: TextStyle(
                        fontFamily: 'Noto Serif SC',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.subtitle,
                      style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/widgets/academy_knowledge_card.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/widgets/academy_knowledge_card.dart
git commit -m "feat(academy): add knowledge card widget"
```

---

## Task 11: 学院首页

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/pages/academy_page.dart`

**Interfaces:**
- Consumes: All widgets from Tasks 6-10, all providers from Task 5, `themeTokensProvider`, `LumiraNav`, `GlassBackground`, `FloatingTabBar`, `FadeUp`, `RouteNames`
- Produces: `AcademyPage` widget

- [ ] **Step 1: 创建 academy_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tabbar/floating_tabbar.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';
import '../widgets/academy_course_card.dart';
import '../widgets/academy_knowledge_card.dart';
import '../widgets/academy_level_selector.dart';
import '../widgets/academy_overview_card.dart';

/// 摄影美学院首页
class AcademyPage extends ConsumerStatefulWidget {
  const AcademyPage({super.key});

  @override
  ConsumerState<AcademyPage> createState() => _AcademyPageState();
}

class _AcademyPageState extends ConsumerState<AcademyPage> {
  AcademyLevel? _selectedLevel;

  void _goDetail(String courseId) {
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.profileAcademyDetail, {RouteNames.paramAcademyId: courseId}),
    );
  }

  void _goKnowledge(String cardId) {
    GoRouter.of(context).push(
      RouteNames.profileAcademyKnowledge,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final actionState = ref.watch(academyActionsProvider);
    final overviewAsync = ref.watch(academyOverviewProvider);
    final favoriteIdsAsync = ref.watch(favoriteCardIdsProvider);
    final knowledgeCards = ref.watch(knowledgeCardsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '摄影美学院', transparent: true),
      body: GlassBackground(
        variant: GlassBackgroundVariant.profile,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 140),
            children: [
              // Section 1: 学习概览卡
              FadeUp(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: overviewAsync.when(
                    data: (overview) => AcademyOverviewCard(overview: overview),
                    loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                    error: (_, __) => const SizedBox(height: 72),
                  ),
                ),
              ),
              // Section 2: 难度等级选择器
              FadeUp(
                delay: const Duration(milliseconds: 60),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: AcademyLevelSelector(
                    selected: _selectedLevel,
                    onChanged: (level) => setState(() => _selectedLevel = level),
                  ),
                ),
              ),
              // Section 3: 课程网格（2 列）
              FadeUp(
                delay: const Duration(milliseconds: 100),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _CourseGrid(
                    level: _selectedLevel,
                    actionVersion: actionState.version,
                    onTap: _goDetail,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              // Section 4: 知识卡片
              FadeUp(
                delay: const Duration(milliseconds: 140),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 0, 12),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined, size: 20, color: tokens.brand),
                      const SizedBox(width: 6),
                      Text(
                        '美学知识',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: tokens.textPrimary,
                          letterSpacing: -0.2,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: 20),
                  itemCount: knowledgeCards.length,
                  itemBuilder: (context, index) {
                    final kc = knowledgeCards[index];
                    final isFav = favoriteIdsAsync.maybeWhen(
                      data: (ids) => ids.contains(kc.id),
                      orElse: () => false,
                    );
                    return AcademyKnowledgeCard(
                      card: kc,
                      isFavorited: isFav,
                      onTap: () => _goKnowledge(kc.id),
                      onFavorite: () {
                        ref.read(academyActionsProvider.notifier).toggleFavorite(kc.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const FloatingTabBar(active: 'profile'),
    );
  }
}

/// 课程网格（2 列）
class _CourseGrid extends ConsumerWidget {
  const _CourseGrid({required this.level, required this.actionVersion, required this.onTap});

  final AcademyLevel? level;
  final int actionVersion;
  final void Function(String courseId) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch actionVersion to trigger rebuild after status changes
    ref.watch(academyActionsProvider);
    final courses = ref.watch(coursesProvider(level));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: courses.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.52,
      ),
      itemBuilder: (context, index) {
        final course = courses[index];
        final progressAsync = ref.watch(courseProgressProvider(course.id));
        final status = progressAsync.maybeWhen(
          data: (p) => p?.status ?? CourseStatus.notStarted,
          orElse: () => CourseStatus.notStarted,
        );
        return AcademyCourseCard(
          course: course,
          status: status,
          onTap: () => onTap(course.id),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/pages/academy_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_page.dart
git commit -m "feat(academy): add academy main page with course grid and knowledge cards"
```

---

## Task 12: 课程详情页

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/pages/academy_detail_page.dart`

**Interfaces:**
- Consumes: `courseDetailProvider`、`courseProgressProvider`、`academyActionsProvider` from Task 5, `themeTokensProvider`, `LumiraNav`, `NeuCard`, `LumiraButton`, `RouteNames`, existing private widget classes from `profile_academy_detail_page.dart` (migrated)
- Produces: `AcademyDetailPage` widget

- [ ] **Step 1: 创建 academy_detail_page.dart**

从 `profile_academy_detail_page.dart` 迁移全部私有 widget 类（`_BackButton`、`_LessonHead`、`_HeroImage`、`_ContentBody`、`_SectionTitle`、`_TipCard`、`_CompareGrid`、`_CompareCellView`、`_PracticeCard`、`_TipsCard`、`_RecommendCard`），改为从 `AcademyMockData` / providers 动态加载课程数据。核心变化：

1. 页面类名从 `ProfileAcademyDetailPage` 改为 `AcademyDetailPage`
2. 数据来源从 `ProfileContentMockData` 硬编码改为 `courseDetailProvider(academyId)` 动态加载
3. 新增"开始实战"CTA 按钮跳转作业页
4. 标记完成绑定 `academyActionsProvider.notifier.markCompleted`
5. 新增内嵌知识卡片 section
6. import 路径从 `../data/profile_content_mock_data.dart` 改为 academy 模块内的路径

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 课程详情页
class AcademyDetailPage extends ConsumerStatefulWidget {
  const AcademyDetailPage({super.key, this.academyId});

  final String? academyId;

  @override
  ConsumerState<AcademyDetailPage> createState() => _AcademyDetailPageState();
}

class _AcademyDetailPageState extends ConsumerState<AcademyDetailPage> {
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    // 标记为已开始学习
    if (widget.academyId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(academyActionsProvider.notifier).markStarted(widget.academyId!);
      });
    }
  }

  void _toggleBookmark() {
    setState(() => _bookmarked = !_bookmarked);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_bookmarked ? '已收藏' : '已取消收藏'),
        duration: const Duration(milliseconds: 1000),
      ),
    );
  }

  void _markComplete() {
    if (widget.academyId == null) return;
    ref.read(academyActionsProvider.notifier).markCompleted(widget.academyId!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已标记为已学完'), duration: Duration(milliseconds: 1000)),
    );
  }

  void _goAssignment() {
    if (widget.academyId == null) return;
    GoRouter.of(context).push(
      RouteNames.profileAcademyAssignment,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final academyId = widget.academyId;
    final detail = academyId != null ? ref.watch(courseDetailProvider(academyId)) : null;
    final progressAsync = academyId != null ? ref.watch(courseProgressProvider(academyId)) : null;

    if (detail == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: LumiraNav(title: '教程', transparent: true),
        body: Center(child: Text('课程不存在', style: TextStyle(color: tokens.textTertiary))),
      );
    }

    final isCompleted = progressAsync?.maybeWhen(
          data: (p) => p?.status == CourseStatus.completed,
          orElse: () => false,
        ) ?? false;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '教程',
        transparent: true,
        actions: [
          GestureDetector(
            onTap: _toggleBookmark,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                _bookmarked ? Icons.bookmark : Icons.bookmark_border,
                size: 22,
                color: tokens.textPrimary,
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [tokens.brandSubtle.withOpacity(0.35), tokens.canvas.withOpacity(0.0)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _LessonHead(detail: detail, tokens: tokens),
                _HeroImage(detail: detail, tokens: tokens),
                _ContentBody(
                  detail: detail,
                  tokens: tokens,
                  isCompleted: isCompleted,
                  onMarkComplete: _markComplete,
                  onGoAssignment: _goAssignment,
                  ref: ref,
                ),
                // 内嵌知识卡片 section
                if (detail.knowledgeCardIds.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('相关知识', style: TextStyle(
                      fontFamily: 'Noto Serif SC', fontSize: 17,
                      fontWeight: FontWeight.w600, color: tokens.textPrimary,
                    )),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 140,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(left: 24),
                      itemCount: detail.knowledgeCardIds.length,
                      itemBuilder: (context, index) {
                        final cardId = detail.knowledgeCardIds[index];
                        final kc = AcademyMockData.getKnowledgeCard(cardId);
                        if (kc == null) return const SizedBox.shrink();
                        return Container(
                          width: 160,
                          margin: const EdgeInsets.only(right: 12),
                          child: NeuCard(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(kc.title, style: TextStyle(
                                  fontFamily: 'Noto Serif SC', fontSize: 14,
                                  fontWeight: FontWeight.w600, color: tokens.textPrimary,
                                ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(kc.subtitle, style: TextStyle(
                                  fontSize: 11, color: tokens.textTertiary,
                                ), maxLines: 2, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// === 迁移自 profile_academy_detail_page.dart 的私有 widget ===
// 以下 widget 与原文件基本一致，唯一变化：数据来源从 ProfileContentMockData 改为 AcademyCourseDetail

class _LessonHead extends StatelessWidget {
  const _LessonHead({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第${detail.course.lessonNumber}课 · ${detail.course.title}',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(detail.course.meta, style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Image.network(detail.heroImage, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: tokens.surfaceAlt,
              child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContentBody extends StatelessWidget {
  const _ContentBody({
    required this.detail,
    required this.tokens,
    required this.isCompleted,
    required this.onMarkComplete,
    required this.onGoAssignment,
    required this.ref,
  });

  final AcademyCourseDetail detail;
  final ThemeTokens tokens;
  final bool isCompleted;
  final VoidCallback onMarkComplete;
  final VoidCallback onGoAssignment;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final sections = detail.sections;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1
          if (sections.isNotEmpty) ...[
            _SectionTitle(text: sections[0].title, tokens: tokens),
            const SizedBox(height: 8),
            for (var i = 0; i < sections[0].paragraphs.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(sections[0].paragraphs[i], style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
            ],
            const SizedBox(height: 28),
          ],
          // TipCard
          _TipCard(detail: detail, tokens: tokens),
          const SizedBox(height: 28),
          // Section 2 + CompareGrid
          if (sections.length >= 2) ...[
            _SectionTitle(text: sections[1].title, tokens: tokens),
            const SizedBox(height: 8),
            if (sections[1].paragraphs.isNotEmpty)
              Text(sections[1].paragraphs[0], style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
            const SizedBox(height: 12),
            _CompareGrid(detail: detail, tokens: tokens),
            const SizedBox(height: 28),
          ],
          // PracticeCard
          _PracticeCard(detail: detail, tokens: tokens),
          const SizedBox(height: 28),
          // Section 3 + Tips
          if (sections.length >= 3) ...[
            _SectionTitle(text: sections[2].title, tokens: tokens),
            const SizedBox(height: 12),
            _TipsCard(detail: detail, tokens: tokens),
            const SizedBox(height: 28),
          ],
          // RecommendTemplate
          if (detail.recommendTemplate != null) ...[
            _SectionTitle(text: '推荐模板', tokens: tokens),
            const SizedBox(height: 12),
            _RecommendCard(detail: detail, tokens: tokens),
            const SizedBox(height: 32),
          ],
          // 开始实战 CTA
          if (detail.assignment != null) ...[
            LumiraButton(
              label: '开始实战',
              icon: Icons.camera_alt_outlined,
              onPressed: onGoAssignment,
            ),
            const SizedBox(height: 12),
          ],
          // 标记完成
          LumiraButton(
            label: '标记为已学完',
            icon: Icons.check,
            onPressed: isCompleted ? null : onMarkComplete,
            enabled: !isCompleted,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(
      fontFamily: 'Noto Serif SC', fontSize: 17,
      fontWeight: FontWeight.w600, color: tokens.textPrimary,
    ));
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(9999)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.auto_awesome, size: 12, color: tokens.brandText),
              const SizedBox(width: 4),
              Text('技巧', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.brandText)),
            ]),
          ),
          const SizedBox(height: 10),
          Text(detail.tipCardTitle, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 6),
          Text(detail.tipCardParagraph, style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(detail.tipCardImage, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareGrid extends StatelessWidget {
  const _CompareGrid({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final cells = detail.compareCells;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _CompareCellView(cell: cells[i], tokens: tokens)),
          ],
        ],
      ),
    );
  }
}

class _CompareCellView extends StatelessWidget {
  const _CompareCellView({required this.cell, required this.tokens});
  final CompareCell cell;
  final ThemeTokens tokens;

  Color get _tagBg => cell.tagColor == 'green' ? tokens.successSubtle : tokens.brandSubtle;
  Color get _tagText => cell.tagColor == 'green' ? tokens.success : tokens.brandText;

  IconData _iconFor(String name) {
    switch (name) {
      case 'arrow_down': return Icons.arrow_downward;
      case 'arrows_left_right': return Icons.swap_horiz;
      case 'sun': return Icons.wb_sunny_outlined;
      case 'lightbulb': return Icons.lightbulb_outline;
      case 'face': return Icons.face_outlined;
      default: return Icons.compare_arrows;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: tokens.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_iconFor(cell.iconName), size: 32, color: tokens.brand),
          const SizedBox(height: 8),
          Text(cell.name, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 4),
          Text(cell.desc, style: TextStyle(fontSize: 11, color: tokens.textTertiary, height: 1.5)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _tagBg, borderRadius: BorderRadius.circular(9999)),
            child: Text(cell.tagText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _tagText)),
          ),
        ],
      ),
    );
  }
}

class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  Color _tagBg(String color) {
    switch (color) {
      case 'gold': return tokens.brandSubtle;
      case 'green': return tokens.successSubtle;
      default: return tokens.dangerSubtle;
    }
  }

  Color _tagText(String color) {
    switch (color) {
      case 'gold': return tokens.brandText;
      case 'green': return tokens.success;
      default: return tokens.danger;
    }
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'camera': return Icons.camera_alt_outlined;
      case 'sun': return Icons.wb_sunny_outlined;
      case 'arrow_down': return Icons.arrow_downward;
      case 'face': return Icons.face_outlined;
      case 'lightbulb': return Icons.lightbulb_outline;
      default: return Icons.label_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tokens.brand, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: tokens.brand, borderRadius: BorderRadius.circular(9999)),
            child: Text('实战练习', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.textInverse)),
          ),
          const SizedBox(height: 10),
          Text(detail.practiceTitle, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary)),
          const SizedBox(height: 6),
          Text(detail.practiceParagraph, style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: detail.practiceTags.map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _tagBg(t.color), borderRadius: BorderRadius.circular(9999)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_iconFor(t.iconName), size: 12, color: _tagText(t.color)),
                const SizedBox(width: 4),
                Text(t.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _tagText(t.color))),
              ]),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  const _TipsCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: tokens.canvas,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tokens.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < detail.tips.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 8), child: Container(width: 4, height: 4, decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle))),
              const SizedBox(width: 8),
              Expanded(child: Text(detail.tips[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 2.0))),
            ]),
          ],
        ],
      ),
    );
  }
}

class _RecommendCard extends StatelessWidget {
  const _RecommendCard({required this.detail, required this.tokens});
  final AcademyCourseDetail detail;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final r = detail.recommendTemplate!;
    return NeuCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 80,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(r.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.broken_image_outlined, color: tokens.textTertiary)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.name, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(r.desc, style: TextStyle(fontSize: 12, color: tokens.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(9999)),
                child: Text(r.badge, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: tokens.brandText)),
              ),
            ],
          )),
        ],
      ),
    );
  }
}
```

注意：`AcademyMockData` 的引用来自 Task 2 的 `academy_mock_data.dart`，需在文件顶部添加 `import '../data/academy_mock_data.dart';`（如果 `courseDetailProvider` 没有返回 knowledgeCardIds 的解析）。实际上 `detail.knowledgeCardIds` 已经是 `List<String>`，通过 `AcademyMockData.getKnowledgeCard(cardId)` 获取卡片详情。需在文件顶部添加该 import。

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/pages/academy_detail_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_detail_page.dart
git commit -m "feat(academy): add course detail page migrated from profile"
```

---

## Task 13: 实战作业页

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/pages/academy_assignment_page.dart`
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart` — 添加 returnResult 模式

**Interfaces:**
- Consumes: `courseDetailProvider`、`assignmentSubmissionProvider`、`academyActionsProvider` from Task 5, `themeTokensProvider`, `LumiraNav`, `LumiraButton`, `NeuCard`, `file_picker`, `RouteNames`
- Produces: `AcademyAssignmentPage` widget

- [ ] **Step 1: 修改 capture_page.dart 添加 returnResult 模式**

在 `capture_page.dart` 中：
1. 添加 `returnResult` 参数解析（从 query params 读取 `mode=return`）
2. 在拍照完成后，如果 `returnResult == true`，调用 `context.pop(photoPath)` 返回，而非导航到 preview 页

具体修改：
- 在 `CapturePage` 的 build 或 initState 中读取 `mode` query param
- 在拍照成功回调中，检查 `returnResult` flag，如果为 true 则 `context.pop(processedPath)`

由于 capture_page.dart 的拍照流程涉及 `_onCapture` 方法和 `captureState$` 监听器，需要在导航到 preview 的两个位置（约 line 187 和 line 443）添加条件判断：

```dart
// 原代码（约 line 187）:
context.push('${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(processedPath)}');

// 修改为:
if (_returnResult) {
  context.pop(processedPath);
} else {
  context.push('${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(processedPath)}');
}
```

在 `CapturePage` 类中添加：
```dart
bool _returnResult = false;

@override
void initState() {
  super.initState();
  // 已有的 initState 逻辑...
  // 检查是否为返回结果模式
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final mode = GoRouterState.of(context).queryParams[RouteNames.paramMode];
    _returnResult = mode == 'return';
  });
}
```

对 line 443 的第二处导航做相同条件判断。

- [ ] **Step 2: 创建 academy_assignment_page.dart**

```dart
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/buttons/lumira_buttons.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_mock_data.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 实战作业页
class AcademyAssignmentPage extends ConsumerStatefulWidget {
  const AcademyAssignmentPage({super.key, this.academyId});

  final String? academyId;

  @override
  ConsumerState<AcademyAssignmentPage> createState() => _AcademyAssignmentPageState();
}

class _AcademyAssignmentPageState extends ConsumerState<AcademyAssignmentPage> {
  String? _photoPath;
  String? _photoUrl;
  String _note = '';
  bool _submitting = false;
  AssignmentSubmission? _result;

  Future<void> _pickFromCamera() async {
    // 通过拍摄页拍摄，返回 photoPath
    final result = await GoRouter.of(context).push<String>(
      RouteNames.build(RouteNames.capture, {RouteNames.paramMode: 'return'}),
    );
    if (result != null && mounted) {
      setState(() {
        _photoPath = result;
        _photoUrl = null;
      });
    }
  }

  Future<void> _pickFromAlbum() async {
    try {
      final pickResult = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (pickResult == null || pickResult.files.isEmpty) return;
      final file = pickResult.files.first;
      final path = file.path;
      if (path != null && mounted) {
        setState(() {
          _photoPath = path;
          _photoUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择照片失败: $e'), duration: const Duration(milliseconds: 1500)),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (widget.academyId == null) return;
    final detail = AcademyMockData.getCourseDetail(widget.academyId!);
    final assignment = detail?.assignment;
    if (assignment == null) return;

    setState(() => _submitting = true);

    // 模拟评分
    await Future.delayed(const Duration(seconds: 1));
    final score = AcademyMockData.generateScore();
    final feedback = AcademyMockData.generateFeedback(score);

    final submission = AssignmentSubmission(
      id: 'sub_${assignment.id}_${DateTime.now().millisecondsSinceEpoch}',
      assignmentId: assignment.id,
      courseId: widget.academyId!,
      photoPath: _photoPath,
      photoUrl: _photoUrl,
      note: _note.isNotEmpty ? _note : null,
      status: AssignmentStatus.reviewed,
      score: score,
      feedback: feedback,
      submittedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await ref.read(academyActionsProvider.notifier).submitAssignment(submission);

    if (mounted) {
      setState(() {
        _result = submission;
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final academyId = widget.academyId;
    final detail = academyId != null ? ref.watch(courseDetailProvider(academyId)) : null;
    final assignment = detail?.assignment;

    if (assignment == null) {
      return Scaffold(
        backgroundColor: tokens.canvas,
        appBar: LumiraNav(title: '实战作业', transparent: true),
        body: Center(child: Text('作业不存在', style: TextStyle(color: tokens.textTertiary))),
      );
    }

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '实战作业', transparent: true),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 作业标题
              Text(assignment.title, style: TextStyle(
                fontFamily: 'Noto Serif SC', fontSize: 20,
                fontWeight: FontWeight.w600, color: tokens.textPrimary,
              )),
              const SizedBox(height: 8),
              Text(assignment.description, style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.6)),
              const SizedBox(height: 16),
              // 作业要求
              if (assignment.requirements.isNotEmpty) ...[
                Text('作业要求', style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 8),
                for (var i = 0; i < assignment.requirements.length; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(color: tokens.brand, shape: BoxShape.circle),
                    )),
                    const SizedBox(width: 8),
                    Expanded(child: Text(assignment.requirements[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6))),
                  ]),
                ],
                const SizedBox(height: 24),
              ],
              // 照片预览或选择按钮
              if (_photoPath != null || _photoUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: _photoPath != null
                        ? Image.file(File(_photoPath!), fit: BoxFit.cover)
                        : Image.network(_photoUrl!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: LumiraButton(
                    label: '重新拍摄', icon: Icons.camera_alt_outlined,
                    onPressed: _pickFromCamera,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    label: '重新选择', icon: Icons.photo_library_outlined,
                    onPressed: _pickFromAlbum,
                  )),
                ]),
              ] else ...[
                Row(children: [
                  Expanded(child: LumiraButton(
                    label: '去拍摄', icon: Icons.camera_alt_outlined,
                    onPressed: _pickFromCamera,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: LumiraButton(
                    label: '从相册选择', icon: Icons.photo_library_outlined,
                    onPressed: _pickFromAlbum,
                  )),
                ]),
              ],
              const SizedBox(height: 20),
              // 备注
              TextField(
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  labelStyle: TextStyle(color: tokens.textTertiary, fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.divider)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.divider)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tokens.brand)),
                ),
                maxLines: 3,
                style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                onChanged: (v) => _note = v,
              ),
              const SizedBox(height: 24),
              // 提交按钮
              if (_result == null)
                LumiraButton(
                  label: _submitting ? '提交中...' : '提交作业',
                  icon: Icons.send,
                  onPressed: (_photoPath != null || _photoUrl != null) && !_submitting ? _submit : null,
                  enabled: (_photoPath != null || _photoUrl != null) && !_submitting,
                )
              else ...[
                // 评分结果
                NeuCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    Icon(Icons.emoji_events_outlined, size: 48, color: tokens.brand),
                    const SizedBox(height: 8),
                    Text('${_result!.score} 分', style: TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w700, color: tokens.brand,
                    )),
                    const SizedBox(height: 8),
                    Text(_result!.feedback ?? '', style: TextStyle(
                      fontSize: 13, color: tokens.textSecondary, height: 1.6,
                    ), textAlign: TextAlign.center),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/pages/academy_assignment_page.dart lib/features/capture/pages/capture_page.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_assignment_page.dart lumira_app_flutter/lib/features/capture/pages/capture_page.dart
git commit -m "feat(academy): add assignment page with camera/album submission"
```

---

## Task 14: 知识卡片详情页

**Files:**
- Create: `lumira_app_flutter/lib/features/academy/pages/academy_knowledge_page.dart`

**Interfaces:**
- Consumes: `knowledgeCardsProvider`、`favoriteCardIdsProvider`、`academyActionsProvider` from Task 5, `themeTokensProvider`, `LumiraNav`, `NeuCard`
- Produces: `AcademyKnowledgePage` widget

- [ ] **Step 1: 创建 academy_knowledge_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/academy_models.dart';
import '../providers/academy_providers.dart';

/// 知识卡片详情页
class AcademyKnowledgePage extends ConsumerStatefulWidget {
  const AcademyKnowledgePage({super.key, this.cardId});

  final String? cardId;

  @override
  ConsumerState<AcademyKnowledgePage> createState() => _AcademyKnowledgePageState();
}

class _AcademyKnowledgePageState extends ConsumerState<AcademyKnowledgePage> {
  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final cards = ref.watch(knowledgeCardsProvider);
    final favoriteIdsAsync = ref.watch(favoriteCardIdsProvider);

    // 如果有 cardId，显示单卡详情；否则显示全部卡片列表
    final card = widget.cardId != null
        ? cards.where((c) => c.id == widget.cardId).firstOrNull
        : null;

    if (card != null) {
      // 单卡详情模式
      final isFav = favoriteIdsAsync.maybeWhen(
        data: (ids) => ids.contains(card.id),
        orElse: () => false,
      );

      return Scaffold(
        backgroundColor: tokens.canvas,
        extendBodyBehindAppBar: true,
        appBar: LumiraNav(title: '知识卡片', transparent: true),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 封面图
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(card.coverImage, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.image_outlined, color: tokens.textTertiary)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 标题
                Text(card.title, style: TextStyle(
                  fontFamily: 'Noto Serif SC', fontSize: 22,
                  fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 4),
                Text(card.subtitle, style: TextStyle(fontSize: 13, color: tokens.textTertiary)),
                const SizedBox(height: 16),
                // 收藏按钮
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () => ref.read(academyActionsProvider.notifier).toggleFavorite(card.id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isFav ? tokens.dangerSubtle : tokens.brandSubtle,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: isFav ? tokens.danger : tokens.brandText),
                        const SizedBox(width: 6),
                        Text(isFav ? '已收藏' : '收藏', style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500,
                          color: isFav ? tokens.danger : tokens.brandText,
                        )),
                      ]),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 正文
                Text(card.body, style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.8)),
                const SizedBox(height: 24),
                // 关键要点
                if (card.keyPoints.isNotEmpty) ...[
                  Text('关键要点', style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                  )),
                  const SizedBox(height: 12),
                  NeuCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0; i < card.keyPoints.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Container(
                              width: 20, height: 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: tokens.brandSubtle, shape: BoxShape.circle),
              child: Text('${i + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: tokens.brandText)),
            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(card.keyPoints[i], style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.6))),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // 相关推荐
                Text('相关知识', style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600, color: tokens.textPrimary,
                )),
                const SizedBox(height: 12),
                _RelatedCards(
                  currentCardId: card.id,
                  topic: card.topic,
                  ref: ref,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 全部卡片列表模式
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: const LumiraNav(title: '美学知识', transparent: true),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: cards.length,
          itemBuilder: (context, index) {
            final kc = cards[index];
            final isFav = favoriteIdsAsync.maybeWhen(
              data: (ids) => ids.contains(kc.id),
              orElse: () => false,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NeuCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 80,
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(kc.coverImage, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt, child: Icon(Icons.image_outlined, color: tokens.textTertiary)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kc.title, style: TextStyle(fontFamily: 'Noto Serif SC', fontSize: 15, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text(kc.subtitle, style: TextStyle(fontSize: 12, color: tokens.textTertiary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: tokens.brandSubtle, borderRadius: BorderRadius.circular(4)),
                            child: Text(kc.topic.label, style: TextStyle(fontSize: 10, color: tokens.brandText)),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => ref.read(academyActionsProvider.notifier).toggleFavorite(kc.id),
                            child: Icon(isFav ? Icons.favorite : Icons.favorite_border, size: 16, color: isFav ? tokens.danger : tokens.textTertiary),
                          ),
                        ]),
                      ],
                    )),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RelatedCards extends ConsumerWidget {
  const _RelatedCards({required this.currentCardId, required this.topic, required this.ref});
  final String currentCardId;
  final AcademyTopic topic;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef _) {
    final tokens = ref.watch(themeTokensProvider);
    final allCards = ref.watch(knowledgeCardsProvider);
    final related = allCards.where((c) => c.id != currentCardId && c.topic == topic).toList();

    if (related.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: related.map((kc) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: NeuCard(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                child: AspectRatio(
                  aspectRatio: 4 / 3,
                  child: Image.network(kc.coverImage, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: tokens.surfaceAlt),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(kc.title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(kc.subtitle, style: TextStyle(fontSize: 11, color: tokens.textTertiary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            )),
          ]),
        ),
      )).toList(),
    );
  }
}
```

- [ ] **Step 2: 运行 analyze 验证**

Run: `cd lumira_app_flutter && flutter analyze lib/features/academy/pages/academy_knowledge_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lumira_app_flutter/lib/features/academy/pages/academy_knowledge_page.dart
git commit -m "feat(academy): add knowledge card detail page"
```

---

## Task 15: 路由更新 + 入口设计 + 清理

**Files:**
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart` — 新增 2 个路由常量
- Modify: `lumira_app_flutter/lib/app/router.dart` — 更新现有路由引用 + 新增 2 个路由
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_page.dart` — 新增学院入口卡片
- Delete: `lumira_app_flutter/lib/features/profile/pages/profile_academy_page.dart`
- Delete: `lumira_app_flutter/lib/features/profile/pages/profile_academy_detail_page.dart`
- Modify: `lumira_app_flutter/lib/features/profile/data/profile_content_mock_data.dart` — 移除 academy 相关数据

- [ ] **Step 1: 更新 route_names.dart — 新增路由常量**

在 `route_names.dart` 的路径常量区域，`profileAcademyDetail` 之后新增：

```dart
  static const String profileAcademyAssignment = '/profile/academy/assignment';
  static const String profileAcademyKnowledge = '/profile/academy/knowledge';
```

- [ ] **Step 2: 更新 router.dart — 替换页面引用 + 新增路由**

1. 替换 import：
```dart
// 删除：
// import '../features/profile/pages/profile_academy_page.dart';
// import '../features/profile/pages/profile_academy_detail_page.dart';
// 新增：
import '../features/academy/pages/academy_page.dart';
import '../features/academy/pages/academy_detail_page.dart';
import '../features/academy/pages/academy_assignment_page.dart';
import '../features/academy/pages/academy_knowledge_page.dart';
```

2. 替换现有 academy 路由的 builder：
```dart
      GoRoute(
        path: RouteNames.profileAcademy,
        name: 'profileAcademy',
        builder: (context, state) => const AcademyPage(),
      ),
      GoRoute(
        path: RouteNames.profileAcademyDetail,
        name: 'profileAcademyDetail',
        builder: (context, state) {
          final academyId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyDetailPage(academyId: academyId);
        },
      ),
```

3. 新增 2 个路由（在 `profileAcademyDetail` 路由之后）：
```dart
      GoRoute(
        path: RouteNames.profileAcademyAssignment,
        name: 'profileAcademyAssignment',
        builder: (context, state) {
          final academyId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyAssignmentPage(academyId: academyId);
        },
      ),
      GoRoute(
        path: RouteNames.profileAcademyKnowledge,
        name: 'profileAcademyKnowledge',
        builder: (context, state) {
          final cardId = state.queryParams[RouteNames.paramAcademyId];
          return AcademyKnowledgePage(cardId: cardId);
        },
      ),
```

注意：assignment 路由也需要传递 `academyId`。更新 `academy_detail_page.dart` 中的 `_goAssignment` 方法，确保传递 academyId：

```dart
  void _goAssignment() {
    if (widget.academyId == null) return;
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.profileAcademyAssignment, {RouteNames.paramAcademyId: widget.academyId!}),
    );
  }
```

同时更新 `academy_page.dart` 中的 `_goKnowledge` 方法传递 cardId：

```dart
  void _goKnowledge(String cardId) {
    GoRouter.of(context).push(
      RouteNames.build(RouteNames.profileAcademyKnowledge, {RouteNames.paramAcademyId: cardId}),
    );
  }
```

- [ ] **Step 3: 更新 templates_page.dart — 新增学院入口卡片**

在 `templates_page.dart` 的 ListView body 中，`SceneCategoryOverview` 之后新增学院入口卡片 section：

```dart
    const SizedBox(height: 28),
    // === 摄影美学院 section ===
    FadeUp(delay: const Duration(milliseconds: 240), child: _AcademyEntrySection()),
    const SizedBox(height: 140), // bottom spacer
```

在文件底部新增 `_AcademyEntrySection` widget（需新增 import `academy_page.dart` 用于跳转）：

```dart
// 文件顶部新增 import：
import '../../academy/pages/academy_page.dart'; // 仅用于类型引用（实际跳转用 GoRouter）
import '../../../core/router/route_names.dart';

/// 摄影美学院入口卡片
class _AcademyEntrySection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(appThemeProvider).tokens;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.school_outlined, size: 20, color: tokens.brand),
                const SizedBox(width: 6),
                Text(
                  '摄影美学院',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: tokens.textPrimary,
                    letterSpacing: -0.2,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // 入口卡片（与模板网格卡片视觉一致）
          NeuCard(
            padding: EdgeInsets.zero,
            shadowVariant: NeuShadowVariant.convex,
            onTap: () => GoRouter.of(context).push(RouteNames.profileAcademy),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  // 封面图
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      'https://picsum.photos/seed/academy_entry/640/360',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: tokens.surfaceAlt,
                        child: Icon(Icons.school_outlined, size: 40, color: tokens.textTertiary),
                      ),
                    ),
                  ),
                  // 渐变遮罩 + 文字
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                          ],
                          stops: const [0.4, 1.0],
                        ),
                      ),
                    ),
                  ),
                  // 标题 + 副标题
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 14,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '系统学习摄影美学',
                          style: TextStyle(
                            fontFamily: 'Noto Serif SC',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '16 节课程 · 8 张知识卡片 · 实战作业',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // 右上角箭头
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.85),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 12,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

注意：`templates_page.dart` 顶部已有 `neu_card.dart` 和 `lumira_nav.dart` 的 import，需确认 `NeuCard`、`NeuShadowVariant`、`appThemeProvider` 已导入。如未导入，添加：

```dart
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../core/theme/theme_controller.dart';
```

- [ ] **Step 4: 清理旧 profile 文件**

1. 删除 `profile_academy_page.dart`：

```bash
git rm lumira_app_flutter/lib/features/profile/pages/profile_academy_page.dart
```

2. 删除 `profile_academy_detail_page.dart`：

```bash
git rm lumira_app_flutter/lib/features/profile/pages/profile_academy_detail_page.dart
```

3. 清理 `profile_content_mock_data.dart` — 移除已迁移到 academy 的数据：

打开 `lumira_app_flutter/lib/features/profile/data/profile_content_mock_data.dart`，删除以下内容：
- `LessonSection` 类定义（约 line 38-43）
- `CompareCell` 类定义（约 line 46-60）
- `PracticeTag` 类定义（约 line 63-73）
- `RecommendTemplate` 类定义（约 line 76-88）
- `ProfileContentMockData` 类中的 academy 相关字段：`lessonTitle`、`lessonMeta`、`lessonHeroImage`、`lessonSections`、`tipCardTitle`、`tipCardParagraph`、`tipCardImage`、`compareCells`、`practiceTitle`、`practiceParagraph`、`practiceTags`、`tips`、`recommendTemplate`（约 line 166-238）

保留 `ProfileContentMockData` 中的 `collections`、`photos`、`customTemplates`、`totalUsage`、`favoriteCount` 字段（这些属于 profile 模块，不属于 academy）。

4. 检查 `profile_page.dart` 中是否有对已删除文件的引用，如有则更新跳转路径：

```bash
cd lumira_app_flutter && grep -r "profile_academy" lib/
```

Expected: 仅 `router.dart` 中有引用（已在 Step 2 更新为 `AcademyPage`）。如有其他引用，更新为新的 academy 页面类。

- [ ] **Step 5: 运行 analyze 验证全部改动**

Run: `cd lumira_app_flutter && flutter analyze lib/app/router.dart lib/core/router/route_names.dart lib/features/templates/pages/templates_page.dart lib/features/profile/`
Expected: No issues found（无对已删除文件的引用错误）

- [ ] **Step 6: Commit**

```bash
cd e:\Project\photo_post
git add lumira_app_flutter/lib/core/router/route_names.dart lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/features/templates/pages/templates_page.dart lumira_app_flutter/lib/features/profile/data/profile_content_mock_data.dart
git rm lumira_app_flutter/lib/features/profile/pages/profile_academy_page.dart lumira_app_flutter/lib/features/profile/pages/profile_academy_detail_page.dart
git commit -m "feat(academy): update routes, add templates entry, cleanup old profile files"
```

---

## Task 16: DAO 单元测试

**Files:**
- Create: `lumira_app_flutter/test/features/academy/academy_dao_test.dart`

**Interfaces:**
- Consumes: `AcademyDao` from Task 3, `AcademyTables` constants, `sqflite_common_ffi` test helpers
- Produces: DAO 单元测试覆盖 course progress CRUD、assignment submission CRUD、knowledge favorite toggle

- [ ] **Step 1: 创建测试文件**

注意：测试直接调用 DAO 的底层方法（`upsertProgress`、`upsertSubmission`、`addFavorite`/`removeFavorite`），而非 Repository 的领域方法（`markStarted` 等）。Repository 的领域逻辑由其自身测试覆盖。

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/features/academy/data/academy_dao.dart';
import 'package:lumira_app_flutter/features/academy/data/academy_models.dart';

void main() {
  late Database db;
  late AcademyDao dao;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await openDatabase(':memory:', version: 1, onCreate: _onCreate);
    dao = AcademyDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('CourseProgress', () {
    test('getProgress returns null for non-existent course', () async {
      final progress = await dao.getProgress('non_existent');
      expect(progress, isNull);
    });

    test('upsertProgress creates inProgress record', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress, isNotNull);
      expect(progress!.status, CourseStatus.inProgress);
      expect(progress.progressPercent, 0);
      expect(progress.startedAt, now);
      expect(progress.completedAt, isNull);
    });

    test('upsertProgress updates percent', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 50, startedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress!.progressPercent, 50);
      expect(progress.status, CourseStatus.inProgress);
    });

    test('upsertProgress sets completed status and completedAt', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('course_1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('course_1', CourseStatus.completed, 100, startedAt: now, completedAt: now, lastViewedAt: now);
      final progress = await dao.getProgress('course_1');
      expect(progress!.status, CourseStatus.completed);
      expect(progress.progressPercent, 100);
      expect(progress.completedAt, isNotNull);
    });

    test('getAllProgress returns all records', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c2', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c3', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      final all = await dao.getAllProgress();
      expect(all.length, 3);
    });

    test('countCompleted returns only completed courses', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertProgress('c1', CourseStatus.inProgress, 0, startedAt: now, lastViewedAt: now);
      await dao.upsertProgress('c2', CourseStatus.completed, 100, startedAt: now, completedAt: now, lastViewedAt: now);
      expect(await dao.countCompleted(), 1);
    });
  });

  group('AssignmentSubmission', () {
    test('getSubmission returns null for non-existent assignment', () async {
      final sub = await dao.getSubmission('non_existent');
      expect(sub, isNull);
    });

    test('upsertSubmission inserts submission', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final submission = AssignmentSubmission(
        id: 'sub_1',
        assignmentId: 'assign_1',
        courseId: 'course_1',
        photoPath: '/path/to/photo.jpg',
        note: '我的作业',
        status: AssignmentStatus.submitted,
        submittedAt: now,
      );
      await dao.upsertSubmission(submission);
      final sub = await dao.getSubmission('assign_1');
      expect(sub, isNotNull);
      expect(sub!.assignmentId, 'assign_1');
      expect(sub.courseId, 'course_1');
      expect(sub.photoPath, '/path/to/photo.jpg');
      expect(sub.note, '我的作业');
      expect(sub.status, AssignmentStatus.submitted);
      expect(sub.submittedAt, now);
    });

    test('upsertSubmission replaces existing (upsert by assignmentId)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertSubmission(AssignmentSubmission(
        id: 'sub_1', assignmentId: 'assign_1', courseId: 'c1',
        photoPath: '/photo1.jpg', note: '第一版',
        status: AssignmentStatus.submitted, submittedAt: now,
      ));
      await dao.upsertSubmission(AssignmentSubmission(
        id: 'sub_2', assignmentId: 'assign_1', courseId: 'c1',
        photoPath: '/photo2.jpg', note: '第二版',
        status: AssignmentStatus.submitted, submittedAt: now,
      ));
      final sub = await dao.getSubmission('assign_1');
      expect(sub!.photoPath, '/photo2.jpg');
      expect(sub.note, '第二版');
    });

    test('getCourseSubmissions filters by courseId', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.upsertSubmission(AssignmentSubmission(id: 's1', assignmentId: 'a1', courseId: 'c1', photoPath: 'p1', status: AssignmentStatus.submitted, submittedAt: now));
      await dao.upsertSubmission(AssignmentSubmission(id: 's2', assignmentId: 'a2', courseId: 'c1', photoPath: 'p2', status: AssignmentStatus.submitted, submittedAt: now));
      await dao.upsertSubmission(AssignmentSubmission(id: 's3', assignmentId: 'a3', courseId: 'c2', photoPath: 'p3', status: AssignmentStatus.submitted, submittedAt: now));
      final c1Subs = await dao.getCourseSubmissions('c1');
      expect(c1Subs.length, 2);
    });
  });

  group('KnowledgeFavorite', () {
    test('isCardFavorited returns false for non-favorited card', () async {
      expect(await dao.isCardFavorited('card_1'), isFalse);
    });

    test('addFavorite inserts favorite', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      expect(await dao.isCardFavorited('card_1'), isTrue);
    });

    test('removeFavorite deletes existing favorite', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      expect(await dao.isCardFavorited('card_1'), isTrue);
      await dao.removeFavorite('card_1');
      expect(await dao.isCardFavorited('card_1'), isFalse);
    });

    test('getFavoriteCardIds returns all favorited ids', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await dao.addFavorite('card_1', now);
      await dao.addFavorite('card_3', now);
      final ids = await dao.getFavoriteCardIds();
      expect(ids.length, 2);
      expect(ids.contains('card_1'), isTrue);
      expect(ids.contains('card_3'), isTrue);
    });
  });
}

Future<void> _onCreate(Database db, int version) async {
  await db.execute(AcademyTables.cpCreateSql);
  await db.execute(AcademyTables.asCreateSql);
  await db.execute(AcademyTables.kfCreateSql);
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `cd lumira_app_flutter && flutter test test/features/academy/academy_dao_test.dart`
Expected: All tests passed

- [ ] **Step 3: Commit**

```bash
cd e:\Project\photo_post
git add lumira_app_flutter/test/features/academy/academy_dao_test.dart
git commit -m "test(academy): add DAO unit tests for progress, submission, favorites"
```

---

## Self-Review

### 1. Spec coverage

| Spec 章节 | 覆盖任务 | 状态 |
|----------|---------|------|
| §2.1 文件组织 | File Structure | ✅ 全部 14 个文件覆盖 |
| §2.2 迁移策略 | Task 15 Step 4 | ✅ 删除旧文件 + 清理 mock data |
| §2.3 路由更新 | Task 15 Step 1-2 | ✅ 4 个路由路径 + 页面引用 |
| §3.1 枚举 | Task 1 | ✅ 4 个枚举 + 扩展方法 |
| §3.2 核心数据类 | Task 1 | ✅ 7 个类 |
| §3.3 复用模型 | Task 1 | ✅ 从 profile 迁移 4 个类 |
| §3.4 课程矩阵 16 课 | Task 2 | ✅ 16 课完整数据 |
| §4.1-4.3 SQLite 表 | Task 3 | ✅ 3 张表 + AcademyTables 常量 |
| §4.4 数据库迁移 | Task 3 Step 2 | ✅ v2→v3 非破坏性迁移 |
| §5.1 Repository 接口 | Task 4 | ✅ 抽象接口 + 本地实现 |
| §5.2 Provider 清单 | Task 5 | ✅ 10 个 Provider |
| §6.1 学院首页 | Task 11 | ✅ 4 个 section |
| §6.2 课程详情页 | Task 12 | ✅ 动态加载 + 知识卡片 + CTA |
| §6.3 实战作业页 | Task 13 | ✅ 拍摄/相册 + mock 评分 |
| §6.4 知识卡片详情页 | Task 14 | ✅ 收藏 + 推荐 |
| §7 页面导航关系 | Task 15 路由 | ✅ 全部导航路径 |
| §8 Mock 数据 | Task 2 | ✅ 16 课 + 8 卡片 + picsum URL |
| §9 入口设计 | Task 15 Step 3 | ✅ templates_page 入口卡片 |

### 2. Placeholder scan

- 无 "TBD" / "TODO" / "implement later"
- 无 "add appropriate error handling" 等模糊描述
- 每个步骤都包含完整代码
- 类型签名在跨任务间一致（`AcademyCourse`、`CourseProgress`、`AssignmentSubmission` 等）

### 3. Type consistency

- `AcademyCourse.id` (String) → `CourseProgress.courseId` (String) ✅
- `AcademyAssignment.id` (String) → `AssignmentSubmission.assignmentId` (String) ✅
- `KnowledgeCard.id` (String) → `knowledgeFavorite.cardId` (String) ✅
- `CourseStatus` 枚举在 models / dao / repository / providers 间一致 ✅
- `AcademyLevel` / `AcademyTopic` 枚举在 models / mock_data / providers 间一致 ✅
- Provider 名称在 Task 5 定义后，Task 6-14 消费时名称完全匹配 ✅
- DAO 方法名（`upsertProgress`/`upsertSubmission`/`addFavorite`/`removeFavorite`/`getFavoriteCardIds`）与 Task 16 测试调用一致 ✅
- Repository 领域方法（`markStarted`/`markCompleted`/`toggleFavorite`）内部委托 DAO 底层方法，测试直接测 DAO 层 ✅
- `AcademyMockData` import 在 providers 文件中已补全 ✅

---

## Execution Handoff

计划已保存至 `docs/superpowers/plans/2026-07-23-academy-feature.md`。共 16 个任务，涵盖数据层（Task 1-4）、状态层（Task 5）、UI 层（Task 6-14）、集成与清理（Task 15）、测试（Task 16）。

**两种执行方式：**

**1. Subagent-Driven（推荐）** — 每个 Task 派发独立 subagent 执行，任务间审查，快速迭代

**2. Inline Execution** — 在当前会话中按 executing-plans 批量执行，带检查点审查

**选择哪种方式？**