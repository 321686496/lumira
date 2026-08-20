# 搜索模块设计（模板搜索页 + 场景搜索页标准化）

日期：2026-08-20
状态：已评审通过，待实现（实现顺序：先做后端「使用次数统计」，后做本搜索模块）

## 1. 背景与目标

当前 `TemplatesSearchPage` 与 `ScenesSearchPage` 两页结构几乎雷同，均存在以下不足：

- 数据一次性全量加载到内存并全部渲染，无分页 / 滑动加载
- 无历史搜索记录、无热门搜索、无推荐信息
- 筛选能力弱（仅用户标签 AND 过滤）
- 搜索字段少（模板：名称/分类/系统标签；场景：名称/氛围/分类）
- 两页逻辑重复、无公共抽象

**目标**：仿照淘宝 / 小红书体验，把两页标准化为「搜索初始页 + 结果页分页懒加载 + 全量筛选弹层」，并提供多字段检索、历史记录、热门搜索与推荐信息。

## 2. 范围切分（重要）

本需求横跨两个相对独立的子系统，拆分为两个子项目推进：

| 子项目 | 内容 | 侧重点 |
|---|---|---|
| **A. 搜索模块（本文档）** | 客户端两页标准化：初始页 + 分页懒加载 + 全量筛选 + 多字段搜索 | 纯客户端，离线优先，不做后端改动 |
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

两模型字段足够支撑多字段检索，无需改库新增字段。

### 3.3 匹配纯函数现状

`lib/features/tags/tag_filter_logic.dart` 提供 `containsIgnoreCase`、`templateMatchesKeyword`、`sceneMatchesKeyword`、`filterTagsByKeyword`，可复用并扩展。

## 4. 交互与页面结构（淘宝/小红书式）

### 4.1 搜索初始页（未输入关键词 / 清空关键词时）

```
┌ LumiraNav：搜索模板 / 搜索场景 ─────────────┐
│  搜索框（聚焦时高亮，含清除按钮）               │
│  ── 历史搜索 ──────────────────────          │
│  [词1] [词2] [词3] ...   （单个 ✕  、右上"清空"）│
│  ── 热门搜索 ──────────────────────          │
│  1.词 2.词 ...（序号样式，词条可点）            │
│  ── 为你推荐 ──────────────────────          │
│  分类/人气卡片（模板：分类导航卡；场景：风格卡）    │
└──────────────────────────────────────────┘
```

- 历史：最近 N 条（默认 10），按时间倒序去重；支持单条删除与一键清空
- 热搜：本地派生 = 自身高频搜索历史 top + 预置热门词（见 §7 渐进切换）
- 推荐：从分类/标签/人气派生，点击跳转分类页或填充关键词

### 4.2 搜索结果页（有关键词）

```
┌ LumiraNav ───────────────────────────────┐
│  搜索框                                     │
│  [筛选栏] 分类 | 价格 | 来源 | 排序  ▾        │
│  ── 结果 2 列瀑布流 ──────────────          │
│  ⬜ ⬜   ⬜ ⬜   ⬜ ⬜                        │
│  ⬜ ⬜   ⬜ ⬜   ⬜ ⬜                        │
│  （触底加载中… / 已经到底 / 空结果）           │
└──────────────────────────────────────────┘
```

- 结果集 = 关键词命中 → 筛选弹层条件 → 排序，然后分页懒渲染
- 触底加载 20 条，直到 `hasMore=false`
- 空结果：给出「换个关键词」提示 + 热搜词引导

### 4.3 全量筛选弹层（仿小红书布局）

底部弹出 `showModalBottomSheet`，布局分三区：

```
┌ 重置          筛选                                       确定 ┐
│ ── 排序 ──────────────────────────────                       │
│  综合 │ 热度 │ 最新        （横向可换行 pill，单选）             │
│ ── 分类 ──────────────────────────────                       │
│  全部 人像 风光 美食 …     （横向可换行 pill，多选=或 或 单选）   │
│ ── 价格 ──────────────────────────────                       │
│  全部 │ 免费 │ 付费                                           │
│ ── 来源 ──────────────────────────────                       │
│  全部 │ 我拥有的            （模板专用）                        │
│ ── 用户标签 ──────────────────────────                       │
│  [标签1] [标签2] …        （多选 AND，沿用现状）               │
└──────────────────────────────────────────┘
```

- 底部固定「重置 / 确定」操作栏，顶部随内容滚动
- 选中项使用当前主题品牌色，未选为中性色
- 所有配色一律从 `appThemeProvider` / `uiStyleProvider` 派生（项目铁律）

## 5. 架构与公共抽象（标准化）

为消除两页重复，抽一层公共能力（放 `lib/shared/searchengine/`，与业务解耦）：

```
lib/shared/searchengine/
  ├── search_store.dart          # 历史记录增删查清（scope 维度隔离）
  ├── search_filters.dart        # 筛选状态模型 + 排序枚举 + 条件应用
  ├── PagedResultsController.dart# 分页懒渲染控制器（page 累积 + hasMore + loading）
  └── filter_sheet.dart          # 通用「全量筛选弹层」组件

lib/features/templates/search/
  └── template_search_service.dart  # 多字段检索 + 筛选 + 排序纯函数
lib/features/scenes/search/
  └── scene_search_service.dart     # 多字段检索 + 筛选 + 排序纯函数
```

两页只保留各自的 `_buildResults` 卡片与导航差异，其余逻辑走公共抽象。

### 5.1 历史记录存储

新建 sqflite 表（沿用项目 `tables.dart` 建表方式）：

```sql
CREATE TABLE search_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  scope TEXT NOT NULL,          -- 'template' | 'scene'
  keyword TEXT NOT NULL,
  search_count INTEGER NOT NULL DEFAULT 1,
  last_searched_at INTEGER NOT NULL
);
-- 索引：scope + last_searched_at（排序）
```

- `scope` 隔离模板/场景，互不串扰
- 点选历史/热搜/提交搜索均触发写入：同 scope + 同 keyword 去重累加 `search_count` 并刷新时间
- 检索/清空按 scope 定向操作

### 5.2 多字段搜索

沿用 `tag_filter_logic.dart` 的 `containsIgnoreCase`（大小写不敏感子串），扩展：

**模板命中字段**：`name`、`category` 中文标签、`classification` 三级 key 中文标签（type/majorStyle/subStyle/method）、`tags`、`description`、`referenceSource`、`composition.description`、`postProcess.lut` 中文标签。

**场景命中字段**：`name`、`category`、`style`、`vibe`、`description`、`tips`、`whereToShoot`、`bestTime`、`relatedCategory`。

分类/LUT 英文 key 需映射中文标签（复用 `templates_browse_mock_data.dart` 的 `categoryLabel`/`lutLabel` 等），保证中文搜索能命中英文 key 数据。

### 5.3 筛选维度

| 页面 | 排序 | 条件 |
|---|---|---|
| 模板 | 综合/热度/最新 | 分类（四级 key 子树，复用 `getSubtreeKeys`）、价格（免费/付费）、来源（是否我拥有）、用户标签 AND |
| 场景 | 综合/热度/最新 | 分类、风格、用户标签 AND |

- 分类采用「单选」语义（进入该分类子树）；价格/来源单选；用户标签沿用多选 AND
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

- **纯函数单测**：新增 `tag_filter_logic` 扩展、`template_search_service`、`scene_search_service`、`search_store` 均做单元测试（沿用项目现有 test 结构）
- **分页控制器**：对 `hasMore`/触底追加/reset 行为做单测
- **历史记录**：去重、scope 隔离、清空、上限裁剪做单测
- **UI**：沿用 `flutter analyze` + 现有测试基线，不做重型 widget 测试；真机/模拟器手工验证两页交互

## 9. 交付清单（子项目 A）

- 新增 `lib/shared/searchengine/`（store / filters / paged controller / filter sheet）
- 新增 `template_search_service`、`scene_search_service`
- 重构 `templates_search_page.dart`、`scenes_search_page.dart` 接入公共抽象与初始页
- sqflite 新增 `search_history` 表（含迁移）
- 单测补齐