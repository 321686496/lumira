# 摄影美学院收藏功能完善 — 实现报告

> 报告日期：2026-08-19
> 实现计划：`docs/superpowers/plans/2026-08-19-academy-favorites.md`
> 依赖分支状态：所有改动提交于当前检出分支 `feature/experience-tier`

## 总览

按计划 Task 1 → Task 6 顺序全部完成。每个 Task 独立提交一次，每次 `flutter analyze` 均 **无新增 error**。

| Task | 内容 | Commit（短哈希） | `flutter analyze` |
|---|---|---|---|
| 1 | 数据层：课程收藏表 + DAO 方法 | `4b42238` | 无新增 error |
| 2 | 仓储层：Repository 课程收藏方法 | `028c6b3` | 无新增 error |
| 3 | Provider 层：课程收藏 provider + 通知器 | `5844f02` | 无新增 error |
| 4 | 课程详情页：假收藏改为持久化爱心收藏 | `88bf290` | 无新增 error |
| 5 | 新总览页 + 路由 + 学院首页入口 | `06d7ef0` | 无新增 error |
| 6 | 全量验证 | —（无代码改动） | 0 error |

共 6 次提交，其中 Task 1–5 各一次，Task 6 无遗漏文件需提交。

## 逐 Task 验证结果

- **Task 1** `4b42238`：新增 `academy_course_favorite` 表常量/`cfCreateSql`，`_onCreate` 注册建表，`_onUpgrade` 新增 `<25` 分块，`_kDbVersion` 24→25；`AcademyDao` 新增 `isCourseFavorited` / `getFavoriteCourseIds` / `addCourseFavorite` / `removeCourseFavorite`。analyze：无 error。
- **Task 2** `028c6b3`：抽象接口 + `LocalAcademyRepository` 各新增 3 个课程收藏方法。analyze：无 error。
- **Task 3** `5844f02`：新增 `favoriteCourseIdsProvider`，`AcademyActionNotifier.toggleCourseFavorite`，`_refresh()` 中补 invalidate。analyze：无 error。
- **Task 4** `88bf290`：删除 `_bookmarked`/`_toggleBookmark`，AppBar 爱心按钮改走 `favoriteCourseIdsProvider` + `toggleCourseFavorite`。analyze：无 error。
- **Task 5** `06d7ef0`：新建 `academy_favorites_page.dart`；新增 `RouteNames.academyFavorites`；`router.dart` 注册 GoRoute；`academy_page.dart` 右上加入口图标。analyze：无 error。
- **Task 6**：全量 `flutter analyze` 结果为 **0 error**（348 条 issue 均为既有 info/warning 级 lint，主要位于 `test/`）。手工路径（Task 6 Step 2 的 5 条）需要真机/模拟器，本次未执行。

## 与计划的偏差

1. **`academy_favorites_page.dart` 的 `const` 笔误（必须修正）**：计划 Task 5 Step 2 中 `loading: () => const Center(child: LumiraProgress.circular()),` 会触发 `const_with_non_const` **error**（`LumiraProgress.circular` 是 factory 构造器，非 const）。为满足「无新增 error」，已去掉 `const`，改为与项目内其他 19 处用法一致的 `loading: () => Center(child: LumiraProgress.circular()),`。

2. **`router.dart` import 位置（微调，逻辑等价）**：计划指示把 import 放在 `academy_trajectory_page.dart` 之后，但按字母序应置于 `academy_knowledge_page.dart` 之前（即当前写法），以避免 import 顺序 lint。属纯位置微调，功能一致。

3. **计划中行号/锚点的偏差**：计划标注的部分行号（如 academy_dao L200-231、provider L138-141 等）与磁盘实际基本一致，按实际结构就近插入，逻辑与计划一致。详见各 Task 复核。

## 已发现的问题 / 顾虑

1. **工作区存在并发的「经验等级(experience-tier)」开发**：执行期间工作区被另一进程/开发者并行修改，且：
   - 两次回滚掉我的中间改动（`academy_detail_page.dart` 的 `isFav` 块、`router.dart` 的 GoRoute），我均重新补插并最终核验读写一致；
   - 并发修改与我有重叠的文件 `academy_repository.dart`、`academy_providers.dart`（同为我要改的文件），并一度在 `capture_page.dart` 制造未完成的 `awardAndClaim`/`utc8DateStr` 两个 error——这些均非本任务产生，我未合并其工作、也未提交其改动，最终这些并发改动由对方自行提交并消除。
2. **提交落在 `feature/experience-tier` 分支**（并非 master）。与 `AGENTS.md` 中「后端改动需 push 两远程」无关（本次为纯 Flutter 本地改动），但请注意当前检出的分支名。
3. **`flutter analyze` 无法达到 0 issues**：仓库基线即有 347–348 条 info 级 lint（多为 `test/` 下的 pre_const / unused_import / unnecessary_import 等），本功能仅新增 1 条 `unnecessary_non_null_assertion` 警告（`academy_detail_page.dart:91`，来自计划字面的 `academyId!` 在 `if (academyId == null) return;` 守卫之后触发，非 error）。符合计划「无新增 error」的门禁。
4. **手工验收路径未执行**：涉及收藏持久化、总览页空态/导航等运行时行为，需在真机/模拟器上验证（计划 Task 6 Step 2）。建议后续补跑该 5 条验证。