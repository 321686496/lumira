# 个性化模板推荐引擎设计

> 日期：2026-08-25
> 范围：Flutter 端（`lumira_app_flutter/`）个性化模板推荐
> 后端：**零改动、零新增请求**（全部逻辑本机运行，后端 QPS 保持不变）

## 目标

把「给用户推荐哪类/哪个模板」从「全站热度 + 单分类统计」的规则式推荐，升级为**个人化的「越用越懂你、越用越停不下来」的模板推荐引擎**（神经网络式理念：学习用户喜欢什么模板 → 实时反馈回流 → 推荐更贴合）。

- 用户每次「用模板拍摄 / 看详情 / 收藏 / 分享」都会回流到本地个人画像；
- 推荐列表按「用户喜欢的类型(熟) 50% + 探索新类型(新) 50%」混合，既懂你又保持新奇（类似抖音平衡）；
- 应用到**发现页模板列表、首页 Banner、灵感页、模板详情页同类推荐**四个入口。

## 非目标 / 范围界定

- **不做**方案 B 的特征向量余弦相似/协同过滤（模板规模约百余条，属过度设计）。
- **不做**「不感兴趣」显式负反馈 UI（登记到 `docs/future-optimizations.md`）。
- **不引入**服务端画像、埋点与离线评估体系（后续单独立项）。
- **不做**任何后端请求增加——个人化全部在客户端完成。

## 术语与现状

- 模板分类为 JSON 字段：`category / majorStyle / style / subStyle / method`（见 `TemplateRecord.classification`）。
- 现有已埋点：完成拍摄 `use_shoot`（[capture_page.dart](lib/features/capture/pages/capture_page.dart)；触发点为 `UsageEventType.useShoot`）、查看详情 `open_detail`（[templates_detail_page.dart](lib/features/templates/pages/templates_detail_page.dart)，`UsageEventType.openDetail`）。
- 现有全站热度：`usage_stats` 的 `use_shoot`、`open_detail`，经 `UsageDao.countMap` 读取。

---

## 一、数据模型：用户兴趣画像（新增）

**新表 `user_interests`**（本机 SQLite）：

```
user_interests(
  id              TEXT PRIMARY KEY,   -- 形如 "category:portrait" / "major_style:xxx" / "style:xxx"
  scope           TEXT NOT NULL,      -- 'category' | 'major_style' | 'style'
  key             TEXT NOT NULL,      -- 对应维度的分类/风格 key
  score           REAL NOT NULL,      -- 时间衰减后的兴趣分
  last_signal_at  INTEGER NOT NULL,   -- 最近一次正反馈时间戳(ms)
  UNIQUE(scope, key)
)
```

- **迁移**：沿用 `database_provider.dart` 现有迁移体系，新增一个版本创建该表。
- **DAO**：新增 `InterestDao`：`getAll()`、`read(scope,key)`、`upsert(scope,key,newScore,at)`（写内存计算好的分数，不做全表历史扫描）。

## 二、时间衰减（增量式）

每次正反馈时对受影响行做**就地衰减再加权**：

```
score = score * decay^Δt_days + weight,   decay = 0.5^(1/14)   // 约 14 天半衰期
```

`Δt_days` 为 `last_signal_at` 到当前时刻的天数。`decay` 与半衰期作为常量，便于调参。
这样避免每次遍历历史相册，读画像即取即用，性能开销极小。

## 三、反馈采集与加权（P1：建立反馈闭环）

新增 `InterestService.recordSignal(template, weight)`：写入该模板的 `category / majorStyle / style` 三个维度对应画像行。

| 信号 | 权重 | 作用维度 | 接线点 | 来源 |
|---|---|---|---|---|
| 完成拍摄 | 3.0 | 三级 | capture_page `useShoot` 处 | 复用现有触发点 |
| 查看详情 | 0.6 | 三级 | templates_detail_page `openDetail` 处 | 复用现有触发点 |
| 收藏照片(映射模板) | 1.5 | 三级 | gallery_page 收藏某照片 | 照片含 `template_id` 时映射 |
| 分享模板 | 1.5 | 三级 | 模板/照片分享入口（share_reporter） | 含 `template_id` 时映射 |

> 说明：**不做**新增「编辑/反复用」独立字段；「反复用」由完成拍摄多次的权重累计自然覆盖，避免过度设计。

## 四、排序函数（P0+P1 核心）

`TemplateRanking.rank(templates, ctx)` 对每条模板打分：

```
score(T) = wI·interest(T)      // 画像三级兴趣（归一化到 0..1）
         + wE·exploration(T)   // 探索：T 的 category 用户所拍占比低 / 未拍 → 加分
         + wH·globalHot(T)     // 全站热度 use_shoot*2+open_detail（归一化）
         + wQ·questionnaire(T) // 问卷首选分类加分（新用户弱加成）
         -  penalty·recentlyShown(T)  // 近期列表已展示 → 降权防「刷到同一个」
```

- **三级兴趣 `interest(T)`**：对 T 的 `category/majorStyle/style` 三个维度分别取画像分，加权求和：
  `interest(T) = wCat·s(category) + wMaj·s(majorStyle) + wSty·s(style)`（各维度为空则跳过，求和不除缺失项），再做归一化。
- **50/50 混合（默认可调）**：将候选分别按 `interest(T)`（「熟」）与 `exploration(T)`（「新」）各取前一半，交替合并成最终列表，保证 `~50% 熟 / ~50% 新`。
- **探索奖励定义**：`exploration(T)` = 由用户各 `category` 累计拍摄占比反比得出——某分类拍得越少/未拍，该分类模板探索奖励越高；与已熟分类不同者也加分。
- **冷启动**：画像为空时 `wI` 退化为 `wQ`（问卷）+ `wH`（热度），`wE` 置高 → 自然过渡到探索型推荐，不空白。

**参数常量**（集中定义，便于 A/B 调参）：`wI/wE/wH/wQ`、penalty、decay、半衰期、50/50 比例。

## 五、统一画像 Provider

- `userInterestProvider`：FutureProvider 异步读取全量画像（`InterestDao.getAll()`），返回 `Map<String, double>`（key 为 `id`）。
- 每个反馈点调用 `InterestService.recordSignal` 后 `ref.invalidate(userInterestProvider)`，推荐处下次读取即最新。
- 所有入口复用该单一画像，替代各模块各自重复的「countByCategory 取 top」逻辑。

## 六、四入口接线

| 入口 | 文件 | 改动 |
|---|---|---|
| 发现页模板列表 | `templates_page.dart` + `templates_providers.dart` | 主列表沿用现有分区结构；「为你推荐」分区与列表排序改用 `TemplateRanking.rank`；「更多模板」保留热门/最新分区但入选名单叠加个人兴趣 |
| 首页 Banner | `home/services/recommendation_service.dart` | 槽 2/4/5 选模板的打分 `_pickUnusedSystemPick`、`_pickExplorationCategory` 改为混合 `score = wH·hot + wI·interest + wQ·questionnaire`（Banner=热度+偏好+问卷），槽位结构不变 |
| 灵感页 | `inspiration/data/inspiration_providers.dart`、`inspiration_service.dart` | `pickRecommendedTemplate` / `pickTodayShoot` 的类别匹配叠加画像 `interest` 到打分 |
| 模板详情页 | `templates_detail_page.dart` | 底部新增「为你推荐」板块（同 category/majorStyle 的模板，用 `rank()` 排序取前若干），若已存在同类板块则改造为个性化排序 |

## 七、性能与 QPS 保证

- **后端 QPS 不变**：整套个人化（画像、排序、混合）全部本机运行，只读本地 `gallery / usage_stats / user_interests`；唯一后端数据仍是现有模板列表 API。个人化不再增加任何服务器请求。
- **客户端轻量**：
  - 画像是增量 `upsert`，每次反馈仅写一条分数，不做全表历史扫描；
  - 排序对象为内置模板全集（约 132 条），单次排序量极小（微秒级）；
  - Provider 缓存 + 反馈后 `invalidate`，tab 切换不重算；
  - 所有失败静默回退到现有全站热度逻辑，不影响 UI 可用。

## 八、错误处理与边界

- 画像表未就绪/读取失败 → 返回空画像，排序退化为「热度+问卷」原逻辑。
- `InterestService.recordSignal` 失败不抛异常、不影响拍摄/详情主流程。
- 排序无候选 → 各入口保持现有展示（Banner 保底系统推荐、详情页无「为你推荐」板块则隐藏）。

## 九、测试（`flutter analyze` 0 error + 单元测试）

1. **衰减**：给定 `last_signal_at` 与当前时间，断言分数按 `decay^Δt` 变化。
2. **信号加权**：完成拍摄/详情/收藏写入画像的分数符合权重表。
3. **50/50 混合**：结果列表熟侧/新侧占比符合配置（约各半）。
4. **探索奖励**：少拍分类模板探索分高于已熟分类。
5. **去重 & 最近展示降权**：recentlyShown 模板被降权。
6. **冷启动回落**：画像为空时排序退化为热度+问卷，无异常。
7. **四入口 provider smoke**：各入口在画像空/有数据两种情况下都能产出列表。

## 十、文件改动清单（预估）

| 文件 | 改动 |
|---|---|
| `core/db/tables.dart` | 新增 `user_interests` 表定义 + 迁移版本 |
| `core/db/database_provider.dart` | 迁移列表追加新表 |
| `core/db/dao/user_interests_dao.dart`（新） | InterestDao（getAll/read/upsert） |
| `features/templates/recommend/user_interests.dart`（新） | InterestService + recordSignal（写入三维度） |
| `features/templates/recommend/template_ranking.dart`（新） | TemplateRanking + 参数常量 + 50/50 混合 |
| `features/templates/data/templates_providers.dart` | userInterestProvider；发现页排序 |
| `features/templates/pages/templates_page.dart` | 「为你推荐」/列表用 rank |
| `features/home/services/recommendation_service.dart` | Banner 槽 2/4/5 混合打分 |
| `features/inspiration/*` | 灵感页推荐叠加画像 |
| `features/templates/pages/templates_detail_page.dart` | 底部「为你推荐」板块 |
| `features/capture/pages/capture_page.dart` | 完成拍摄时写画像 |
| `features/templates/pages/templates_detail_page.dart` | 打开详情时写画像 |
| `features/gallery/pages/gallery_page.dart` / 分享 | 收藏/分享映射写画像 |
| 测试 | 上述 7 项单元测试 |
| `docs/future-optimizations.md` | 追加「不感兴趣负反馈」「时间窗/冷启动调参」等后续项 |