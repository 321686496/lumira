# 摄影美学院功能设计规格

**创建日期**: 2026-07-23
**状态**: 待实现
**模块**: `features/academy/`

---

## 1. 功能概述

摄影美学院是 Flutter 项目中的独立学习功能模块，包含课程学习、知识卡片和实战作业三大子功能，从 `features/profile/` 拆出为独立模块。

### 核心功能

| 子功能 | 说明 |
|--------|------|
| 课程列表与学习路径 | 16 课按难度×主题矩阵组织，自由浏览+推荐顺序 |
| 学习进度跟踪 | 连续学习天数、完成百分比、累计 XP，SQLite 持久化 |
| 美学知识卡片 | 8 张知识卡片，双轨展示（详情页内嵌+首页 section） |
| 实战作业 | 每课附带 1 个作业，支持拍摄新照片或从相册选择提交 |

---

## 2. 模块架构

### 2.1 文件组织

```
lib/features/academy/
├── pages/
│   ├── academy_page.dart              ← 学院首页（替换原空状态）
│   ├── academy_detail_page.dart       ← 课程详情（迁移自 profile）
│   ├── academy_assignment_page.dart   ← 实战作业页
│   └── academy_knowledge_page.dart    ← 知识卡片详情页
├── widgets/
│   ├── academy_overview_card.dart     ← 学习概览卡
│   ├── academy_level_selector.dart    ← 难度等级选择器
│   ├── academy_course_card.dart       ← 课程卡片
│   ├── academy_knowledge_card.dart    ← 知识卡片
│   └── academy_progress_ring.dart     ← 进度环
├── data/
│   ├── academy_models.dart            ← 数据模型
│   ├── academy_mock_data.dart         ← 16 课 mock 数据
│   ├── academy_dao.dart               ← SQLite DAO
│   └── academy_repository.dart        ← repository
└── providers/
    └── academy_providers.dart         ← Riverpod providers
```

### 2.2 迁移策略

| 现有文件 | 操作 |
|---------|------|
| `features/profile/pages/profile_academy_page.dart` | 迁移内容到 academy_page.dart，原文件删除 |
| `features/profile/pages/profile_academy_detail_page.dart` | 迁移内容到 academy_detail_page.dart，原文件删除 |
| `features/profile/data/profile_content_mock_data.dart` 中的 academy 相关部分 | 迁移到 academy_mock_data.dart，原文件保留其余内容 |

### 2.3 路由更新

路由路径保持不变，仅调整页面类引用：
- `/profile/academy` → `AcademyPage`（原 `ProfileAcademyPage`）
- `/profile/academy-detail` → `AcademyDetailPage`（原 `ProfileAcademyDetailPage`）
- 新增 `/profile/academy/assignment` → `AcademyAssignmentPage`
- 新增 `/profile/academy/knowledge` → `AcademyKnowledgePage`

---

## 3. 数据模型

### 3.1 枚举

```dart
enum AcademyLevel { beginner, intermediate, advanced }
enum AcademyTopic { portrait, landscape, stillLife, street }
enum CourseStatus { notStarted, inProgress, completed }
enum AssignmentStatus { notSubmitted, submitted, reviewed }
```

### 3.2 核心数据类

| 类名 | 用途 |
|------|------|
| `AcademyCourse` | 课程元数据（列表展示） |
| `AcademyCourseDetail` | 课程详情（完整内容） |
| `KnowledgeCard` | 美学知识卡片 |
| `AcademyAssignment` | 作业定义 |
| `AssignmentSubmission` | 作业提交记录 |
| `AcademyOverview` | 学习概览 |
| `CourseProgress` | 课程进度记录（持久化） |

### 3.3 复用模型

从 `profile_content_mock_data.dart` 迁移：`LessonSection`、`CompareCell`、`PracticeTag`、`RecommendTemplate`

### 3.4 课程矩阵（16 课）

| 等级 | 主题 | 课程 |
|------|------|------|
| 入门 | 人像 | 第1课 找到你的最佳角度、第2课 光线基础 |
| 入门 | 风光 | 第3课 构图三分法、第4课 黄金时段 |
| 入门 | 静物 | 第5课 俯拍平铺 |
| 入门 | 街头 | 第6课 决定性瞬间 |
| 进阶 | 人像 | 第7课 伦勃朗光、第8课 情绪表达 |
| 进阶 | 风光 | 第9课 引导线构图 |
| 进阶 | 静物 | 第10课 布光法、第11课 色彩搭配 |
| 进阶 | 街头 | 第12课 街头光影 |
| 高级 | 人像 | 第13课 风格化人像 |
| 高级 | 风光 | 第14课 黑白风光 |
| 高级 | 静物 | 第15课 极简静物 |
| 高级 | 街头 | 第16课 街头叙事 |

---

## 4. SQLite 表结构

### 4.1 academy_course_progress（课程进度）

| 字段 | 类型 | 说明 |
|------|------|------|
| course_id | TEXT PK | 课程 ID |
| status | TEXT | not_started / in_progress / completed |
| progress_percent | INTEGER | 0-100 |
| started_at | INTEGER | 开始时间戳 |
| completed_at | INTEGER | 完成时间戳 |
| last_viewed_at | INTEGER | 最后查看时间戳 |

### 4.2 academy_assignment_submission（作业提交）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | TEXT PK | 提交 ID |
| assignment_id | TEXT UNIQUE | 作业 ID |
| course_id | TEXT | 所属课程 |
| photo_path | TEXT | 本地照片路径 |
| photo_url | TEXT | 网络照片 URL |
| note | TEXT | 用户备注 |
| status | TEXT | not_submitted / submitted / reviewed |
| score | INTEGER | 评分 0-100 |
| feedback | TEXT | 反馈 |
| submitted_at | INTEGER | 提交时间戳 |

### 4.3 academy_knowledge_favorite（知识卡片收藏）

| 字段 | 类型 | 说明 |
|------|------|------|
| card_id | TEXT PK | 卡片 ID |
| favorited_at | INTEGER | 收藏时间戳 |

### 4.4 数据库迁移

`database_provider.dart` 版本从 2 升到 3，`_onUpgrade` 增加 `if (oldVersion < 3)` 分支创建上述 3 张表。

---

## 5. Repository 与 Provider

### 5.1 Repository 抽象接口

```dart
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
  Future<void> submitAssignment({...});
  Future<List<AssignmentSubmission>> getCourseSubmissions(String courseId);

  // 知识卡片
  List<KnowledgeCard> getKnowledgeCards({AcademyTopic? topic});
  Future<bool> isCardFavorited(String cardId);
  Future<void> toggleFavorite(String cardId);
}
```

### 5.2 Provider 清单

| Provider | 类型 | 用途 |
|----------|------|------|
| `academyDaoProvider` | FutureProvider | DAO 实例 |
| `academyRepositoryProvider` | FutureProvider | Repository 实例 |
| `coursesProvider` | Provider.family | 按等级筛选课程 |
| `academyOverviewProvider` | FutureProvider | 学习概览 |
| `courseDetailProvider` | Provider.family | 课程详情 |
| `courseProgressProvider` | FutureProvider.family | 单课进度 |
| `assignmentSubmissionProvider` | FutureProvider.family | 作业提交记录 |
| `knowledgeCardsProvider` | Provider | 知识卡片列表 |
| `favoriteCardIdsProvider` | FutureProvider | 收藏卡片 ID 集合 |
| `academyActionsProvider` | StateNotifierProvider | 状态变更通知器 |

---

## 6. 页面设计

### 6.1 学院首页 `AcademyPage`

单 ListView 滚动，4 个 section：

1. **学习概览卡**：进度环（CustomPainter）+ 连续天数 + XP + 推荐下一课
2. **难度等级选择器**：横向滑动 pill（入门基础/进阶技巧/高级创作）
3. **课程网格**：2 列瀑布流，课程卡片含封面图+标题+meta+tags+状态角标
4. **美学知识卡片 section**：标题行 + 横向滑动知识卡片

### 6.2 课程详情页 `AcademyDetailPage`

迁移自现有 `profile_academy_detail_page.dart`，核心改造：从单课硬编码改为按 academyId 动态加载。新增：
- 内嵌知识卡片 section
- "开始实战" CTA 按钮跳转作业页
- 标记完成绑定 `markCompleted`

### 6.3 实战作业页 `AcademyAssignmentPage`

两种提交方式（去拍摄 / 从相册选择），提交后展示 mock 评分和反馈。

**拍摄返回流程**：用户点击"去拍摄"→ `context.push('/capture')` 进入拍摄页 → 拍摄完成后调用 `context.pop(photoPath)` 返回作业页 → 作业页通过 `GoRouter` 的 `pop` 结果接收 `photoPath` 并显示预览。

**相册选择**：使用 `image_picker` 插件（实现时需先确认 `pubspec.yaml` 是否已包含，如未包含需添加依赖）。

### 6.4 知识卡片详情页 `AcademyKnowledgePage`

展示卡片完整内容、收藏按钮、相关知识推荐。

---

## 7. 页面导航关系

```
academy_page
    ├─ 课程卡片 → academy_detail_page
    │               ├─ "开始实战" → academy_assignment_page
    │               │                   ├─ "去拍摄" → /capture → 返回
    │               │                   └─ "从相册选择" → image_picker
    │               └─ 知识卡片 → academy_knowledge_page
    ├─ 知识卡片 → academy_knowledge_page
    └─ "查看全部" → academy_knowledge_page
```

---

## 8. Mock 数据

- 16 课完整数据（含章节、TipCard、对比网格、实战练习、小贴士、推荐模板、知识卡片、作业）
- 8 张知识卡片
- 所有图片使用 picsum.photos（`https://picsum.photos/seed/{seed}/{w}/{h}`）
- 作业提交后生成 70-94 随机评分和对应反馈文案

---

## 9. 入口设计

- **主入口**：`profile_page.dart` 快捷操作区"摄影美学院"按钮（保留现有入口不动）
- **发现页入口**：`templates_page.dart` 在场景分区下方增加"摄影美学院"入口卡片，样式与现有模板卡片一致（封面图+标题+副标题），点击跳转 `/profile/academy`。卡片高度与模板网格卡片对齐，保持 2 列网格的视觉连续性。
