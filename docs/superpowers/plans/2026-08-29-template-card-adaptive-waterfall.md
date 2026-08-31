# 模板卡片封面自适应高度 + 瀑布流统一 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让发现页/搜索页/模板库/收藏页的模板封面按真实比例完全展示（9:16 温和削减），并把发现页「更多模板」改为瀑布流双列。

**Architecture:** 新增有状态组件 `AdaptiveCoverImage`，通过 `ImageStream.resolve` 获取封面真实宽高比，按 `clampCoverRatio` 钳制到 [0.65, 2.0] 后以 `AspectRatio` 包裹渲染；四处卡片统一换用该组件。发现页「更多模板」由固定高 `GridView` 改为手写双列瀑布流（与 `TemplateGrid` 同模式）。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（**不支持 Dart 3 records 语法**）、flutter_riverpod、go_router、sqflite（测试）。

## Global Constraints

- Dart 2.19.6 / Flutter 3.7.12，禁止 Dart 3 records 语法。
- UI 必须跟随主题（`appThemeProvider` / `uiStyleProvider`），禁止硬编码主题色；叠在照片上的黑/白半透明遮罩属于合法例外（现有角标沿用，不新增）。
- `TemplateCoverImage` 渲染路径保持走 `LumiraImage`（字节缓存 + 降采样），**不得改动其对外行为**。
- 封面来源路由规则（`buildCoverProvider`）必须与 `LumiraImage` 内部路由保持一致：`coverData`/`data:` base64 → `MemoryImage`、`assets/` → `AssetImage`、`http(s)` → `NetworkImage`、其它 → `FileImage`。
- 发现页「更多模板」保留「最多 6 个」截断与 loading/空态逻辑。
- 搜索页场景、美学院卡片保持现有固定比例（4:3 / 3:4），仅模板封面自适应。

---

### Task 1: 常量 + 纯函数 `clampCoverRatio` / `buildCoverProvider`（TDD）

**Files:**
- Create: `lumira_app_flutter/lib/features/templates/widgets/adaptive_cover_image.dart`
- Test: `lumira_app_flutter/test/features/templates/widgets/adaptive_cover_image_test.dart`

**Interfaces:**
- Produces:
  - `const double kDefaultCoverRatio = 3 / 4;`（加载中/未知比例兜底）
  - `const double kMinCoverRatio = 0.65;`
  - `const double kMaxCoverRatio = 2.0;`
  - `double clampCoverRatio(double realRatio)` → 钳制到 `[kMinCoverRatio, kMaxCoverRatio]`
  - `ImageProvider? buildCoverProvider(String? cover, String? coverData)` → 按来源路由构造 provider；无来源或非法 base64 返回 `null`

- [ ] **Step 1: 写失败测试**

`test/features/templates/widgets/adaptive_cover_image_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/templates/widgets/adaptive_cover_image.dart';

void main() {
  group('clampCoverRatio', () {
    test('常规比例在区间内保持不变', () {
      expect(clampCoverRatio(3 / 4), closeTo(0.75, 1e-9));
      expect(clampCoverRatio(1.0), 1.0);
      expect(clampCoverRatio(16 / 9), closeTo(16 / 9, 1e-9));
    });
    test('9:16 长屏钳到最低比例 0.65', () {
      expect(clampCoverRatio(9 / 16), closeTo(kMinCoverRatio, 1e-9));
    });
    test('更长的竖图（如 1:4）也钳到 0.65', () {
      expect(clampCoverRatio(0.25), closeTo(kMinCoverRatio, 1e-9));
    });
    test('超宽全景钳到最高比例 2.0', () {
      expect(clampCoverRatio(3.0), closeTo(kMaxCoverRatio, 1e-9));
      expect(clampCoverRatio(4 / 1), closeTo(kMaxCoverRatio, 1e-9));
    });
  });

  group('buildCoverProvider', () {
    test('coverData base64 → MemoryImage', () {
      final p = buildCoverProvider(null, 'data:image/png;base64,aGVsbG8=');
      expect(p, isA<MemoryImage>());
    });
    test('cover 以 data: 开头 → MemoryImage', () {
      final p = buildCoverProvider('data:image/png;base64,aGVsbG8=', null);
      expect(p, isA<MemoryImage>());
    });
    test('assets 路径 → AssetImage', () {
      final p = buildCoverProvider('assets/templates/x.png', null);
      expect(p, isA<AssetImage>());
    });
    test('http → NetworkImage', () {
      final p = buildCoverProvider('https://example.com/a.jpg', null);
      expect(p, isA<NetworkImage>());
    });
    test('本地文件路径 → FileImage', () {
      final p = buildCoverProvider(r'C:\tmp\a.jpg', null);
      expect(p, isA<FileImage>());
    });
    test('无来源 → null', () {
      expect(buildCoverProvider(null, null), isNull);
      expect(buildCoverProvider('', null), isNull);
      expect(buildCoverProvider(null, ''), isNull);
    });
    test('非法 base64 → null', () {
      expect(buildCoverProvider('data:image/png;base64,!!!', null), isNull);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/templates/widgets/adaptive_cover_image_test.dart`
Expected: 编译失败（`adaptive_cover_image.dart` 不存在 / 符号未定义）。

- [ ] **Step 3: 实现**

`lumira_app_flutter/lib/features/templates/widgets/adaptive_cover_image.dart`（本任务只放常量与纯函数，组件在 Task 2 追加）：

```dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 模板封面默认展示比例（加载中/未知比例兜底，≈ 3:4）。
const double kDefaultCoverRatio = 3 / 4;

/// 封面展示比例下限：9:16(0.5625) 等长屏钳到 0.65，高度温和削减约 13%。
const double kMinCoverRatio = 0.65;

/// 封面展示比例上限：超宽全景（>2:1）钳到 2.0，裁左右。
const double kMaxCoverRatio = 2.0;

/// 将图片真实宽高比钳制到 [kMinCoverRatio, kMaxCoverRatio]。
///
/// 区间内的比例完全展示；超出区间的（9:16 长屏 / 超宽全景）用 cover 裁切多余方向。
double clampCoverRatio(double realRatio) =>
    realRatio.clamp(kMinCoverRatio, kMaxCoverRatio);

/// 构造封面 ImageProvider（四种来源统一路由，与 LumiraImage 内部路由保持一致）：
/// 1. [coverData] 非空 → base64 → [MemoryImage]
/// 2. [cover] 以 `data:` 开头 → base64 → [MemoryImage]
/// 3. [cover] 以 `assets/` 开头 → [AssetImage]
/// 4. [cover] 以 `http(s)` 开头 → [NetworkImage]
/// 5. 其它 → 本地文件 [FileImage]
/// 无任何有效来源时返回 null。
ImageProvider? buildCoverProvider(String? cover, String? coverData) {
  final cd = coverData;
  if (cd != null && cd.isNotEmpty) {
    final bytes = _decodeBase64Bytes(cd);
    if (bytes != null) return MemoryImage(bytes);
  }
  final c = cover;
  if (c == null || c.isEmpty) return null;
  if (c.startsWith('data:')) {
    final bytes = _decodeBase64Bytes(c);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
  if (c.startsWith('assets/')) return AssetImage(c);
  if (c.startsWith('http://') || c.startsWith('https://')) {
    return NetworkImage(c);
  }
  return FileImage(File(c));
}

Uint8List? _decodeBase64Bytes(String data) {
  try {
    final commaIdx = data.indexOf(',');
    final raw = (commaIdx >= 0 && data.startsWith('data:'))
        ? data.substring(commaIdx + 1)
        : data;
    return base64Decode(raw);
  } catch (_) {
    return null;
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/templates/widgets/adaptive_cover_image_test.dart`
Expected: 全部 PASS（`flutter: All tests passed!`）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/adaptive_cover_image.dart lumira_app_flutter/test/features/templates/widgets/adaptive_cover_image_test.dart
git commit -m "feat(templates): 封面比例钳制与来源路由纯函数(clampCoverRatio/buildCoverProvider)"
```

---

### Task 2: `AdaptiveCoverImage` 组件（TDD）

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/adaptive_cover_image.dart`（追加组件）
- Test: `lumira_app_flutter/test/features/templates/widgets/adaptive_cover_image_test.dart`（追加 widget 测试）

**Interfaces:**
- Consumes: `kDefaultCoverRatio`、`kMinCoverRatio`、`kMaxCoverRatio`、`clampCoverRatio`、`buildCoverProvider`（Task 1）；`TemplateCoverImage`（现有，`lib/features/templates/widgets/template_cover_image.dart`）。
- Produces:
  - `class AdaptiveCoverImage extends StatefulWidget`，构造参数：`String? cover`、`String? coverData`、`BoxFit fit = BoxFit.cover`、`Widget? fallback`、`Widget? errorFallback`、`List<Widget> overlay = const []`。
  - 渲染：有来源时 `AspectRatio(ratio)` 包裹 `Stack(fit: StackFit.expand)`，内层 `TemplateCoverImage` + `overlay` 子组件；`ratio = _realAspect == null ? kDefaultCoverRatio : clampCoverRatio(_realAspect)`。无来源时直接返回 `fallback`。

- [ ] **Step 1: 写失败测试**

在 `adaptive_cover_image_test.dart` 追加（导入 `package:flutter/material.dart` 已具备）：

```dart
void main() {
  // ... 原有 group 保留 ...

  group('AdaptiveCoverImage', () {
    // 1x1 透明 PNG（base64），解码后真实比例 = 1.0
    const png1x1 =
        'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

    testWidgets('无来源时显示 fallback', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdaptiveCoverImage(
            cover: null,
            coverData: null,
            fallback: const Text('EMPTY'),
          ),
        ),
      ));
      expect(find.text('EMPTY'), findsOneWidget);
    });

    testWidgets('加载中先用默认 3:4，解码完成后用真实比例', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AdaptiveCoverImage(
            cover: png1x1,
            fallback: const Text('EMPTY'),
          ),
        ),
      ));
      // 加载中（未解码）：默认比例 0.75
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(kDefaultCoverRatio, 1e-9),
      );
      // 等待真实解码（base64 走 UI isolate 异步，需 runAsync）
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      // 1x1 图片真实比例 1.0
      expect(
        tester.widget<AspectRatio>(find.byType(AspectRatio)).aspectRatio,
        closeTo(1.0, 1e-9),
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/templates/widgets/adaptive_cover_image_test.dart`
Expected: 编译失败（`AdaptiveCoverImage` 未定义）。

- [ ] **Step 3: 实现组件**

在 `adaptive_cover_image.dart` 末尾追加：

```dart
/// 自适应封面组件：按封面真实比例定高，宽度 100%，比例钳制在
/// [kMinCoverRatio, kMaxCoverRatio]（9:16 温和削减 / 超宽裁切）。
///
/// - 通过 `ImageStream.resolve` 取真实宽高（先例：gallery/photo_crop_layer.dart）。
/// - 渲染仍委托 [TemplateCoverImage]（走 LumiraImage 字节缓存 + 降采样），
///   本组件只负责外层比例与尺寸。
/// - [overlay] 作为封面 Stack 内的叠加子组件（免费/积分/已拍等角标）。
class AdaptiveCoverImage extends StatefulWidget {
  const AdaptiveCoverImage({
    super.key,
    this.cover,
    this.coverData,
    this.fit = BoxFit.cover,
    this.fallback,
    this.errorFallback,
    this.overlay = const <Widget>[],
  });

  final String? cover;
  final String? coverData;
  final BoxFit fit;
  final Widget? fallback;
  final Widget? errorFallback;
  final List<Widget> overlay;

  @override
  State<AdaptiveCoverImage> createState() => _AdaptiveCoverImageState();
}

class _AdaptiveCoverImageState extends State<AdaptiveCoverImage> {
  /// 图片真实宽高比（width / height）；null 表示尚未解析（用默认比例）。
  double? _realAspect;
  ImageStream? _stream;
  ImageStreamListener? _listener;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(AdaptiveCoverImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cover != widget.cover ||
        oldWidget.coverData != widget.coverData) {
      _realAspect = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _listener = null;
    final s = _stream;
    if (s != null && _listener != null) {
      s.removeListener(_listener!);
    }
    super.dispose();
  }

  void _resolve() {
    final s = _stream;
    if (s != null && _listener != null) {
      s.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;

    final provider = buildCoverProvider(widget.cover, widget.coverData);
    if (provider == null) return;

    final stream = provider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, _) {
        if (!mounted) return;
        final w = info.image.width;
        final h = info.image.height;
        if (w > 0 && h > 0) {
          setState(() => _realAspect = w / h);
        }
      },
      onError: (_, __) {
        // 解析失败：保持默认比例，画面由 TemplateCoverImage 的 errorFallback 兜底。
        if (mounted && _realAspect != null) {
          setState(() => _realAspect = null);
        }
      },
    );
    stream.addListener(listener);
    _stream = stream;
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    final provider = buildCoverProvider(widget.cover, widget.coverData);
    if (provider == null) {
      return widget.fallback ?? const SizedBox.shrink();
    }
    final real = _realAspect;
    final ratio = (real == null) ? kDefaultCoverRatio : clampCoverRatio(real);
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          TemplateCoverImage(
            cover: widget.cover,
            coverData: widget.coverData,
            fit: widget.fit,
            fallback: widget.fallback,
            errorFallback: widget.errorFallback,
          ),
          ...widget.overlay,
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/templates/widgets/adaptive_cover_image_test.dart`
Expected: 全部 PASS。若「解码后真实比例」断言失败，把 Step 3 中 `runAsync` 的延迟从 200ms 调大到 500ms 重跑（图片解码为真实异步，仅影响测试等待时长）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/adaptive_cover_image.dart lumira_app_flutter/test/features/templates/widgets/adaptive_cover_image_test.dart
git commit -m "feat(templates): 自适应封面组件 AdaptiveCoverImage(真实比例定高+钳制)"
```

---

### Task 3: 我的收藏页 `TemplateCard` 封面自适应 + 估算更新

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_grid.dart:149-221`（`TemplateCard` 的封面区）、`:68-73`（`_estimateCardHeight`）
- Test: `lumira_app_flutter/test/features/templates/templates_page_dao_test.dart`（既有，验证不回归）

**Interfaces:**
- Consumes: `AdaptiveCoverImage`（Task 2）、`kDefaultCoverRatio`。

- [ ] **Step 1: 加 import**

文件顶部 import 区追加：

```dart
import 'adaptive_cover_image.dart';
```

- [ ] **Step 2: 替换封面区**

把 `TemplateCard.build` 中这段（当前 149-221 行）：

```dart
            // 3:4 aspect ratio image
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateCoverImage(
                    cover: template.cover,
                    coverData: template.coverData,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.photo_outlined,
                        color: tokens.textTertiary,
                        size: 28,
                      ),
                    ),
                    errorFallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
```

替换为：

```dart
            // 封面：真实比例自适应（9:16 温和削减），宽度 100%
            AdaptiveCoverImage(
              cover: template.cover,
              coverData: template.coverData,
              fallback: Container(
                color: tokens.surfaceAlt,
                child: Icon(
                  Icons.photo_outlined,
                  color: tokens.textTertiary,
                  size: 28,
                ),
              ),
              errorFallback: Container(
                color: tokens.surfaceAlt,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: tokens.textTertiary,
                ),
              ),
```

然后该段剩余部分（价格角标 `if (template.price == 0) ... else ...` 与已拍角标 `if (usageCount > 0) ...` 的 `Positioned`）继续保留，但需把外层闭合从：

```dart
                ],
              ),
            ),
            Padding(
```

改为：

```dart
              ],
            ),
            Padding(
```

即：`Stack(...)` 的结束括号变为 `AdaptiveCoverImage(...)` 的 `overlay:` 列表结束。具体做法：原 `AspectRatio( child: Stack( fit:, children: [ TemplateCoverImage(...), <角标 Positioned>... ] ) )` 整体替换为 `AdaptiveCoverImage( cover:, coverData:, fallback:, errorFallback:, overlay: [ <角标 Positioned>... ] )`，末尾由 `),\n            ),`（Stack 收口 + AspectRatio 收口）改为 `],\n            ),`（overlay 列表收口 + AdaptiveCoverImage 收口）。完成后该文件不应再出现 `aspectRatio: 3 / 4`。

- [ ] **Step 3: 更新估算高度**

`_estimateCardHeight` 中：

```dart
    final imageH = cardWidth * 4 / 3;
```

改为：

```dart
    final imageH = cardWidth / kDefaultCoverRatio;
```

- [ ] **Step 4: 静态检查 + 既有测试**

Run: `flutter analyze`
Expected: No issues found（无未使用 import，`TemplateCoverImage` 若不再被本文件其它处使用则移除其 import）。

Run: `flutter test test/features/templates/templates_page_dao_test.dart test/features/templates/templates_all_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/template_grid.dart
git commit -m "feat(templates): 收藏页模板卡片封面自适应高度+估算对齐默认比例"
```

---

### Task 4: 模板库 `_TplCard` 封面自适应 + 估算更新

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart:1121-1192`（`_TplCard` 封面区）、`:1041-1046`（`_TemplateGrid._estimateCardHeight`）
- Test: `lumira_app_flutter/test/features/templates/templates_all_page_test.dart`（既有，验证不回归）

**Interfaces:**
- Consumes: `AdaptiveCoverImage`、`kDefaultCoverRatio`。

- [ ] **Step 1: 加 import**

文件顶部 import 区（`../widgets/template_cover_image.dart` 附近）追加：

```dart
import '../widgets/adaptive_cover_image.dart';
```

- [ ] **Step 2: 替换封面区**

`_TplCard.build` 中 `// 3:4 aspect ratio image` 的 `AspectRatio(aspectRatio: 3 / 4, child: Stack(fit:, children: [ TemplateCoverImage(...), <价格角标>, <已拍角标> ]))` 整体替换为 `AdaptiveCoverImage(cover:, coverData:, fallback: Container(...), errorFallback: Container(...), overlay: [ <价格角标 Positioned>, <已拍角标 Positioned> ])` —— 与 Task 3 完全同构，角标结构与 tokens 用法原样保留（参考 Task 3 Step 2 的替换说明）。完成后本文件不应再出现 `aspectRatio: 3 / 4`。

- [ ] **Step 3: 更新估算高度**

`_TemplateGrid._estimateCardHeight` 中：

```dart
    final imageH = cardWidth * 4 / 3;
```

改为：

```dart
    final imageH = cardWidth / kDefaultCoverRatio;
```

- [ ] **Step 4: 静态检查 + 既有测试**

Run: `flutter analyze`
Expected: No issues found。

Run: `flutter test test/features/templates/templates_all_page_test.dart`
Expected: 全部 PASS（模板名、分类计数断言不变，仅封面布局变化）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/pages/templates_all_page.dart
git commit -m "feat(templates): 模板库全部模板页卡片封面自适应高度+估算对齐"
```

---

### Task 5: 搜索页模板封面自适应 + 估算更新

**Files:**
- Modify: `lumira_app_flutter/lib/features/search/widgets/search_result_card.dart:58-113`（`_imageStack`）
- Modify: `lumira_app_flutter/lib/features/search/pages/global_search_page.dart:898-911`（`_estimateCardHeight`）
- Test: `lumira_app_flutter/test/features/search/pages/global_search_page_test.dart`（既有，验证不回归）

**Interfaces:**
- Consumes: `AdaptiveCoverImage`、`kDefaultCoverRatio`。
- 行为约定：仅 `r.template != null` 时走 `AdaptiveCoverImage`；场景/美学院保持 `AspectRatio`（`ratio = academy ? 4/3 : 3/4`），叠加角标逻辑不变。

- [ ] **Step 1: 加 import**

`search_result_card.dart` 顶部（`../../templates/widgets/template_cover_image.dart` 附近）追加：

```dart
import '../../templates/widgets/adaptive_cover_image.dart';
```

- [ ] **Step 2: 重写 `_imageStack`**

把 `_imageStack` 整体替换为：

```dart
  Widget _imageStack(SearchResult r, ThemeTokens tokens) {
    // 左上角类型角标（模板/场景/美学院）
    final typeBadge = showTypeBadge
        ? Positioned(top: 8, left: 8, child: _typeBadge(tokens, r.scope.label))
        : null;
    // 模板价格/免费徽标：类型角标在左时放右上，模板专属页放左上（对齐全部模板页）
    final priceBadge = r.template != null
        ? Positioned(
            top: 8,
            right: showTypeBadge ? 8 : null,
            left: showTypeBadge ? null : 8,
            child: r.price == 0
                ? _priceBadge(tokens, '免费', true)
                : _priceBadge(tokens, '${r.price}', false),
          )
        : null;
    // 已拍数：叠图角标（模板），不占用下方信息行空间
    final usageBadge = (r.template != null && r.usageCount > 0)
        ? Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.camera_alt_outlined,
                      size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    '已拍 ${r.usageCount} 张',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    final overlay = <Widget>[
      if (typeBadge != null) typeBadge,
      if (priceBadge != null) priceBadge,
      if (usageBadge != null) usageBadge,
    ];

    // 模板封面：真实比例自适应（宽度 100%，9:16 温和削减）
    if (r.template != null) {
      return AdaptiveCoverImage(
        cover: r.imageUrl,
        coverData: r.coverData,
        fallback: _placeholder(tokens, r),
        errorFallback: _placeholder(tokens, r),
        overlay: overlay,
      );
    }

    // 场景/美学院：保持现有固定比例
    final ratio = r.scope == SearchScope.academy ? 4 / 3 : 3 / 4;
    return AspectRatio(
      aspectRatio: ratio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _image(r, tokens),
          ...overlay,
        ],
      ),
    );
  }
```

- [ ] **Step 3: 更新搜索瀑布流估算**

`global_search_page.dart` 顶部加 import：

```dart
import '../../templates/widgets/adaptive_cover_image.dart';
```

`_estimateCardHeight` 中：

```dart
    final coverRatio = r.scope == SearchScope.academy ? 4 / 3 : 3 / 4;
    final coverH = w / coverRatio;
```

改为：

```dart
    final coverRatio = r.scope == SearchScope.academy ? 4 / 3 : 3 / 4;
    // 模板封面走自适应，估算用默认比例；场景/美学院用各自固定比例
    final coverH = r.template != null ? w / kDefaultCoverRatio : w / coverRatio;
```

- [ ] **Step 4: 静态检查 + 既有测试**

Run: `flutter analyze`
Expected: No issues found。

Run: `flutter test test/features/search/pages/global_search_page_test.dart`
Expected: 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/search/widgets/search_result_card.dart lumira_app_flutter/lib/features/search/pages/global_search_page.dart
git commit -m "feat(search): 搜索页模板封面自适应高度+瀑布流估算对齐"
```

---

### Task 6: 发现页「更多模板」改瀑布流 + `TemplateGridCard` 封面自适应

**Files:**
- Modify: `lumira_app_flutter/lib/features/templates/widgets/template_grid_card.dart:101-158`（`_GridImage`）
- Modify: `lumira_app_flutter/lib/features/templates/pages/templates_page.dart:446-475`（`_OtherSection` 的 `GridView.builder`）
- Test: `lumira_app_flutter/test/features/templates/templates_page_test.dart`（既有，验证不回归）

**Interfaces:**
- Consumes: `AdaptiveCoverImage`、`kDefaultCoverRatio`。
- 行为约定：`_OtherSection` 保留 `others.length > 6 ? sublist(0,6) : others` 截断、loading → `SizedBox.shrink()`、error/空 → `_EmptyState`。瀑布流为左/右 `Column` + 估算高度配平（与 `TemplateGrid` 同模式）。

- [ ] **Step 1: `TemplateGridCard` 封面自适应**

`template_grid_card.dart` 顶部（`template_cover_image.dart` import 附近）追加：

```dart
import 'adaptive_cover_image.dart';
```

把 `_GridImage.build` 中：

```dart
    return AspectRatio(
      aspectRatio: 1.0, // padding-bottom: 100% → 1:1
      child: Stack(
        fit: StackFit.expand,
        children: [
          TemplateCoverImage(
            cover: tpl.cover,
            coverData: tpl.coverData,
            fit: BoxFit.cover,
            fallback: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tokens.brandSubtle,
                    tokens.brand.withOpacity(0.4),
                  ],
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 28,
                  color: tokens.brandDeep.withOpacity(0.6),
                ),
              ),
            ),
            errorFallback: Container(
              color: tokens.surfaceAlt,
              child: Center(
                child: Icon(
                  Icons.broken_image_outlined,
                  size: 24,
                  color: tokens.textTertiary,
                ),
              ),
            ),
          ),
          if (tpl.price == 0)
            Positioned(
              top: 6, // 12rpx → 6dp
              left: 6,
              child: _FreeBadge(),
            ),
        ],
      ),
    );
```

替换为：

```dart
    return AdaptiveCoverImage(
      cover: tpl.cover,
      coverData: tpl.coverData,
      fallback: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.brandSubtle,
              tokens.brand.withOpacity(0.4),
            ],
          ),
        ),
        child: Center(
          child: Icon(
            Icons.photo_camera_outlined,
            size: 28,
            color: tokens.brandDeep.withOpacity(0.6),
          ),
        ),
      ),
      errorFallback: Container(
        color: tokens.surfaceAlt,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 24,
            color: tokens.textTertiary,
          ),
        ),
      ),
      overlay: [
        if (tpl.price == 0)
          Positioned(
            top: 6, // 12rpx → 6dp
            left: 6,
            child: _FreeBadge(),
          ),
      ],
    );
```

- [ ] **Step 2: `_OtherSection` 改瀑布流**

`templates_page.dart` 顶部加 import：

```dart
import '../widgets/adaptive_cover_image.dart';
```

把 `_OtherSection.build` 中 `asyncOthers.when(... data: ...)` 里从 `final visible = ...` 到 `);`（`GridView.builder(...)` 结束）整体替换为：

```dart
              final visible = others.length > 6 ? others.sublist(0, 6) : others;
              // 瀑布流双列：按估算高度配平（与 TemplateGrid 同模式）
              final screenW = MediaQuery.of(context).size.width;
              final cardW = (screenW - 40 - 12) / 2; // 页面左右 padding 20*2 + 列间距 12
              final left = <Widget>[];
              final right = <Widget>[];
              var leftH = 0.0;
              var rightH = 0.0;
              for (final rec in visible) {
                final tpl = _recordToItem(rec);
                final card = Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TemplateGridCard(
                    template: tpl,
                    onTap: () => onTap(tpl.id),
                  ),
                );
                final h = _estimateMoreCardHeight(cardW);
                if (leftH <= rightH) {
                  left.add(card);
                  leftH += h;
                } else {
                  right.add(card);
                  rightH += h;
                }
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: left,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: right,
                    ),
                  ),
                ],
              );
```

在同一文件新增估算函数（放 `_OtherSection` 类内私有方法或文件级顶层函数均可，建议顶层函数与 `_recordToItem` 并列）：

```dart
/// 估算「更多模板」卡片高度（瀑布流配平用）。
///
/// 结构：封面(宽 ÷ kDefaultCoverRatio) + 文字区(上 padding 8 + 名称 13*1.2 +
/// 间距 3 + 分类 11 + 下 padding 10)。
double _estimateMoreCardHeight(double cardWidth) {
  final coverH = cardWidth / kDefaultCoverRatio;
  final textH = 8 + 13 * 1.2 + 3 + 11 + 10;
  return coverH + textH;
}
```

- [ ] **Step 3: 清理与静态检查**

Run: `flutter analyze`
Expected: No issues found。若 `TemplateCoverImage` / `GridView` 在本文件不再被引用，移除对应 import（`GridView` 属于 material.dart，无需处理；`TemplateCoverImage` import 若仍被其它处使用则保留）。

- [ ] **Step 4: 既有测试**

Run: `flutter test test/features/templates/templates_page_test.dart test/features/templates/templates_page_dao_test.dart`
Expected: 全部 PASS（`更多模板` 区块仍渲染 6 张卡 → `find.text('免费')` 仍为 6 个，模板名断言不变）。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/templates/widgets/template_grid_card.dart lumira_app_flutter/lib/features/templates/pages/templates_page.dart
git commit -m "feat(templates): 发现页更多模板改瀑布流+卡片封面自适应高度"
```

---

### Task 7: 全量回归 + 目视检查

**Files:**
- Test: `lumira_app_flutter/test/features/templates/`、`lumira_app_flutter/test/features/search/`、`lumira_app_flutter/test/features/gallery/`（相关目录全量）

- [x] **Step 1: 全量静态检查**

Run: `flutter analyze`
Expected: No issues found。
结果：改动涉及的 8 个源文件 + 新增测试文件零 error/warning（新增测试文件 6 条 info 级 `prefer_const_constructors` 已修复提交）。全仓 457 条均为既有 info 级 lint（test/tool 目录），与本次改动无关。

- [x] **Step 2: 相关目录测试**

Run:
```
flutter test test/features/templates test/features/search
```
Expected: 全部 PASS（若 `templates_page_dao_test.dart` 出现既有的 "Local 'db' has not been initialized" 失败，属已知 harness 问题，与本轮改动无关，可跳过并在提交说明中标注）。
结果：`flutter test test/features/templates test/features/search` 共 62 个失败，**全部为基线既有失败**（用 git worktree 在改动前基线 HEAD~8 跑同一套件对比，失败集合与 HEAD 完全一致，`NEW at HEAD = none`；失败根因一致，如 `templates_page_test.dart` 期望 2 个「发现」而测试 router 未挂载 FloatingTabBar 属测试环境问题）。新增 `adaptive_cover_image_test.dart`（15 用例）与 `global_search_page_test.dart` 单独运行全部 PASS。本轮改动未引入任何新增失败。

- [ ] **Step 3: 目视检查（真机/模拟器）**

手动运行 `flutter run --dart-define=API_BASE_URL=...`，检查：
1. 发现页「更多模板」：6 张卡呈瀑布流双列、封面按真实比例完整展示、9:16 封面高度被温和削减。
2. 搜索页模板结果：模板封面自适应；场景/美学院卡片比例不变。
3. 模板库全部模板页 / 我的收藏页：封面自适应、左右两列配平无明显错位、无溢出。
4. 切换 4 套 UI 风格（neumorphic/flat/glass/female）× 主题色，卡片外观正常、无硬编码色残留。

> ⚠️ 本步骤需真机/模拟器手动验证，当前会话无法代跑。请用户真机运行确认后完成。

- [x] **Step 4: 提交（如目视发现问题）**

若目视发现问题，在本会话内修复后提交：
```bash
git add lumira_app_flutter/lib/features/templates lumira_app_flutter/lib/features/search
git commit -m "fix(templates): 瀑布流/自适应封面目视回归修复"
```
结果：本轮回归无目视修复需求；新增测试文件的 lint 清理已单独提交（`0187f35`）。

---

## Self-Review 记录

- **Spec 覆盖**：§3（AdaptiveCoverImage + clamp + 路由）→ Task 1/2；§4.1 收藏页 → Task 3；§4.2 模板库 → Task 4；§4.3 搜索页 → Task 5；§4.4 发现页瀑布流 + TemplateGridCard → Task 6；§5 常量统一引用（kDefaultCoverRatio）→ Task 3/4/5/6；§6 范围边界（场景/美学院保持固定、推荐卡/详情页不动）→ Task 5 显式保留；§7 回归 → Task 7。
- **占位符扫描**：无 TBD/TODO/“类似 Task N”式描述，所有代码步骤给出完整代码。
- **类型一致性**：`AdaptiveCoverImage` 构造参数（cover/coverData/fit/fallback/errorFallback/overlay）在所有任务中一致；`clampCoverRatio`/`buildCoverProvider`/`kDefaultCoverRatio` 签名与 Task 1 定义一致；`_estimateCardHeight`/`_estimateMoreCardHeight` 均引用 `kDefaultCoverRatio`。
