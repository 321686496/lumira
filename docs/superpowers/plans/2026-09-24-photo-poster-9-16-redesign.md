# 如画 · 9:16 照片分享海报重设计（三方向九款）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将照片详情分享海报 9:16（fullScreen）比例下的三款旧样式（d1 满版照片 / dN 多图拼贴 / dL 对角动态）替换为重设计的三方向九款（净版 n1-n3 / 画刊 m1-m3 / 画卷 j1-j3），海报画布与照片同为 9:16（300 × 533.33），文字全部落在暖白实底或白卡上，零遮挡、零裁切。

**Architecture:** 沿用既有海报架构（`PosterStyleRegistry` → `PosterStyle` → `PosterStyleData` + `PosterCanvas` 固定品牌色板）。先调整 `posterFixedHeight(fullScreen)` 使画布变为 9:16；再新增共享小件（`PosterSeal` 小印、`PosterQrMini` 二维码迷你卡、`PosterFootMini` 迷你品牌脚、`PosterPara` 题跋、`PosterVerticalText` 竖排文字）与 `PosterAuthorRow` 字号扩展；随后按方向分三个任务重写九款样式；最后给样式选择条加方向分组并全量验证。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁用 Dart 3 records / patterns / class modifiers）；`flutter_test` widget 测试；命令均在 `d:\app\projects\photo_post\lumira_app_flutter` 目录执行。

## Global Constraints

以下约束对每个任务隐含生效，逐条抄自设计文档（`docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md`）：

- 画布：**300 × 533.33（9:16）**，与照片同比例；照片原生 9:16、`BoxFit.cover` 填充，零裁切零变形；**一张海报只用一张照片**（拼贴双图不回归）。
- 固定品牌色板 `PosterPalette`（不随主题切换）：surface `#FDFBF7` / surfaceAlt `#F6F1E8` / gold `#C9A96E` / goldDeep `#B08D4F` / goldSoft `#E8CFA4` / ink `#1A1A1A` / text2 `#6B645C` / text3 `#8E867B` / line `rgba(201,169,110,.32)`。
- 标题一律 `posterSerif`（思源宋体），英文期号 `posterSerifEn`；发丝线一律金色 1px（`PosterPalette.line` / `PosterPalette.gold`）。
- 禁止：emoji、金色纸边框（整幅海报包金边）、双向浮雕阴影、完全居中的大段文字。
- 文案槽位与现有一致：kicker `LUMIRA · 如画出品`（`posterKickerOf`）、二维码主提示 `长按识别 · 查看高清原图`（拆两行展示）、落款 `@小满 · 用「如画」拍摄`、品牌脚 `LUMIRA · 如画` + `如你所见，皆成画卷`；二维码副文案「打开如画 · 保存原图」暂不上线（Task 8 登记 future-optimizations）。
- 新增编辑/装裱语汇（刊头、`VOL.01` / `第 028 期 · 2026 秋` / `No.028 · 2026 秋`、图注「摄于九月晴午 · 光落在草尖上」、题跋「九月晴午，光落草尖，见之成卷。」、小印「如 / 画」）均为**排版元素**，不引入任何新功能；不新增海报比例、不新增颜色/字体。
- 新九款尺寸为 300 宽画布下的逻辑像素，**直接使用不乘 `posterScale`**（旧 d 系列才乘 k；fullScreen 下 `posterCanvasWidth = 300`）。
- 每个 Task 结束须 `flutter analyze`（无新增 issue）+ 相关 `flutter test` 全绿后立即 commit；commit message 风格 `feat(poster): <中文描述>`。
- 不改 `lumira-app/`（uni-app 旧项目）；纯 Flutter 改动只需 commit，无需 push（CI 验证）。

## File Structure

| 文件 | 责任 | 任务 |
| --- | --- | --- |
| `lib/shared/widgets/poster/poster_common.dart` | `posterFixedHeight` 9:16 化；`PosterAuthorRow` 字号/间距扩展 + 空 suffix 跳过 | T1 / T3 |
| `lib/shared/widgets/poster/poster_seal.dart`（新建） | 画卷小印（22×22 金框圆角 4，竖排两字） | T2 |
| `lib/shared/widgets/poster/poster_styles_shared.dart` | 共享小件：`posterQrMiniLinesOf` / `PosterQrMini` / `PosterFootMini` / `PosterPara` / `PosterVerticalText` | T3 |
| `lib/shared/widgets/poster/photo_poster_styles.dart` | 删除 d1/dL；重写九款（n1-n3 / m1-m3 / j1-j3）+ 私有共享件（`_FramedPhoto` 等） | T4-T6 |
| `lib/shared/widgets/poster/poster_style_types.dart` | `PosterStyle` 新增 `group` 字段（默认 ''） | T7 |
| `lib/shared/widgets/poster/poster_style_picker.dart` | 缩略条按 `group` 插分组标签 | T7 |
| `lib/shared/widgets/poster/poster_style_registry.dart` | 仅修正文档注释中的款式计数 | T4 |
| `test/shared/widgets/poster/poster_common_test.dart`（新建） | 画布高度单测 + 模板 s3 无溢出守护 | T1 |
| `test/shared/widgets/poster/poster_seal_test.dart`（新建） | 小印渲染测试 | T2 |
| `test/shared/widgets/poster/poster_styles_shared_test.dart`（新建） | 共享小件测试 | T3 |
| `test/shared/widgets/poster/photo_poster_styles_test.dart`（新建） | 九款渲染无溢出测试 | T6 |
| `test/shared/widgets/poster/poster_style_registry_test.dart` | 9:16 九款 id 顺序 / 默认 n1 / 分组断言 | T4 / T5 / T6 / T7 |
| `docs/future-optimizations.md` | 登记二维码副文案暂不上线 | T8 |

---

### Task 1: 画布高度 9:16 化（`posterFixedHeight`）

**Files:**
- Modify: `lib/shared/widgets/poster/poster_common.dart:80-81`
- Test: `test/shared/widgets/poster/poster_common_test.dart`（新建）

**Interfaces:**
- Consumes: `posterCanvasWidth`、`posterScale`（同文件既有）。
- Produces: `posterFixedHeight(PosterRatio.fullScreen) == 300 * 16 / 9 ≈ 533.33`；其余比例不变（`760 * posterScale(ratio)`）。副作用：模板 `s3`（fullScreen）画布高由 ≈691 变为 ≈533.33，其内容为 bottom 锚定、实测约 247px，不溢出（本任务测试守护）。

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/poster/poster_common_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_registry.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

PosterStyleData _tplData() => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/tpl/1',
      qrHint: '长按识别 · 查看完整模板',
      qrSub: '打开如画，拍出同款',
      shareText: '测试文案',
      authorName: '',
      photoBuilder: (w, h) => Container(width: w, height: h, color: const Color(0xFFD8D8D8)),
    );

void main() {
  test('posterFixedHeight(fullScreen) = 画布宽 × 16/9（9:16，≈533.33）', () {
    expect(posterFixedHeight(PosterRatio.fullScreen), closeTo(300 * 16 / 9, 0.001));
    expect(
      posterCanvasWidth(PosterRatio.fullScreen) / posterFixedHeight(PosterRatio.fullScreen),
      closeTo(9 / 16, 0.001),
    );
  });

  test('其余比例固定高度沿用 760 × 缩放系数（不变）', () {
    for (final r in const [
      PosterRatio.ratio34,
      PosterRatio.square,
      PosterRatio.ratio43,
      PosterRatio.ratio169,
    ]) {
      expect(posterFixedHeight(r), 760 * posterScale(r));
    }
  });

  testWidgets('模板 fullScreen 三款在新画布高度（≈533.33）下无渲染溢出', (tester) async {
    for (final style in PosterStyleRegistry.stylesFor(PosterKind.template, PosterRatio.fullScreen)) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: style.builder(_tplData())),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${style.id} 不应在 533.33 高度下溢出');
    }
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_common_test.dart`
Expected: FAIL（`posterFixedHeight(fullScreen)` 返回 ≈691，与 533.33 不符）

- [ ] **Step 3: 修改实现**

将 `lib/shared/widgets/poster/poster_common.dart:80-81`：

```dart
/// 固定高度型海报（选型稿 min-height:760）在当前画布宽度下的高度。
double posterFixedHeight(PosterRatio ratio) => 760 * posterScale(ratio);
```

替换为：

```dart
/// 固定高度型海报在当前画布宽度下的高度。
///
/// fullScreen 为 9:16 画布（300 宽）：高 = 宽 × 16/9 ≈ 533.33，与照片同比例，
/// 社交分享全屏展示不裁切；其余比例沿用选型稿（330 宽画布 min-height:760）
/// 的等比缩放值。
double posterFixedHeight(PosterRatio ratio) {
  switch (ratio) {
    case PosterRatio.fullScreen:
      return posterCanvasWidth(ratio) * 16 / 9;
    default:
      return 760 * posterScale(ratio);
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/shared/widgets/poster/poster_common_test.dart`
Expected: PASS（3 个测试全绿；模板 s3 无溢出）

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/poster_common.dart lumira_app_flutter/test/shared/widgets/poster/poster_common_test.dart
git commit -m "feat(poster): fullScreen 海报画布高度 9:16 化（300×16/9≈533.33）"
```

---

### Task 2: 新增 `PosterSeal` 画卷小印

**Files:**
- Create: `lib/shared/widgets/poster/poster_seal.dart`
- Test: `test/shared/widgets/poster/poster_seal_test.dart`（新建）

**Interfaces:**
- Consumes: `poster_common.dart` 的 `posterSerif` / `PosterPalette`。
- Produces: `PosterSeal({String chars = '如画', double size = 22, double fontSize = 8})` —— 22×22 金框圆角 4 方章，竖排前两字（默认「如 / 画」），goldDeep 衬线；Task 6 三款画卷样式使用。

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/poster/poster_seal_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_seal.dart';

void main() {
  testWidgets('PosterSeal 渲染竖排两字且尺寸 22×22', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PosterSeal()),
        ),
      ),
    );
    expect(find.text('如'), findsOneWidget);
    expect(find.text('画'), findsOneWidget);
    final box = tester.getSize(find.byType(PosterSeal));
    expect(box.width, 22);
    expect(box.height, 22);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_seal_test.dart`
Expected: FAIL（`PosterSeal` 未定义 / 文件不存在）

- [ ] **Step 3: 写实现**

创建 `lib/shared/widgets/poster/poster_seal.dart`：

```dart
import 'package:flutter/material.dart';

import 'poster_common.dart';

/// 画卷小印：22 × 22 金框圆角方章，竖排两字（默认「如 / 画」）。
///
/// 用于画卷方向（⑦ 立轴款行 / ⑧ 诗塘题字 / ⑨ 对题栏尾）的款行小印：
/// 色板取 [PosterPalette.goldDeep]，衬线字形，固定品牌资产不随主题切换。
class PosterSeal extends StatelessWidget {
  const PosterSeal({
    super.key,
    this.chars = '如画',
    this.size = 22,
    this.fontSize = 8,
  });

  /// 印文（取前两个字竖排）。
  final String chars;

  /// 印章边长。
  final double size;

  /// 单字字号。
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final glyphs = chars.characters.take(2).toList();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: PosterPalette.goldDeep),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < glyphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            Text(
              glyphs[i],
              style: posterSerif(
                fontSize,
                color: PosterPalette.goldDeep,
                weight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/shared/widgets/poster/poster_seal_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/poster_seal.dart lumira_app_flutter/test/shared/widgets/poster/poster_seal_test.dart
git commit -m "feat(poster): 新增画卷小印 PosterSeal（22×22 金框竖排两字）"
```

---

### Task 3: 共享小件与 `PosterAuthorRow` 扩展

**Files:**
- Modify: `lib/shared/widgets/poster/poster_common.dart:550-582`（`PosterAuthorRow`）
- Modify: `lib/shared/widgets/poster/poster_styles_shared.dart`（文件末尾追加 5 个成员）
- Test: `test/shared/widgets/poster/poster_styles_shared_test.dart`（新建）

**Interfaces:**
- Consumes: Task 2 的 `PosterSeal` 思路（不依赖）；`poster_common.dart` 全部既有部件。
- Produces:
  - `List<String> posterQrMiniLinesOf(PosterStyleData d)` —— 主提示按「·」拆两行，无「·」时回退 `[hint, sub]`。
  - `PosterQrMini({required PosterStyleData data})` —— 白卡 7px padding / 圆角 12 / QR 36（padding 0、白底）/ 两行 8px。
  - `PosterFootMini()` —— 右对齐两行：`LUMIRA · 如画`（8px）+ 标语（7.5px）。
  - `PosterPara({required String text, double size = 9.5, double letterSpacing = 2, double height = 1.6})` —— 衬线 text2 题跋。
  - `PosterVerticalText({required String text, required TextStyle style, double charGap = 2})` —— 逐字 Column 竖排。
  - `PosterAuthorRow` 新增 `whoSize`（默认 11）/ `withSize`（默认 9）/ `gap`（默认 8）参数，`suffix` 为空字符串时跳过落款（向后兼容，既有调用零变化）。

- [ ] **Step 1: 写失败测试**

创建 `test/shared/widgets/poster/poster_styles_shared_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_common.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_styles_shared.dart';

PosterStyleData _data({String hint = '长按识别 · 查看高清原图'}) => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: hint,
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: '小满',
      photoBuilder: (w, h) => SizedBox(width: w, height: h),
    );

void main() {
  test('posterQrMiniLinesOf 按「·」拆两行', () {
    expect(posterQrMiniLinesOf(_data()), <String>['长按识别', '查看高清原图']);
  });

  test('posterQrMiniLinesOf 主提示无「·」时回退副文案', () {
    expect(
      posterQrMiniLinesOf(_data(hint: '长按识别')),
      <String>['长按识别', '打开如画 · 保存原图'],
    );
  });

  testWidgets('PosterAuthorRow 空 suffix 时不渲染落款', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterAuthorRow(name: '小满', suffix: ''),
        ),
      ),
    );
    expect(find.text('@小满'), findsOneWidget);
    expect(find.textContaining('· 用'), findsNothing);
  });

  testWidgets('PosterAuthorRow 自定义字号生效', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterAuthorRow(name: '小满', whoSize: 10, withSize: 8, avatarSize: 18),
        ),
      ),
    );
    final who = tester.widget<Text>(find.text('@小满'));
    expect(who.style?.fontSize, 10);
  });

  testWidgets('PosterPara 使用衬线 text2 样式', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
        ),
      ),
    );
    final t = tester.widget<Text>(find.text('九月晴午，光落草尖，见之成卷。'));
    expect(t.style?.color, PosterPalette.text2);
    expect(t.style?.fontFamily, 'NotoSerifSC');
  });

  testWidgets('PosterVerticalText 逐字渲染', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PosterVerticalText(text: '如画', style: posterPlain(9)),
        ),
      ),
    );
    expect(find.text('如'), findsOneWidget);
    expect(find.text('画'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_styles_shared_test.dart`
Expected: FAIL（`posterQrMiniLinesOf` / `PosterPara` / `PosterVerticalText` 未定义；`whoSize` 参数不存在）

- [ ] **Step 3: 扩展 `PosterAuthorRow`**

将 `lib/shared/widgets/poster/poster_common.dart:550-582` 的 `PosterAuthorRow` 整体替换为：

```dart
/// 照片海报作者行：头像 + @小满 + · 用「如画」拍摄。
class PosterAuthorRow extends StatelessWidget {
  const PosterAuthorRow({
    super.key,
    required this.name,
    this.suffix = '用「如画」拍摄',
    this.light = false,
    this.avatarSize = 24,
    this.justifyCenter = false,
    this.whoSize = 11,
    this.withSize = 9,
    this.gap = 8,
  });

  final String name;
  final String suffix;
  final bool light;
  final double avatarSize;
  final bool justifyCenter;

  /// 「@小满」字号（9:16 新款式用 10 / 8.5）。
  final double whoSize;

  /// 落款「· 用「如画」拍摄」字号（9:16 新款式用 8）。
  final double withSize;

  /// 头像与文字间距（9:16 新款式用 6 / 5）。
  final double gap;

  @override
  Widget build(BuildContext context) {
    final Color who = light ? Colors.white : PosterPalette.ink;
    final Color withC = light ? Colors.white70 : PosterPalette.text3;
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterAvatar(char: name.isEmpty ? 'L' : name.characters.first, size: avatarSize),
        SizedBox(width: gap),
        Text('@$name',
            style: posterPlain(whoSize, color: who, weight: FontWeight.w600, letterSpacing: 1)),
        if (suffix.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text('· $suffix', style: posterPlain(withSize, color: withC, letterSpacing: 1)),
        ],
      ],
    );
    return justifyCenter ? Center(child: row) : row;
  }
}
```

- [ ] **Step 4: 追加共享小件**

在 `lib/shared/widgets/poster/poster_styles_shared.dart` 文件**末尾**追加：

```dart

/// 二维码迷你提示两行：主提示按「·」拆分为两行（副文案暂不上线，
/// 画布高度收紧后 QR 迷你卡仅保留两行，见 docs/future-optimizations.md）。
List<String> posterQrMiniLinesOf(PosterStyleData d) {
  final parts = posterQrHintOf(d)
      .split('·')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  if (parts.length >= 2) {
    return [parts.first, parts.sublist(1).join(' · ')];
  }
  return [posterQrHintOf(d), posterQrSubOf(d)];
}

/// 二维码迷你卡：白卡 + 36px 二维码 + 两行 8px 提示（九款底行通用）。
class PosterQrMini extends StatelessWidget {
  const PosterQrMini({super.key, required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final lines = posterQrMiniLinesOf(data);
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PosterPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PosterQr(
            data: data.qrData,
            size: 36,
            padding: 0,
            radius: 0,
            background: Colors.white,
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                lines.first,
                style: posterPlain(8, color: PosterPalette.ink, weight: FontWeight.w600, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                lines.last,
                style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 迷你品牌脚（右对齐两行）：LUMIRA · 如画 + 如你所见，皆成画卷。
class PosterFootMini extends StatelessWidget {
  const PosterFootMini({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('LUMIRA',
                style: posterSerifEn(8, color: PosterPalette.goldDeep, letterSpacing: 2)),
            const SizedBox(width: 3),
            Text('· 如画', style: posterPlain(8, color: PosterPalette.text3)),
          ],
        ),
        const SizedBox(height: 2),
        Text('如你所见，皆成画卷',
            style: posterPlain(7.5, color: PosterPalette.text3, letterSpacing: 1)),
      ],
    );
  }
}

/// 题跋文本（画卷方向）：衬线 text2，默认 9.5px / 字距 2 / 行高 1.6。
class PosterPara extends StatelessWidget {
  const PosterPara({
    super.key,
    required this.text,
    this.size = 9.5,
    this.letterSpacing = 2,
    this.height = 1.6,
  });

  final String text;
  final double size;
  final double letterSpacing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: posterSerif(
        size,
        color: PosterPalette.text2,
        letterSpacing: letterSpacing,
        weight: FontWeight.w400,
        height: height,
      ),
    );
  }
}

/// 竖排文字：逐字 Column + 固定字距（不用 RotatedBox，字距与基线可控）。
class PosterVerticalText extends StatelessWidget {
  const PosterVerticalText({
    super.key,
    required this.text,
    required this.style,
    this.charGap = 2,
  });

  final String text;
  final TextStyle style;

  /// 相邻两字之间的附加间距。
  final double charGap;

  @override
  Widget build(BuildContext context) {
    final glyphs = text.characters.toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < glyphs.length; i++) ...[
          Text(glyphs[i], style: style),
          if (i < glyphs.length - 1) SizedBox(height: charGap),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run: `flutter test test/shared/widgets/poster/poster_styles_shared_test.dart`
Expected: PASS（6 个测试全绿）

- [ ] **Step 6: 回归 + Commit**

Run: `flutter analyze lib test`（应无新增 issue）后：

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/poster_common.dart lumira_app_flutter/lib/shared/widgets/poster/poster_styles_shared.dart lumira_app_flutter/test/shared/widgets/poster/poster_styles_shared_test.dart
git commit -m "feat(poster): 新增九款共享小件（QR迷你卡/迷你脚/题跋/竖排）并扩展作者行字号"
```

---

### Task 4: 方向一 · 净版（n1 满幅净版 / n2 画册相框 / n3 浮卡叠影）

**Files:**
- Modify: `lib/shared/widgets/poster/photo_poster_styles.dart`（删 95-395 行三个旧类；替换 8-90 行注册表与文档注释；在 `_k` 后插入私有共享件与三个新类）
- Modify: `lib/shared/widgets/poster/poster_style_registry.dart:14-15`（注释计数）
- Modify: `test/shared/widgets/poster/poster_style_registry_test.dart:54-58`

**Interfaces:**
- Consumes: Task 1 的 `posterFixedHeight`（fullScreen ≈ 533.33）；Task 3 的 `PosterQrMini` / `PosterFootMini` / 扩展后的 `PosterAuthorRow`；`poster_common.dart` 既有 `PosterCanvas` / `PosterBrandRow` / `PosterKicker` / `PosterTitle` / `PosterCatText` / `PosterDivider` / `posterSerifEn` / `posterPlain`。
- Produces: 私有 `_FramedPhoto` / `_AuthorQrRow` / `_FootBar`（Task 5/6 复用）；三个样式类 `_N1FullBand` / `_N2AlbumFrame` / `_N3FloatCard`；注册 id `n1` / `n2` / `n3`（group `净版`）。

- [ ] **Step 1: 更新注册表测试（失败）**

将 `test/shared/widgets/poster/poster_style_registry_test.dart:53-61`：

```dart
  group('PosterStyleRegistry 照片样式（kind=photo）', () {
    test('9:16 提供 d1 / dN / dL', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, containsAll(<String>['d1', 'dN', 'dL']));
      expect(ids.length, 3);
    });
```

替换为：

```dart
  group('PosterStyleRegistry 照片样式（kind=photo）', () {
    test('9:16 提供 n1 / n2 / n3（方向一 · 净版）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>['n1', 'n2', 'n3']);
    });

    test('照片分享默认样式为满幅净版（n1）', () {
      final def = PosterStyleRegistry.defaultFor(PosterKind.photo, PosterRatio.fullScreen);
      expect(def?.id, 'n1');
    });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: FAIL（9:16 仍返回 d1/dN/dL）

- [ ] **Step 3: 替换注册表与文档注释**

将 `lib/shared/widgets/poster/photo_poster_styles.dart:8-90`（文档注释 + `photoPosterStyles()` 整个函数）替换为：

```dart
/// 照片详情分享海报样式。
///
/// 9:16 为重设计三方向九款（净版 n1-n3 / 画刊 m1-m3 / 画卷 j1-j3，
/// 设计文档见 docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md）：
/// 画布与照片同为 9:16（300 × 533.33），文字全部落在暖白实底或白卡上。
/// 统一落款 `@小满`，二维码语义为「查看高清原图」。每个样式按 kind=photo +
/// 支持的 ratio 注册到 [PosterStyleRegistry]。
List<PosterStyle> photoPosterStyles() => [
      // —— 9:16 · 方向一 净版（信息与照片彻底分区，文字落在暖白实底/白卡上）——
      PosterStyle(
        id: 'n1',
        name: '满幅净版',
        groupName: '净版 · 满幅净版',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N1FullBand(data: d),
      ),
      PosterStyle(
        id: 'n2',
        name: '画册相框',
        groupName: '净版 · 画册相框',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N2AlbumFrame(data: d),
      ),
      PosterStyle(
        id: 'n3',
        name: '浮卡叠影',
        groupName: '净版 · 浮卡叠影',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N3FloatCard(data: d),
      ),
      // —— 3:4 / 1:1 / 横图既有款（不动）——
      PosterStyle(
        id: 'd3',
        name: '相纸拼贴',
        groupName: '样式四 · 相纸拼贴',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _D3Polaroid(data: d),
      ),
      PosterStyle(
        id: 'dA',
        name: '取景器镜头',
        groupName: '样式五 · 取景器镜头',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _DAViewfinder(data: d),
      ),
      PosterStyle(
        id: 's1',
        name: '大图出血',
        groupName: '样式六 · 大图出血',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => PosterClassicCard(data: d),
      ),
      PosterStyle(
        id: 'pC',
        name: '相纸卡片',
        groupName: '样式七 · 相纸卡片',
        kind: PosterKind.photo,
        ratios: const {
          PosterRatio.square,
          PosterRatio.ratio169,
          PosterRatio.ratio43,
        },
        builder: (d) => PosterPrintCard(data: d),
      ),
      PosterStyle(
        id: 'dC',
        name: '几何构成',
        groupName: '样式八 · 几何构成',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.square},
        builder: (d) => _DCGeometric(data: d),
      ),
      PosterStyle(
        id: 'dM',
        name: '底图倒置',
        groupName: '样式九 · 底图倒置',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.square},
        builder: (d) => _DMBottom(data: d),
      ),
    ];
```

- [ ] **Step 4: 删除旧三类、插入私有共享件与新三类**

4a. 删除 `lib/shared/widgets/poster/photo_poster_styles.dart` 中 `_D1FullPhoto`（95-189 行）、`_DNCollage`（191-286 行）、`_DLDiagonal`（288-395 行）三个类的完整代码（保留其后的 `_D3Polaroid` 及之后所有类不动）。

4b. 在保留的 `_k` 辅助函数之后插入：

```dart
/// 金线装裱照片框：1px 金线外框（可选裱边底色/留白与轻投影），
/// 内部按 9:16 推导照片尺寸并居中，照片零变形（n2/m1/m2/m3/j1/j2/j3 共用）。
class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto({
    required this.data,
    this.mountColor,
    this.mountPadding = EdgeInsets.zero,
    this.boxShadow,
    this.borderRadius = 0,
  });

  final PosterStyleData data;

  /// 裱边底色（画卷方向的 surfaceAlt 装裱）。
  final Color? mountColor;

  /// 裱边留白（画心与金线之间的装裱宽度）。
  final EdgeInsets mountPadding;

  /// 轻投影（双轨夹窗照片窗；单层柔和，非双向浮雕）。
  final List<BoxShadow>? boxShadow;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mountColor,
        border: Border.all(color: PosterPalette.line),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availW = constraints.maxWidth - 2 - mountPadding.horizontal;
          final availH = constraints.maxHeight - 2 - mountPadding.vertical;
          var pw = availH * 9 / 16;
          var ph = availH;
          if (pw > availW) {
            pw = availW;
            ph = availW * 16 / 9;
          }
          return Padding(
            padding: mountPadding,
            child: Center(
              child: SizedBox(
                width: pw,
                height: ph,
                child: data.photoBuilder(pw, ph),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 底行（净版/画刊通用）：作者信息（左）+ 二维码迷你卡（右）。
class _AuthorQrRow extends StatelessWidget {
  const _AuthorQrRow({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PosterAuthorRow(
          name: data.authorName,
          avatarSize: 18,
          whoSize: 10,
          withSize: 8,
          gap: 6,
        ),
        const Spacer(),
        PosterQrMini(data: data),
      ],
    );
  }
}

/// 金线品牌脚（净版/画刊底行）：LUMIRA · 如画 + 标语，顶部 1px 金线。
class _FootBar extends StatelessWidget {
  const _FootBar({this.paddingTop = 7});
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: paddingTop),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PosterPalette.line)),
      ),
      child: Row(
        children: [
          Text('LUMIRA',
              style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 3)),
          const SizedBox(width: 4),
          Text('· 如画', style: posterPlain(9, color: PosterPalette.text3)),
          const Spacer(),
          Text('如你所见，皆成画卷',
              style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
        ],
      ),
    );
  }
}

/// 满幅净版（9:16）：照片满幅零叠字 + 底部 160px 暖白实底信息带。
class _N1FullBand extends StatelessWidget {
  const _N1FullBand({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      borderRadius: 0,
      borderColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          d.photoBuilder(w, h),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                color: PosterPalette.surface,
                border: Border(top: BorderSide(color: PosterPalette.line)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PosterKicker(text: posterKickerOf(d)),
                      const Spacer(),
                      Text('如你所见，皆成画卷',
                          style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
                  const SizedBox(height: 4),
                  PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                  const Spacer(),
                  _AuthorQrRow(data: d),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 画册相框（9:16）：金线相框装裱 9:16 照片的画册内页。
class _N2AlbumFrame extends StatelessWidget {
  const _N2AlbumFrame({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PosterBrandRow(),
              const Spacer(),
              Text('VOL.01',
                  style: posterSerifEn(9, color: PosterPalette.text3, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 172,
              height: 305.78,
              child: _FramedPhoto(data: d),
            ),
          ),
          const SizedBox(height: 12),
          PosterKicker(text: posterKickerOf(d)),
          const SizedBox(height: 3),
          PosterTitle(text: d.title, size: 22, letterSpacing: 2, height: 1.25),
          const SizedBox(height: 3),
          PosterCatText(category: d.category, size: 9, letterSpacing: 2),
          const SizedBox(height: 7),
          _AuthorQrRow(data: d),
          const SizedBox(height: 7),
          const _FootBar(paddingTop: 8),
        ],
      ),
    );
  }
}

/// 浮卡叠影（9:16）：照片满幅 + 白色信息卡悬浮叠底（单层柔和投影）。
class _N3FloatCard extends StatelessWidget {
  const _N3FloatCard({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      borderRadius: 0,
      borderColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          d.photoBuilder(w, h),
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosterPalette.line),
                boxShadow: const [
                  // 设计稿：0 16px 36px -16px rgba(70,55,30,.45)
                  BoxShadow(
                    color: Color(0x7346371E),
                    offset: Offset(0, 16),
                    blurRadius: 36,
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosterKicker(text: posterKickerOf(d)),
                  const SizedBox(height: 5),
                  PosterTitle(text: d.title, size: 22, letterSpacing: 2, height: 1.25),
                  const SizedBox(height: 6),
                  PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                  const SizedBox(height: 8),
                  PosterAuthorRow(
                    name: d.authorName,
                    avatarSize: 20,
                    whoSize: 10,
                    withSize: 8,
                    gap: 6,
                  ),
                  const SizedBox(height: 10),
                  const PosterDivider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PosterQrMini(data: d),
                      const Spacer(),
                      const PosterFootMini(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 修正注册表注释计数**

将 `lib/shared/widgets/poster/poster_style_registry.dart:14-15`：

```dart
/// 样式清单严格对应选型稿 `docs/design/poster_mockup_selected.html`
/// （模板 15 款 + 照片 11 款）；「扫码导入」海报走导出分享流程
```

替换为：

```dart
/// 样式清单严格对应选型稿 `docs/design/poster_mockup_selected.html`
/// （模板 10 款 + 照片 15 款，其中 9:16 为 2026-09-24 重设计三方向九款）；
/// 「扫码导入」海报走导出分享流程
```

- [ ] **Step 6: 运行测试确认通过 + 回归**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: PASS（9:16 = n1/n2/n3，默认 n1）

Run: `flutter analyze lib test`
Expected: 无新增 issue

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/photo_poster_styles.dart lumira_app_flutter/lib/shared/widgets/poster/poster_style_registry.dart lumira_app_flutter/test/shared/widgets/poster/poster_style_registry_test.dart
git commit -m "feat(poster): 9:16 重设计方向一净版三款（满幅净版/画册相框/浮卡叠影）"
```

---

### Task 5: 方向二 · 画刊（m1 刊头装裱 / m2 双轨夹窗 / m3 竖排刊）

**Files:**
- Modify: `lib/shared/widgets/poster/photo_poster_styles.dart`（注册表 n3 条目后、d3 条目前插入 m1-m3 三条目；在 `_N3FloatCard` 类后插入三个私有部件与三个新类）
- Modify: `test/shared/widgets/poster/poster_style_registry_test.dart`（9:16 断言扩为 6 款）

**Interfaces:**
- Consumes: Task 3 的 `PosterVerticalText`；Task 4 的 `_FramedPhoto` / `_AuthorQrRow` / `_FootBar`。
- Produces: 私有 `_MastBrand` / `_IssueLines` / `_VolNoInline`；三个样式类 `_M1Masthead` / `_M2TwinRails` / `_M3VerticalColumn`；注册 id `m1` / `m2` / `m3`（group `画刊`）。

- [ ] **Step 1: 更新注册表测试（失败）**

将 `test/shared/widgets/poster/poster_style_registry_test.dart` 中 Task 4 写入的第一个测试：

```dart
    test('9:16 提供 n1 / n2 / n3（方向一 · 净版）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>['n1', 'n2', 'n3']);
    });
```

替换为：

```dart
    test('9:16 提供 n1-n3 / m1-m3（净版 + 画刊）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>['n1', 'n2', 'n3', 'm1', 'm2', 'm3']);
    });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: FAIL（当前仅 n1/n2/n3）

- [ ] **Step 3: 注册表插入 m1-m3**

在 `lib/shared/widgets/poster/photo_poster_styles.dart` 的注册表中，n3 条目结束的 `),` 之后、`// —— 3:4 / 1:1 / 横图既有款（不动）——` 注释行之前，插入：

```dart
      // —— 9:16 · 方向二 画刊（杂志编辑感：刊头 / VOL 期号 / 发丝线 / 竖排标题）——
      PosterStyle(
        id: 'm1',
        name: '刊头装裱',
        groupName: '画刊 · 刊头装裱',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M1Masthead(data: d),
      ),
      PosterStyle(
        id: 'm2',
        name: '双轨夹窗',
        groupName: '画刊 · 双轨夹窗',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M2TwinRails(data: d),
      ),
      PosterStyle(
        id: 'm3',
        name: '竖排刊',
        groupName: '画刊 · 竖排刊',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M3VerticalColumn(data: d),
      ),
```

- [ ] **Step 4: 插入私有部件与三个新类**

在 `_N3FloatCard` 类结束后插入：

```dart
/// 刊头品牌行（m1 放大版）：logo 16 + LUMIRA 15px 墨色 + 如画。
class _MastBrand extends StatelessWidget {
  const _MastBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PosterLogo(size: 16),
        const SizedBox(width: 8),
        Text('LUMIRA',
            style: posterSerifEn(15, color: PosterPalette.ink, letterSpacing: 4)),
        const SizedBox(width: 5),
        Text('如画', style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 2)),
      ],
    );
  }
}

/// 期号两行（m1 刊头右侧）：VOL.01（金）+ 第 028 期 · 2026 秋。
class _IssueLines extends StatelessWidget {
  const _IssueLines({this.no = '第 028 期 · 2026 秋'});
  final String no;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('VOL.01',
            style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 2)),
        Text(no,
            style: posterPlain(7.5,
                color: PosterPalette.text3, letterSpacing: 1, height: 1.5)),
      ],
    );
  }
}

/// 期号单行（m2/m3 刊头右侧）：VOL.01 + 第 028 期。
class _VolNoInline extends StatelessWidget {
  const _VolNoInline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('VOL.01',
            style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 2)),
        const SizedBox(width: 8),
        Text('第 028 期',
            style: posterPlain(7.5, color: PosterPalette.text3, letterSpacing: 1)),
      ],
    );
  }
}

/// 刊头装裱（9:16）：杂志刊头 + VOL 期号 + 金线装裱照片 + 图注。
class _M1Masthead extends StatelessWidget {
  const _M1Masthead({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _MastBrand(),
              Spacer(),
              _IssueLines(),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: PosterPalette.gold),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(data: d),
                ),
              ),
            ),
          ),
          Text('摄于九月晴午 · 光落在草尖上',
              style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
          const SizedBox(height: 7),
          PosterKicker(text: posterKickerOf(d)),
          const SizedBox(height: 2),
          PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
          const SizedBox(height: 4),
          PosterCatText(category: d.category, size: 9, letterSpacing: 2),
          const SizedBox(height: 7),
          _AuthorQrRow(data: d),
          const SizedBox(height: 7),
          const _FootBar(),
        ],
      ),
    );
  }
}

/// 双轨夹窗（9:16）：上轨刊头 + 中段照片窗 + 下轨信息，分区最彻底。
class _M2TwinRails extends StatelessWidget {
  const _M2TwinRails({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Text('如你所见，皆成画卷',
                    style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                const SizedBox(width: 12),
                const _VolNoInline(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(
                    data: d,
                    boxShadow: const [
                      // 设计稿：0 12px 26px -16px rgba(70,55,30,.4)
                      BoxShadow(
                        color: Color(0x6646371E),
                        offset: Offset(0, 12),
                        blurRadius: 26,
                        spreadRadius: -16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterKicker(text: posterKickerOf(d)),
                const SizedBox(height: 2),
                PosterTitle(text: d.title, size: 20, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 3),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 7),
                _AuthorQrRow(data: d),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 竖排刊（9:16）：左侧竖排衬线标题轨 + 右侧照片，画刊内页感。
class _M3VerticalColumn extends StatelessWidget {
  const _M3VerticalColumn({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                const _VolNoInline(),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 44,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: PosterPalette.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
                  child: Column(
                    children: [
                      PosterVerticalText(
                        text: d.title,
                        style: posterSerif(20, letterSpacing: 7),
                        charGap: 7,
                      ),
                      const SizedBox(height: 12),
                      Container(width: 1, height: 36, color: PosterPalette.gold),
                      const SizedBox(height: 12),
                      PosterVerticalText(
                        text: '如你所见，皆成画卷',
                        style: posterPlain(7.5,
                            color: PosterPalette.text3, letterSpacing: 2),
                        charGap: 2,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: _FramedPhoto(data: d),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PosterKicker(text: posterKickerOf(d)),
                        const SizedBox(height: 3),
                        PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                        const SizedBox(height: 7),
                        _AuthorQrRow(data: d),
                        const SizedBox(height: 7),
                        const _FootBar(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: 运行测试确认通过 + 回归**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: PASS（9:16 = n1-n3 + m1-m3）

Run: `flutter analyze lib test`
Expected: 无新增 issue

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/photo_poster_styles.dart lumira_app_flutter/test/shared/widgets/poster/poster_style_registry_test.dart
git commit -m "feat(poster): 9:16 重设计方向二画刊三款（刊头装裱/双轨夹窗/竖排刊）"
```

---

### Task 6: 方向三 · 画卷（j1 立轴 / j2 诗塘 / j3 对题）

**Files:**
- Modify: `lib/shared/widgets/poster/photo_poster_styles.dart`（注册表 m3 条目后插入 j1-j3 三条目；在 `_M3VerticalColumn` 类后插入三个新类）
- Modify: `test/shared/widgets/poster/poster_style_registry_test.dart`（9:16 断言扩为九款）
- Create: `test/shared/widgets/poster/photo_poster_styles_test.dart`（九款渲染守护）

**Interfaces:**
- Consumes: Task 2 的 `PosterSeal`；Task 3 的 `PosterPara` / `PosterFootMini` / `PosterQrMini` / `PosterVerticalText`；Task 4 的 `_FramedPhoto` / `_AuthorQrRow`。
- Produces: 三个样式类 `_J1HangingScroll` / `_J2PondTop` / `_J3FacingTitle`；注册 id `j1` / `j2` / `j3`（group `画卷`）；9:16 照片海报满九款。

- [ ] **Step 1: 写九款渲染守护测试（失败）**

创建 `test/shared/widgets/poster/photo_poster_styles_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/photo_poster_styles.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_ratio.dart';
import 'package:lumira_app_flutter/shared/widgets/poster/poster_style_types.dart';

PosterStyleData _data() => PosterStyleData(
      ratio: PosterRatio.fullScreen,
      title: '晴空田园少女',
      category: '自然光 · 清新治愈 · 人像写真',
      qrData: 'https://example.com/photo/1',
      qrHint: '长按识别 · 查看高清原图',
      qrSub: '打开如画 · 保存原图',
      shareText: '测试文案',
      authorName: '小满',
      photoBuilder: (w, h) =>
          Container(width: w, height: h, color: const Color(0xFFDDDDDD)),
    );

void main() {
  testWidgets('9:16 九款照片海报均正常渲染且无溢出', (tester) async {
    final styles = photoPosterStyles()
        .where((s) => s.supports(PosterRatio.fullScreen))
        .toList();
    expect(styles.length, 9);
    for (final s in styles) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: s.builder(_data())),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '${s.id} 渲染应无异常');
    }
  });
}
```

- [ ] **Step 2: 更新注册表测试（失败）**

将 `test/shared/widgets/poster/poster_style_registry_test.dart` 中 Task 5 写入的测试：

```dart
    test('9:16 提供 n1-n3 / m1-m3（净版 + 画刊）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>['n1', 'n2', 'n3', 'm1', 'm2', 'm3']);
    });
```

替换为：

```dart
    test('9:16 提供三方向九款（净版/画刊/画卷）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>[
        'n1', 'n2', 'n3', // 净版
        'm1', 'm2', 'm3', // 画刊
        'j1', 'j2', 'j3', // 画卷
      ]);
    });
```

- [ ] **Step 3: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart test/shared/widgets/poster/photo_poster_styles_test.dart`
Expected: FAIL（j1-j3 未注册；九款数量不足）

- [ ] **Step 4: 注册表插入 j1-j3**

在 `lib/shared/widgets/poster/photo_poster_styles.dart` 注册表中，m3 条目结束的 `),` 之后、`// —— 3:4 / 1:1 / 横图既有款（不动）——` 注释行之前，插入：

```dart
      // —— 9:16 · 方向三 画卷（装裱语汇：天头/画心/地头/诗塘/题跋/小印）——
      PosterStyle(
        id: 'j1',
        name: '立轴',
        groupName: '画卷 · 立轴',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J1HangingScroll(data: d),
      ),
      PosterStyle(
        id: 'j2',
        name: '诗塘',
        groupName: '画卷 · 诗塘',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J2PondTop(data: d),
      ),
      PosterStyle(
        id: 'j3',
        name: '对题',
        groupName: '画卷 · 对题',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J3FacingTitle(data: d),
      ),
```

- [ ] **Step 5: 插入三个新类**

在 `_M3VerticalColumn` 类结束后插入：

```dart
/// 立轴（9:16）：天头 / 裱边画心 / 地头三段式装裱结构。
class _J1HangingScroll extends StatelessWidget {
  const _J1HangingScroll({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('如你所见，皆成画卷',
                        style:
                            posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                    Text('No.028 · 2026 秋',
                        style: posterSerifEn(8,
                            color: PosterPalette.goldDeep, letterSpacing: 2)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(
                    data: d,
                    mountColor: PosterPalette.surfaceAlt,
                    mountPadding: const EdgeInsets.all(5),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterTitle(text: d.title, size: 20, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 3),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 6),
                const PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PosterAuthorRow(
                      name: d.authorName,
                      avatarSize: 18,
                      whoSize: 10,
                      withSize: 8,
                      gap: 6,
                    ),
                    const Spacer(),
                    const PosterSeal(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PosterQrMini(data: d),
                    const Spacer(),
                    const PosterFootMini(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 诗塘（9:16）：顶部题字面板（诗塘）+ 画心 + 款行尾轨。
class _J2PondTop extends StatelessWidget {
  const _J2PondTop({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 13),
            decoration: const BoxDecoration(
              color: PosterPalette.surfaceAlt,
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PosterBrandRow(),
                    const Spacer(),
                    Text('No.028 · 2026 秋',
                        style: posterSerifEn(8,
                            color: PosterPalette.goldDeep, letterSpacing: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                PosterKicker(text: posterKickerOf(d)),
                const SizedBox(height: 3),
                PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 4),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
                    Spacer(),
                    PosterSeal(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(data: d),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: _AuthorQrRow(data: d),
          ),
        ],
      ),
    );
  }
}

/// 对题（9:16）：左题跋栏 + 右画心并置 + 尾轨（分类 + 二维码）。
class _J3FacingTitle extends StatelessWidget {
  const _J3FacingTitle({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Text('No.028 · 2026 秋',
                    style: posterSerifEn(8,
                        color: PosterPalette.goldDeep, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: PosterPalette.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PosterKicker(
                        text: posterKickerOf(d),
                        size: 8.5,
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 8),
                      PosterTitle(text: d.title, size: 19, letterSpacing: 1, height: 1.3),
                      const SizedBox(height: 8),
                      const PosterPara(
                        text: '九月晴午，光落草尖，见之成卷。',
                        size: 8.5,
                        letterSpacing: 1,
                        height: 1.8,
                      ),
                      const Spacer(),
                      const PosterSeal(),
                      const SizedBox(height: 8),
                      PosterAuthorRow(
                        name: d.authorName,
                        suffix: '',
                        avatarSize: 16,
                        whoSize: 8.5,
                        gap: 5,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: SizedBox(
                        width: 184,
                        height: 327.11,
                        child: _FramedPhoto(data: d),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const Spacer(),
                PosterQrMini(data: d),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: 运行测试确认通过 + 回归**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart test/shared/widgets/poster/photo_poster_styles_test.dart`
Expected: PASS（九款 id 顺序正确；九款渲染无异常无溢出）

Run: `flutter analyze lib test`
Expected: 无新增 issue

- [ ] **Step 7: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/photo_poster_styles.dart lumira_app_flutter/test/shared/widgets/poster/poster_style_registry_test.dart lumira_app_flutter/test/shared/widgets/poster/photo_poster_styles_test.dart
git commit -m "feat(poster): 9:16 重设计方向三画卷三款（立轴/诗塘/对题），九款齐备"
```

---

### Task 7: 样式选择条方向分组

**Files:**
- Modify: `lib/shared/widgets/poster/poster_style_types.dart:81-108`（`PosterStyle` 新增 `group`）
- Modify: `lib/shared/widgets/poster/poster_style_picker.dart`（缩略条分组）
- Modify: `test/shared/widgets/poster/poster_style_registry_test.dart`（分组断言）

**Interfaces:**
- Consumes: Task 4-6 注册的 `group`（净版/画刊/画卷；其余款为 ''）；Task 3 的 `PosterVerticalText`。
- Produces: `PosterStyle.group`（默认 `''`，向后兼容）；`PosterStylePicker` 在同组首款前插入竖排分组标签（金色短竖条 + 竖排组名）。

- [ ] **Step 1: 写失败测试**

在 `test/shared/widgets/poster/poster_style_registry_test.dart` 的照片 group 中追加：

```dart
    test('9:16 九款带方向分组（净版 / 画刊 / 画卷）', () {
      final styles = PosterStyleRegistry.stylesFor(PosterKind.photo, PosterRatio.fullScreen);
      expect(
        styles.map((s) => s.group).toList(),
        <String>['净版', '净版', '净版', '画刊', '画刊', '画刊', '画卷', '画卷', '画卷'],
      );
    });

    test('既有 3:4 / 1:1 款不带分组（group 为空）', () {
      for (final ratio in const [
        PosterRatio.ratio34,
        PosterRatio.square,
        PosterRatio.ratio169,
        PosterRatio.ratio43,
      ]) {
        for (final s in PosterStyleRegistry.stylesFor(PosterKind.photo, ratio)) {
          expect(s.group, isEmpty, reason: '${s.id} 不应分组');
        }
      }
    });
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: FAIL（`group` getter 不存在）

- [ ] **Step 3: `PosterStyle` 新增 `group` 字段**

将 `lib/shared/widgets/poster/poster_style_types.dart:81-89`：

```dart
class PosterStyle {
  const PosterStyle({
    required this.id,
    required this.name,
    required this.groupName,
    required this.kind,
    required this.ratios,
    required this.builder,
  });
```

替换为：

```dart
class PosterStyle {
  const PosterStyle({
    required this.id,
    required this.name,
    required this.groupName,
    required this.kind,
    required this.ratios,
    required this.builder,
    this.group = '',
  });

  /// 样式选择条分组标签（如「净版 / 画刊 / 画卷」；为空表示不分组）。
  final String group;
```

- [ ] **Step 4: 选择条分组渲染**

将 `lib/shared/widgets/poster/poster_style_picker.dart` 的 import 区（1-4 行）：

```dart
import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_style_types.dart';
```

替换为：

```dart
import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_style_types.dart';
import 'poster_styles_shared.dart';
```

将 `_PosterStylePickerState` 类（39-106 行）整体替换为：

```dart
class _PosterStylePickerState extends State<PosterStylePicker> {
  /// 底部紧凑缩略卡尺寸（有意做小，视觉重心留给主效果卡片）。
  static const double _thumbWidth = 58;
  static const double _thumbHeight = 72;
  static const double _stripHeight = _thumbHeight + 20;
  static const double _groupLabelWidth = 18;

  /// 每个样式的缩略图在 initState 时构建一次并缓存，
  /// 后续选中切换不再重建（仅外层选中态装饰变化）。
  late final Map<String, Widget> _thumbs;

  /// 横向滚动项：分组标签（同组首款前插入一次）+ 缩略卡。
  late final List<_PickerItem> _items;

  @override
  void initState() {
    super.initState();
    _thumbs = {for (final s in widget.styles) s.id: s.builder(widget.data)};
    _items = _buildItems();
  }

  List<_PickerItem> _buildItems() {
    final items = <_PickerItem>[];
    String? current;
    for (final s in widget.styles) {
      if (s.group.isEmpty) {
        current = null;
      } else if (s.group != current) {
        items.add(_PickerItem.group(s.group));
        current = s.group;
      }
      items.add(_PickerItem.style(s));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              const Text(
                '选择版式',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PosterPalette.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '左右滑动卡片切换',
                style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              final style = item.style;
              if (style == null) return _GroupLabel(item.label!);
              return _CompactTab(
                name: style.name,
                selected: style.id == widget.selectedId,
                onTap: () => widget.onSelect(style.id),
                child: _thumbs[style.id]!,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 选择条横向滚动项：分组标签或缩略卡。
class _PickerItem {
  const _PickerItem.group(this.label) : style = null;
  const _PickerItem.style(this.style) : label = null;

  final String? label;
  final PosterStyle? style;
}

/// 分组标签：金色短竖条 + 竖排组名（净版 / 画刊 / 画卷）。
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PosterStylePickerState._groupLabelWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 2, height: 8, color: PosterPalette.gold),
          const SizedBox(height: 3),
          PosterVerticalText(
            text: label,
            style: posterPlain(
              9,
              color: PosterPalette.goldDeep,
              weight: FontWeight.w600,
              letterSpacing: 1,
            ),
            charGap: 1,
          ),
        ],
      ),
    );
  }
}
```

（`_CompactTab` 类保持不变。）

- [ ] **Step 5: 运行测试确认通过 + 回归**

Run: `flutter test test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: PASS（分组断言通过）

Run: `flutter analyze lib test`
Expected: 无新增 issue

- [ ] **Step 6: Commit**

```bash
git add lumira_app_flutter/lib/shared/widgets/poster/poster_style_types.dart lumira_app_flutter/lib/shared/widgets/poster/poster_style_picker.dart lumira_app_flutter/test/shared/widgets/poster/poster_style_registry_test.dart
git commit -m "feat(poster): 样式选择条按方向分组（净版/画刊/画卷）"
```

---

### Task 8: 全量验证与文档登记

**Files:**
- Modify: `docs/future-optimizations.md`（末尾追加一节）

**Interfaces:**
- Consumes: Task 1-7 全部产物。
- Produces: 全量绿测 + 二维码副文案暂不上线的后续优化登记。

- [ ] **Step 1: 全量测试**

Run: `flutter analyze lib test`
Expected: No issues found

Run: `flutter test`
Expected: All tests passed（含既有 poster_generator_test / poster_ratio_test / 本次新增/改动的全部测试）

- [ ] **Step 2: 人工核对清单（逐款对照 HTML 选型稿）**

打开 `docs/preview/poster-9-16-preview-v10.html`，在 App 内对九款逐款核对（结构 / 字号 / 间距 / 照片 9:16 比例）：
1. 照片均原生 9:16、无变形无拼贴；
2. 无文字压照片；无文字溢出画布；
3. 缩略条 9 张缩略卡 + 净版/画刊/画卷三个竖排分组标签，QR 为品牌占位图形；
4. 导出海报（1080 宽）后二维码可被 App「扫一扫」识别。

- [ ] **Step 3: 登记后续优化**

在 `docs/future-optimizations.md` 末尾追加：

```markdown

---

## 照片分享海报 · 9:16 重设计（2026-09-24）

### P2 · 9:16 海报二维码副文案「打开如画 · 保存原图」暂并入主提示两行

- **模块**：照片分享海报（Flutter：`poster_styles_shared.dart` 的 `posterQrMiniLinesOf` / `PosterQrMini`）
- **优化点**：9:16 画布高度由 ≈691 收紧到 300×16/9≈533.33 后，二维码迷你卡仅展示主提示拆分两行（「长按识别 / 查看高清原图」），副文案「打开如画 · 保存原图」未单独展示。
- **背景/动机**：画布高度收紧 + 信息带/浮卡垂直空间有限，副文案入卡会挤压标题/作者行或导致溢出；HTML 设计稿基准（poster-9-16-preview-v10.html）同样只保留两行。
- **目标状态**：后续若重新分配画布信息区空间（或将副文案与主提示合并为一句完整文案），在 QR 迷你卡中恢复「主提示 + 副提示」完整语义。
- **状态**：⏳ 待优化
```

- [ ] **Step 4: Commit**

```bash
git add docs/future-optimizations.md
git commit -m "docs: 登记 9:16 海报二维码副文案暂不上线的后续优化"
```

---

## Self-Review 记录（计划自检）

1. **Spec 覆盖**：§2.1 画布 300×533.33 → Task 1；九款逐款结构/尺寸/文案 → Task 4/5/6（尺寸逐条对齐 v10 HTML：① band 160 + padding 14/24/12 + title 24 + QR 36；② frame 172×305.78 + padding 20；③ 浮卡 left/right 22 bottom 18 圆角 16 padding 18/20；④ 刊头 logo16/LUMIRA15/期号两行 + 金线 + 图注 8px；⑤ 上下轨 40px + 轻投影；⑥ spine 44px 竖排 20px ls7 + 36px 金线 + 竖排标语 7.5px；⑦ 天头 46px + 裱边 surfaceAlt padding 5 + 地头题跋/小印；⑧ 诗塘 surfaceAlt + 题跋 + 尾轨；⑨ col 88px + heart 184×327.11 + 尾轨）；§5 组件改动点表 → Task 1/2/3/7；§6 YAGNI（副文案不上线）→ Task 8；§7 验证 → Task 8。
2. **占位符扫描**：无 TBD/TODO；所有代码步骤均为完整代码；无「类似 Task N」引用（跨任务的注册表插入均给出锚点与完整代码）。
3. **类型一致性**：`PosterSeal` / `PosterQrMini` / `PosterFootMini` / `PosterPara` / `PosterVerticalText` / `posterQrMiniLinesOf` 在 Task 3 定义，Task 4-7 使用的签名一致；`_FramedPhoto` / `_AuthorQrRow` / `_FootBar` 在 Task 4 定义，Task 5/6 复用一致；`PosterStyle.group` 在 Task 7 定义并立即被 Task 4-6 注册使用（字段带默认值，Task 4-6 编译不依赖 Task 7）；id 顺序 `n1-n3/m1-m3/j1-j3` 在 Task 4/5/6 与测试中断言一致。
