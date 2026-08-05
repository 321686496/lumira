# 探店打卡（checkin）功能 — 交接文档（未完成部分）

> 本文档记录「灵感页探店打卡卡片真实功能化」需求的**剩余未完成工作**，供后续开发者接手。
> 编写日期：2026-08-05 ｜ 当前分支：`master`（origin/master 领先 16 个提交，含本功能 Task 1/2）

---

## 一、需求背景

灵感页「探店打卡」卡片原为静态 mock（`CheckinEntry` 3 条假数据 + 硬编码总数 23，无点击交互）。
目标：实现真实功能闭环 —— 双表本地存储（sqflite）+ 列表/详情/新增编辑三页 + 相册照片详情入口预填 + 卡片真实数据接入。

**设计文档：** `docs/superpowers/specs/2026-08-05-checkin-design.md`
**实施计划：** `docs/superpowers/plans/2026-08-05-checkin.md`（6 个 Task，后续任务实现细节以计划为准）

## 二、已完成（2/6 任务，已提交）

| 任务 | 提交 | 内容 |
|---|---|---|
| Task 1 数据层 | `0f95aeb` | checkins/checkin_photos 两表 + v16 迁移（_onCreate+_onUpgrade 双路径）+ CheckinRecord/ListItem/Detail 模型 + 7 分类表 + CheckinDao（8 方法）+ 4 个 provider + DAO 测试 8/8 |
| Task 2 共享小部件 | `d2cd0e3` | `lib/features/checkin/widgets/checkin_common.dart`：CheckinRatingStars、CheckinCategoryTag、formatCheckinDate、CheckinPhotoImage |

另外：`RouteNames` 4 个常量（`checkinList`/`checkinDetail`/`checkinEdit`/`paramCheckinId`）已在 `route_names.dart` 加入（本交接提交中包含）。

## 三、未完成清单

### 1. Task 3 收尾：列表页测试修复（1 例失败）

- 文件已实现于工作区（随本交接提交）：`lib/features/checkin/pages/checkin_list_page.dart` + `test/features/checkin/checkin_list_page_test.dart`
- 当前测试状态：**3 例中 2 例通过**（空态显示引导、空态点击跳新增），1 例失败：
  - 「列表渲染足迹与总数」失败原因：`setUp` 中预解析 `checkinsProvider` 后缓存了**空结果**，用例内 `seed(n: 3)` 插入数据后 provider 未失效，页面仍显示空态。
- **修复方法**（在 `checkin_list_page_test.dart` 的该用例内，`seed` 之后、`pumpWidget` 之前补两行）：

```dart
await seed(n: 3);
container.invalidate(checkinsProvider);
container.invalidate(checkinTotalCountProvider);
await preload(); // preload() 已在测试文件中定义
```

- 修复后验证：`cd lumira_app_flutter && flutter test test/features/checkin/checkin_list_page_test.dart`（3 例全过）

### 2. Task 4：足迹详情页 `CheckinDetailPage` + 测试（未开始）

- 新建 `lib/features/checkin/pages/checkin_detail_page.dart` + `test/features/checkin/checkin_detail_page_test.dart`
- 要点（详见计划 Task 4）：
  - `CheckinDetailPage({super.key, this.checkinId})`（String? 可空，仿 GalleryDetailPage）
  - watch `checkinDetailProvider(id)`；`checkinId` 为空或记录不存在 → 显示「足迹不存在或已删除」
  - 照片墙 4:3 横向（`CheckinPhotoImage`）；`_InfoRow` 展示店名/地点/分类/日期/评分/心得
  - AppBar 编辑入口（`Icons.edit_outlined`）→ push `checkinEdit?checkinId=$id`；删除（`Icons.delete_outline`）→ 确认弹窗 → `dao.delete` → invalidate 三个 provider → LumiraToast → `context.pop()`
- 测试参考：`test/features/gallery/gallery_detail_page_test.dart`（FfiNoIsolate + 预解析 + 视口 + GoRouter 双路由）

### 3. Task 5：新增/编辑页 `CheckinEditPage` + 测试（未开始）

- 新建 `lib/features/checkin/pages/checkin_edit_page.dart` + `test/features/checkin/checkin_edit_page_test.dart`
- 要点（详见计划 Task 5）：
  - 表单：店名（必填校验）/ 地点 / 日期选择器 / 5 星点选（可清零）/ 7 分类单选 / 心得多行 / 照片 1-9 张
  - 构造参数 `checkinId`（编辑预填）与 `photoId`（相册入口预填，作为首张照片）
  - 保存：insert 或 update + `replacePhotos` + invalidate 三个 provider + toast + pop
  - 照片选择：70% 高底部 sheet + 4 列 grid + maxCount 上限（仿 profile_collection_edit_page）
- 代码量最大，注意分段实现

### 4. Task 6：接线（路由注册 + 卡片接入 + 相册入口 + mock 清理）（未开始）

- `router.dart` 注册 3 个 GoRoute（`/checkin/list`、`/checkin/detail?checkinId=`、`/checkin/edit?checkinId=|photoId=`），仿 scenes/挑战路由写法
- `lib/features/inspiration/widgets/checkin_card.dart` 改真实 provider：最近 3 条 + 总数 + 空态引导（点击 → checkinList）
- `lib/features/gallery/pages/gallery_detail_page.dart` 的 `_MoreAction` 加「记录探店」选项（result=='checkin' → push checkinEdit 带 photoId）
- `test/features/inspiration/inspiration_page_test.dart` 更新：DB 注入 + seed 3 条 checkin + 断言更新
- 移除 `inspiration_mock_data` 中的 checkin mock

### 5. 最终验证 + 整体审查

- `flutter analyze` 0 error + `flutter test` 全量通过
- whole-branch review，处理台账中记录的 Minors（见下文第五节）

## 四、接手必读（技术要点）

1. **主项目**：`lumira_app_flutter/`（Flutter 3.7.12 / Dart 2.19.6，**禁止 records 语法**）；uni-app `lumira-app/` 已废弃，**禁止修改**
2. **数据库**：当前 `_kDbVersion = 16`；新增表必须同时在 `_onCreate`（全量 batch）与 `_onUpgrade`（增量 try/catch 幂等）两处加
3. **数据流**：FutureProvider 三层（DAO → Provider → 页面 watch）；写操作走 `ref.read(checkinDaoProvider.future)` + `ref.invalidate(...)`
4. **测试坑**（必读）：
   - 必须 `databaseFactory = databaseFactoryFfiNoIsolate;`（isolate 版在 FakeAsync 中 future 不 resolve 导致 pumpAndSettle 超时）
   - `ProviderContainer` 预解析依赖的 provider future（loading 态 `LumiraProgress.circular()` 是无限动画，会拖垮 pumpAndSettle）
   - 视口：`physicalSizeTestValue = Size(800, 1400)` + `devicePixelRatioTestValue = 1.0`
5. **UI 范式**：`LumiraNav` 标题栏（非 tab 页默认返回按钮）、`FadeUp` 入场、`NeuCard` 卡片、`ThemeTokens` 颜色、`LumiraToast`/`LumiraButton`/`LumiraProgress`
6. **任务 brief**：`.superpowers/sdd/task-3-brief.md` 已生成（Task 4/5/6 的 brief 可参照计划文件按需生成：`.trae/skills/subagent-driven-development/scripts/task-brief docs/superpowers/plans/2026-08-05-checkin.md N`）

## 五、风险与注意事项

1. **并发会话 WIP 勿动**：工作区存在其他功能（templates/backend/profile-edit）的未提交改动（`templates_dao.dart`、`remote_templates_providers.dart`、`lumira-server/packages/backend/` 等），与本功能无关，**不要 stage/提交/回滚它们**
2. **`cankaociios/` 目录**：iOS 打包参考资料（GitHub Actions 指南），**不应提交**，提交时忽略
3. **台账 Minors**（`.superpowers/sdd/progress.md`，最终 review 时 triage）：
   - Task 1：测试 2 个 info lint、provider N+1 照片查询（计划内，数据量小可接受）、fromRow 空值分支未测
   - Task 2：空 url 占位绕过 ClipRRect（直角 vs 圆角不一致）、CheckinPhotoImage 文档注释与实现（dataUrl 前缀走文件分支，实际 dataUrl 字段存 http URL，可接受）、CheckinCategoryTag 的 tokens 参数未在 build 使用（brief 规定签名）
4. **本交接提交中的测试**：`checkin_list_page_test.dart` 存在第三节第 1 条所述 1 例失败，接手后先修该例再继续

## 六、交付物索引

| 文件 | 说明 |
|---|---|
| `docs/superpowers/specs/2026-08-05-checkin-design.md` | 设计规格 |
| `docs/superpowers/plans/2026-08-05-checkin.md` | 实施计划（3423 行，6 Task 全量） |
| `.superpowers/sdd/progress.md` | 进度台账（含各 Task 审查结论与 Minors） |
| `.superpowers/sdd/task-3-brief.md` | Task 3 brief（已完成部分） |
| `lumira_app_flutter/lib/features/checkin/` | checkin 模块代码（data/ + widgets/ 已完成，pages/ 部分完成） |
| `lumira_app_flutter/test/features/checkin/` | checkin 测试（dao 全过，列表页 2/3 过） |
