# Task 4 报告：预设更新（新增「拍立得」）

## 实现内容
- 在 `lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart` 中新增 `_polaroid()` 预设（id=`preset_polaroid`，名称「拍立得」），并追加到 `getPresetWatermarks()` 列表末尾，现在返回 **6 款**。
- 拍立得预设：`frame` 类型 `WatermarkFrameType.polaroid` + `bottomPlate: true`（底部白板），日期元素（`dateTime`）`space=WatermarkElementSpace.frame`，`fontFamily:'serif'`、`italic:true`、居中。
- 解决了 `Color` 导入问题：将文件头 `import 'package:flutter/painting.dart' show TextAlign;` 改为 `import 'package:flutter/painting.dart' show Color, TextAlign;`（`painting` 重导出的即 `dart:ui` Color，与模型 `WatermarkFrame`/`WatermarkElement` 的 `ui.Color` 字段类型一致，`const Color(...)` 编译通过）。
- 同步更新文件头文档注释（5 款 → 6 款，风格描述加入「拍立得」）。

## TDD 证据
- **RED**：`flutter test test/features/watermark/preset_watermarks_test.dart` 首次运行失败——`Expected: <6> Actual: <5>`，且 `preset_polaroid` 不存在（`Bad state: No element`）。符合预期。
- **GREEN**：实现后同命令 `+3: All tests passed!`（3 个用例全部通过：预设有 6 款且 id 唯一 / 拍立得 frame=polaroid 且日期在 frame 空间 / 其余预设 frame=none）。

## 变更文件
- `lumira_app_flutter/lib/features/watermark/data/preset_watermarks.dart`（修改）
- `lumira_app_flutter/test/features/watermark/preset_watermarks_test.dart`（新建）

## 自检
- `flutter analyze lib/features/watermark/data/preset_watermarks.dart` → `No issues found!`
- 提交前 `git status` 核对：仅暂存本任务的 2 个文件；并行会话（usage/scenes）对 `app_theme.dart` / `neu_card.dart` / `lumira_button.dart` / `floating_tabbar.dart` / `theme_test.dart` 的改动保持未暂存、未被混入。未使用 `git add -A`。
- Dart 2.19.6 兼容，未引入 Dart 3 records。

## 提交
- `f680886e41b6a1f4d7a33b10bb36143ee23025fe` feat(watermark): add polaroid preset with frame-space date