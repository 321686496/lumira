# 首页第 2 槽位：性别 + 二级风格自适应推荐

## Context

首页第二个 banner 槽位（新用户/老用户分流）目前只做到「一级大类」粒度：新用户按问卷选的大类、老用户按拍得最多的大类取模板，全程不进入二级风格，也未考虑用户性别。

用户诉求（已在澄清中确认）：
1. **二级风格细分**：该槽位推荐的模板细分到某个大类下的具体二级风格，新老用户都要。
2. **模板性别匹配**：模板已有 `gender` 字段（`unisex/male/female`），问卷已有「性别」问题（`male/female/prefer_not`），需让推荐用到它。
3. **问卷优化**：让用户在大类下再选具体风格。
4. 已确认的边界：性别匹配用**软偏好**；风格偏好**仅本地**存储不上报后端；本次**只改首页第 2 槽位**，不波及其他槽位/挑战页。

> 无需后端改动（用户选「仅本地」）。只改 Flutter 端，且仅本地存储 → 无 SQLite 版本号变更。

## 现状关键事实

- 问卷答案存 JSON blob（`questionnaire_dao.dart` 的 `answers_json`）→ 加字段无需迁移。
- 模板 `classification` Map：人像 L2=`majorStyle`，非人像 L2=`style`；统一取「二级风格 key」用 `cls['majorStyle'] ?? cls['style']`。
- `scenes.style`（cafe/neon…）是场所风格，**不等于**模板分类 L2 风格，故老用户二级风格不能靠 `countByStyle`；改从「用户已拍模板的 classification 二级风格」推断。
- `getStylesForType(typeKey)`（`templates_dao.dart`）返回大类下 L2 风格，供问卷级联选择。
- `recommendation_service.dart` 已持有 `_questionnaireDao`（可读 `gender`/`favoriteStyles`）与 `_galleryDao`（`countByTemplate()` 可拿每个已用模板的拍摄数）。

## 改动清单

### 1. 问卷：新增「二级风格」选择（`questionnaire_data.dart` / `questionnaire_answers.dart` / `questionnaire_page.dart` / `questionnaire_sync_service.dart`）

- **`questionnaire_data.dart`**：新增 `QuestionType.hierarchical` 枚举值；新增一道题：
  - `id: 'favorite_styles'`，title「在这些大类下，你更偏好哪种风格？」，`type: QuestionType.hierarchical`（选项非静态——由已选大类动态生成，故 `options` 留空）。
- **`questionnaire_page.dart`**：为该题型加渲染分支——遍历已选大类（`favorite_categories`），每类显示区段标题（类名）+ 该类 L2 风格 chip（多选）。chip 列表取自 `TemplatesDao.getStylesForType(category)`。切换 chip 时写/删 `favorite_styles` 集合；取消某大类时一并清掉其下已选风格。需要用 `TemplatesDao`，建议从 provider 注入。
- **`questionnaire_answers.dart`**：`QuestionnaireAnswers` 新增 `favoriteStyles`（`List<String>`，默认 `[]`）；补 `fromJson`/`toJson`/`copyWith`。
- **`questionnaire_sync_service.dart`**：上报后端时**剥离 `favorite_styles` 字段**（仅本地，用户已确认），payload 仍只含 `favorite_categories` 等既有字段。

> 性别问题已存在（id `gender`，`male/female/prefer_not`），无需新增，只需让推荐读取它。

### 2. 推荐算法（`recommendation_service.dart`，slot 1 新老用户分支）

新增两个局部工具函数：
- `String? _secondaryStyleOf(TemplateRecord t)` = `t.classification['majorStyle'] ?? t.classification['style']`。
- 性别分组：读 `_questionnaireDao.getAnswers()?.gender`；`null`/`prefer_not` 视为中性（不分组）。否则把候选模板分成「性别匹配（`t.gender == userGender` 或 `t.gender == 'unisex'`）」与「其余」，**匹配组优先**，组内仍用现有 `_pickBest`（热度×0.5 + 兴趣×0.5）排序；匹配组为空时自然回退到其余组 → 满足「软偏好、永不空槽」。

**新用户分支**（现 L154-196）：
- 目标大类 `topCat` = `questionnaire.favoriteCategories.first`（不变）。
- 候选 = `getBuiltin(category: topCat, isRecommended: true)`。
- 若 `questionnaire.favoriteStyles` 非空 → 过滤为 `_secondaryStyleOf(tpl) ∈ favoriteStyles`；过滤后为空则回退整类。
- 性别分组 + 组内 `_pickBest`，取整体第一条。

**老用户分支**（现 L197-251）：
- 目标大类 `topCategory` = `countByCategory` 最高（不变）。
- 确定偏好风格集合：
  - 问卷 `favoriteStyles`（若存在，且该风格在当前大类候选中有对应模板才算数）；
  - 叠加「该大类下用户拍得最多的模板」的 `_secondaryStyleOf`（用 `_galleryDao.countByTemplate()` 计数 + 候选池/`getBuiltin` 反查模板 classification）。取 counts 最大、且在候选内的模板风格。
- 候选 = `getBuiltin(category: topCategory, isRecommended: true)`，先过滤 `_secondaryStyleOf ∈ 偏好风格集合`；为空回退整类。
- 性别分组 + 组内 `_pickBest`，文案 tag 沿用「常拍分类」。

> 注：`_loadRecentlyUsedTemplateIds()` 已将 `countByTemplate()` 当 keys 用；此处改为保留完整 counts 供老用户偏好风格推断，其它逻辑不变。

### 3. 复用与不变量

- 复用：`getBuiltin()`、`_pickBest()`、`_rankCandidates()`、`_blendScore()`、`_truncate()`、`getStylesForType()`。
- 不引入新 DB 表/列；`favorite_styles` 仅存在于问卷 JSON blob 内。
- 不触碰其他槽位（slot0/2/3）、挑战推荐、后端。

## 验证

1. `flutter analyze lib/features/home lib/features/onboarding` 无新增 error（原 1 条无关 info 可忽略）。
2. `flutter test test/features/home` 与 `flutter test test/features/onboarding`（如有）通过。
3. 手工（可选，若跑得起来）：新用户填问卷选「人像」+ 某个二级风格 → 首页第 2 槽位应落到该风格模板；老用户常拍 human 大类下某风格 → 命中同风格模板；性别软偏好不产生空槽。
4. 回归：未填问卷 / 性别 `prefer_not` 时，槽位表现与原逻辑一致（回退整类、中性分组）。

## 提交

Flutter 端改动：本地 commit 后 `git push origin master && git push github master`（与仓库惯例保持一致）。