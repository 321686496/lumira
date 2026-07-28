# 拍照去模糊功能设计

**日期**：2026-07-28
**作者**：协作设计（用户 + AI）
**状态**：待评审

## 背景与动机

用户反馈拍照时手机抖动导致照片模糊。项目当前已有 `sharpen`（卷积锐化）和 `clarity`（局部对比度）参数，但它们只是边缘增强，对真正的运动模糊（手抖导致的位移模糊）效果有限。

华为相机去模糊的核心是多帧融合（连拍 N 张 → 对齐 → 加权平均）。但调查发现 `camerawesome_ohos 1.0.2` 完全不支持连拍（burst），Pigeon 通道只有单张 `takePhoto(path)`。要做真多帧需要 fork 包扩展 OHOS 原生层，工作量过大。

## 三端适配约束（核心）

**必须完全兼容 OHOS / iOS / Android 三端**。技术选型全部基于已验证三端兼容的组件：

| 组件 | 三端兼容性 | 依据 |
|---|---|---|
| `image` 包（Lucy-Richardson 反卷积） | ✅ 纯 Dart | pubspec.yaml line 52，无原生代码 |
| `sqflite`（设置持久化） | ✅ OHOS 已用 CPF-Flutter fork | pubspec.yaml line 44-48 |
| `dart:ui` Canvas（GPU 加速） | ✅ Flutter 引擎内置 | 已在 photo_post_processor.dart 使用 |
| Riverpod StateProvider | ✅ 纯 Dart | 项目已用 |

**不引入**：
- `shared_preferences`：项目未用，且 2.2+ 需 Dart 3，与当前 Dart 2.19.6 冲突
- `onnxruntime` / `tflite_flutter`：OHOS 无官方适配（Phase 2 调研）
- 任何原生平台通道代码：保证零三端差异

## 目标

- 拍照后自动去除手抖模糊，处理时间 ≤ 300ms（保证用户体验）
- 预览页提供"AI 加强去模糊"按钮，用户主动触发更强算法（可接受 ~300ms）
- 设置项允许用户关闭自动去模糊，**持久化到数据库（三端通用）**

## 非目标

- 不做多帧融合（camerawesome 不支持连拍，fork 工作量过大）
- 不做视频防抖
- 不做实时取景器防抖（仅处理后照片）
- Phase 1 不引入 AI 模型（OHOS NN 框架需调研）

## 方案选择

**选定方案**：A + B 组合

| 子方案 | 触发 | 算法 | 耗时 | 适用场景 | 三端 |
|---|---|---|---|---|---|
| A. 反卷积 | 拍照后自动 | Lucy-Richardson + 自动模糊核估计 | 150-250ms | 所有照片（默认开启） | ✅ 纯 Dart |
| B. AI 模型 | 预览页手动 | ONNX 轻量去模糊网络 | 150-300ms | 用户觉得自动效果不够时 | ⚠️ Phase 2 调研 |

**被否决方案**：
- C. Dart 模拟多帧融合（Timer.periodic 连拍 3 张）：超 500ms，不满足 300ms 约束
- D. Fork camerawesome 扩展原生连拍：工作量过大，需维护 fork，三端各自扩展
- E. shared_preferences 持久化：项目未用，2.2+ 需 Dart 3，OHOS 适配版本不确定

## 架构设计

### 模块划分

```
lib/features/capture/services/
├── photo_post_processor.dart   # 修改，集成去模糊调用
└── deblur_processor.dart       # 新增，方案 A 反卷积（纯 Dart）

lib/core/db/
├── tables.dart                 # 修改，加 colAutoDeblur 列常量
├── database_provider.dart      # 修改，_kDbVersion 5→6，加 v6 迁移
└── dao/
    └── settings_dao.dart       # 新增，对齐项目 DAO 模式

lib/features/profile/providers/
└── settings_providers.dart     # 新增，autoDeblurProvider + 异步加载

lib/features/profile/pages/
└── profile_settings_page.dart  # 修改，加"自动去模糊"开关 + 接入持久化

lib/features/capture/pages/
└── capture_page.dart           # 修改，读 autoDeblurProvider 传给 processFile

# Phase 2（本次不实现）
lib/features/capture/services/
└── ai_deblur_processor.dart    # 未来，方案 B AI 模型
lib/features/capture/pages/
└── capture_preview_page.dart   # 未来，加"AI 加强"按钮
```

### 数据流（方案 A 自动模式）

```
拍照完成
  ↓
PhotoPostProcessor.processFile()
  ├─ 1. 解码 JPEG
  ├─ 2. 计算裁剪区域
  ├─ 3. 计算降采样尺寸
  ├─ 4. Canvas 合并（裁剪 + 降采样 + ColorMatrix + Vignette）
  ├─ 5.【新增】若 autoDeblur 开启：
  │      ├─ DeblurProcessor.estimateBlur(image) → blurScore
  │      ├─ blurScore ≥ 清晰阈值 → 跳过（省 200ms）
  │      └─ blurScore < 清晰阈值 → DeblurProcessor.deblur(image, strength)
  ├─ 6. 逐像素效果（Sharpen / Clarity / Grain）
  └─ 7. 编码 JPEG
```

## 方案 A 详细设计（Phase 1，本次实现）

### 模糊程度估计

**算法**：基于 Laplacian 方差的模糊度估计（纯 Dart，image 包卷积）

```
1. 对图像做 3x3 Laplacian 卷积：
   [0, -1, 0]
   [-1, 4, -1]
   [0, -1, 0]
2. 计算卷积结果的方差（variance）
3. 方差越小 → 越模糊（边缘少 = 模糊）
4. 方差越大 → 越清晰（边缘多 = 锐利）
```

**阈值**（经验值，需在设备上调校）：
- variance < 100 → 严重模糊，strength 0.8
- variance 100-300 → 中度模糊，strength 0.5
- variance 300-600 → 轻度模糊，strength 0.3
- variance > 600 → 清晰，跳过

### 去模糊算法：Lucy-Richardson 反卷积

**原理**：给定观测图像 g 和模糊核 PSF h，迭代估计原始图像 f：
```
f_{k+1} = f_k * (h* ⊗ (g / (h ⊗ f_k)))
```
其中 `⊗` 是卷积，`*` 是逐元素乘法，`h*` 是 PSF 的共轭翻转。

**PSF 估计**：手抖通常是线性运动模糊，PSF 是一条线段
- 方向：用图像梯度主方向估计（Sobel + 主成分分析）
- 长度：用模糊度估计反推（blurScore 越低，长度越长）
- 长度范围：3-15 像素

**迭代次数**：3 次（平衡效果与性能，每次约 50ms）

### 性能优化

- **降采样**：输入图像先降采样到长边 ≤ 1024 做反卷积（反卷积复杂度 O(N²)），完成后升采样回原尺寸
- **隔离计算**：反卷积在 `img.Image`（image 包）上做，避免 GPU Canvas 上下文切换
- **提前退出**：blurScore > 600 直接跳过，省 200ms
- **与现有流程合并**：反卷积结果作为新的 `resultImage` 传给后续 Sharpen/Clarity 步骤

### 预期耗时（1024x1024 图像）

| 步骤 | 耗时 |
|---|---|
| Laplacian 模糊度估计 | 20-30ms |
| PSF 估计 | 5-10ms |
| Lucy-Richardson 3 次迭代 | 120-180ms |
| **总计** | **145-220ms** |

加上现有流程（裁剪 + 滤镜 ~100ms），总处理时间约 250-320ms。若超 300ms，降采样到 768 长边。

## 方案 B 详细设计（Phase 2，本次不实现）

### 模型选择（待调研）

候选模型：
1. MIMO-UNet-lite：约 1.2MB，256x256 输入 ~80ms
2. DeblurGAN-v2-tiny：约 2MB，256x256 输入 ~120ms
3. NAFNet-tiny：约 1.5MB，256x256 输入 ~100ms

### OHOS NN 框架调研需求（Phase 2 阻塞项）

pub.dev 上的 `onnxruntime` 和 `tflite_flutter` 都没有官方 OHOS 适配。Phase 2 启动前需调研：
- `@ohos.ai.ai_service` 或 `@ohos.neural_network_runtime` 是否可暴露给 Flutter
- 是否需要自建 Pigeon 通道封装 NN 推理
- 三端推理后端选择（OHOS NNAPI / iOS Core ML / Android NNAPI）

## 持久化设计（三端通用）

### 复用现有 user_settings 表

**不引入 shared_preferences**，复用项目已有的 sqflite + `user_settings` 单行表。

**调研发现**：项目 `lib/core/db/tables.dart:91-100` 已有 `user_settings` 表，含 `grid_enabled / level_enabled / watermark / shutter_sound` 四列。当前 `profile_settings_page.dart` 的 Switch 全是 setState() 局部状态，未持久化（项目已知缺陷）。

### 数据库迁移

1. `tables.dart` 新增常量：
   ```dart
   static const String colAutoDeblur = 'auto_deblur';
   ```

2. `database_provider.dart`：
   - `_kDbVersion` 从 5 改为 6
   - v1 建表 SQL 的 user_settings 表加 `auto_deblur INTEGER NOT NULL DEFAULT 1`（默认开启）
   - `_onUpgrade` 加 `if (oldVersion < 6)` 分支，用 `_addColumnIfNotExists` 幂等添加列

3. 新增 `SettingsDao`（对齐项目 7 个现有 DAO 的 `FutureProvider<Dao>` 模式）：
   - `Future<bool> getAutoDeblur()`
   - `Future<void> setAutoDeblur(bool)`
   - 内部 `UPDATE user_settings SET auto_deblur = ? WHERE id = 1`

### Provider 设计

```dart
// lib/features/profile/providers/settings_providers.dart

/// 自动去模糊开关（持久化到 user_settings 表）
/// 默认 true（开启）。CapturePage 读取此值决定是否调用 DeblurProcessor。
/// ProfileSettingsPage 的 Switch 双向绑定此 provider。
final autoDeblurProvider = StateProvider<bool>((ref) => true);

/// 应用启动时从 DB 异步加载历史值
/// 在 main.dart 或 ProfileSettingsPage initState 中调用
Future<void> loadSettingsFromDb(ProviderContainer container) async {
  final dao = await container.read(settingsDaoProvider.future);
  final value = await dao.getAutoDeblur();
  container.read(autoDeblurProvider.notifier).state = value;
}
```

### 设置页 UI

在 `profile_settings_page.dart` 的"拍摄"分组加一项（参考现有 `_SettingItem` + `Switch` 模式 line 260-272）：

```
[图标: blur_on] 自动去模糊        [Switch: 默认开]
```

`Switch.onChanged`：
1. `setState(() => _autoDeblurOn = v)`（即时 UI 反馈）
2. `ref.read(autoDeblurProvider.notifier).state = v`（更新全局状态）
3. `dao.setAutoDeblur(v)`（fire-and-forget 写入 DB，失败 debugPrint）

### 集成点

#### PhotoPostProcessor 修改

`processFile` 方法签名新增 `bool autoDeblur = false` 参数，在第 4 步（Canvas 合并）和第 5 步（逐像素效果）之间插入：

```dart
// 4b. 自动去模糊（若开启且检测到模糊）
if (autoDeblur) {
  final blurScore = DeblurProcessor.estimateBlur(resultImage);
  if (blurScore < kClearThreshold) {
    final strength = DeblurProcessor.strengthForScore(blurScore);
    resultImage = await DeblurProcessor.deblur(resultImage, strength: strength);
  }
}
```

#### CapturePage 调用点

`capture_page.dart:288` 的 `PhotoPostProcessor.processFile(...)` 调用新增：
```dart
final autoDeblur = ref.read(autoDeblurProvider);
// ...
final processedPath = await PhotoPostProcessor.processFile(
  // ...现有参数
  autoDeblur: autoDeblur,
);
```

## 测试策略

### 单元测试（纯 Dart，三端通用）

1. `DeblurProcessor.estimateBlur`：
   - 清晰图像（梯度丰富）→ blurScore > 600
   - 故意模糊图像（高斯模糊）→ blurScore < 100
2. `DeblurProcessor.deblur`：
   - 输入故意运动模糊图像 → 输出 SSIM 提升
   - strength=0 → 输出 = 输入
3. `PhotoPostProcessor.processFile`：
   - autoDeblur=true + 清晰图 → 不调用 deblur（性能优化）
   - autoDeblur=false → 永不调用 deblur
4. `SettingsDao`：
   - 默认值 = true
   - setAutoDeblur(false) → getAutoDeblur() == false
   - v6 迁移：旧 DB 升级后 auto_deblur 列存在，默认 1
5. `autoDeblurProvider` 默认值 = true

### 性能测试

- 1024x1024 图像，autoDeblur=true，重度模糊：总耗时 ≤ 300ms
- 1024x1024 图像，autoDeblur=true，清晰图：总耗时 ≤ 150ms（提前退出）

### 三端回归

- OHOS：真机验证反卷积耗时 + DB 持久化
- iOS：模拟器验证算法正确性 + DB 持久化
- Android：真机验证性能（中端机型）+ DB 持久化

## 实现分阶段

### Phase 1（本次实现）
- `DeblurProcessor` 类（模糊估计 + Lucy-Richardson 反卷积，纯 Dart）
- `SettingsDao` + `autoDeblurProvider` + 数据库 v6 迁移
- `ProfileSettingsPage` 加"自动去模糊"开关 + 接入持久化
- `PhotoPostProcessor` + `CapturePage` 集成
- 单元测试 + 性能测试

### Phase 2（未来）
- `AiDeblurProcessor` 类（ONNX 模型）
- 预览页"AI 加强去模糊"按钮
- OHOS NN 框架调研 + 模型选型 + 三端推理后端

## 风险与缓解

| 风险 | 概率 | 缓解 |
|---|---|---|
| Lucy-Richardson 对复杂抖动效果差 | 中 | 仅处理线性运动模糊，复杂模糊留给 Phase 2 AI |
| 1024x1024 反卷积超 300ms | 中 | 自动降采样到 768，或减少迭代到 2 次 |
| image 包在大图上内存峰值 | 低 | 已有 1536 长边降采样限制 |
| 模糊度阈值需设备调校 | 中 | 阈值设为常量，提供 debug 日志便于调校 |
| v6 迁移失败 | 低 | 用 `_addColumnIfNotExists` 幂等 + try/catch 静默回退 |
| OHOS sqflite 性能差异 | 低 | 已有 7 个 DAO 跑通，user_settings 单行读写极轻量 |

## 验收标准

1. 开启自动去模糊后，拍故意抖动的照片，处理后比处理前清晰（SSIM 提升）
2. 拍清晰照片，autoDeblur=true 时不应引入伪影或额外模糊
3. 总处理时间 ≤ 300ms（1024x1024 图像）
4. 设置页开关可正常切换并**持久化到数据库**（杀进程重启后保持）
5. 三端（OHOS / iOS / Android）行为一致，无平台特定代码
6. 现有 242 个测试全部通过
7. 新增测试覆盖 DeblurProcessor / SettingsDao / autoDeblurProvider
