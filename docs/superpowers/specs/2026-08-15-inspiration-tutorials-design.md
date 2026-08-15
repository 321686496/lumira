# 灵感页「拍摄小课堂」设计（覆盖全摄影大类 + 个性化推荐）

> 日期：2026-08-15
> 状态：待用户确认
> 范围：Flutter 端（`lumira_app_flutter/`），后端零改动；小教程图片用 `scripts/gen_image.py` 生成

## 1. 背景与问题

当前灵感页（2026-08-13 重构后）为 4 区块：顶部引导条 → 今日可拍 → **拍得更好** → 灵感图集。其中「拍得更好」区块（`better_shoot_section.dart`）横向推荐**美学院系统课程**（`coursePicksProvider` → `AcademyContent`）。

存在两个问题：

1. **与美学院相撞**：「拍得更好」的副标题是"找到你的最佳角度"，推的却是美学院系统课——主题与新功能"如何拍出高级感/氛围感/找好角度"几乎重叠，但形态是"8 分钟系统课"而非"1-3 分钟短文"。用户想随手读一篇小技巧，却被迫进入系统课程详情页。
2. **学习闭环错位**：灵感页定位是"轻量、碎片、读完去拍"，系统课定位是"系统、作业、XP、进度"。两者共用同一个推荐位，语义冲突。

## 2. 目标与边界

### 目标

把灵感页「拍得更好」改造成 **「拍摄小课堂」**：覆盖全摄影大类（含通用技巧）的轻量单篇小教程，按**问卷偏好 + 近期拍摄行为 + 未读状态**个性化推荐，且保持多样性（不形成信息茧房）。读完有落点（CTA 去拍/去模板），并有反导向流（想系统学 → 美学院）。

### 硬性约束

- **纯本地**：教程内容为 App 内置静态配置（const），无网络依赖；沿用 `inspiration_content.dart` / `academy_content.dart` 的模式。
- **个性化仅用本地数据**：问卷偏好（`questionnaire` 表）+ 近 30 天拍摄统计（`gallery` 表）+ 本地已读记录，绝不上传。
- **不与美学院相撞**：小教程无作业、无 XP、无进度环、无学习轨迹；卡片与详情页明确标注"小课堂·短文"；美学院入口保持独立（我的 → 美学院）。
- **图片用生成脚本**：所有教程封面/步骤图用 `scripts/gen_image.py`（MaaS 平台）生成，存 `assets/images/tutorials/`。

### 非目标（本迭代不做）

- 不做后端内容流 / 动态下发 / 社区互动。
- 不做教程收藏、点赞、分享。
- 不改美学院模块本身。
- 不改灵感页其他 3 个区块（引导条/今日可拍/灵感图集）。

## 3. 页面定位与内容架构

灵感页 4 区块结构不变，仅第 3 区块换内容源：

| # | 区块 | 变更 |
|---|---|---|
| 1 | 顶部引导条 | 保留 |
| 2 | 今日可拍 | 保留 |
| 3 | **拍摄小课堂**（原"拍得更好"） | **替换内容源**：小教程取代美学院系统课 |
| 4 | 灵感图集 | 保留 |

- 区块标题改为「拍摄小课堂」，副标题「每天 3 分钟，拍得更好」。
- 标题行右侧保留"全部课程"入口但**改为指向美学院**（弱化：文字改为「系统性学习 → 美学院」），形成反导向流。
- 删除：`BetterShootSection` 推系统课逻辑、`coursePicksProvider`。
- 新增：`TutorialSection`（卡片区）、`tutorialPicksProvider`（推荐）、详情页路由。

## 4. 数据模型 `ShootingTutorial`

```dart
class ShootingTutorial {
  final String id;                 // 'tut_general_premium' 等，唯一
  final String title;              // 卡片标题
  final String subtitle;           // 卡片一句话副标题
  final String coverImage;         // assets/images/tutorials/ 封面
  final String category;           // general/portrait/landscape/food/street/night/macro/still-life
  final String readMinutes;        // '3分钟'
  final List<String> tags;         // ['高级感','光影',...]
  final String intro;              // 引言段
  final List<TutorialStep> steps;  // 步骤块（1-3 个）
  final List<String> tips;         // 小贴士（2-3 条）
  final TutorialCta cta;           // 结尾动作：去拍场景 / 去模板
  final String? academyCourseId;   // 关联美学院课程（导流）
}

class TutorialStep {
  final String title;              // 如「找逆光」
  final String body;               // 步骤正文
  final String? imageAsset;        // 步骤对比图（可选）
}

class TutorialCta {
  final TutorialCtaType type;      // scene | template
  final String targetId;           // 场景 id 或模板 id
}

enum TutorialCtaType { scene, template }
```

## 5. 内容体系（首批 20 篇，覆盖全摄影大类）

两类教程共用同一模型，按 `category` 区分：

| 类型 | category | 内容 | 数量 |
|---|---|---|---|
| 通用技巧（人人可读） | `general` | 如何拍出高级感 / 氛围感 / 找好角度 / 光影 / 构图 / 色彩 | 6 |
| 分类专项（全大类覆盖） | `portrait` 等 7 类 | 人像 / 风光 / 美食 / 街拍 / 夜景 / 微距 / 静物，每类 2 篇 | 14 |

- 每篇内容包含：1 封面 + 引言 + 2-3 步骤块（部分带 1 张对比图）+ 2-3 条小贴士 + 1 个 CTA + 可选关联美学院课程。
- 每篇的 CTA 指向真实存在的场景（`scene` 预设）或模板 id；关联的美学院课程 id 必须存在于 `AcademyContent`。
- 内容可后续发版扩展（在 `tutorial_content.dart` 追加条目即可）。

## 6. 个性化推荐算法

新建 `TutorialRecommendationService`（独立 service，仿 `features/home/services/recommendation_service.dart` 的多槽位混合架构），由 `tutorialPicksProvider`（`FutureProvider<List<ShootingTutorial>>`）调用。

### 6.1 信号输入（全部现成）

1. 问卷偏好：`QuestionnaireDao.getAnswers().favoriteCategories`（用户想拍什么，可能为空 = 未填）。
2. 近期行为：`GalleryDao.countByCategory()`（近 30 天实际拍摄类别分布，可能为空 = 新用户）。
3. 已读状态：`TutorialReadDao`（`tutorial_reads` 表，见 §7），未读教程优先。

### 6.2 类别权重计算

| 用户画像 | 权重逻辑 |
|---|---|
| 冷启动（无问卷且无拍摄） | 所有类别均匀（权重 1），`general` 通用技巧权重略高（1.2，人人可读） |
| 有问卷、无拍摄 | `favoriteCategories` 中类别权重 3，其余 1 |
| 有拍摄（含问卷） | 近期 top2 拍摄类别权重 3（行为优先），问卷偏好类别权重 2（与行为叠加时取 max 不叠加），其余 1 |

说明：当某类别既是问卷偏好又是近期常拍时，权重取 3（不累加为 5），避免单一类别过载。

### 6.3 多样性约束（防信息茧房）

- 打分排序后取 **60% 来自高分池（相关类别）+ 40% 来自低分池（探索类别）**。
- 最终推荐列表保证**覆盖 ≥ 3 个不同类别**（含 `general`）。
- 未读优先：未读教程在同类内优先于已读；全部已读时正常重读展示。
- 推荐数量：横滑卡展示 6 篇（3 相关 + 2 探索 + 1 general 保底，数量按内容池自适应裁剪）。
- 每次进入页面基于当前数据重算（不缓存），保证"最近拍了美食 → 下次进来美食相关教程变多"。

### 6.4 降级

- DAO 查询异常：捕获后回退为冷启动均匀推荐（每类各 1 篇），不阻塞页面。

## 7. 已读状态

- 新表 `tutorial_reads(id TEXT PRIMARY KEY, read_at INTEGER)`。
- 数据库版本 **22 → 23**，在 `database_provider.dart` 的 `_onUpgrade` 追加 `if (oldVersion < 23)` 块（`CREATE TABLE IF NOT EXISTS`，幂等）。
- 新 DAO `TutorialReadDao`（置于 `lib/core/db/dao/`，遵循现有 DAO 模式），方法：
  - `Future<Set<String>> getReadIds()`
  - `Future<void> markRead(String tutorialId)`（`ConflictAlgorithm.replace`，写入 `read_at`）
  - `Future<void> markUnread(String tutorialId)`（预留，供测试/重置）
- 新 Provider：`tutorialReadDaoProvider`（`FutureProvider<TutorialReadDao>`，仿 `galleryDaoProvider`）。
- 详情页打开即标记已读（`initState` 或首次渲染触发，幂等）。

## 8. 详情页设计

- 新路由：`/inspiration/tutorial-detail`，参数 `tutorialId`（新增 `RouteNames.inspirationTutorialDetail` + `RouteNames.paramTutorialId`）。
- 页面结构（`Scaffold` + `LumiraNav`（透明）+ 渐变背景，与美学院详情页视觉一致）：
  1. 封面图（全宽，`assets/images/tutorials/`）
  2. 标题 + 阅读时长 + tags
  3. 引言段
  4. 编号步骤块（标题 + 正文 + 可选对比图）
  5. 小贴士区（2-3 条，图标列表）
  6. 「去试试」CTA 按钮（`LumiraBtnPrimary`）：scene → 跳 `capture_scene_guide?scene=<id>`；template → 跳 `templates_detail?templateId=<id>`
  7. 底部导流条（仅当 `academyCourseId` 非空）：「想系统学？进入美学院」→ 跳 `profile_academy_detail?academyId=<id>`
- 进入页面即标记已读；右上角无收藏（非目标）。

## 9. 与美学院边界与导流

| 维度 | 拍摄小课堂 | 美学院 |
|---|---|---|
| 形态 | 单篇短文 | 系统课程 |
| 顺序 | 任意、无前置 | 难度×主题矩阵 |
| 闭环 | 无作业/XP/进度 | 作业+XP+进度环 |
| 时长 | 1-3 分钟 | 8 分钟+ |
| 钩子 | 读完→去拍（CTA） | 完成→进阶 |

导流关系：
- 灵感页标题行右侧「系统性学习 → 美学院」（替代原"全部课程"）。
- 详情页底部导流条（有 `academyCourseId` 时）跳关联课程。
- 美学院独立入口（我的 → 美学院）不受影响。

## 10. 图片资源生成

- 所有封面/步骤图用 `scripts/gen_image.py` 生成，输出到 `assets/images/tutorials/`。
- 图片规格：封面 16:9（`--size 16:9`），步骤对比图横图 4:3（`--size 4:3`）；统一暖米白/金棕品牌色调，与 App 视觉一致。
- 生成后需在 `pubspec.yaml` 追加 `assets/images/tutorials/` 目录注册。
- 每张图生成命令记录在实现计划的图片任务中，逐张生成并核对落盘文件名。

## 11. 文件结构（实现阶段）

```
lib/features/inspiration/
├── data/
│   ├── tutorial_content.dart            # 新增：20 篇小教程 const 数据
│   ├── tutorial_models.dart             # 新增：ShootingTutorial/TutorialStep/TutorialCta
│   ├── tutorial_recommendation_service.dart  # 新增：推荐算法
│   ├── inspiration_content.dart         # 修改：移除 pickCourses（或保留 unused）
│   └── inspiration_providers.dart       # 修改：coursePicksProvider → tutorialPicksProvider
├── widgets/
│   ├── tutorial_section.dart            # 新增：拍摄小课堂卡片区（原 better_shoot_section.dart 替换）
│   ├── tutorial_card.dart               # 新增：横滑小卡（封面/标题/时长/已读勾）
│   └── better_shoot_section.dart        # 删除
├── pages/
│   ├── inspiration_page.dart            # 修改：第 3 区块换 TutorialSection
│   └── tutorial_detail_page.dart        # 新增：小教程详情页
```

```
lib/core/db/
├── dao/tutorial_read_dao.dart           # 新增
├── tables.dart                          # 修改：tutorial_reads 表常量
└── database_provider.dart               # 修改：v23 迁移 + tutorialReadDaoProvider
```

```
lib/core/router/
├── route_names.dart                     # 修改：新增路由/参数常量
└── router.dart                          # 修改：注册详情页路由
```

```
lib/app/…（若需）inspiration.dart 内导流文案调整
```

```
test/features/inspiration/
├── tutorial_content_test.dart           # 新增：id 唯一、asset 存在、CTA/academy 引用有效
├── tutorial_recommendation_service_test.dart  # 新增：4 类画像 × 多样性/未读断言
├── tutorial_read_dao_test.dart          # 新增（或归入 core/db/dao/ 测试目录）
├── inspiration_page_test.dart           # 修改：第 3 区块断言更新
└── tutorial_detail_page_test.dart       # 新增：渲染/CTA/导流/已读
```

## 12. 测试计划（TDD）

1. **数据完整性**：20 篇 id 唯一；coverImage/步骤图 asset 存在；CTA 的 scene/templateId 有效；`academyCourseId` 在 `AcademyContent` 中存在。
2. **推荐算法**：冷启动均匀 / 问卷加权 / 行为优先 / 多样性 ≥3 类 / 未读优先 / 全已读重读 / DAO 异常降级。
3. **DAO**：markRead/getReadIds/markUnread 增删查。
4. **页面**：灵感页第 3 区块渲染 6 卡；点卡跳详情；点"系统性学习"跳美学院；详情页 CTA 跳场景/模板、导流条跳课程、进入即已读。

## 13. 验收标准

1. 灵感页「拍得更好」改为「拍摄小课堂」，不再展示美学院系统课卡片。
2. 冷启动用户看到 ≥3 个类别的教程；填问卷用户首类权重最高；狂拍某类用户该类偏多但不独占（多样性 60/40）。
3. 详情页可完整阅读：封面/引言/步骤/贴士/CTA，进入即记已读。
4. 详情页 CTA 与导流条跳转全部可达（场景/模板/美学院课程均为真实 id）。
5. 全部教程图片由 `gen_image.py` 生成且已注册到 pubspec。
6. 数据库 v22 → v23 迁移幂等；已有用户数据不受影响。
7. `flutter analyze` 无错误无警告；相关测试全绿。
