# Task 1: 模块化迁移（目录迁移 + 引用更新）

**Files:**
- Move: `lumira_app_flutter/lib/features/capture/watermark/` → `lumira_app_flutter/lib/features/watermark/`（内部 10 个文件整体迁移，`models/`、`data/`、`services/`、`pages/`、`widgets/` 结构不变）
- Modify: `lumira_app_flutter/lib/app/router.dart:16-17`（import 路径）
- Modify: `lumira_app_flutter/lib/core/db/dao/watermark_dao.dart:6`（import 路径）
- Modify: `lumira_app_flutter/lib/core/db/dao/settings_dao.dart:8`（import 路径）
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（import 路径，37-39 行）
- Modify: `lumira_app_flutter/lib/features/profile/pages/profile_settings_page.dart`（import 路径，15 行）

**Interfaces:**
- Consumes: 无（纯迁移）。
- Produces: 新路径 `lib/features/watermark/...`，后续所有任务在该路径下工作。路由常量不变（`RouteNames.profileSettingsWatermark` / `...Edit`）。

- [ ] **Step 1: 迁移目录**
  - 用文件系统操作将 `lib/features/capture/watermark/` 整个目录移动到 `lib/features/watermark/`，删除原目录。
  - 确认迁移后文件清单：
    - `lib/features/watermark/models/watermark_template.dart`
    - `lib/features/watermark/models/watermark_settings.dart`
    - `lib/features/watermark/data/watermark_providers.dart`
    - `lib/features/watermark/data/preset_watermarks.dart`
    - `lib/features/watermark/services/watermark_renderer.dart`
    - `lib/features/watermark/pages/watermark_manage_page.dart`
    - `lib/features/watermark/pages/watermark_editor_page.dart`
    - `lib/features/watermark/widgets/watermark_preview.dart`
    - `lib/features/watermark/widgets/watermark_animation_overlay.dart`

- [ ] **Step 2: 更新引用文件的 import 路径**

  `router.dart` 两处：
  ```dart
  import '../features/watermark/pages/watermark_editor_page.dart';
  import '../features/watermark/pages/watermark_manage_page.dart';
  ```
  `watermark_dao.dart`：
  ```dart
  import '../../../features/watermark/models/watermark_template.dart';
  ```
  `settings_dao.dart`：
  ```dart
  import '../../../features/watermark/models/watermark_settings.dart';
  ```
  对 `capture_page.dart`（37-39 行：`'../watermark/data/watermark_providers.dart'`、`'../watermark/models/watermark_template.dart'`、`'../watermark/widgets/watermark_animation_overlay.dart'` → 改为 `'../../watermark/...'`）与 `profile_settings_page.dart`（15 行：`'../../capture/watermark/data/watermark_providers.dart'` → `'../../watermark/data/watermark_providers.dart'`）中的 import 做路径替换。

- [ ] **Step 3: 验证无残留引用**

  Run: `flutter analyze`
  Expected: 无 error（允许 info 级提示）。用 Grep 全仓确认不再存在字符串 `features/capture/watermark`。

- [ ] **Step 4: 跑相关既有测试确保未破坏**

  Run: `flutter test test/features/profile/profile_settings_page_test.dart test/features/capture/capture_page_test.dart`
  Expected: 全部 PASS。

- [ ] **Step 5: Commit**

  ```bash
  git add lumira_app_flutter/lib/features lumira_app_flutter/lib/app/router.dart lumira_app_flutter/lib/core/db/dao
  git commit -m "refactor(watermark): extract watermark into independent feature module"
  ```

  **注意**：工作区已清空（仅含本次水印相关文件），上述宽路径 git add 不会混入无关改动。提交前用 `git status` 确认暂存内容仅涉及 watermark 迁移相关文件。
