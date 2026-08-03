# 参数调整、持久化与补光颜色优化设计

> **日期**: 2026-08-02
> **主题**: 相机参数精简、色彩/细节参数全功能实现、参数持久化、补光颜色合并与删改

## 背景与目标

拍摄页参数面板（ParamPanel）目前存在四类问题：
1. **相机 Tab** 展示了 ISO/快门/白平衡/对焦等 camerawesome 1.4.0 不支持控制的参数，仅 EV 通过 `setBrightness` 间接生效，其余为"摆设"。
2. **色彩 Tab** 饱和度调整出现色偏（非纯饱和度变化），且高光/阴影/黑点/鲜明度/明度等参数的矩阵实现为粗糙近似，效果不佳。
3. **细节 Tab** 的锐化/磨皮/暗角/颗粒仅有 UI 控件，后处理未实现。
4. **参数无持久化**：自由模式参数退出即丢失，重置按钮仅在模板模式且修改后显示。
5. **补光颜色**：系统预设与自定义颜色分两列表显示，文案为"收藏颜色"，自定义颜色仅支持长按删除，无修改功能。

**目标**：
- 相机 Tab 精简为 EV + 闪光，移除不可控参数控件
- 修复饱和度色偏 bug，优化色彩参数矩阵
- 细节 Tab 的锐化/磨皮/暗角/颗粒在拍照后处理中实现
- 自由模式参数（相机/色彩/细节/构图）持久化到本地数据库，下次进入恢复
- 重置按钮始终显示，按当前模式重置（自由模式→默认值，模板模式→模板原始值）
- 补光颜色合并为单列表，支持长按删改，提示用户操作方式

## 范围

**包含**：
- 相机 Tab UI 精简
- 色彩矩阵修复与优化
- 拍照后处理增加色彩矩阵 + 锐化 + 磨皮 + 暗角 + 颗粒
- SettingsDao 扩展 + 参数持久化
- 重置按钮行为调整
- 补光颜色列表合并 + 长按删改 + 操作提示

**不包含**：
- ISO/快门/白平衡/对焦的硬件控制（camerawesome 不支持）
- 模板参数修改的持久化（模板套用始终从模板原始值开始）
- 新增色彩/细节参数（仅实现现有 UI 参数）

## 架构设计

### 模块1：相机 Tab 精简

**改动**：`lib/features/capture/widgets/param_panel.dart` 的 `_CameraTab`

- 移除「曝光」分组中的 ISO、快门两行
- 移除「白平衡」整个分组
- 移除「其他」分组中的对焦行
- 保留：EV 滑块（曝光分组）、闪光灯（其他分组）
- 移除底部"ISO/快门/白平衡为推荐值"提示
- `CameraParams` 数据模型不变（兼容模板数据），仅 UI 不展示

**EV 实时生效**：现有 `camera_preview.dart` 的 `_onCameraReady` 已读取 `effectiveCameraProvider.exposureCompensation` 并通过 `setBrightness` 应用，此行为保持不变。

### 模块2：色彩矩阵修复与优化

**文件**：`lib/features/capture/domain/filter_recipe.dart`

#### 2.1 修复饱和度色偏

**根因**：`_saturationMatrix` 使用老式 NTSC 亮度权重 `lumR=0.3086, lumG=0.6094, lumB=0.0820`，现代 sRGB 应使用 Rec.709 权重 `0.2126, 0.7152, 0.0722`。权重偏差导致饱和度调整时亮度偏移，视觉上表现为色偏。

**修复**：
```dart
List<double> _saturationMatrix(double v) {
  final s = 1 + v / 100;
  // Rec.709 亮度权重（sRGB 标准），替代老式 NTSC 权重
  const lumR = 0.2126, lumG = 0.7152, lumB = 0.0722;
  final sr = (1 - s) * lumR;
  final sg = (1 - s) * lumG;
  final sb = (1 - s) * lumB;
  return [
    s + sr, sr, sr, 0, 0,
    sg, s + sg, sg, 0, 0,
    sb, sb, s + sb, 0, 0,
    0, 0, 0, 1, 0,
  ];
}
```

#### 2.2 优化高光/阴影/黑点矩阵

当前实现用 brightness/contrast 近似，效果粗糙。优化为更精确的色调映射：

- **高光（highlights）**：仅影响亮区。通过在亮度>0.5 区域增加 contrast、暗区不变的方式近似。使用分段对比度矩阵。
- **阴影（shadows）**：仅影响暗区。与高光对称，在亮度<0.5 区域增加 contrast。
- **黑点（blackPoint）**：调整暗部截止点。通过 contrast 矩阵 + 负偏移实现。
- **鲜明度（vibrance）**：选择性饱和度，对低饱和像素影响大。预览端用饱和度矩阵近似（/1.5 系数保留），拍照端可实现更精确版本。
- **明度（brilliance）**：亮度+饱和度组合，保持现有实现。

> 注：ColorFilter.matrix 是全局线性变换，无法做真正的"仅影响亮区"的非线性操作。预览端的 high光/阴影仅为近似，真正精确的色调映射在拍照后处理中用 image 包实现。

### 模块3：拍照后处理增加色彩与细节

**文件**：`lib/features/capture/pages/capture_page.dart` 的 `_processCaptureInIsolate`

当前后处理流程：方向对齐 → 裁切 → 镜像 → 限制尺寸 → 编码 JPEG

**新流程**：方向对齐 → 裁切 → 镜像 → **应用色彩矩阵** → **锐化** → **磨皮** → **暗角** → **颗粒** → 限制尺寸 → 编码 JPEG

#### 3.1 应用色彩矩阵

在 isolate 中用 image 包的 `colorMatrix` 函数应用 `composePostProcessMatrix(postProcess)` 生成的矩阵：

```dart
import 'package:image/image.dart' as img;

// 在 isolate 中
final matrix = composePostProcessMatrix(params.postProcess);
result = img.colorMatrix(result, matrix);
```

> 注意：`filter_recipe.dart` 中的矩阵是 5x4（20 元素），image 包的 `colorMatrix` 接受 5x4 或 5x5。需确认格式兼容，必要时补齐为 5x5（末行 `[0,0,0,0,1]`）。

#### 3.2 锐化（sharpen）

复用项目已有的 Unsharp Mask 算法（`dart_photo_pipeline.dart` 中的实现）：
- 强度映射：`sharpen`（0-100）→ `strength`（0.0-0.4）
- 3x3 Box Blur 卷积核
- 仅当 `sharpen > 0` 时应用

#### 3.3 磨皮（smoothStrength）

简单实现：降采样模糊 + 原图混合
- 将图像降采样到原尺寸的 1/4
- 高斯模糊（radius 根据 smoothStrength 映射）
- 与原图按 `smoothStrength/100` 比例混合
- 仅当 `smoothStrength > 0` 时应用

#### 3.4 暗角（vignette）

在图像四角绘制径向渐变暗化：
- 中心亮度=1.0，四角亮度=`1.0 - vignette/100 * 0.6`
- 使用 `img.fillCircle` 配合 `blendMode` 或手动像素遍历

#### 3.5 颗粒（grain）

随机噪声叠加：
- 为每个像素的 RGB 通道添加 `[-grain/2, +grain/2]` 范围的随机值
- 噪声强度映射：`grain`（0-100）→ `noiseAmount`（0-30）
- 仅当 `grain > 0` 时应用

#### 3.6 性能控制

- 色彩矩阵：O(n) 线性操作，快
- 锐化/磨皮：O(n) 卷积，对 2048px 图像约 50-100ms
- 暗角/颗粒：O(n) 像素遍历，约 20-40ms
- 总目标：<500ms（当前 300ms 基础上 +200ms 后处理）

### 模块4：参数持久化

#### 4.1 数据库扩展

**文件**：`lib/core/db/tables.dart`、`lib/core/db/database_provider.dart`、`lib/core/db/dao/settings_dao.dart`

`user_settings` 表新增三列：
- `free_mode_camera` TEXT（CameraParams JSON）
- `free_mode_post_process` TEXT（PostProcess JSON）
- `free_mode_composition` TEXT（Composition JSON）

数据库版本升级（migration）使用 `_addColumnIfNotExists`（项目既有模式）。

#### 4.2 序列化方法

`CameraParams`、`PostProcess`、`PostProcessColor`、`Composition` 添加 `toJson()` 和 `fromJson()` 工厂构造。

#### 4.3 SettingsDao 扩展

```dart
class SettingsDao {
  // 既有：getAutoDeblur / setAutoDeblur

  Future<CameraParams?> getFreeModeCamera() async { ... }
  Future<void> setFreeModeCamera(CameraParams value) async { ... }

  Future<PostProcess?> getFreeModePostProcess() async { ... }
  Future<void> setFreeModePostProcess(PostProcess value) async { ... }

  Future<Composition?> getFreeModeComposition() async { ... }
  Future<void> setFreeModeComposition(Composition value) async { ... }
}
```

#### 4.4 加载与持久化时机

**文件**：`lib/features/capture/data/capture_state.dart`、`lib/features/capture/pages/capture_page.dart`

- **加载**：拍摄页 `initState` 中异步从 DAO 读取，写入 `freeModeCameraProvider` 等。加载前 provider 保持默认值。
- **持久化**：在 `CaptureState.updateCamera`/`updatePostProcess`/`updateComposition` 中，自由模式分支更新 provider 后，防抖 500ms 写入 DAO。用 `Timer` 实现，每次更新取消上次未触发的写入。
- **模板模式不持久化**：`updateCamera` 等方法的模板分支仅更新 `editableTemplateProvider`，不写 DAO。

#### 4.5 重置按钮

**文件**：`lib/features/capture/widgets/param_panel.dart` 的 `_PanelFooter`

- 移除 `hasTemplate && isModified` 条件，始终显示重置按钮
- 自由模式：`onReset` 将 `freeModeCameraProvider`/`freeModePostProcessProvider`/`freeModeCompositionProvider` 重置为 `const` 默认值，并立即持久化
- 模板模式：`onReset` 将 `editableTemplateProvider` 重置为 `originalTemplate.copyWith()`

### 模块5：补光颜色合并与删改

#### 5.1 数据模型扩展

**文件**：`lib/features/capture/data/custom_fill_light_colors.dart`

`CustomFillLightColorsNotifier` 新增方法：
```dart
/// 修改已有颜色（按 name 匹配）
Future<void> update(String name, {String? newName, Color? newColor}) async { ... }
```

#### 5.2 UI 重构

**文件**：`lib/features/capture/pages/capture_page.dart` 的 `_CustomColorsRow` 及相关

- 系统预设颜色列表与用户保存颜色列表合并为单个 `ListView`
- 用户颜色追加在系统预设之后，视觉上用一个小标签或分隔符区分
- 文案修改：标题"收藏颜色"→"保存颜色"，按钮"收藏当前"→"保存当前"
- 长按用户保存的颜色 → 弹出 `showModalBottomSheet` ActionSheet：
  - 「修改名称」→ 弹出输入框
  - 「修改颜色」→ 打开颜色选择器（复用现有 HueBar）
  - 「删除」→ 确认后删除
- 系统预设颜色长按无响应

#### 5.3 操作提示

- 首次进入补光面板时，在颜色列表下方显示提示条："长按保存的颜色可修改或删除"
- 用户首次长按颜色或保存第一个颜色后，提示条消失
- 用 `SharedPreferences` 记录 `fill_light_hint_shown` 标记

## 数据流

### 参数调整与持久化流

```
用户拖动滑块
  → ParamPanel.onChanged
  → CaptureState.updatePostProcess（自由模式分支）
  → freeModePostProcessProvider 更新
  → effectivePostProcessProvider 通知
  → CameraPreview 重建（ColorFilter.matrix 实时应用）
  → 防抖 Timer 500ms 后 → SettingsDao.setFreeModePostProcess
```

### 拍照后处理流

```
用户点击快门
  → cameraService.capture() 返回原始 JPEG
  → _processCaptureQueueItem 入队
  → isolate 中 _processCaptureInIsolate:
    1. 方向对齐
    2. 按比例裁切
    3. 前置镜像
    4. 应用色彩矩阵（composePostProcessMatrix）
    5. 锐化（Unsharp Mask）
    6. 磨皮（降采样模糊+混合）
    7. 暗角（径向渐变）
    8. 颗粒（随机噪声）
    9. 限制尺寸到 2048px
    10. 编码 JPEG quality 90
  → 更新角标与 lastPhotoPathProvider
```

## 错误处理

- 持久化失败：静默降级，仅打印日志，不阻塞 UI
- DAO 加载失败：provider 保持默认值，不影响进入拍摄页
- isolate 后处理失败：返回原路径（不应用色彩/细节），不阻塞拍照
- 补光颜色文件读写失败：静默降级（现有行为）

## 测试策略

- **饱和度矩阵单元测试**：验证使用 Rec.709 权重后，纯灰图（R=G=B）饱和度调整后仍为纯灰（无色偏）
- **序列化往返测试**：`CameraParams`/`PostProcess`/`Composition` 的 toJson→fromJson 应保持相等
- **DAO 测试**：`setFreeModeCamera` 后 `getFreeModeCamera` 应返回相等值
- **后处理集成测试**：给定带色彩参数的 PostProcess，处理后的图像像素应反映矩阵变换

## 文件清单

**修改**：
- `lib/features/capture/widgets/param_panel.dart` — 相机 Tab 精简、重置按钮始终显示
- `lib/features/capture/domain/filter_recipe.dart` — 修复饱和度矩阵、优化高光/阴影矩阵
- `lib/features/capture/domain/photo_template.dart` — 添加 toJson/fromJson
- `lib/features/capture/pages/capture_page.dart` — 后处理增加色彩/细节、补光颜色 UI 重构、持久化加载
- `lib/features/capture/data/capture_state.dart` — 持久化防抖逻辑
- `lib/features/capture/data/custom_fill_light_colors.dart` — 新增 update 方法
- `lib/core/db/tables.dart` — 新增列常量
- `lib/core/db/database_provider.dart` — 版本升级 migration
- `lib/core/db/dao/settings_dao.dart` — 新增 get/set 方法
- `lib/features/capture/widgets/camera_preview.dart` — 无功能改动（EV 已生效），仅确认

**新增**：
- 无新文件（所有改动在现有文件内）

## 约束

- 三端兼容：所有改动不依赖原生平台 API，仅 Dart 层
- 性能：拍照后处理总时间 <500ms（2048px 图像）
- 向后兼容：数据库 migration 使用 `_addColumnIfNotExists`，旧版本数据不丢失
- 不引入新依赖：复用 image 包（已在依赖中）和现有 DAO 模式
