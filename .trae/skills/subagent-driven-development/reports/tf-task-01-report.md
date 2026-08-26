# Task 1 执行报告：数据层 — 模板收藏持久化

> 状态：**DONE**
> Branch: `feat/template-favorite` | Commit: `73954cf86798e68e49f9be143356a0cd2ab39fe6`
> 遵循简报 `tf-task-01-brief.md` 原样代码，Step1–8 全部完成，只 commit 未 push。

## 改动文件（本次 commit 涉及 3 个文件，99 insertions / 1 deletion）

1. **`lumira_app_flutter/lib/core/db/tables.dart`**（修改）
   - Step 1：在 `Tables` 类 `custom_templates` 段紧跟 `colUpdatedAt` 后新增常量
     `templateFavorites = 'template_favorites'`，并附 v42 说明注释（复用 `colId`/`colCreatedAt`）。

2. **`lumira_app_flutter/lib/core/db/dao/templates_favorite_dao.dart`**（新建）
   - Step 2：`TemplatesFavoriteDao`，构造 `TemplatesFavoriteDao(Database _db)`。
   - 方法：`isFavorite` / `addFavorite`(ConflictAlgorithm.replace) / `removeFavorite` /
     `toggleFavorite`(返回切换后收藏态) / `getFavoriteIds`(created_at DESC) / `countFavorites`。
   - 模板 id 为主键，覆盖全来源（builtin/custom/remote）。

3. **`lumira_app_flutter/lib/core/db/database_provider.dart`**（修改）
   - Step 3：`_kDbVersion` 41 → **42**；import 区新增 `dao/templates_favorite_dao.dart`。
   - Step 4：`_onCreate` 的 `custom_templates` 段 `idx_custom_templates_source` 之后、
     `template_categories` 之前，新增 `CREATE TABLE IF NOT EXISTS template_favorites`（batch 内）。
   - Step 5：`_onUpgrade` 末尾 `oldVersion < 41` 块之后追加 `oldVersion < 42` 块，
     `CREATE TABLE IF NOT EXISTS` + `try/catch(debugPrint 静默降级)`，幂等。
   - Step 6：`templatesDaoProvider` 之后新增 `templatesFavoriteDaoProvider`
     （`FutureProvider<TemplatesFavoriteDao>`）。

## Step 7 — analyze 实际输出

命令在 `lumira_app_flutter/` 下执行：`flutter analyze lib/core/db`

```
Analyzing db...
No issues found! (ran in 30.1s)
```

**结果：无新增 error / warning。**（执行时自动跑了 `flutter pub get`，无报错）

## Step 8 — Commit

暂存内容确认仅含上述 3 个文件（`git status --short` 仅 `A/M` 以上三个目标文件）：
- `A  lib/core/db/dao/templates_favorite_dao.dart`
- `M  lib/core/db/database_provider.dart`
- `M  lib/core/db/tables.dart`

提交信息：`feat(templates): 新增模板收藏表与 Tv42 迁移及 DAO`
**Commit hash：`73954cf86798e68e49f9be143356a0cd2ab39fe6`**

**只 commit，未 push。**

## 顾虑 / 备注

- 工作区存在与本任务无关的脏文件（未暂存/未提交）：`lib/features/gallery/pages/gallery_monthly_digest_page.dart`、`pubspec.yaml`（modified），以及若干 untracked 文件（含 `.trae/` 简报、`docs/` 设计文档、`.idea/`、临时 har 文件）。按简报要求，本次只处理 3 个目标文件，未混入这些无关改动。
- 新增表未加索引（若后续按 created_at 查询频繁可补 `idx_template_favorites_created_at`），但简报未要求，遵循"原样使用、不过度设计"原则未添加。