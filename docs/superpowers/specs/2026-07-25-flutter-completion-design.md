# Flutter 项目未完成模块完善设计

**日期**：2026-07-25
**分支**：基于 `feat/capture-bugfixes`（HEAD `0ec3a8a`）继续
**目标**：完成 Flutter 项目 10 项未完成功能，使主流程可演示、数据可持久化、UI 对齐规范、分享与学院闭环可用。

---

## 1. 范围与目标

### 1.1 用户提出的 10 项任务

| # | 任务 | 归属模块 |
|---|---|---|
| T1 | 场景页：使用场景拍照、加入组合功能 | M2 |
| T2 | 组合页：添加组合功能 | M2 |
| T3 | 我的模板页使用真实数据，新建模板保存后出现在我的模板页 | M1 |
| T4 | 完善模板导入导出功能 | M3 |
| T5 | 成长中心使用真实数据 | M1 |
| T6 | 场景页、模板页使用真实数据 | M1 |
| T7 | 四 Tab 标题栏对齐 + 首页 nav 图标无反应 | M4 |
| T8 | 碎片收集页 5+ 图用九宫格展示 | M4 |
| T9 | 分享功能完善：生成/导出/分享海报 | M5 |
| T10 | 学院记录学习轨迹 | M6 |

### 1.2 用户已确认的决策

| 决策点 | 用户选择 |
|---|---|
| 「组合功能」语义 | 场景+模板组合套件（kit） |
| 学院完成判定 | 完成课程 + 提交作业图片 |
| 真实数据范围 | 种子数据 + 用户自定义持久化 |
| 模板导入导出格式 | 双格式兼容（.pptpl + .lumira） |

### 1.3 非目标

- 不引入新状态管理框架（继续用 flutter_riverpod 2.3.6）
- 不重构现有 8 主题 / 4 UI 风格系统
- 不引入 backend 联网（仍为纯本地）
- 不调整相机核心拍照流程（仅接线参数）
- 不重写已有 academy 模块结构

---

## 2. 模块划分

```
M1 数据层接入 ──┬─→ M2 组合套件
                ├─→ M3 导入导出
                └─→ M5.2 拍摄分享

M4 UI 优化        ── 独立，可与 M1 并行
M5.1, M5.3 分享   ── 独立
M6 学习轨迹       ── 独立，但依赖 M1 的 academy 接线
```

推荐实施顺序：**M1 → M4 → M6 → M2 → M3 → M5**

---

## 3. M1 — 数据层接入

### 3.1 种子数据策略

**触发条件**：数据库版本 v4 升级时，若 `user_settings.seed_v3_done != 1` 则执行种子插入。

**种子内容**：
- **预置场景**：从 `CaptureSceneMockData.scenes` + `ScenesMockData.scenesList` 序列化插入 `scenes` 表（共 12 个 ScenePreset，覆盖 4 大类）
- **预置模板**：从 `templatesBrowseMockData`（12 个 AllTemplateItem）+ `capture/data/templates/*.dart`（完整 PhotoTemplate 结构）序列化插入 `custom_templates` 表
  - 8 个免费模板：`price=0, is_builtin=1`
  - 4 个付费模板：`price>0, is_builtin=1`

**新增 Provider**：
```dart
final scenesDaoProvider = FutureProvider<ScenesDao>((ref) async { ... });
final templatesDaoProvider = FutureProvider<TemplatesDao>((ref) async { ... });
final seededProvider = FutureProvider<void>((ref) async { /* 触发种子 */ });
```

### 3.2 数据库迁移

`database_provider.dart` v3 → v4：
- `_onUpgrade` 中执行：
  1. 创建 `composition_kits` 表（M2 用）
  2. 创建 `academy_learning_trajectory` 表（M6 用）
  3. 在 `custom_templates` 表新增列（若不存在）：
     - `is_builtin INTEGER DEFAULT 0` — 标记预置模板
     - `is_recommended INTEGER DEFAULT 0` — 标记 Hero 推荐模板
  4. 在 `scenes` 表确认 `is_favorite` 列存在
  5. 调用 `_seedBuiltinData(db)` 插入预置数据：
     - 12 个预置场景（4 大类）
     - 12 个预置模板（8 免费 + 4 付费），其中 3 个标记 `is_recommended=1` 用于 Hero 区
  6. 写入 `user_settings.seed_v3_done = 1`

迁移失败时 try/catch 静默回退，应用继续运行（数据查询返回空列表时再读 mock）。

### 3.3 场景页接入

**`ScenesPage`**：
- 移除 `ref.read(scenesListProvider)` 与 `CaptureSceneMockData.categories` 直接引用
- 改为 `ref.watch(scenesDaoProvider).when(data: (dao) => dao.getAll(category: _activeCategoryId))`
- 二级分类筛选改为 SQL `WHERE category = ?`

**`CaptureSceneDetailPage._loadScene()`**：
- 改为 async，await `scenesDao.getById(widget.sceneId)`
- `_isFav` 从 `scenes.is_favorite` 列读取
- `_toggleFav()` 调用 `scenesDao.setFavorite(id, value)`

### 3.4 模板页接入

**`TemplatesPage`**：
- Hero 推荐区：watch `templatesDaoProvider` 取 `is_builtin=1 AND is_recommended=1` 的 3 条
- 更多模板 grid：watch `templatesDaoProvider.getAll(category: filter)` 取 `is_builtin=1 AND price=0`
- 付费模板卡：watch `price > 0` 的 4 条

**`TemplatesAllPage`**：
- 全部模板 grid 改为 watch DAO，按 `price ASC, name ASC` 排序

### 3.5 我的模板页接入

**`ProfileMyTemplatesPage`**：
- 新增 Provider：
  ```dart
  final customTemplatesProvider = FutureProvider<List<CustomTemplate>>((ref) async {
    final dao = await ref.watch(templatesDaoProvider.future);
    final records = await dao.getAllBuiltinOnly(isBuiltin: false);
    return records.map(_recordToCustomTemplate).toList();
  });
  ```
- `_filteredTemplatesWith` 移除 `ProfileContentMockData.customTemplates`，改为 watch `customTemplatesProvider`
- 长按 ActionSheet 的「删除」调用 `templatesDao.delete(id)` 后 invalidate provider
- 「编辑」跳转 `/templates/editor?templateId={id}`

**`TemplatesEditorPage._onSave()`**：
- 验证 name 非空
- 序列化 `_form` 为 `TemplateRecord`（包含完整 composition/pose/camera/sceneGuide/postProcess JSON）
- 调用 `templatesDao.upsert(record)`
- invalidate `customTemplatesProvider`
- SnackBar "保存成功" + 800ms 后 pop

### 3.6 成长中心接入

**新增 `growth_dao.dart`**（操作 `user_progress` 表 + `challenge_history` 表 + `gallery_items` 表 + `academy_course_progress` 表，**只读计算**不写入）：
```dart
class GrowthDao {
  Future<int> getTotalXP();           // 来自 user_progress.xp，无记录时按 challenge_history.reward_xp 求和
  Future<int> getLevel();             // XP / 500 + 1
  Future<List<AchievementRecord>> getAchievements();  // 从 user_progress.achievements_json 反序列化（JSON 数组）
  Future<List<GrowthTrajectoryRecord>> getGrowthTrajectory();
  Future<Map<String, int>> getDailyActivity();  // 用于热力图，从 challenge_history 按日期 GROUP BY
}
```

**GrowthTrajectoryRecord 数据源**（按时间倒序，取最近 4 条）：
- 聚合多个事件流：`challenge_history.completed_at`（挑战完成）/ `academy_course_progress.completed_at`（课程完成）/ `gallery_items.created_at`（首次拍摄 / 累计里程碑）
- 每条记录字段：`eventId` / `type` ('challenge' / 'course' / 'milestone') / `title` / `timestamp`
- 在 DAO 内用 SQL UNION 查询合并三个流，按 timestamp DESC LIMIT 4

**新增 `growth_providers.dart`**：
- `growthLevelProvider` — 等级、当前 XP、下一级所需 XP（基于 `user_progress.xp`，无记录时降级到 challenge_history 求和）
- `growthAchievementsProvider` — 6 项成就墙（基于 `user_progress.achievements_json`，无记录时返回 6 项未解锁的占位成就）
- `growthTrajectoryProvider` — 4 项成长轨迹时间线（基于 DAO UNION 查询）
- `growthHeatmapProvider` — 112 格热力图数据（基于 `challenge_history` 按日期聚合 + `gallery_items` 补充）

> **命名澄清**：本节的 "growth trajectory" 指成长中心的时间线（多种事件聚合），与 M6 的 "academy trajectory"（仅学院课程完成顺序）是**不同概念**，使用不同表与 DAO。

**`ProfileGrowthPage`**：
- 移除 `ProfileMockData.growth` 引用
- 4 个 section 改为 watch 上述 providers
- 空状态：显示"暂无数据，去完成第一次拍摄解锁成长记录" + 跳转 capture 按钮

---

## 4. M2 — 组合套件功能

### 4.1 数据库

新增表 `composition_kits`（v4 迁移同步创建）：
```sql
CREATE TABLE IF NOT EXISTS composition_kits (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  scene_id TEXT NOT NULL,
  template_id TEXT,
  camera_overrides_json TEXT,
  note TEXT,
  cover_url TEXT,
  created_at INTEGER NOT NULL,
  last_used_at INTEGER,
  usage_count INTEGER DEFAULT 0
);
```

新增 `composition_kits_dao.dart`：
```dart
class CompositionKitsDao {
  Future<List<CompositionKit>> getAll();
  Future<CompositionKit?> getById(String id);
  Future<String> insert(CompositionKit kit);
  Future<void> update(CompositionKit kit);
  Future<int> delete(String id);
  Future<void> incrementUsage(String id);
}
```

新增模型 `CompositionKit`（lib/features/profile/data/composition_kit_models.dart）。

### 4.2 场景详情页接线

**`CaptureSceneDetailPage._goCapture()`**：
```dart
void _goCapture() {
  GoRouter.of(context).push(
    RouteNames.build(RouteNames.capture, {RouteNames.paramScene: _scene!.id}),
  );
}
```

**`CapturePage`**：
- `onLoad` 读取 `scene` 参数，调用 `scenesDao.getById(sceneId)` 加载场景预设
- 应用场景对应的 `recommendedIso`、`recommendedShutter`、`recommendedExposure` 到 `CaptureConfigState`

**`CaptureSceneDetailPage._goCreateKit()`**：
- 弹出 `AddToCompositionSheet`（底部 Sheet）：
  - 名称输入框（默认 "场景名-模板名"）
  - 关联模板下拉（可选，从 `customTemplatesProvider` + 内置模板中选）
  - 参数备注输入框
  - "保存套件" 按钮 → `compositionKitsDao.insert(...)` + Toast
  - Toast 提供"查看组合"快捷入口 → `/profile/composition-kits`

### 4.3 组合页

新增路由 `/profile/composition-kits`（在 `route_names.dart` 注册 `compositionKits` 常量）。

**`CompositionKitsPage`**（lib/features/profile/pages/composition_kits_page.dart）：
- 顶部 StatsBar：套件总数 / 总使用次数 / 最近使用
- 套件列表卡片：
  - 封面（场景图）
  - 套件名 + 场景标签 + 模板标签
  - 上次使用时间 + 使用次数
- 卡片点击 → 进入 `CompositionKitDetailPage`
- 卡片长按 → ActionSheet（编辑 / 套用 / 复制 / 删除）
- FAB "新建套件"

**`CompositionKitDetailPage`**（lib/features/profile/pages/composition_kit_detail_page.dart）：
- 套件预览：
  - 场景图 + 模板叠图
  - 参数表（曝光/ISO/快门 + 备注）
- "立即使用此套件拍照" 按钮：
  ```dart
  GoRouter.of(context).push(RouteNames.build(RouteNames.capture, {
    RouteNames.paramScene: kit.sceneId,
    RouteNames.paramTemplate: kit.templateId,
    RouteNames.paramKit: kit.id,
  }));
  ```
- 「编辑」按钮 → `/templates/editor?kitId={id}` 复用模板编辑器

**入口**：
1. 我的页 `QuickActionsRow` 新增「我的组合」按钮 → `/profile/composition-kits`
2. 场景详情页"加入组合"成功后的 Toast 提供"查看组合"快捷入口

### 4.4 CapturePage 套件应用

`CapturePage.onLoad`：
- 读取 `kit` 参数
- 调用 `compositionKitsDao.getById(kitId)` 加载套件
- 同时应用 sceneId + templateId + camera_overrides 到 CaptureConfigState
- 拍摄完成时调用 `compositionKitsDao.incrementUsage(kitId)` + 更新 `last_used_at`

---

## 5. M3 — 模板导入导出完善

### 5.1 双格式定义

#### `.pptpl`（完整 AGENT.md 规范）
```json
{
  "format": "pptpl",
  "version": "1.0",
  "meta": { "id": "...", "name": "...", "author": "...", "category": "...", ... },
  "composition": { "overlayType": "...", "subjectFrame": {...}, ... },
  "pose": { "silhouette": { "type": "builtin|image|svg", "data": "..." }, ... },
  "camera": { "exposureCompensation": 0, "iso": 100, ... },
  "sceneGuide": { "lightDirection": "...", ... },
  "postProcess": { "cropRatio": "...", "color": {...}, ... }
}
```

#### `.lumira`（简化版，向后兼容）
```json
{
  "format": "lumira",
  "version": "1.0",
  "meta": { "id": "...", "name": "...", "category": "...", "tags": [...] },
  "camera": { "exposureCompensation": 0, "iso": 100, "shutterSpeed": "1/125" },
  "composition": { "overlayType": "rule_of_thirds" }
}
```

### 5.2 导出实现

新增 `lib/features/templates/services/template_exporter.dart`：
```dart
class TemplateExporter {
  static String exportToPptpl(TemplateRecord record);
  static String exportToLumira(TemplateRecord record);
  static Future<void> shareTemplate(TemplateRecord record, {required bool usePptpl});
  static Future<void> saveToFile(TemplateRecord record, {required bool usePptpl, required String dirPath});
}
```

**剪影自包含策略**（导出时）：
- `builtin` → 仅存 key 字符串（如 `'standing-profile'`）
- `image` → 读取本地文件路径转 base64 data URL 存入
- `svg` → 直接存 SVG 字符串

**UI 统一入口**：
- `TemplatesEditorPage._onExport()` 与 `ProfileMyTemplatesPage._exportTemplate()` 都改为调用 `TemplateExporter.shareTemplate(record, usePptpl: ?)`
- 导出前弹出格式选择 Sheet：
  - 选项 1：完整 .pptpl（推荐）
  - 选项 2：简化 .lumira
  - 取消

### 5.3 导入实现

**`template_import_sheet.dart` 增强**：
- 文件后缀白名单：`.pptpl` / `.lumira` / `.json`
- 自动嗅探：
  ```dart
  final json = jsonDecode(content);
  final format = json['format'] as String?;
  if (format == 'pptpl' || json.containsKey('composition') && json['composition']?.containsKey('subjectFrame')) {
    // 完整 .pptpl 格式
  } else {
    // 简化 .lumira 格式
  }
  ```
- **持久化**：导入后调用 `templatesDao.upsert(record)`，标记 `is_builtin=0, author="imported"`
- **移除内存态**：`ImportedTemplatesNotifier` 标记为 deprecated，新导入全部走 DAO；为兼容保留 `importedAllTemplatesProvider` 但内部改为读 DAO
- **ID 冲突处理**：
  ```dart
  var finalId = record.id;
  while (await dao.getById(finalId) != null) {
    finalId = '${finalId}_imported_${DateTime.now().millisecondsSinceEpoch}';
  }
  ```
- **降级**：`pose.silhouette.type='builtin'` 但 key 不存在于内置 SVG 库时，降级为 `type='none'`，记录 warning 日志

### 5.4 模型映射

新增 `lib/features/templates/services/template_mapper.dart`：
- `TemplateRecord ↔ PhotoTemplate` 双向转换
- `TemplateRecord ↔ CustomTemplate` 双向转换（用于 profile_my_templates_page）
- 处理 SilhouetteResource 的序列化/反序列化

---

## 6. M4 — UI 优化

### 6.1 四 Tab 标题栏对齐

**问题诊断**：
- `LumiraNav` 内部用 `Padding(horizontal: 8)`
- 页面 body 通常用 `padding: EdgeInsets.symmetric(horizontal: 24)`
- 导致 nav 左右内容与 body 不对齐

**修复方案**：
- `LumiraNav` 新增 `horizontalPadding` 参数（默认 24.0）
- 内部 `Padding(horizontal: 8)` 改为 `Padding(horizontal: horizontalPadding)`
- 4 个 Tab 页（home/templates/challenge/profile）显式传入 `horizontalPadding: 24`
- 非 Tab 页（如详情页）保持默认或传 12

**影响范围**：
- `lib/shared/widgets/nav/lumira_nav.dart` — 修改 `_LumiraNavState.build` 中的 Padding
- 4 个 Tab 页的 `LumiraNav(...)` 调用 — 添加 `horizontalPadding` 参数

### 6.2 首页 Nav 右侧图标接线

**通知中心**（`Icons.notifications_outlined`）：
- 新增路由 `/profile/notifications`
- 新增页面 `lib/features/profile/pages/profile_notifications_page.dart`
- 内容：占位说明 + 历史 5 条通知 mock 列表（"你的连续打卡已 7 天" / "新模板已上线" 等）
- 长按可清除单条

**扫一扫**（`Icons.qr_code_outlined`）：
- 检查 `mobile_scanner` 在 CPF-Flutter 适配清单中的状态
- **方案 A（适配 OK）**：调用 `MobileScannerController` 启动相机扫码，识别到 `LUMIRA-{category}-{name}` 格式分享码后调用 `template_import_sheet` 自动导入
- **方案 B（不适配）**：弹出对话框让用户手动输入分享码，校验格式后调用 `template_import_sheet` 导入

**降级**：默认采用方案 B（避免引入新依赖），后续如用户反馈需要可再升级到方案 A。

### 6.3 碎片九宫格 5+ 完善

**当前状态**：`_PhotoGrid` 已实现 `count > 4 → crossCount = 3`，但 count=5/7/8 时最后一行不满 3 个会留空白。

**修复**：
- count=5/7/8：最后一行不满时显示"+N 更多"占位卡（灰色方块 + "+N" 文字 + `Icons.more_horiz`）
- count>9：只显示前 9 张 + 第 9 张替换为 "+N" 卡片（半透明遮罩 + "+N" 文字），点击展开完整列表（弹出全屏 GridView）
- 同步改进 `fragment_poster_generator._PhotoGrid` 保持一致

**新增组件**：`lib/shared/widgets/images/adaptive_photo_grid.dart`
- 公开 API：`AdaptivePhotoGrid(urls: List<String>, maxDisplay: 9)`
- 内部封装上述逻辑
- 替换 `_PhotoGrid` 两处使用

---

## 7. M5 — 分享功能完善

### 7.1 海报三件套

**重构**：把 `FragmentPosterGenerator` 提取为通用 `PosterGenerator`（lib/shared/services/poster_generator.dart）：
```dart
class PosterGenerator {
  static Future<void> showPoster({
    required BuildContext context,
    required ThemeTokens tokens,
    required String title,
    required Widget content,
    required GlobalKey posterKey,
    required String shareSubject,
    required String shareText,
    required String fileNamePrefix,
  });
}
```

**底部 Sheet 三个按钮**：
1. **生成海报**：仅预览（已在 Sheet 内显示，无操作）
2. **导出海报**（保存到相册）：
   ```dart
   final image = await boundary.toImage(pixelRatio: 2.0);
   final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
   await SaverGallery.saveImage(bytes.buffer.asUint8List(),
     fileName: '${fileNamePrefix}_${DateTime.now().millisecondsSinceEpoch}.png',
     skipIfExists: false);
   ```
3. **分享海报**：调用 `Share.shareXFiles([XFile(file.path)], subject: ..., text: ...)`

**`ProfileFragmentDetailPage`**：替换为 `PosterGenerator.showPoster(...)`。

### 7.2 拍摄成品分享

**`CapturePreviewPage`** 修改：
- 顶部 nav 右侧新增分享按钮（`Icons.ios_share_outlined`）
- 点击弹出底部 Sheet 选项：
  1. **保存到相册**：调用 `SaverGallery.saveImage` 保存原始照片
  2. **分享到系统**：调用 `Share.shareXFiles` 分享原始照片
  3. **生成 EXIF 海报**：调用 `exif_card_generator.dart` 的 `ExifCardGenerator.generate(...)` 生成包含照片缩略图 + EXIF 元数据的海报 PNG → 弹出 `PosterGenerator.showPoster(...)` 预览，可继续保存或分享
  4. **取消**

### 7.3 成就分享

**`ProfileGrowthPage._AchievementCard`** 新增分享按钮（`Icons.ios_share_outlined`）：
- 点击调用 `PosterGenerator.showPoster(...)` 生成"我获得了XX成就"海报
- 海报内容：成就图标 + 名称 + 描述 + 用户等级 + 品牌水印

---

## 8. M6 — 学院学习轨迹

### 8.1 完成判定

**规则**：满足以下两个条件才算"真正完成"：
1. `academy_course_progress.status = 'completed'`
2. 该课程对应作业有至少一条 `academy_assignment_submission` 记录，且 `status IN ('submitted', 'reviewed')` AND `photo_path IS NOT NULL`

**DAO 新增方法**：
```dart
Future<bool> isCourseFullyCompleted(String courseId) async {
  final progress = await getProgress(courseId);
  if (progress?.status != CourseStatus.completed) return false;
  final submissions = await getSubmissionsByCourse(courseId);
  return submissions.any((s) =>
    s.status != AssignmentStatus.notSubmitted && s.photoPath != null);
}
```

### 8.2 学习轨迹表

新增表 `academy_learning_trajectory`（v4 迁移同步创建）：
```sql
CREATE TABLE IF NOT EXISTS academy_learning_trajectory (
  course_id TEXT PRIMARY KEY,
  completed_at INTEGER NOT NULL,
  sequence INTEGER NOT NULL
);
```

**DAO 自动维护**：在 `AcademyRepository.markComplete(courseId)` 内部调用：
```dart
Future<void> markComplete(String courseId) async {
  await dao.upsertProgress(courseId, CourseStatus.completed, 100, completedAt: now);

  // 检查是否真正完成
  if (await dao.isCourseFullyCompleted(courseId)) {
    final maxSeq = await dao.getMaxTrajectorySequence();
    await dao.upsertTrajectory(courseId, completedAt: now, sequence: maxSeq + 1);
  }
}
```

**触发时机**：
- 用户在课程详情页点击"标记已学完"按钮 → 调用 `markComplete(courseId)`
- 用户提交作业（含 photoPath） → 调用 `markComplete(courseId)` 重新校验

### 8.3 课程列表排序

**`AcademyPage`** 课程网格排序规则：
1. 先按 `level` 升序（beginner → intermediate → advanced）
2. 同 level 内：
   - 未完成（`isCourseFullyCompleted = false`）的在前，按 `lastViewedAt DESC`
   - 已完成的沉底，按 `completedAt ASC`（按完成顺序排列）

**`AcademyCourseCard`** 修改：
- 已完成课程的卡片右上角显示绿色"已学完"徽章（`Icons.check_circle` + "已学完" 文字）

### 8.4 学习轨迹页

新增路由 `/academy/trajectory`（注册 `academyTrajectory` 常量）。

**`AcademyTrajectoryPage`**（lib/features/academy/pages/academy_trajectory_page.dart）：
- 顶部统计卡：已完成 X / 总 Y 课程，总学习时长（按 `sections.paragraphs.length * 30秒` 估算）
- 时间线竖向布局：
  - 每个节点：圆形序号 + 课程封面缩略图 + 课程名 + 完成时间 + "第 N 个完成"标签
  - 节点之间用虚线连接
- 空状态：未完成任何课程时显示"开始你的第一节课程吧" + 跳转 academy 按钮

**入口**：
- `AcademyPage` 顶部概览卡新增"我的学习轨迹"按钮 → `/academy/trajectory`

---

## 9. 风险与降级

| 风险 | 降级方案 |
|---|---|
| `mobile_scanner` 不适配 HarmonyOS | 回退为手动输入分享码弹窗（默认采用此方案） |
| 数据库迁移失败 | try/catch 包裹种子插入，失败时静默回退 mock 数据 |
| EXIF 海报生成在低端机超时 | 加 loading 指示，超时 5s 提示重试 |
| 学院 trajectory 表迁移冲突 | 表已存在则跳过创建（`IF NOT EXISTS`） |
| `templatesDao.upsert` 保存失败 | 显示错误 SnackBar，保留 _form 不清空，允许重试 |
| 用户已存在的自定义模板 ID 与种子冲突 | 种子插入前 `SELECT COUNT(*) FROM custom_templates WHERE is_builtin=0` 不为 0 时跳过种子 |

---

## 10. 测试策略

### 10.1 单元测试

- `TemplatesDao` 种子插入与查询（使用 `sqflite_common_ffi`）
- `CompositionKitsDao` CRUD
- `TemplateExporter` 双格式序列化/反序列化
- `AcademyDao.isCourseFullyCompleted` 边界条件
- `GrowthDao` XP 计算与等级提升

### 10.2 Widget 测试

- `ProfileMyTemplatesPage` 保存模板后列表更新
- `CompositionKitsPage` 空状态、列表、ActionSheet
- `AdaptivePhotoGrid` 5/7/9/12 张图片渲染
- `AcademyTrajectoryPage` 时间线显示

### 10.3 集成测试（手动）

- 完整流程：新建模板 → 保存 → 我的模板页可见 → 导出 .pptpl → 删除 → 重新导入 → 可见
- 完整流程：场景详情页加入组合 → 组合页可见 → 套用拍照 → 使用次数 +1
- 完整流程：学院标记完成 + 提交作业 → 学习轨迹页可见 → 列表排序正确

---

## 11. 文件清单（预估）

### 新增文件
```
lib/core/db/dao/composition_kits_dao.dart
lib/core/db/dao/growth_dao.dart
lib/features/profile/data/composition_kit_models.dart
lib/features/profile/data/growth_models.dart
lib/features/profile/pages/composition_kits_page.dart
lib/features/profile/pages/composition_kit_detail_page.dart
lib/features/profile/pages/profile_notifications_page.dart
lib/features/profile/providers/composition_kits_providers.dart
lib/features/profile/providers/growth_providers.dart
lib/features/templates/services/template_exporter.dart
lib/features/templates/services/template_mapper.dart
lib/features/academy/data/academy_trajectory_dao.dart
lib/features/academy/pages/academy_trajectory_page.dart
lib/shared/widgets/images/adaptive_photo_grid.dart
lib/shared/services/poster_generator.dart
test/composition_kits_dao_test.dart
test/template_exporter_test.dart
test/academy_trajectory_test.dart
test/growth_dao_test.dart
test/adaptive_photo_grid_test.dart
```

### 修改文件
```
lib/core/db/database_provider.dart              # v3 → v4 迁移
lib/core/db/tables.dart                          # 新表常量
lib/core/router/route_names.dart                 # 新路由常量
lib/app/router.dart                              # 注册新路由
lib/shared/widgets/nav/lumira_nav.dart           # horizontalPadding 参数
lib/features/home/pages/home_page.dart           # nav 图标接线 + horizontalPadding
lib/features/templates/pages/templates_page.dart # DAO 接入 + horizontalPadding
lib/features/challenge/pages/challenge_page.dart # horizontalPadding
lib/features/profile/pages/profile_page.dart     # horizontalPadding + QuickActions 入口
lib/features/profile/pages/profile_my_templates_page.dart # DAO 接入
lib/features/profile/pages/profile_growth_page.dart       # DAO 接入
lib/features/profile/pages/profile_fragment_detail_page.dart # AdaptivePhotoGrid
lib/features/profile/widgets/fragment_poster_generator.dart  # 重构为通用 PosterGenerator
lib/features/templates/pages/templates_editor_page.dart     # _onSave/_onExport DAO 接入
lib/features/templates/widgets/template_import_sheet.dart   # 双格式嗅探 + DAO 持久化
lib/features/templates/data/imported_templates_provider.dart # deprecated
lib/features/scenes/pages/scenes_page.dart                 # DAO 接入
lib/features/capture/pages/capture_scene_detail_page.dart  # 按钮接线
lib/features/capture/pages/capture_page.dart               # sceneId/templateId/kitId 参数读取
lib/features/capture/pages/capture_preview_page.dart       # 分享按钮
lib/features/academy/data/academy_dao.dart                 # isCourseFullyCompleted + trajectory
lib/features/academy/data/academy_repository.dart          # markComplete 维护 trajectory
lib/features/academy/pages/academy_page.dart               # 排序 + 已学完徽章 + 入口
lib/features/academy/widgets/academy_course_card.dart      # 已学完徽章
```

---

## 12. 验收标准

| 任务 | 验收点 |
|---|---|
| T1 | 场景详情页「用此场景拍照」跳转 capture 并应用场景参数；「加入组合」保存到 DAO |
| T2 | 组合页可查看、新建、编辑、删除、套用套件；套用后 capture 应用全部参数 |
| T3 | 我的模板页显示 DAO 中的模板；新建模板保存后立即出现（无需重启） |
| T4 | 可导出 .pptpl / .lumira 双格式；可导入两种格式并持久化；剪影自包含 |
| T5 | 成长中心 4 个 section 全部显示 DAO 真实数据；空状态有提示 |
| T6 | 场景页、模板页全部显示 DAO 真实数据；首次启动种子数据正确 |
| T7 | 4 Tab 页 nav 左右内容与 body 对齐；首页 nav 通知/扫码按钮有响应 |
| T8 | 5+ 张图片用 3 列九宫格；7/8 张时最后一行 +N 占位卡；>9 张时显示前 9 + "+N" |
| T9 | 碎片海报可生成/导出/分享；拍摄成品可分享；成就可分享 |
| T10 | 学院课程列表已完成的沉底；徽章显示；学习轨迹页按完成顺序显示时间线 |
