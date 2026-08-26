# Task 1: 抽取共享模板网格组件并回接全部模板页

> 项目：Flutter 客户端 `lumira_app_flutter/`（模板收藏功能扩展）。所有命令在 `lumira_app_flutter/` 目录下执行。
> 分支：feat/template-favorite（当前 head `260939f1`）。只 commit，不 push。

**Files:**
- Create: `lib/features/templates/widgets/template_grid.dart`
- Modify: `lib/features/templates/pages/templates_all_page.dart`

**Interfaces:**
- Consumes: `AllTemplateItem` 与 `TemplatesBrowseMockData`（定义于 `lib/features/templates/data/templates_browse_mock_data.dart`）；`TemplateRecord`（`core/db/dao/templates_dao.dart`）；`TemplateMapper`（`../services/template_mapper.dart`）；`NeuCard`（`shared/widgets/cards/neu_card.dart`）；`TemplateCoverImage` 与 `AmbienceBadges`（`../widgets/...`）；`FadeUp`（`shared/widgets/common/fade_up.dart`）；`ThemeTokens`（`core/theme/theme_tokens.dart`）。
- Produces: 公共 `templateGridItemFromRecord(TemplateRecord, {required bool isCustom}) → AllTemplateItem`、`TemplateGrid`（瀑布流双列）、`TemplateCard`、`truncate(String, {int maxLen})`。

## 目标

把 `templates_all_page.dart` 中**私有的模板网格/卡片渲染代码原样迁到新共享文件并公开命名**（去掉 `_` 前缀），全部模板页改为 import 该文件、删除本地私有副本。**渲染逻辑逐字不变，仅改类名/函数名与 import。**

## 迁移清单（从 `templates_all_page.dart`）

以下私有成员迁入 `template_grid.dart`，去 `_` 前缀公开命名：
- `_recordToItem`（`:1782`）→ `templateGridItemFromRecord`
- `_truncate`（`:1806`）→ `truncate`
- `_TemplateGrid`（`:1006`，含其 `_estimateCardHeight:1020`）→ `TemplateGrid`
- `_TplCard`（`:1073`）→ `TemplateCard`
- `_FreeBadge`（`:1255`）→ 一并迁入（可保持私有 `_FreeBadge` 或公开 `FreeBadge`，随你；若留在 `template_grid.dart` 则与 `_PremiumBadge` 一样 保持 `_` 前缀即可，仅 `TemplateGrid`/`TemplateCard` 需公开）
- `_PremiumBadge`（`:1280`）→ 同上

新文件需 import `AllTemplateItem`、`TemplatesBrowseMockData`（用于 `categoryLabel`）、`TemplateRecord`、`TemplateMapper`、`NeuCard`、`TemplateCoverImage`、`AmbienceBadges`、`FadeUp`、`ThemeTokens`、`go_router`、`material`、`flutter_riverpod`（如 `TemplateGrid`/`TemplateCard` 用到）。**以实际引用补全 import，不要多引入。**

## Step

- [ ] **Step 1: 新建 `template_grid.dart`**

把上面列出的私有代码迁入并改成公共命名，补齐 import。**逻辑逐字保留**（瀑布流双列、3:4 封面、免费/付费徽标、已拍 N 张、氛围徽标、自定义标签等）。

> `_TplCard` 的 `onTap` 详情跳转沿用 `/templates/detail?templateId=${template.id}`（或 `RouteNames.withTemplateId(RouteNames.templatesDetail, template.id)`，与原一致即可）。命名统一后在 `templates_all_page.dart` 调用处同步。

- [ ] **Step 2: 回接 `templates_all_page.dart`**

- 删除文件内 `_recordToItem`、`_truncate`、`_TemplateGrid`、`_estimateCardHeight`、`_TplCard`、`_FreeBadge`、`_PremiumBadge` 的定义。
- 新增 import：`import '../widgets/template_grid.dart';`（保留既有 `templates_browse_mock_data.dart` import 以继续使用 `AllTemplateItem` 类型）。
- 调用点改用公共命名：
  - `_recordToItem(` → `templateGridItemFromRecord(`
  - `_TemplateGrid(` → `TemplateGrid(`
  - `_TplCard(` → `TemplateCard(`
  - 若 `_truncate` 在本文件被 `_TplCard` 之外使用，改用 `truncate`（否则随迁移消失）。

- [ ] **Step 3: analyze**

Run: `flutter analyze lib/features/templates/widgets/template_grid.dart lib/features/templates/pages/templates_all_page.dart`
Expected: 无新增 error/warning。

- [ ] **Step 4: 既有测试**

Run: `flutter test test/features/templates`
Expected: `templates_all_page_test.dart` 相关用例仍通过。**若测试引用了私有类名或布局断言受影响，按实际情况把测试中引用更新为公共命名。**

- [ ] **Step 5: Commit**

```bash
git add lib/features/templates/widgets/template_grid.dart lib/features/templates/pages/templates_all_page.dart
git commit -m "refactor(templates): 抽取共享模板网格组件"
```

> 提交前确认 git status 暂存仅含这两个文件。**只 commit，不 push。**

若抽取后发现 `templates_all_page_test.dart` 因私有类改名而大面积失败，报告时说明受影响范围与你的处理方式（是同步测试命名，还是保留某些类为本文件私有）。