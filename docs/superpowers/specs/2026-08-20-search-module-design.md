# 搜索模块设计（统一全局搜索页：模板 + 场景 + 美学院）

日期：2026-08-20
状态：已评审通过，待实现（实现顺序：先做后端「使用次数统计」，后做本搜索模块）

## 1. 背景与目标

当前 `TemplatesSearchPage` 与 `ScenesSearchPage` 两页结构几乎雷同，均存在以下不足：

- 数据一次性全量加载到内存并全部渲染，无分页 / 滑动加载
- 无历史搜索记录、无热门搜索、无推荐信息
- 筛选能力弱（仅用户标签 AND 过滤）
- 搜索字段少（模板：名称/分类/系统标签；场景：名称/氛围/分类）
- 两页逻辑重复、无公共抽象
- 无全局搜索：无法一次搜到模板 / 场景 / 美学院知识等多类内容

**目标**：仿照淘宝 / 小红书体验，把两页收敛为**一个统一全局搜索页**（`GlobalSearchPage`），以「范围 scope」维度打通模板、场景、美学院三类内容，标准化为「搜索初始页 + 结果页分页懒加载 + 全量筛选弹层」，并提供多字段检索、历史记录、热门搜索与推荐信息。原 `TemplatesSearchPage` / `ScenesSearchPage` 两页由统一搜索页 + scope 参数取代。

## 2. 范围切分（重要）

本需求横跨两个相对独立的子系统，拆分为两个子项目推进：

| 子项目 | 内容 | 侧重点 |
|---|---|---|
| **A. 搜索模块（本文档）** | 客户端统一全局搜索页：初始页 + 分页懒加载 + 全量筛选 + 多字段搜索（模板/场景/美学院） | 纯客户端，离线优先，不做后端改动 |
| **B. 使用次数统计与推荐** | 模板/场景使用次数统计 → 推荐算法 → banner 位 → 搜索页推荐信息 → 搜索结果排序；后台管理内置场景与 banner | 后端 + admin + 客户端消费 |

> 实施顺序：**先实现子项目 B 的使用次数统计**，再实现本文档所述的搜索模块。本文档已为子项目 B 预留消费位（热搜、推荐、排序的渐进式切换），见 §7。

### 2.1 子项目 A 的非目标（YAGNI）

- 不做服务端分页（数据量小，离线优先，客户端内存分页即可）
- 不做云端热搜/云端推荐（由子项目 B 接替前，本地派生）
- 不做运营 banner 位（归入子项目 B）
- 不引入第三方搜索/列表框架

## 3. 现状分析

### 3.1 页面现状

两个页面均为 `ConsumerStatefulWidget`，核心流程一致：

```
initState → 全量加载(_allTemplates/_allScenes + _allTags)
keyword → templateMatchesKeyword / sceneMatchesKeyword（名称/分类/标签）
用户标签 → _refreshUserTagFilter（AND 取交集）
结果 → GridView.builder(2列, NeverScrollable, shrinkWrap) 一次性渲染
```

### 3.2 数据模型（可搜索字段）

`TemplateRecord`（`lib/core/db/dao/templates_dao.dart`）：
`name / category / classification{type,majorStyle,subStyle,method} / tags / description / referenceSource / composition{description} / sceneGuide / postProcess{lut}`。

`SceneRecord`（`lib/core/db/dao/scenes_dao.dart`）：
`name / category / style / vibe / description / tips / whereToShoot / bestTime / relatedCategory`。

`AcademyContent`（`lib/features/academy/data/academy_content.dart`，纯静态，不入库）：
- `AcademyCourse`（16 课）：`id / lessonNumber / title / level / topic / meta / tags / rewardXP`
- `KnowledgeCard`（8 张）：`id / topic / title / subtitle / body / keyPoints`

`TopicExt.label`（人像/风光/静物/街头）与 `LevelExt.label`（入门基础/进阶技巧/高级创作）提供中文标签供检索。

### 3.3 入口现状与目标

| 入口 | 现状 | 目标 |
|---|---|---|
| 「发现」Tab（`TemplatesPage`）右上搜索图标 | push `templatesSearch` | 仅指向**全局搜索**（`/search?scope=all`） |
| 模板库一级分类页（`TemplatesAllPage`，title=「模板库」） | 无搜索按钮 | 新增搜索按钮 → `/search?scope=template` |
| 场景库（`ScenesPage`）右上搜索图标 | push `scenesSearch` | `/search?scope=scene` |
| 摄影美学院（`AcademyPage`） | 无搜索入口 | 新增搜索按钮 → `/search?scope=academy` |

> 即：搜索页本身只有一个统一入口（`/search`），通过 `scope` 查询参数决定默认搜索范围；`scope=all` 跨三类内容混合搜索。

### 3.4 匹配纯函数现状

`lib/features/tags/tag_filter_logic.dart` 提供 `containsIgnoreCase`、`templateMatchesKeyword`、`sceneMatchesKeyword`、`filterTagsByKeyword`，可复用并扩展；美学院检索需新增 `academyMatchesKeyword` 纯函数。

## 4. 交互与页面结构（淘宝/小红书式）

统一搜索页 `GlobalSearchPage` 由 `scope` 查询参数决定初始范围；页面内提供范围切换栏（类似淘宝类目 tab / 小红书搜索筛选）：

```
┌ 搜索框 ──────────────────────────────────────┐
│ [全部] [模板] [场景] [美学院]   ← scope 切换栏  │
├─────────────────────────────────────────────┤
│  （scope=all）混合结果卡片带类型角标             │
│  （scope=template/scene/academy）只显示该类     │
└─────────────────────────────────────────────┘
```

### 4.1 搜索初始页（未输入关键词 / 清空关键词时）

```
┌ LumiraNav：搜索（全部/模板/场景/美学院）──────┐
│  搜索框（聚焦时高亮，含清除按钮）               │
│  [全部] [模板] [场景] [美学院]               │
│  ── 历史搜索 ──────────────────────          │
│  [词1] [词2] [词3] ...   （单个 ✕  、右上"清空"）│
│  ── 热门搜索 ──────────────────────          │
│  1.词 2.词 ...（序号样式，词条可点）            │
│  ── 为你推荐 ──────────────────────          │
│  分类/人气卡片（模板：分类导航卡；场景：风格卡；   │
│   美学院：主题/等级卡）                         │
└──────────────────────────────────────────┘
```

- 历史：最近 N 条（默认 10），按时间倒序去重；支持单条删除与一键清空；按 scope 隔离（见 §5.1）
- 热搜：本地派生 = 自身高频搜索历史 top + 预置热门词（见 §7 渐进切换）；按 scope 联动
- 推荐：从分类/标签/人气派生，点击跳转分类页或填充关键词；`scope=all` 时三类推荐并列展示

### 4.2 搜索结果页（有关键词）

```
┌ LumiraNav ───────────────────────────────┐
│  搜索框                                     │
│  [全部] [模板] [场景] [美学院]  [筛选 ▾]     │
│  ── 结果 2 列瀑布流 ──────────────          │
│  ⬜ ⬜   ⬜ ⬜   ⬜ ⬜                        │
│  ⬜ ⬜   ⬜ ⬜   ⬜ ⬜                        │
│  （触底加载中… / 已经到底 / 空结果）           │
└──────────────────────────────────────────┘
```

- 结果集 = 关键词命中 → 筛选弹层条件 → 排序，然后分页懒渲染
- `scope=all`：三类内容混合排序展示，卡片左上角叠加类型角标（模板/场景/美学院），点击分别跳转对应详情页
- 触底加载 20 条，直到 `hasMore=false`
- 空结果：给出「换个关键词」提示 + 热搜词引导
- 切换 scope：立即按当前关键词在新范围内重算并**重置分页为第一页**

### 4.3 全量筛选弹层（仿小红书布局）

底部弹出 `showModalBottomSheet`，布局分三区；**分区随 scope 联动**（`scope=all` 只保留排序 + 用户标签）：

```
┌ 重置          筛选                                       确定 ┐
│ ── 排序 ──────────────────────────────                       │
│  综合 │ 热度 │ 最新        （横向可换行 pill，单选）             │
│ ── 分类 ──────────────────────────────  （template 专用）      │
│  全部 人像 风光 美食 …     （横向可换行 pill，多选=或 或 单选）   │
│ ── 风格 ──────────────────────────────  （scene 专用）        │
│  全部 复古 清新 …                                             │
│ ── 主题 ──────────────────────────────  （academy 专用）      │
│  全部 人像 风光 静物 街头                                       │
│ ── 等级 ──────────────────────────────  （academy 专用）      │
│  全部 入门基础 进阶技巧 高级创作                                │
│ ── 价格 ──────────────────────────────                       │
│  全部 │ 免费 │ 付费          （template 专用）                 │
│ ── 来源 ──────────────────────────────                       │
│  全部 │ 我拥有的            （template 专用）                  │
│ ── 用户标签 ──────────────────────────                       │
│  [标签1] [标签2] …        （多选 AND，沿用现状）               │
└──────────────────────────────────────────┘
```

- 底部固定「重置 / 确定」操作栏，顶部随内容滚动
- 选中项使用当前主题品牌色，未选为中性色
- 所有配色一律从 `appThemeProvider` / `uiStyleProvider` 派生（项目铁律）

## 5. 架构与公共抽象（标准化）

为消除三类内容搜索重复，抽一层公共能力（放 `lib/shared/searchengine/`，与业务解耦）：

```
lib/shared/searchengine/
  ├── search_scope.dart         # scope 枚举（all/template/scene/academy）+ 标签/顺序
  ├── search_store.dart          # 历史记录增删查清（scope 维度隔离）
  ├── search_filters.dart        # 筛选状态模型 + 排序枚举 + 条件应用
  ├── PagedResultsController.dart# 分页懒渲染控制器（page 累积 + hasMore + loading）
  └── filter_sheet.dart          # 通用「全量筛选弹层」组件（分区随 scope 联动）

lib/features/templates/search/
  └── template_search_service.dart  # 多字段检索 + 筛选 + 排序纯函数
lib/features/scenes/search/
  └── scene_search_service.dart     # 多字段检索 + 筛选 + 排序纯函数
lib/features/academy/search/
  └── academy_search_service.dart   # 美学院课程/知识卡片检索纯函数
```

统一搜索页 `GlobalSearchPage`（`lib/features/search/pages/global_search_page.dart`）接收 `scope` 参数，内部按 scope 调用对应 service，`scope=all` 时聚合三类结果。原 `templates_search_page.dart` / `scenes_search_page.dart` 删除，由 `GlobalSearchPage` 取代。

### 5.0 路由与入口

- 新增路由 `RouteNames.search = '/search'`，参数 `paramScope`（`scope`）
- 「发现」Tab 搜索图标 → `/search?scope=all`
- 模板库一级分类页（`TemplatesAllPage`）LumiraNav actions 新增搜索按钮 → `/search?scope=template`
- 场景库 `ScenesPage` 搜索图标 → `/search?scope=scene`
- 摄影美学院 `AcademyPage` LumiraNav actions 新增搜索按钮 → `/search?scope=academy`
- 原 `RouteNames.templatesSearch`、`RouteNames.scenesSearch` 移除或保留为兼容跳转（建议直接替换）

### 5.1 历史记录存储

新建 sqflite 表（沿用项目 `tables.dart` 建表方式）：

```sql
CREATE TABLE search_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT NOT NULL,          -- 'template' | 'scene' | 'academy'
  keyword TEXT NOT NULL,
  search_count INTEGER NOT NULL DEFAULT 1,
  last_searched_at INTEGER NOT NULL
);
-- 索引：scope + last_searched_at（排序）
```

- `scope` 隔离模板/场景/美学院，互不串扰
- 点选历史/热搜/提交搜索均触发写入：同 scope + 同 keyword 去重累加 `search_count` 并刷新时间
- `scope=all` 全局搜索提交时，同时写入三个 scope（keyword 相同、各自 scope 去重）
- 检索/清空按 scope 定向操作；`scope=all` 初始页展示三 scope 并集（按 `last_searched_at` 去重倒序）

### 5.2 多字段搜索

沿用 `tag_filter_logic.dart` 的 `containsIgnoreCase`（大小写不敏感子串），扩展：

**模板命中字段**：`name`、`category` 中文标签、`classification` 三级 key 中文标签（type/majorStyle/subStyle/method）、`tags`、`description`、`referenceSource`、`composition.description`、`postProcess.lut` 中文标签。

**场景命中字段**：`name`、`category`、`style`、`vibe`、`description`、`tips`、`whereToShoot`、`bestTime`、`relatedCategory`。

**美学院命中字段**：
- 课程：`title`、`topic.label`、`level.label`、`tags`、`meta`
- 知识卡片：`title`、`subtitle`、`topic.label`、`body`、`keyPoints`

分类/LUT 英文 key 需映射中文标签（复用 `templates_browse_mock_data.dart` 的 `categoryLabel`/`lutLabel` 等；美学院复用 `AcademyTopicExt.label` / `AcademyLevelExt.label`），保证中文搜索能命中英文 key 数据。

### 5.3 筛选维度

| scope | 排序 | 条件 |
|---|---|---|
| template | 综合/热度/最新 | 分类（四级 key 子树，复用 `getSubtreeKeys`）、价格（免费/付费）、来源（是否我拥有）、用户标签 AND |
| scene | 综合/热度/最新 | 分类、风格、用户标签 AND |
| academy | 综合/热度/最新 | 主题（topic）、等级（level） |
| all | 综合/热度/最新 | 仅用户标签 AND（跨三类数据时分类/风格/价格语义不统一，YAGNI） |

- 分类/主题/等级采用「单选」语义；价格/来源单选；用户标签沿用多选 AND
- 「热度」优先级依赖子项目 B 数据，未就绪前退回本地派生热度（如 `isRecommended` + 本地使用次数），见 §7

### 5.4 分页懒渲染

- 全量数据加载到内存后，先经「关键词 → 筛选 → 排序」得到完整有序结果列表
- `GridView.builder` 声明 `_visibleCount`（每页 20），随 `ScrollController` 触底 `_visibleCount += 20`
- `hasMore = _visibleCount < results.length`
- 底部状态条：`加载中…` / `已经到底了` / 空结果引导
- 明确可观测：排序或筛选变化时重置分页为第一页

## 6. UI 约束（项目铁律 compliance）

- 颜色/阴影/边框一律取自 `appThemeProvider`（`tokens.*`）与 `uiStyleProvider`，禁止硬编码 `Colors.xxx` / `Color(0xFF...)`
- 新拟态风格下，叠在照片上的浮层按钮用「实心 surface + 细边」，不用外阴影/毛玻璃
- 复用 `LumiraNav`、共享卡片组件；新增风格自适应组件放 `lib/shared/widgets/`
- 不引入新的第三方图标库，沿用项目现有图标体系
- 首屏/触底加载需防抖防重入（避免重复请求/重复追加）

## 7. 与子项目 B（使用次数统计）的衔接

搜索模块对子项目 B 依赖的字段处，设「渐进式来源」开关，避免阻塞：

- **热搜**：暂无云端 → 本地派生（预置热门词 ∪ 自身高频历史）；B 就绪后 → 拉取云端热搜接口
- **推荐信息**：暂无云端 → 分类/标签/`isRecommended` 派生；B 就绪后 → 云端推荐
- **热度排序**：暂无云端使用数据 → 本地派生（推荐标记 + 本地导入/使用次数兜底）；B 就绪后 → 后端统计的 `usage_count` 驱动
- **banner 位**：本模块不实现，留给 B

> 这样即使子项目 B 未完成，搜索模块也能独立上线且行为合理。

## 8. 测试策略

- **纯函数单测**：新增 `tag_filter_logic` 扩展、`template_search_service`、`scene_search_service`、`academy_search_service`（含课程/知识卡片字段命中）、`search_store` 均做单元测试（沿用项目现有 test 结构）
- **分页控制器**：对 `hasMore`/触底追加/reset 行为做单测
- **历史记录**：去重、scope 隔离、清空、上限裁剪、`scope=all` 三写并集做单测
- **scope 切换**：`all` 混合排序与类型角标、切换 scope 重置分页做单测
- **UI**：沿用 `flutter analyze` + 现有测试基线，不做重型 widget 测试；真机/模拟器手工验证全局搜索、各入口（发现/模板库/场景库/美学院）默认 scope、筛选弹层与触底加载

## 9. 交付清单（子项目 A）

- 新增 `lib/shared/searchengine/`（scope / store / filters / paged controller / filter sheet）
- 新增 `template_search_service`、`scene_search_service`、`academy_search_service`
- 新增统一搜索页 `lib/features/search/pages/global_search_page.dart`，删除 `templates_search_page.dart`、`scenes_search_page.dart`
- 新增路由 `RouteNames.search`（`/search?scope=`），替换 `templatesSearch` / `scenesSearch` 路由
- 入口接入：发现 Tab、模板库一级分类页、场景库、摄影美学院各新增/改指向搜索按钮
- sqflite 新增 `search_history` 表（含迁移，scope 支持 template/scene/academy）
- 单测补齐