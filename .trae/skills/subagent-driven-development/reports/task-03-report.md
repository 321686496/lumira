# Task 3 报告：渲染器扩展（画框 + 坐标空间 + 返回尺寸）并修正拍照管线

## 实现内容

### 1. 渲染器重写 `watermark_renderer.dart`
- 新增 `WatermarkRenderResult { rgbaBytes, width, height }`，显式返回输出尺寸（拍立得画框会扩展画布）。
- `render` 新签名：`Future<WatermarkRenderResult> render({required ui.Image sourceImage, required WatermarkTemplate template})`，不再暴露旧的 `elements` 列表版本。
- 支持三种画框类型：
  - `none`：画布 = 原图。
  - `polaroid`：四周 padding（`borderRatio`），底部可选白板（`bottomRatio`），底部投影（`shadowOpacity>0` 时）。
  - `innerBorder`：画布 = 原图，沿照片边缘画内描边。
- 坐标空间：元素按 `WatermarkElement.space` 选择基准矩形——`photo` 用 `photoRect`，`frame` 用 `plateRect`（拍立得底部白板）。
- 保留 `_withOpacity` 辅助方法（Flutter 3.7.12 无 `Color.withValues`，全部改用 `_withOpacity`/`Color.fromARGB`，并未触发编译错误——分析通过）。

### 2. 拍照管线修正 `capture_page.dart`
- 调用 `renderer.render(sourceImage: ..., template: watermarkTemplate)` 接收 `WatermarkRenderResult`。
- `img.Image.fromBytes` 改用 `wmResult.width/height`（原先是 `workerResult.width/height`，当画框扩展输出时会裁剪错误）。

### 3. 新增测试 `watermark_renderer_test.dart`
5 个用例：无画框=原图尺寸、拍立得=照片+白边+白板、内描边=原图尺寸、拍立得关闭白板不加高、frame 空间元素可渲染。

## TDD 证据

- **RED**：`flutter test test/features/watermark/watermark_renderer_test.dart`
  - 输出：`No named parameter with the name 'template'`（编译失败未加载，5 用例全失败）✓
- **GREEN**：重写渲染器 + 修管线后
  - 输出：`00:00 +5: All tests passed!` ✓
- **分析**：`flutter analyze` 无 error（351 条为既有 info/warning，与本次改动无关；本测试无 lint 警告，`_tpl` 已改名 `tpl` 避免 no_leading_underscores）。

## 文件变更（commit dd238ab）

- `lumira_app_flutter/lib/features/watermark/services/watermark_renderer.dart`（重写，+123/-49）
- `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（+10/-x，仅 watermark hunk）
- `lumira_app_flutter/test/features/watermark/watermark_renderer_test.dart`（新建 +90）

## 自查发现的问题

1. **并行任务污染 + 回滚**：在开发过程中检测到并行任务（usage-stats/埋点 `_reportUseShoot`）同时修改了 `capture_page.dart` 并一度回滚了我的渲染器与测试文件。已重新写入所有我的改动。
2. **git 选择性暂存**：`capture_page.dart` 工作区含并行任务的 import + `_reportUseShoot` hunks 及我的 watermark hunk。为遵守"不提交无关变更"，用 git diff + Python 提取仅含 `@@ -668` watermark hunk 的干净 patch，`git apply --cached` 只暂存我的 hunk，并行任务改动保持未暂存状态。
3. **Powershell 编码问题**：`Out-File -Encoding ascii` 会损坏中文注释导致 git apply 报 corrupt patch，改用 Python 直写 UTF-8 patch 解决。

## 遗留 / 提示
- 并行任务的 `capture_page.dart`（imports、`_reportUseShoot` 埋点）及其它文件（app_theme、scene_preset_strip 等）仍为未提交状态，应由对应任务自行提交。
- `git apply --cached` 暂存 watermark hunk 时，index 内容与我工作区该区域一致，提交后工作区 watermark 区域未被误改。