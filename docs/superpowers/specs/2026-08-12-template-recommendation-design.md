# 模板推荐算法优化设计

日期：2026-08-12
范围：Flutter 客户端（lumira_app_flutter）「为你推荐」页纯本地算法改造

## 1. 背景与目标

当前「为你推荐」页（`lib/features/templates/pages/templates_recommend_page.dart`）是一个**纯静态页面**，4 个 section 全部使用 `TemplatesBrowseMockData` 假数据（风格分析 / 猜你喜欢 / 相似用户 / 最近拍摄），链接点击仅弹出"即将上线"。

目标：
- **不使用后端 API 做推荐**，推荐算法全部在 Flutter 本地计算
- 使用**本地真实数据**（sqflite）驱动推荐，替换全部 mock 数据
- 推荐依据：用户喜好风格、最近拍摄照片套用的模板、拍摄场景、爱拍内容
- 排除已拥有 + 已使用过的模板
- 新增**旧模板召回**：很久前用过、近期类型匹配的模板单独召回，附解释文案

## 2. 现状与约束

- 模板目录数据：后端 `GET /api/v1/templates/list` 同步缓存到本地 `custom_templates` 表（source='remote'），系统内置模板（source='builtin'）预置本地。推荐候选池 = `TemplatesDao.getBuiltinAndRemote()`。
- 已拥有模板：`ownedTemplateIdsProvider`（后端 `/templates/owned` 缓存，兑换/解锁信息来自服务端，属数据同步而非推荐计算，允许使用）。
- 无任何本地"用户行为画像"基础设施，需新建。
- 纯本地单用户 → 协同过滤不可行，采用**基于内容的加权相似度打分**。

## 3. 本地真实数据源

| 数据 | 来源 | 推荐用途 |
|---|---|---|
| 照片库 `gallery_items` | `GalleryDao` | 用户行为主体（scene_id / template_id / mood / lut / post_process / is_favorite / created_at） |
| 场景 `scenes` | `ScenesDao` | 场景 style / related_category → 风格偏好 |
| 模板库 `custom_templates` | `TemplatesDao` | 推荐候选池（category / tags / tagIds / classification / price） |
| 分类 `template_categories` | `TemplatesDao.getCategories` | 分类中文名映射（用于文案） |
| 问卷 `questionnaire` | QuestionnaireDao | 冷启动偏好（answers_json） |
| 已拥有 | `ownedTemplateIdsProvider` | 排除项 |

现成可复用的统计方法（`GalleryDao`）：
- `countByCategory()`：按拍摄目标分类统计照片数
- `countByTemplate()`：按模板 ID 统计照片数（判断"已用过"）
- `countByStyle()`：按场景风格统计照片数（风格分析）
- `getRecent({limit})`：最近拍摄照片
- `getFavorites()`：收藏照片

## 4. 算法设计

### 4.1 用户偏好画像（UserProfile）

由本地照片行为聚合得到，含时间衰减（近期权重更高）：

```
timeWeight(t) = exp(-(now - t) / HALF_LIFE)      // HALF_LIFE = 30 天
```

画像维度（照片按 timeWeight 加权）：
1. **场景风格分布** `styleWeights: Map<styleKey, double>` — 来自 photos JOIN scenes.style
2. **分类偏好分布** `categoryWeights: Map<categoryKey, double>` — 来自 photos JOIN scenes.related_category 或套用模板的 category
3. **标签偏好分布** `tagWeights: Map<tagId, double>` — 来自套用模板的 tagIds
4. **后期风格向量** `postProcessAvg` — photos.post_process 均值：saturation / temperature / contrast / brightness（归一化到 [-1, 1]）
5. **常用模板集** `usedTemplateIds` — 按 countByTemplate 得出

### 4.2 候选过滤（排除）

候选池 = `getBuiltinAndRemote()`，排除：
- 已拥有（`ownedTemplateIdsProvider`）
- 近期已使用过（gallery_items 中出现过 template_id，即 `countByTemplate` 的 key）
- 非活跃模板（本地已是 active 数据，无需额外过滤）

### 4.3 匹配打分（猜你喜欢）

对每个候选模板 `t` 计算：

```
score(t) = w1 * categorySim(t)   + w2 * tagSim(t)   + w3 * styleSim(t)   + w4 * postProcessSim(t)
```

| 维度 | 计算 | 默认权重 |
|---|---|---|
| categorySim | 画像 categoryWeights 中 t.category 的归一化权重 | 0.35 |
| tagSim | t.tagIds ∩ 画像 tagWeights 的加权 Jaccard | 0.30 |
| styleSim | 画像 styleWeights 中 t.classification.style / t.category 关联 style 的权重 | 0.20 |
| postProcessSim | 模板 t.postProcess 参数与画像 postProcessAvg 的余弦相似度 | 0.15 |

说明：
- 权重为默认值，常量定义在算法文件顶部便于调参
- 分类不足（冷启动）时降级权重，见 4.5
- 无任何行为数据时跳过打分，直接进入冷启动逻辑

### 4.4 旧模板召回（旧爱回归）

识别"很久之前用过 + 近期类型匹配"的模板：

```
判定：
1. template_id ∈ countByTemplate（历史用过）
2. 最近一次使用时间 > 30 天前（created_at 中最新的使用记录距今 > 30 天）
3. 该模板的 category / tagIds 与当前画像匹配度高于阈值（复用 4.3 打分，threshold ≥ 0.3）
```

命中后进入"旧爱回归"区（Section 3），卡片文案：
- 名称 + 匹配度
- 副文案："你最近很喜欢拍这种类型，这是你很久前用过的同类型模板"
- 展示"× 张"（历史使用张数）

### 4.5 冷启动

无照片（`galleryDao.count() == 0`）且无问卷：
1. **有问卷**：解析 `questionnaire.answers_json`，提取用户选择的偏好（类型/风格/方法标签），用其匹配模板 tagIds/category 排序取 Top N
2. **无问卷**：按一级分类（type）分组，每组取 sortOrder 靠前的模板，均匀覆盖各类型（每类 2 个，共 ~6-8 个），保持多样性

冷启动时风格分析卡展示引导文案（"完成 3 张拍摄后生成你的风格分析"），不展示假百分比。

## 5. 页面改造（4 个 section）

保留推荐页现有视觉骨架（FadeUp / NeuCard / 网格卡片），数据层替换为算法输出：

| Section | 现状（mock） | 改造后（真实） |
|---|---|---|
| 1 风格分析卡 | `TemplatesBrowseMockData.styleAnalysis`（假 128 张） | 真实 `countByStyle()` 分布 Top 3 + 张数（"分析你过往的 N 张作品"） |
| 2 猜你喜欢 | `guessLikes` 假数据 | 4.3 打分 Top 6（排除已拥有+已用过），显示"匹配 xx%" |
| 3 相似用户也在拍 | `similarUsers` 假数据 | **改为「旧爱回归」**：4.4 召回 Top 4，副文案说明"很久前用过" |
| 4 根据最近拍摄 | `recentTemplates` 假数据 | 真实 `getRecent(1)` 最近照片 + 该照片关联模板同类型推荐（4.3 打分子集）Top 4 |

Section 4 依据优先级：最近照片若套用了模板（template_id 非空）→ 取该模板同分类的候选子集按 4.3 打分；若未套用模板但关联场景（scene_id → related_category）→ 取该分类候选子集；两者皆无 → 该照片不作为推荐依据，回退到猜你喜欢结果补位。

交互补充：
- **换一换**：真实实现——对猜你喜欢/旧爱回归结果做洗牌（排除已展示项），不再弹"即将上线"
- 卡片点击保留跳转 `/templates/detail`

## 6. 架构与组件

```
lib/features/templates/
├── recommend/
│   ├── recommendation_engine.dart      # 纯 Dart 算法（无 Flutter 依赖，可单测）
│   │   ├── UserProfile（画像聚合）
│   │   ├── RecommendationResult（section 数据模型）
│   │   └── buildRecommendations(...)   # 主入口：画像 → 过滤 → 打分 → 召回 → 冷启动
│   ├── recommendation_providers.dart   # Riverpod FutureProvider，组合 DAO 输入
│   └── widgets/                        # 页面卡片组件（从推荐页拆分）
pages/templates_recommend_page.dart     # 消费 providers，移除 mock 引用
```

依赖注入：engine 通过构造参数接收 DAO 查询结果（`GalleryDao`、`TemplatesDao`、问卷数据、owned 集合），不直接依赖 Riverpod/数据库，保证可测性。

数据流：
```
进入推荐页
  → recommendationProvider 并行读取（gallery 统计 / 模板池 / 问卷 / owned）
  → 构建画像 → 过滤候选 → 打分排序
  → 分区输出（guessLikes / recall / recent 相关）
  → 页面按 section 渲染
```

## 7. 边界与错误处理

- 候选池为空（无 remote 模板、无内置模板）：各 section 显示空态提示，不崩溃
- 照片存在但模板池为空：风格分析卡正常展示，其余 section 显示空态
- post_process 缺失的照片：跳过后期风格贡献，不参与 postProcessAvg
- scenes JOIN 缺失（scene_id 无对应场景）：该照片仅贡献分类维度（若有套用模板）
- 换一换到无可换项：toast 提示"已展示全部推荐"
- 性能：候选池本地全量加载 + 打分，模板量 < 500 时内存计算 < 50ms；`FutureProvider` 缓存结果避免重复计算

## 8. 测试

- **单元测试**（推荐引擎，无 Flutter 依赖）：
  - 画像聚合：时间衰减正确性、post_process 均值计算
  - 打分：同分类模板得分高于异分类、标签命中加分
  - 过滤：已拥有/已用过被排除
  - 旧召回：30 天阈值、匹配阈值边界
  - 冷启动：无数据 → 多样性覆盖各类型；有问卷 → 按问卷偏好排序
- **Widget 测试**：推荐页在空数据 / 有数据两种状态下正确渲染各 section

## 9. 非目标（明确不做）

- 不做后端推荐 API / 协同过滤（纯本地单用户不可行）
- 不改动模板列表页 / 详情页的既有排序逻辑
- 不采集新的用户行为数据（复用现有 gallery_items 即可，照片拍摄/编辑流程已写入）
- 不改视觉样式体系（沿用现有 NeuCard / FadeUp / 网格布局）
