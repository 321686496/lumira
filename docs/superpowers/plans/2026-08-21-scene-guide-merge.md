# 场景灵感页并入场景库 — 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 删除冗余的 `CaptureSceneGuidePage`（场景灵感页），将其全部入口收敛到场景库 `ScenesPage`（大全浏览）或直达 `CaptureSceneDetailPage`（场景详情开拍），消除"场景灵感页 / 场景库"双落地心智冲突。

**Architecture:** 两套并行场景展示中，场景库页 `ScenesPage` 已使用真实数据库 + 联网同步 + 搜索 + 新建 + 事件上报（更完整），场景灵感页 `CaptureSceneGuidePage` 仅基于 mock 列表 + 两层 pill + 标签筛选（旧实现）。方案：**删除场景灵感页**；所有 `captureSceneGuide` 深链入口改为**直达场景详情** `captureSceneDetail?sceneId=X`；无场景参数的大全入口改跳场景库 `scenes`。统一后用户心智只剩"场景详情（去拍）"与"场景库（大全）"两个场景页面。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6, GoRouter 6.5.7, flutter_riverpod。

## Global Constraints

- **Dart 2.19.6**：禁止 Dart 3 records 语法。
- 深链从 `?scene=X`（场景灵感页参数）统一改为 `?sceneId=X`（`RouteNames.withSceneId(RouteNames.captureSceneDetail, id)`），沿用现有 `captureSceneDetail` 路由与 `CaptureSceneDetailPage(sceneId:)` 签名，**不新增场景库深链逻辑**。
- 仅 `ScenesPage` 保留为全场景大全页；`captureSceneManage`（管理/收藏/自建）与 `captureSceneDetail`（详情/开拍）路由均保留不动。
- 所有主题/风格仍走 `appThemeProvider`，不改任何视觉样式。
- 测试使用 TDD：先改/删测试令其红，再改源码令其绿。
- 删除内容必须是全量引用清除（`RouteNames.captureSceneGuide`、`paramScene`、路由注册、页面文件、测试文件），确保 `flutter analyze` 零错误。

---

### Task 1: 删除场景灵感页及路由

删除页面、路由注册、路由常量，并清理全部引用后发布（本任务先删源，编译报错由 Task 2–5 逐一修复）。

**Files:**
- Delete: `lumira_app_flutter/lib/features/capture/pages/capture_scene_guide_page.dart`
- Delete: `lumira_app_flutter/test/features/capture/capture_scene_guide_page_test.dart`
- Modify: `lumira_app_flutter/lib/core/router/route_names.dart`
- Modify: `lumira_app_flutter/lib/app/router.dart`

**Interfaces:**
- Consumes: 无（纯删除）。
- Produces: 移除 `RouteNames.captureSceneGuide`、`RouteNames.paramScene`；剩余对它们的引用即为 Task 2–5 待修点。

- [ ] **Step 1: 删除场景灵感页源码与测试文件**

删除：
- `lib/features/capture/pages/capture_scene_guide_page.dart`
- `test/features/capture/capture_scene_guide_page_test.dart`

- [ ] **Step 2: 从 `route_names.dart` 删除两个不再需要的常量**

在 `lumira_app_flutter/lib/core/router/route_names.dart` 中删除：
- 第 17 行 `static const String captureSceneGuide = '/capture/scene-guide';`
- 第 88 行 `static const String paramScene = 'scene';`

> 确认 `paramScene` 无其他引用（现有引用全部经由 `RouteNames.build(RouteNames.captureSceneGuide, {RouteNames.paramScene: ...})`，Task 2–5 会全部改写为 `withSceneId(captureSceneDetail, ...)`，改写后即可安全删除）。

- [ ] **Step 3: 从 `router.dart` 删除 captureSceneGuide 路由注册**

在 `lumira_app_flutter/lib/app/router.dart` 删除以下 GoRoute 块（约 159–167 行）：

```dart
      GoRoute(
        path: RouteNames.captureSceneGuide,
        name: 'captureSceneGuide',
        builder: (context, state) {
          // 接收 scene 参数（uni-app: /pages/capture/scene-guide?scene=xxx）
          final scene = state.queryParams[RouteNames.paramScene];
          return CaptureSceneGuidePage(scene: scene);
        },
      ),
```

同时确认该文件头部 `import 'features/capture/pages/capture_scene_guide_page.dart'` 已被移除（若有）。

- [ ] **Step 4: 运行 `flutter analyze` 定位剩余引用**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 列出对 `RouteNames.captureSceneGuide` / `CaptureSceneGuidePage` / `RouteNames.paramScene` 的残余引用（Task 2–5 处理）。

---

### Task 2: 首页场景推荐深链改为直达场景详情

**Files:**
- Modify: `lumira_app_flutter/lib/features/home/pages/home_page.dart:91-100`

**Interfaces:**
- Consumes: `RouteNames.captureSceneDetail`、`RouteNames.withSceneId`、`RouteNames.paramSceneId`。
- Produces: `_goSceneGuide(sceneId)` 改为直达场景详情；签名与方法名保留（调用方不变）。

- [ ] **Step 1: 改写 `_goSceneGuide`**

将 `home_page.dart` 中约 91–100 行的 `_goSceneGuide` 改为：

```dart
  void _goSceneGuide(String sceneId) {
    // 场景卡片深链直达场景详情（场景灵感页并入场景库后的统一落点）
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId),
    );
  }
```

（删除原方法体内的 `RouteNames.build(RouteNames.captureSceneGuide, {RouteNames.paramScene: sceneId})`，以及顶部为兼容旧规则加的注释说明。）

- [ ] **Step 2: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/features/home/home_page_test.dart`
Expected: 若该测试仍注册 `captureSceneGuide` 路由桩且断言其触发，会失败 —— 由 Task 6 统一修正测试桩。

---

### Task 3: 灵感页深链改为直达场景详情

**Files:**
- Modify: `lumira_app_flutter/lib/features/inspiration/pages/inspiration_page.dart:22-29`（`_goSceneGuide` 与 `_defaultSceneForSlot`）

**Interfaces:**
- Consumes: `RouteNames.captureSceneDetail`、`RouteNames.withSceneId`。
- Produces: 引导条与"今日可拍"场景卡片均直达场景详情；`_goSceneGuide(context, sceneId)` 签名保留。

- [ ] **Step 1: 改写 `_goSceneGuide`**

将 `inspiration_page.dart` 中约 22–29 行改为：

```dart
  void _goSceneGuide(BuildContext context, String sceneId) {
    GoRouter.of(context).push(
      RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId),
    );
  }
```

- [ ] **Step 2: 确认"查看全部场景"仍指向场景库**

`inspiration_page.dart:93` 的 `onMoreScenes: () => GoRouter.of(context).push(RouteNames.scenes)` 保持不变（这就是合并后的大全入口）。

- [ ] **Step 3: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/features/inspiration/inspiration_page_test.dart`
Expected: 失败于 `captureSceneGuide` 路由桩缺失/断言 —— Task 6 修正。

---

### Task 4: 拍摄小课堂 CTA 深链改为直达场景详情

**Files:**
- Modify: `lumira_app_flutter/lib/features/inspiration/pages/tutorial_detail_page.dart:282-285`

**Interfaces:**
- Consumes: `TutorialCtaType.scene`、`cta.targetId`、`RouteNames.captureSceneDetail`、`RouteNames.withSceneId`。

- [ ] **Step 1: 改写 CTA 分派**

将 `tutorial_detail_page.dart` 中原 `else`/scene 分支改为：

```dart
        if (cta.type == TutorialCtaType.scene) {
          GoRouter.of(context).push(
            RouteNames.withSceneId(RouteNames.captureSceneDetail, cta.targetId),
          );
        } else {
          GoRouter.of(context).push(RouteNames.withTemplateId(RouteNames.templatesDetail, cta.targetId));
        }
```

（即把 `tutorial.cta` 的场景目标改为直达场景详情。）

- [ ] **Step 2: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/features/inspiration/tutorial_detail_page_test.dart`
Expected: PASS（该测试不校验路由桩，仅校验按钮渲染/回调间接路径；若引用旧常量则更新之）。

---

### Task 5: 场景管理页"查看场景"入口改跳场景库

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_scene_manage_page.dart:79-81`

**Interfaces:**
- Consumes: `RouteNames.scenes`。
- Produces: `_goGuide()` 无场景参数 → 跳场景库大全 `scenes`。

- [ ] **Step 1: 改写 `_goGuide`**

将 `capture_scene_manage_page.dart` 中约 79–81 行改为：

```dart
  void _goGuide() {
    // 管理页"查看场景"统一进入场景库大全（场景灵感页已并入）
    GoRouter.of(context).push(RouteNames.scenes);
  }
```

- [ ] **Step 2: 运行测试**

Run: `cd lumira_app_flutter && flutter test test/features/capture/capture_scene_manage_page_test.dart`
Expected: 失败于 `captureSceneGuide` 路由桩缺失 —— Task 6 修正。

---

### Task 6: 更新受影响的测试桩与断言

**Files:**
- Modify: `lumira_app_flutter/test/core/router/router_test.dart`
- Modify: `lumira_app_flutter/test/features/home/home_page_test.dart`
- Modify: `lumira_app_flutter/test/features/inspiration/inspiration_page_test.dart`
- Modify: `lumira_app_flutter/test/features/capture/capture_scene_manage_page_test.dart`
- Modify: `lumira_app_flutter/test/features/capture/capture_page_test.dart`

**Interfaces:**
- Consumes: 无（只改测试桩/断言）。
- Produces: 全量测试通过；`flutter analyze` 零错误。

- [ ] **Step 1: 更新路由桩**

对上述测试文件里凡出现 `path: RouteNames.captureSceneGuide` / `name: 'captureSceneGuide'` / 返回 `CaptureSceneGuidePage(scene: scene)` 的路由桩，统一改为 `RouteNames.captureSceneDetail` + 返回 `const CaptureSceneDetailPage()`（`capture_scene_detail_page.dart` 的构造为 `CaptureSceneDetailPage(sceneId: sceneId)`；测试桩可用 `const CaptureSceneDetailPage()`）。若桩中引用了 `captureSceneGuide` 常量，一并替换。

以 `test/features/capture/capture_scene_manage_page_test.dart` 约 56–58 行为例：

```dart
GoRoute(
  path: RouteNames.captureSceneDetail,
  name: 'captureSceneDetail',
  builder: (context, state) => const CaptureSceneDetailPage(),
),
```

（`router_test.dart` 中 `captureSceneGuide` 全局路由断言改为 `captureSceneDetail`；`capture_page_test.dart:92` 同理。）

- [ ] **Step 2: 核对各测试语义断言**

- `home_page_test.dart`：若断言"点击场景卡 → 跳转 captureSceneGuide"，改为断言跳转 `captureSceneDetail`（携带 `sceneId`）。
- `inspiration_page_test.dart`：若断言"点击今日可拍 → 跳转 captureSceneGuide"，改为断言跳转 `captureSceneDetail`；"查看全部场景 → scenes"断言保留。
- 删除 `test/features/capture/capture_scene_guide_page_test.dart`（Task 1 已删）。

- [ ] **Step 3: 全量验证**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 零错误、零 warning。

Run: `cd lumira_app_flutter && flutter test`
Expected: 全部通过。

---

## Self-Review

**Spec 覆盖：**
- 删除场景灵感页（页面+路由+常量）：Task 1 ✓
- 首页场景卡深链直达详情：Task 2 ✓
- 灵感页引导条/今日可拍深链直达详情：Task 3 ✓
- 拍摄小课堂 CTA 直达详情：Task 4 ✓
- 场景管理页无参入口跳场景库：Task 5 ✓
- 测试桩/断言同步 + analyze/test 全绿：Task 6 ✓
- "查看全部场景"（`scenes`）与"场景库大全"保留：Task 3/5 确认 ✓

**类型一致性：** 深链统一用既有 `RouteNames.withSceneId(RouteNames.captureSceneDetail, sceneId)`（`paramSceneId`），与 `CaptureSceneDetailPage(sceneId:)` 及 `router.dart:184-186` 解析一致；未引入新参数、新路由。

**已知取舍（已与用户确认）：** 场景灵感页独有的"两层 pill 分类 + 标签 chip 筛选 + 成就 Lv 徽章"列表形态一并移除，不并入场景库；合并后场景浏览统一为场景库的分类概览/网格形态。此为本轮明确决策，不做平方外扩展。