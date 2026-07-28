# 拍照后编辑功能扩展设计

**日期**：2026-07-28
**作者**：协作设计（用户 + AI）
**状态**：待评审

## 背景与动机

当前 `CapturePreviewPage` 的后期编辑能力严重不足，仅暴露 3 个滑块（亮度/对比度/饱和度），无法满足用户拍完照后的完整后期需求。同时存在以下已设计但未实现的遗留项：

1. **`smoothStrength`（皮肤平滑）**：`ParamPanel` 滑块存在、`PostProcess` 字段存在，但 `PhotoPostProcessor.processFile` 从未读取该参数——纯死 UI
2. **预览页编辑能力受限**：相比拍摄时 `ParamPanel` 的 11 个色彩 + 5 个细节滑块，预览页只有 3 个滑块
3. **预览页无滤镜选择器**：`FilterPicker` 只能在拍摄前使用，拍后不可更换
4. **无旋转/翻转/拉直**：常见照片编辑操作完全缺失
5. **原文件被覆盖**：`processFile` 原地覆盖输入文件，导致无法做真正的迭代编辑——滤镜切换、旋转、皮肤平滑等不可逆操作无法基于"已处理"状态做 delta 计算

## 三端适配约束（核心）

**必须完全兼容 OHOS / iOS / Android 三端**。技术选型全部基于已验证三端兼容的组件：

| 组件 | 三端兼容性 | 依据 |
|---|---|---|
| `dart:ui` Canvas（GPU 旋转/翻转） | ✅ Flutter 引擎内置 | 已在 photo_post_processor.dart 使用 |
| `image` 包（双边滤波皮肤平滑） | ✅ 纯 Dart | pubspec.yaml line 52，无原生代码 |
| `sqflite`（编辑参数持久化） | ✅ OHOS 已用 CPF-Flutter fork | database_provider.dart line 19 |
| Riverpod StateProvider | ✅ 纯 Dart | 项目已用 |
| `Transform` / `RotatedBox` widget | ✅ Flutter 内置 | 预览页实时变换 |

**不引入**：
- 任何原生平台通道代码（保持零三端差异）
- `shared_preferences`（项目未用，且与 OHOS 适配版本不确定）
- AI 模型推理（皮肤平滑用传统双边滤波即可满足需求）

## 目标

- 在 `CapturePreviewPage` 暴露完整的 11 个色彩 + 5 个细节滑块（含 `smoothStrength`）
- 预览页支持 `FilterPicker`（7 系统滤镜 + 16 LUT 预设），拍后可换滤镜
- 预览页支持 90°/180°/270° 旋转、水平/垂直翻转、±15° 拉直
- 实现 `smoothStrength` 皮肤平滑算法（双边滤波）并接入 `PhotoPostProcessor` 管线
- 实现非破坏性编辑底座：保留原图，所有编辑都从原图重处理
- 用户保存时可选择"保留原图"（默认开启）或"不保留"（节省存储）
- 三端兼容，无原生代码
- 管线总耗时 ≤ 1500ms（含变换 + 滤镜 + 去模糊 + 皮肤平滑 + 锐化）

## 非目标

- 不做相册详情页（`gallery_detail_page.dart`）的真实编辑接入（本次只做 `CapturePreviewPage`；相册页另有 spec）
- 不做 AI 皮肤平滑（Phase 2 调研）
- 不做选择性/蒙版调整（所有调整仍为全局）
- 不做红眼消除/瑕疵修复/物体移除
- 不做直方图/波形监视器
- 不做真正的 3D LUT（保持 ColorMatrix 近似，已有 spec 说明）

## 方案选择

**选定方案**：A —— 保留原始文件 + 全参数重处理

| 决策点 | 选择 | 理由 |
|---|---|---|
| 非破坏性底座 | 保留原始文件 `P.original.jpg` | 滤镜切换/旋转/平滑不可逆，必须从原图重处理 |
| 保存行为 | 替换当前相册记录 + 保留/不保留原图由用户选择 | 默认保留可再次编辑；用户可主动放弃以节省存储 |
| 编辑写入 | 全参数（非 delta） | 消除 delta 复合 bug，逻辑简洁 |
| 皮肤平滑算法 | 双边滤波（3x3，降采样到 768px） | 三端纯 Dart 兼容，边缘保留，性能可控 |
| 变换应用层 | GPU Canvas（`dart:ui`） | 硬件加速，~10-20ms |

**被否决方案**：
- **B. 首次编辑时才快照**：状态跟踪复杂，需要"是否已快照"标志位，且首次编辑体验有延迟
- **C. 只做增量编辑**：滤镜切换/旋转/平滑不可逆，功能严重受限
- **D. 原地覆盖 + 反向操作**：数学上不可能（锐化/平滑/去模糊不可逆）
- **E. 5x5 双边滤波**：纯 Dart 实现预估 > 1s，超 1500ms 预算
- **F. AI 皮肤分割 + 平滑**：需 ONNX/tflite，OHOS 适配不确定

## 架构设计

### 模块划分

```
lib/features/capture/
├── services/
│   ├── photo_post_processor.dart   # 修改：加 outputPath/transform 参数 + 调用 SkinSmoother
│   └── skin_smoother.dart          # 新增：双边滤波皮肤平滑（纯 Dart）
├── domain/
│   └── photo_template.dart         # 修改：新增 TransformParams 类
├── widgets/
│   └── preview_edit_panel.dart     # 新增：4 标签底部抽屉（色彩/细节/滤镜/裁剪旋转）
└── pages/
    └── capture_preview_page.dart   # 修改：接入 PreviewEditPanel + 重写保存流程

lib/core/db/
├── tables.dart                     # 修改：加 original_path / transform / post_process 列常量
├── database_provider.dart          # 修改：_kDbVersion 6→7，加 v7 迁移
└── dao/
    └── gallery_dao.dart            # 修改：GalleryItemRecord 加新字段 + update 方法
```

### 数据流

```
拍摄流程（修改后）：
  takePhoto() → 原始 4:3 传感器 JPEG 写入 path P
  [新增] 复制 P 的原始字节到 P.original.jpg  ← 必须在 processFile 之前
  PhotoPostProcessor.processFile(P, captureParams) → 覆盖 P 为已处理 JPEG
  GalleryDao.insert({
    path: P,
    originalPath: 'P.original.jpg',   ← 新字段
    postProcess: captureParams,       ← 新字段（JSON）
    transform: null,                  ← 新字段（拍摄时无变换）
    ...
  })

预览页（修改后）：
  加载 Image.file(P) 用于显示
  加载 P.original.jpg 作为"重处理的源"
  _localPostProcess: 拍摄时 PostProcess 的快照（可变）
  _localTransform: TransformParams（新增，默认 0/false）
  实时预览：
    RotatedBox(quarterTurns: rotation/90,
      child: Transform.flip(flipX: flipH, flipY: flipV,
        child: Transform.rotate(angle: straighten * π/180,
          child: ColorFiltered(
            colorFilter: fromPostProcess(_localPostProcess),
            child: Image.file(P),
          ),
        ),
      ),
    )

保存流程（重写）：
  ┌─ 弹出保存对话框 ─────────────────────┐
  │  保存到相册                          │
  │  ☑ 保留原图（可再次编辑）            │  ← toggle，默认 ON
  │  [取消]  [保存]                     │
  └─────────────────────────────────────┘
  
  PhotoPostProcessor.processFile(
    inputPath: P.original.jpg,         ← 从原图重处理（非 P）
    params: _localPostProcess,          ← 全参数（非 delta）
    transform: _localTransform,         ← 旋转/翻转/拉直
    aspectRatio: captureAspectRatio,    ← 重新应用原始裁剪（通过查询参数从拍摄页传入预览页）
    outputPath: P,                      ← 覆盖当前文件
  )
  evict FileImage cache for P + P.original.jpg
  
  IF 用户选择"保留原图":
    GalleryDao.update(id, {
      path: P,
      originalPath: 'P.original.jpg',
      postProcess: _localPostProcess,
      transform: _localTransform,
    })
  ELSE:
    删除 P.original.jpg 文件
    GalleryDao.update(id, {
      path: P,
      originalPath: null,               ← null = 只读
      postProcess: _localPostProcess,
      transform: _localTransform,
    })
  
  saveToAlbum(P) via MethodChannel
```

### 再次编辑守卫

- `GalleryDao.getById(id)` 返回 `originalPath`
- 预览页检查：`originalPath == null` → 只读模式，显示 toast "原图未保留，无法再次编辑"
- `originalPath != null` → 加载原图，允许完整再编辑
- 已存在的旧记录（升级前）`originalPath` 为 null → 只读，符合预期

## 管线扩展：PhotoPostProcessor

### 新增 `processFile` 参数

```dart
static Future<String> processFile({
  required String inputPath,
  required PostProcess params,
  String? outputPath,                    // 新增：默认 inputPath（向后兼容）
  bool rawMode = false,
  String aspectRatio = 'fullscreen',
  double screenRatio = 9.0 / 19.5,
  bool isPortrait = true,
  bool autoDeblur = false,
  TransformParams? transform,            // 新增：旋转/翻转/拉直
});
```

### 新增 `TransformParams` 数据类（`domain/photo_template.dart`）

```dart
class TransformParams {
  final int rotation;        // 0, 90, 180, 270
  final bool flipH;
  final bool flipV;
  final double straighten;   // -15.0 到 +15.0 度

  const TransformParams({
    this.rotation = 0,
    this.flipH = false,
    this.flipV = false,
    this.straighten = 0.0,
  });

  bool get isIdentity =>
      rotation == 0 && !flipH && !flipV && straighten.abs() < 0.01;

  Map<String, dynamic> toJson() => {
        'rotation': rotation,
        'flipH': flipH,
        'flipV': flipV,
        'straighten': straighten,
      };

  factory TransformParams.fromJson(Map<String, dynamic> json) => TransformParams(
        rotation: (json['rotation'] as num?)?.toInt() ?? 0,
        flipH: json['flipH'] as bool? ?? false,
        flipV: json['flipV'] as bool? ?? false,
        straighten: (json['straighten'] as num?)?.toDouble() ?? 0.0,
      );
}
```

### 扩展后的 7 步管线

```
1. 解码 JPEG → ui.Image（硬件加速，~50ms）
2. [新增] 应用变换 via Canvas（GPU）：
   - canvas.rotate(rotation * π/180)
   - canvas.scale(flipH ? -1 : 1, flipV ? -1 : 1)
   - 拉直：rotate(straighten * π/180) + 裁剪到最大内接矩形（去黑边）
   - 输出：变换后的 ui.Image
3. 计算裁剪区域 + 降采样 + ColorMatrix + Vignette（现有 Canvas pass，输入为变换后的图）
4. 自动去模糊（现有，CPU on img.Image，仅当 autoDeblur=true 且 blurScore < 600）
5. [新增] 皮肤平滑（CPU on img.Image，受 params.smoothStrength 控制）
6. 逐像素：Sharpen + Clarity + Grain（现有，CPU）
7. 编码 JPEG q=88，写入 outputPath（之前是 inputPath）
```

**关键决策**：
- 变换在 GPU Canvas 阶段完成（非 CPU `img.copyRotate`），快 10 倍
- 皮肤平滑在去模糊之后、锐化之前——平滑是"准备"步骤，锐化是"增强"步骤
- `smoothStrength <= 0.01` 跳过平滑（快速路径，省 ~200ms）
- `TransformParams.isIdentity` 跳过变换步骤（快速路径，省 ~15ms）

### 皮肤平滑算法：双边滤波

**新文件**：`lib/features/capture/services/skin_smoother.dart`

```dart
class SkinSmoother {
  /// 双边滤波皮肤平滑
  /// [strength] 0.0-1.0，来自 PostProcess.smoothStrength
  static img.Image smooth(img.Image src, double strength) {
    if (strength <= 0.01) return src;

    // 1. 降采样到 768px 长边（性能优化）
    final small = _downsample(src, maxLongEdge: 768);

    // 2. 3x3 双边滤波（仅亮度通道，保留色度）
    final smoothed = _bilateralFilter(
      small,
      spatialSigma: 2.0,
      intensitySigma: 25.0,
    );

    // 3. 混合：output = lerp(original, smoothed, strength)
    final blended = _blend(small, smoothed, strength);

    // 4. 上采样回原尺寸
    return img.copyResize(blended, width: src.width);
  }

  /// 双边滤波：边缘保留平滑
  /// - 空间权重：exp(-dist² / (2 * spatialSigma²))
  /// - 强度权重：exp(-diff² / (2 * intensitySigma²))
  /// - 输出 = Σ(weight * pixel) / Σ(weight)
  static img.Image _bilateralFilter(
    img.Image src, {
    required double spatialSigma,
    required double intensitySigma,
  }) {
    // 3x3 kernel，预计算空间权重
    final spatialWeights = List<double>.filled(9, 0);
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final dist = (dx * dx + dy * dy).toDouble();
        spatialWeights[(dy + 1) * 3 + (dx + 1)] =
            math.exp(-dist / (2 * spatialSigma * spatialSigma));
      }
    }

    final out = img.Image(src.width, src.height);
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final center = src.getPixel(x, y);
        double r = 0, g = 0, b = 0, totalWeight = 0;
        for (var dy = -1; dy <= 1; dy++) {
          for (var dx = -1; dx <= 1; dx++) {
            final nx = x + dx, ny = y + dy;
            if (nx < 0 || nx >= src.width || ny < 0 || ny >= src.height) continue;
            final np = src.getPixel(nx, ny);
            final dr = (np.r - center.r).abs();
            final dg = (np.g - center.g).abs();
            final db = (np.b - center.b).abs();
            final diff = (dr + dg + db) / 3;
            final intensityWeight =
                math.exp(-diff * diff / (2 * intensitySigma * intensitySigma));
            final w = spatialWeights[(dy + 1) * 3 + (dx + 1)] * intensityWeight;
            r += np.r * w;
            g += np.g * w;
            b += np.b * w;
            totalWeight += w;
          }
        }
        out.setPixel(x, y, img.ColorUint8.rgb(
          (r / totalWeight).round().clamp(0, 255),
          (g / totalWeight).round().clamp(0, 255),
          (b / totalWeight).round().clamp(0, 255),
        ));
      }
    }
    return out;
  }
}
```

**性能预算**：
- 降采样（768px）：~20ms
- 3x3 双边滤波（768x1024 = 786K 像素 × 9 采样 × ~5 ops）：~200-300ms
- 上采样：~20ms
- 总计：~250-350ms（在 1500ms 总预算内）

## UI 设计：PreviewEditPanel

**新文件**：`lib/features/capture/widgets/preview_edit_panel.dart`

**4 标签底部抽屉**，替代现有 `_AdjustSection`（仅 3 滑块）：

```
┌─────────────────────────────────────────────┐
│  [色彩] [细节] [滤镜] [裁剪旋转]    [重置]   │
├─────────────────────────────────────────────┤
│                                              │
│  (标签内容 - 可滚动)                        │
│                                              │
└─────────────────────────────────────────────┘
```

### Tab 1：色彩（11 滑块）

| 参数 | 范围 | 默认 |
|---|---|---|
| 亮度 brightness | -1.0 ~ 1.0 | 0 |
| 对比度 contrast | -1.0 ~ 1.0 | 0 |
| 饱和度 saturation | -1.0 ~ 1.0 | 0 |
| 色温 temperature | -1.0 ~ 1.0 | 0 |
| 色调 tint | -1.0 ~ 1.0 | 0 |
| 高光 highlights | -1.0 ~ 1.0 | 0 |
| 阴影 shadows | -1.0 ~ 1.0 | 0 |
| 黑点 blackPoint | -1.0 ~ 1.0 | 0 |
| 自然饱和度 vibrance | -1.0 ~ 1.0 | 0 |
| 明亮度 brilliance | -1.0 ~ 1.0 | 0 |

### Tab 2：细节（5 滑块）

| 参数 | 范围 | 默认 |
|---|---|---|
| 清晰度 clarity | 0 ~ 1.0 | 0 |
| 锐化 sharpen | 0 ~ 1.0 | 0 |
| 皮肤平滑 smoothStrength | 0 ~ 1.0 | 0 |
| 晕影 vignette | 0 ~ 1.0 | 0 |
| 颗粒 grain | 0 ~ 1.0 | 0 |

### Tab 3：滤镜

复用现有 `FilterPicker` 的网格 UI：
- 7 系统滤镜：none / vivid / vivid_warm / vivid_cool / mono / silver / noir
- 16 LUT 预设：none / cinematic / vintage / bw / warm_film / cool_film / pastel / fuji / portrait / japanese / cyberpunk / sepia_classic / mist / rouge / twilight / cyan
- 选中写入 `_localPostProcess.systemFilter` / `_localPostProcess.lut`
- 高亮显示当前选中项

### Tab 4：裁剪旋转

```
┌─────────────────────────────────────────────┐
│  旋转:  [↺ 90°]  [↻ 90°]   当前: 0°         │
│  翻转:  [水平翻转]  [垂直翻转]               │
│  拉直:  ──────●────────  -15° ─── +15°      │
│  当前: 0.0°                                  │
└─────────────────────────────────────────────┘
```

- 旋转按钮：点击后 `_localTransform.rotation = (rotation + 90) % 360`
- 翻转按钮：toggle `flipH` / `flipV`
- 拉直滑块：-15.0 到 +15.0，步长 0.5

### 实时预览 widget 树

```dart
RotatedBox(                                    // 90/180/270 旋转（layout-aware）
  quarterTurns: _localTransform.rotation ~/ 90,
  child: Transform.flip(
    flipX: _localTransform.flipH,
    flipY: _localTransform.flipV,
    child: Transform.rotate(                   // 拉直（小角度）
      angle: _localTransform.straighten * pi / 180,
      child: ColorFiltered(
        colorFilter: fromPostProcess(_localPostProcess),
        child: Image.file(File(widget.photoPath)),
      ),
    ),
  ),
)
```

**关键 UI 决策**：
- 拉直预览显示黑边（与实际输出一致，不做放大填充）
- "重置"按钮仅重置当前标签的参数
- 顶部有"重置全部"选项
- 滑块显示实时数值（如"亮度: +0.15"）
- 长按"对比"按钮仍可用——临时禁用 `ColorFiltered` + `Transform`

## 数据模型与迁移

### DB schema 变更（v6 → v7）

**新列**（gallery_items 表）：

```sql
ALTER TABLE gallery_items ADD COLUMN original_path TEXT;        -- 可空
ALTER TABLE gallery_items ADD COLUMN transform TEXT;            -- JSON，可空
ALTER TABLE gallery_items ADD COLUMN post_process TEXT;         -- JSON，可空
```

**`tables.dart` 新增常量**：

```dart
// === gallery_items 扩展列（v7 迁移新增） ===
static const String colOriginalPath = 'original_path';
static const String colTransform = 'transform';
static const String colPostProcess = 'post_process';
```

**`database_provider.dart` 迁移**：

```dart
const int _kDbVersion = 7;  // 6 → 7

// 在 _onUpgrade 中：
if (oldVersion < 7) {
  try {
    await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colOriginalPath, 'TEXT');
    await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colTransform, 'TEXT');
    await _addColumnIfNotExists(db, Tables.galleryItems, Tables.colPostProcess, 'TEXT');
  } catch (e) {
    debugPrint('v7 migration failed (silent fallback): $e');
  }
}
```

### `GalleryItemRecord` 扩展

```dart
class GalleryItemRecord {
  final String id;
  final String? dataUrl;
  final String? filePath;
  final String? originalPath;           // 新增
  final TransformParams? transform;      // 新增
  final PostProcess? postProcess;        // 新增
  final String? sceneId;
  final String? templateId;
  final String? kitId;
  final String? mood;
  final String? lut;
  final int createdAt;

  // toRow / fromRow 处理 JSON 序列化
}

// GalleryDao 新增方法：
Future<int> updateEdit({
  required String id,
  required String filePath,
  required String? originalPath,
  required TransformParams? transform,
  required PostProcess? postProcess,
});
```

## 测试策略

### 单元测试（`test/features/capture/services/`）

1. **`transform_params_test.dart`**
   - JSON 序列化/反序列化往返
   - 默认值
   - `isIdentity` 判定
   - 等价性

2. **`skin_smoother_test.dart`**
   - `strength=0` 返回输入不变（快速路径）
   - `strength=1.0` 产生可测量的平滑（高频能量降低）
   - 边缘保留：高对比边缘保持锐利
   - 性能：768px 测试图 < 500ms

3. **`photo_post_processor_transform_test.dart`**
   - rotation 90/180/270 产生正确朝向（对比角点像素）
   - flipH/flipV 产生镜像
   - straighten 非零角度旋转 + 裁剪（无黑边）
   - `outputPath != inputPath` 写入正确位置，输入不变
   - `outputPath == null` 回退到 inputPath（向后兼容）
   - `TransformParams.isIdentity` 跳过变换步骤
   - `smoothStrength=0` 跳过平滑步骤

4. **`gallery_dao_v7_test.dart`**
   - v6 → v7 升级添加列
   - 旧记录 `originalPath` 为 null（只读）
   - 新字段 CRUD 正常
   - `updateEdit` 方法正确更新

### 集成测试（`integration_test/`）

1. **`capture_edit_save_flow_test.dart`**
   - 拍照 → 预览 → 调亮度 → 保存
   - 原图文件保留在 `P.original.jpg`
   - 保存的文件反映编辑后的亮度
   - 相册记录更新 `postProcess` + `transform`

2. **`re_edit_guard_test.dart`**
   - `originalPath=X` 的记录 → 可编辑
   - `originalPath=null` 的记录 → 只读，显示 toast

3. **`keep_original_toggle_test.dart`**
   - 开启 → `originalPath` 保留，文件存在
   - 关闭 → `originalPath=null`，文件从磁盘删除

### Widget 测试（`test/features/capture/widgets/`）

1. **`preview_edit_panel_test.dart`**
   - 4 个标签正确渲染
   - 色彩滑块通过 callback 更新 `_localPostProcess`
   - 细节滑块（含 `smoothStrength`）通过 callback 更新
   - 滤镜选择更新 `systemFilter` / `lut`
   - 旋转/翻转按钮更新 `_localTransform`
   - 拉直滑块更新 `_localTransform.straighten`
   - 重置按钮仅重置当前标签

### 性能验证

- 皮肤平滑单独：< 500ms
- 完整管线（变换 + 裁剪 + 滤镜 + 去模糊 + 平滑 + 锐化）：< 1500ms
- 通过 `Stopwatch` 在集成测试中测量，断言阈值

## 风险与缓解

| 风险 | 概率 | 缓解 |
|---|---|---|
| 3x3 双边滤波平滑力度不足 | 中 | 可调大 intensitySigma 或升级到 5x5（性能允许时） |
| 768px 降采样导致细节丢失 | 低 | 仅平滑层降采样，最终混合在原分辨率 |
| 存储翻倍（原图 + 编辑后） | 中 | 用户可选"不保留原图" |
| 旧记录（v6）originalPath=null 无法编辑 | 低 | 设计预期行为；显示明确 toast |
| 拉直裁剪后图片变小 | 低 | UI 显示预览，用户可见结果 |

## 后续阶段（本次不实现）

- **Phase 2**：相册详情页（`gallery_detail_page.dart`）接入真实编辑（基于本次非破坏性底座）
- **Phase 3**：AI 皮肤分割 + 选择性平滑（需 OHOS NN 框架调研）
- **Phase 4**：5x5 双边滤波 + 性能优化（如果 3x3 效果不足）
- **Phase 5**：直方图 / 波形监视器 / 蒙版调整
