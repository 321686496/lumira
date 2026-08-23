# 今日灵感智能模板推荐设计

> 日期：2026-08-23
> 范围：Flutter 端（`lumira_app_flutter/`）首页「今日灵感」卡片
> 不涉及后端改动（复用已落地的 `usage_stats` 全站使用次数与本地模板元数据）

## 目标

把首页「今日灵感」从「纯文案灵感卡片」升级为「文案 + 智能模板推荐」：根据**当前天气 / 时间 / 气温**以及**用户最近拍摄偏好**，实时推送一个既贴合当前时段、又是用户感兴趣的模板；推荐成功时卡片底部按钮变为「用「模板名」拍摄」，点击直接套用该模板进入拍摄页。推荐不出时保持原有展示与行为。

## 行为约定

- **推荐成功**：卡片文案不变，按钮文案改为 `用「<模板名>」拍摄`，点击 `push` 进入拍摄页并带 `templateId=<该模板 id>` 直接套用。
- **推荐失败（回落到原有形态）**：
  1. 用户最近 N 天没有任何「带模板拍摄」记录，无法判断偏好；
  2. 或当前语境（季节/天气/气温/时段）在规则表与模板 `ambience` 中都找不到任何合适模板；
  此时卡片与按钮完全维持现状（`开始拍摄` + 通用进拍摄页）。

## 判定流程

1. **偏好门槛**：复用 `InspirationService` 已计算的「最近 30 天主导 category」。若无任何带模板拍摄记录（主导 category 为空）→ 不推荐，回落。
2. **语境贴合候选**（规则表为主 + `ambience` 优先，用户已确认）：
   - 取当前语境令牌（季节 season / 天气 weather / 气温区间 + 时段 slot），查规则表得「适合风格集合」与「适合类别集合」。
   - 候选条件（任一命中即可）：
     - 模板 `classification.style/subStyle` ∈ 适合风格集合，或 `classification.type/category` ∈ 适合类别集合；
     - 模板自带 `ambience`（seasons/weathers/timeTones）与当前语境匹配 → **最高优先级入选**。
   - 候选集合为空 → 不推荐，回落。
3. **排序取「最火爆 + 贴合偏好」**：候选内先按「是否命中用户主导类别」优先，再按全站 `use_shoot` 拍摄次数（`UsageDao.countFor(itemId,'template','use_shoot')`）从高到低，取 top1 作为推荐模板。

## 数据来源（全部本地读取，零网络开销）

| 输入 | 来源 |
|---|---|
| 当前语境（季节/天气/气温/时段） | 复用 `InspirationService` 的 `InspirationContext` 归一化令牌 |
| 用户主导 category（最近 30 天） | 复用现有计算（gallery 带模板照片统计） |
| 候选模板全集 | `templatesDao`（内置 + 远程可用模板） |
| 模板元数据（风格/类别/ambience） | `TemplateMeta` → `classification` / `category` / `ambience` |
| 全站火爆次数 | `UsageDao.countFor(id, 'template', 'use_shoot')`（`usage_stats` 缓存，离线为 0 不降级） |

## 语境 → 风格/类别 规则表

新增 `lib/features/home/data/template_context_rules.dart`，建模沿用现有 `inspiration_rules.dart` 的令牌体系（slot / season / weather / tempRange）。每条规则：

- 输入约束：`season ∈ {spring,summer,autumn,winter}`，`weather ∈ {sunny,cloudy,overcast,rain,snow,fog}`，气温区间，时段 `slot`；
- 输出：`recommendedStyles: List<String>`（风格/子风格 key）、`recommendedCategories: List<String>`。

示例（用户场景映射）：
- `summer + sunny + 温暖(22–30℃) + 午后(dusk)` → 日系风格、人像类别。

> 具体规则条目需依据现有内置/远程模板实际存在的 `style` / `subStyle` / `category` 取值表构造，确保能命中真实模板（避免规则指向不存在的风格）。规则表仅作为初始版本，后续可在 `docs/future-optimizations.md` 登记扩充。

## 文件改动

| 文件 | 改动 |
|---|---|
| `lib/features/home/data/template_context_rules.dart`（新） | 语境→风格/类别 规则表 + 查询函数 |
| `lib/features/home/services/inspiration_service.dart` | `build()` 内追加模板推荐计算，产出可选 `recommendedTemplate` |
| `lib/features/home/data/inspiration_models.dart` | `HeroInspiration` 增加可空 `recommendedTemplateId` / `recommendedTemplateName` |
| `lib/features/home/widgets/hero_card.dart` | 按钮按推荐状态切换文案；有推荐时 `push(capture?templateId=...)`，否则走 `widget.onCapture` |

## 错误处理与边界

- 所有新增读取均为本地查询，失败静默返回「不推荐」，不抛异常、不影响卡片现有展示。
- 推荐逻辑放入 Provider 内部，复用现有 1 分钟自动刷新；新数据为本地组装，无额外请求与失败路径。
- 全站数量缓存缺失/离线时为 0，仅影响排序（不产生推荐遗漏之外的异常）。

## 测试

- 规则表命中：给定 slot/season/weather/temp 断言推荐风格与类别集合符合预期；
- 偏好门槛回落：用户无带模板照片时 `recommendedTemplate == null`；
- 候选为空回落：语境在规则表与 ambience 均无命中时 `recommendedTemplate == null`；
- 排序：候选内 category 命中者优先、同类别内 use_shoot 高者优先；
- 按钮行为：有推荐时文案与跳转带 templateId；无推荐时维持 `开始拍摄` + 通用进拍摄。