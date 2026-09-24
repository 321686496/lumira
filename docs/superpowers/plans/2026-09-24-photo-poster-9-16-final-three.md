# 如画 · 9:16 照片海报收敛为最终三款 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把照片分享海报 9:16（fullScreen）由九款（n1-n3 / m3 保留系 / j1-j3）收敛为用户最终选定的**三款**：新增「满版照片」（视觉基准 `docs/preview/poster-9-16-preview-v12.html` 之 `.d1`），保留已实现的 `m3` 竖排刊与 `j1` 立轴（与 v12 的二、三两张一一对应，零改动），删除其余 **7 款**（n1 n2 n3 m1 m2 j2 j3）及其私有件。

**Architecture:** 不改海报架构（`PosterStyleRegistry` → `PosterStyle` → `PosterStyleData` + `PosterCanvas`）。满版照片是九:16 系里唯一「文字压照片」款（用户点名的历史选型稿 stage2·方向1），需要一个共享件库没有的 4 段压暗渐变，故在 `poster_styles_shared.dart` 新增 `PosterFullBleedScrim`；唯一的既有件扩展是给 `PosterKicker` 补 `shadows`（`PosterBrandOnPhoto.scale`、`PosterTitle.shadows`、`PosterAuthorRow.light` 现状**已具备**，仅作回归断言）。注册顺序把新款式放首位，`defaultFor(photo, fullScreen)` 即自动变为满版照片。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6（禁用 Dart 3 records / patterns / class modifiers）；`flutter_test` widget 测试；命令一律在 `d:\app\projects\photo_post\lumira_app_flutter` 目录、PowerShell 下执行。

## Global Constraints

- 画布 **300 × 533.33（9:16）**（`posterCanvasWidth`/`posterFixedHeight` 现状即是），照片满幅 = 整块画布（`photoBuilder(w, h)` 直接铺满，FittedBox cover 在 photoBuilder 内部），零裁切零变形；一张海报一张照片。
- 固定品牌色板 `PosterPalette`（surface `#FDFBF7` / surfaceAlt `#F6F1E8` / gold `#C9A96E` / goldDeep `#B08D4F` / goldSoft `#E8CFA4` / ink `#1A1A1A` / text2 `#6B645C` / text3 `#8E867B` / line `rgba(201,169,110,.32)`）；标题 `posterSerif`、英文 `posterSerifEn`、正文 `posterPlain`；发丝线金色 1px。
- 满版照片的尺寸**逐值取自 v12 `.d1`**（300 宽画布逻辑像素，直接用、不乘 `posterScale`）：内衬 `padding 20/20/18`、kicker 9/goldSoft/ls3、标题 26/白/ls2/h1.3、cat 10/白80%/ls2、二维码白块（`rgba(255,255,255,.94)`、圆角 12、padding `10/12`、QR 52、gap 12）、脚注顶边 `rgba(255,255,255,.28)`。
- 压暗渐变四段（设计稿 `rgba(20,16,10)`：`.18@0% / .02@28% / .62@78% / .74@100%`）：既有 `PosterScrim(bottom:true)` 是 3 段、stops 不符，**必须新增 `PosterFullBleedScrim`，不得改 `PosterScrim` 色值**（有既有测试断言其 stops）。
- 二维码**必须保持高分辨率渲染链路**（`PosterQr` 的 ≥260px 矢量 + FittedBox），满版照片用 `PosterQr(size:52, background:白色, padding:4)` 直挂白块内，不走 `PosterQrMini`。
  - 尺寸推演（已核实 `poster_common.dart:371-398`）：`PosterQr` 容器边长 = `size + widgetPadding`，`widgetPadding => paddingAll * 2`，默认 `paddingAll = 0` → **容器就是 52×52**，`padding: 4` 是容器内部的白色留白，不外加尺寸。白块总高 = 52 + 上下 padding 10×2 = **72**。
- 文案槽位不变：kicker `posterKickerOf(d)`；白块内两行**取完整主/副提示**——第一行 `d.qrHint`（空则 `posterQrHintOf(d)`）=「长按识别 · 查看高清原图」，第二行 `d.qrSub`（空则 `posterQrSubOf(d)`）=「打开如画 · 保存原图」。
  - **不要用 `posterQrMiniLinesOf(d)`**：它（`poster_styles_shared.dart:347-358`）会把主提示按 `·` 拆成两行（`[长按识别, 查看高清原图]`），是给 36px `PosterQrMini` 窄卡用的，与 v12 `.d1` 白块的排版不符。
- 分组语义收敛为「满版 / 画刊 / 画卷」；`group` 机制（`poster_style_picker.dart` 的 `_GroupLabel`）保留不动。
- 每个 Task 结束须 `flutter analyze --no-pub`（无新增 issue）+ 相关测试全绿后 commit；commit message 风格 `feat(poster): <中文描述>` 或 `refactor(poster): <中文描述>`。
- 不改 `lumira-app/`（uni-app 旧项目）；纯 Flutter 改动只 commit，不 push（push 规则只约束 lumira-server 后端/后台）。
- **计数铁律**：删 7 款（n1 n2 n3 m1 m2 j2 j3），不是 6 款；最终 9:16 photo = 3 款（f1 m3 j1）。photo 样式**总数 9 款**（3 款 9:16 + d3/dA/s1 三款 3:4 + pC/dC/dM 三款 1:1），按「样式 × 比例」展开计 **11**（`pC` 一款同时支持 1:1 / 16:9 / 4:3）。两个口径不得混用。

## File Structure

| 文件 | 责任 | 任务 |
| --- | --- | --- |
| `test/shared/widgets/poster/poster_style_registry_test.dart` | 9:16 三款 id 顺序 `[f1,m3,j1]`、默认 f1、分组 `[满版,画刊,画卷]`、photo 合计 9 | T1 |
| `lib/shared/widgets/poster/poster_styles_shared.dart` | 新增 `PosterFullBleedScrim`（4 段压暗） | T2 |
| `lib/shared/widgets/poster/poster_common.dart` | `PosterKicker` +`shadows`（`PosterBrandOnPhoto.scale` 已存在，无需改） | T2 |
| `lib/shared/widgets/poster/photo_poster_styles.dart` | 新增 `_F1FullBleed` + 注册 `f1`；删除 7 款注册项与 9 个死类；改头注释 | T3 |
| `test/shared/widgets/poster/photo_poster_styles_test.dart` | 渲染数 9 → 3 | T3 |
| `lib/shared/widgets/poster/poster_style_registry.dart` / `poster_style_types.dart` / `poster_style_picker.dart` / `poster_seal.dart` | 文档注释同步（九款→三款、示例 id、画卷引用） | T4 |
| `docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md` | 顶部加「已被最终三款取代」横幅 | T4 |
| `docs/future-optimizations.md` | 登记满版照片压字可读性的后续打磨项 | T5 |

## 已核实的关键事实（供执行者免重查）

- 保留款 `m3` = `_M3VerticalColumn`（`photo_poster_styles.dart:638`）、`j1` = `_J1HangingScroll`（:729），与 v12 二/三张一一对应，**版式零改动**。
- 删除类清单（`photo_poster_styles.dart`）：`_N1FullBand`(:269) `_N2AlbumFrame`(:326) `_N3FloatCard`(:373) `_MastBrand`(:449) `_IssueLines`(:469) `_M1Masthead`(:508) `_M2TwinRails`(:562) `_J2PondTop`(:823) `_J3FacingTitle`(:896)。
- **必须保留的私有件**（存活样式仍在用）：`_k`(:156)、`_FramedPhoto`(:161，m3/j1/d3 用)、`_VolNoInline`(:490，m3:660 用)、`_AuthorQrRow`(:219，m3:712 用)、`_FootBar`(:242，m3:714 用)；`PosterSeal` 仅 j1 用，保留。
- id `'d1'` 曾被旧满版款占用且 `docs/design/poster_mockup_selected.html` 仍标着 `stage2 · 方向1 · 满版照片`，新 id 用 **`f1`**（f = full-bleed）避免混淆；全库检索确认样式 id 不落任何持久化（`poster_generator.dart` 仅运行时用 `defaultFor(...).id` 初值）。
- 样式选中不做跨会话持久化：删 id 无脏数据风险（`poster_generator.dart:438` 每次以 `defaultFor` 重置）。
- `PosterBrandOnPhoto({super.key, this.logoSize = 15, this.scale = 1})` 的 `scale` 字段与 `final s = scale;` 驱动（LUMIRA `11*s`/如画 `10*s`/gap `8*s`）**已存在**于 `poster_common.dart:206-238` → Task 2 不改该组件，只加一条回归断言。
- `test/shared/widgets/poster/` 下 **`poster_styles_shared_test.dart` 已存在**（6 个测试文件之一）→ Task 2 Step 1 走「追加 group」分支，不新建文件。
- `PosterKicker`（`poster_common.dart:637-659`）现状**无** `shadows` 参数，是本次唯一需要扩展的既有组件。

---

### Task 1: 注册表测试先行（红）——9:16 收敛为三款

**Files:**
- Modify: `test/shared/widgets/poster/poster_style_registry_test.dart:53-109`（照片组）

**Interfaces:**
- Consumes: 现状注册表（仍为九款）。
- Produces: 断言目标契约 `photo@fullScreen = [f1, m3, j1]`、`defaultFor == f1`、groups `[满版, 画刊, 画卷]`、photo 全比例合计 9；本 Task 结束时该测试**必须为红**（`f1` 尚不存在），由 Task 3 转绿。

- [ ] **Step 1: 改写照片样式测试组**

把 `poster_style_registry_test.dart` 第 53–109 行的 `group('PosterStyleRegistry 照片样式（kind=photo）', ...)` 中以下三个 test 替换为（其余 test——3:4/1:1/16:9/4:3、「既有款不带分组」、通用约束——**原样保留**）：

```dart
  group('PosterStyleRegistry 照片样式（kind=photo）', () {
    test('9:16 提供最终三款（满版照片 / 竖排刊 / 立轴）', () {
      final ids = _ids(PosterKind.photo, PosterRatio.fullScreen);
      expect(ids, <String>[
        'f1', // 满版照片（唯一压字款，排在首位即默认）
        'm3', // 竖排刊
        'j1', // 立轴
      ]);
    });

    test('照片分享默认样式为满版照片（f1）', () {
      final def = PosterStyleRegistry.defaultFor(PosterKind.photo, PosterRatio.fullScreen);
      expect(def?.id, 'f1');
    });
```

并在「9:16 九款带方向分组」test（:90-96）处替换为：

```dart
    test('9:16 三款带方向分组（满版 / 画刊 / 画卷）', () {
      final styles = PosterStyleRegistry.stylesFor(PosterKind.photo, PosterRatio.fullScreen);
      expect(
        styles.map((s) => s.group).toList(),
        <String>['满版', '画刊', '画卷'],
      );
    });

    test('photo 按「样式 × 比例」展开合计 11（守护未误删既有比例款式）', () {
      final total = PosterRatio.values
          .map((r) => PosterStyleRegistry.stylesFor(PosterKind.photo, r).length)
          .fold(0, (a, b) => a + b);
      // 9:16 3 + 3:4 3 + 1:1 3 + 16:9 1 + 4:3 1 = 11
      // （pC 一款同时支持 1:1 / 16:9 / 4:3，故 11 ≠ 样式数 9）
      expect(total, 11);
    });
```

- [ ] **Step 2: 运行确认失败（红）**

Run: `flutter test --no-pub test/shared/widgets/poster/poster_style_registry_test.dart`
Expected: 9:16 三款 / 默认 f1 / 分组三个 FAIL（当前实际 `[n1..j3]`、默认 `n1`）；其余 PASS。

- [ ] **Step 3: Commit**

```powershell
git add test/shared/widgets/poster/poster_style_registry_test.dart
git commit -m "test(poster): 9:16 照片海报收敛为最终三款的注册表断言"
```

---

### Task 2: 共享件扩展——新增 `PosterFullBleedScrim` + `PosterKicker.shadows`

**Files:**
- Modify: `lib/shared/widgets/poster/poster_styles_shared.dart`（在 `PosterScrim` 类结束花括号之后、约 :70 处追加新类）
- Modify: `lib/shared/widgets/poster/poster_common.dart:637-659`（`PosterKicker` 加 `shadows`）
- Test: `test/shared/widgets/poster/poster_styles_shared_test.dart`（**已存在**，在其 `main()` 内追加 group；其 imports 已含 `poster_common.dart` 与 `poster_styles_shared.dart`，**无需补 import**）

**Interfaces:**
- Consumes: `posterPlain` / `PosterPalette`（既有）。
- Produces:
  - `class PosterFullBleedScrim extends StatelessWidget`（const，无参数，暴露 `static const List<Color> colors` / `static const List<double> stops`）——4 段自上而下压暗渐变，供 `_F1FullBleed` 使用；
  - `PosterKicker({..., List<Shadow>? shadows})`；
  - （无需改动）`PosterBrandOnPhoto(scale:, logoSize:)` 现成可用，本 Task 仅加一条回归断言锁定 `scale` 语义。

- [ ] **Step 1: 写失败测试**

该测试文件现状 80 行、6 个用例，imports 已含 `poster_common.dart` 与 `poster_styles_shared.dart`（无需新增 import）。在其 `main()` 末尾（`PosterVerticalText 逐字渲染` test 之后、闭合 `}` 之前）追加：

```dart
  group('满版照片（f1）共享件', () {
    test('PosterFullBleedScrim 四段压暗值/停靠点符合 v12 设计稿', () {
      expect(PosterFullBleedScrim.colors, const [
        Color(0x2E14100A),
        Color(0x0514100A),
        Color(0x9E14100A),
        Color(0xBD14100A),
      ]);
      expect(PosterFullBleedScrim.stops, const [0.0, 0.28, 0.78, 1.0]);
    });

    testWidgets('PosterFullBleedScrim 渲染为自上而下线性渐变', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PosterFullBleedScrim())),
      );
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PosterFullBleedScrim),
          matching: find.byType(DecoratedBox),
        ),
      );
      final grad = (box.decoration as BoxDecoration).gradient as LinearGradient;
      expect(grad.begin, Alignment.topCenter);
      expect(grad.end, Alignment.bottomCenter);
      expect(grad.colors, PosterFullBleedScrim.colors);
    });

    testWidgets('PosterKicker 支持 shadows 透传', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosterKicker(
              text: 'LUMIRA · 如画出品',
              color: PosterPalette.goldSoft,
              shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('LUMIRA · 如画出品'));
      expect(text.style?.shadows?.length, 1);
    });

    testWidgets('PosterKicker 不传 shadows 时保持无阴影（浅色底款不受影响）',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PosterKicker(text: 'LUMIRA · 如画出品')),
        ),
      );
      final text = tester.widget<Text>(find.text('LUMIRA · 如画出品'));
      expect(text.style?.shadows, isNull);
    });

    // 回归锁定：scale 为既有能力，f1 用 0.9 时英文标 11*0.9 = 9.9（设计稿 10px）
    testWidgets('PosterBrandOnPhoto scale 等比缩放英文标字号（既有能力回归）',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PosterBrandOnPhoto(scale: 0.9),
          ),
        ),
      );
      final en = tester.widget<Text>(find.text('LUMIRA'));
      final zh = tester.widget<Text>(find.text('如画'));
      expect(en.style?.fontSize, closeTo(9.9, 0.01));
      expect(zh.style?.fontSize, closeTo(9.0, 0.01));
    });
  });
```

> 说明：渐变常量通过 `PosterFullBleedScrim.colors` / `.stops` 静态常量共享给断言（实现与测试同一来源），避免 `StatelessWidget.build` 需要 `BuildContext` 而无法直调的问题。

- [ ] **Step 2: 运行确认失败（红）**

Run: `flutter test --no-pub test/shared/widgets/poster/poster_styles_shared_test.dart`
Expected: FAIL（`PosterFullBleedScrim` 未定义、`PosterKicker` 无 `shadows` 具名参数 → 编译期报错即视为红）。若最后一条 `PosterBrandOnPhoto` 回归用例已 PASS，属预期（该能力现状即存在）。

- [ ] **Step 3: 实现两处扩展**

`poster_styles_shared.dart`（在 `PosterScrim` 类结束花括号之后插入；文件已 import `poster_common.dart`）：

```dart
/// 满幅照片压字用四段压暗渐变（满版照片 f1 专属，对齐 v12 设计稿 .d1 .scrim）。
///
/// rgba(20,16,10)：.18@0% / .02@28% / .62@78% / .74@100%——顶部轻压保证品牌行
/// 可读、中段几乎透明让照片本体透气、底部加重承载标题与二维码信息。
/// 与通用 [PosterScrim]（三段、stops 不同）互不影响。
class PosterFullBleedScrim extends StatelessWidget {
  const PosterFullBleedScrim({super.key});

  static const List<Color> colors = [
    Color(0x2E14100A),
    Color(0x0514100A),
    Color(0x9E14100A),
    Color(0xBD14100A),
  ];
  static const List<double> stops = [0.0, 0.28, 0.78, 1.0];

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ),
      ),
    );
  }
}
```

`poster_common.dart` — `PosterKicker`（:637-659）加 `shadows`：

```dart
class PosterKicker extends StatelessWidget {
  const PosterKicker({
    super.key,
    required this.text,
    this.color = PosterPalette.goldDeep,
    this.size = 9,
    this.letterSpacing = 3,
    this.weight = FontWeight.w600,
    this.shadows,
  });
  final String text;
  final Color color;
  final double size;
  final double letterSpacing;
  final FontWeight weight;

  /// 文字阴影（压照片款保证可读；浅色底款式不传）。
  final List<Shadow>? shadows;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: posterPlain(size, color: color, weight: weight, letterSpacing: letterSpacing)
          .copyWith(shadows: shadows),
    );
  }
}
```

`poster_common.dart` — `PosterBrandOnPhoto`（:206-238）**不需要改动**：已核实该组件签名为 `PosterBrandOnPhoto({super.key, this.logoSize = 15, this.scale = 1})`，build 内以 `final s = scale;` 驱动英文标 `posterSerifEn(11 * s, letterSpacing: 4 * s)`、中文「如画」`10 * s`、gap `8 * s` / `6 * s`。v12 设计稿 `.d1 .brand-top` 为 logo 15 / en 10 / zh 9 / gap 8 → f1 只传 `scale: 0.9`（11×0.9=9.9≈10、10×0.9=9、logo 取默认 15 即完全对齐），**不传 `logoSize`**。Step 1 中的对应 testWidgets 只作回归锁定。

- [ ] **Step 4: 运行确认通过（绿）**

Run: `flutter test --no-pub test/shared/widgets/poster/poster_styles_shared_test.dart test/shared/widgets/poster/poster_common_test.dart`
Expected: 全绿（该目录下 6 个测试文件为 `poster_style_registry_test` / `photo_poster_styles_test` / `poster_styles_shared_test` / `poster_seal_test` / `poster_common_test` / `poster_ratio_test`；此时 registry 测试仍应为红，属 Task 1 预期，不在本 Step 范围内）。

- [ ] **Step 5: analyze + Commit**

```powershell
flutter analyze --no-pub lib/shared/widgets/poster
git add lib/shared/widgets/poster/poster_styles_shared.dart lib/shared/widgets/poster/poster_common.dart test/shared/widgets/poster/poster_styles_shared_test.dart
git commit -m "feat(poster): 满版照片共享件（四段压暗渐变 + kicker 阴影透传）"
```

---

### Task 3: `_F1FullBleed` 新款式 + 删除七款（注册表转绿）

**Files:**
- Modify: `lib/shared/widgets/poster/photo_poster_styles.dart`（头注释 :9-15、注册列表 :16-154、删除 :269-446 与 :449-560 区段内死类、:823-997 的 `_J2PondTop`/`_J3FacingTitle`）
- Modify: `test/shared/widgets/poster/photo_poster_styles_test.dart:61`（`expect(styles.length, 9)` → `3`）

**Interfaces:**
- Consumes: `PosterFullBleedScrim`、`PosterKicker(shadows:)`、`PosterBrandOnPhoto(scale:)`、`PosterTitle(shadows:)`、`PosterAuthorRow(light:true)`、`PosterQr`、`posterKickerOf`、`posterCanvasWidth/posterFixedHeight`。
- Produces: `PosterStyle(id:'f1', name:'满版照片', groupName:'满版 · 满版照片', group:'满版', kind:photo, ratios:{fullScreen})`，注册于 9:16 首位 → `defaultFor(photo, fullScreen) == f1`；Task 1 的注册表测试转绿。

- [ ] **Step 1: 新款式类（放在 `PosterStyleRegistry` 注释之后、原 `_N1FullBand` 的位置）**

```dart
/// 满版照片（9:16）：照片满幅出血 + 四段压暗渐变上直接压品牌行/标题/二维码。
///
/// 视觉基准 `docs/preview/poster-9-16-preview-v12.html` · 一（源自
/// `docs/design/poster_mockup_selected.html` stage2·方向1，按 533.33 高画布重标）。
/// 9:16 系唯一「文字压照片」款（用户点名的历史选型稿，属「文字不压照片」铁律的
/// 显式例外）；可读性靠 [PosterFullBleedScrim] 与白色二维码块托底。
class _F1FullBleed extends StatelessWidget {
  const _F1FullBleed({required this.data});
  final PosterStyleData data;

  static const List<Shadow> _textShadow = [
    Shadow(color: Color(0x61000000), offset: Offset(0, 1), blurRadius: 6),
  ];

  @override
  Widget build(BuildContext context) {
    final d = data;
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final hint = d.qrHint.isNotEmpty ? d.qrHint : posterQrHintOf(d);
    final sub = d.qrSub.isNotEmpty ? d.qrSub : posterQrSubOf(d);
    return PosterCanvas(
      width: w,
      height: h,
      borderRadius: 0,
      borderColor: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          d.photoBuilder(w, h),
          const PosterFullBleedScrim(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const PosterBrandOnPhoto(scale: 0.9),
                const Spacer(),
                PosterKicker(
                  text: posterKickerOf(d),
                  color: PosterPalette.goldSoft,
                  shadows: _textShadow,
                ),
                const SizedBox(height: 10),
                PosterTitle(
                  text: d.title,
                  color: Colors.white,
                  size: 26,
                  letterSpacing: 2,
                  height: 1.3,
                  shadows: _textShadow,
                ),
                const SizedBox(height: 8),
                PosterCatText(
                  category: d.category,
                  size: 10,
                  color: const Color(0xCCFFFFFF),
                  separatorColor: Colors.white,
                  letterSpacing: 2,
                ),
                const SizedBox(height: 10),
                PosterAuthorRow(
                  name: d.authorName,
                  light: true,
                  avatarSize: 20,
                  whoSize: 10,
                  withSize: 8,
                  gap: 6,
                ),
                const SizedBox(height: 16),
                Container(
                  // v12 .qrblock 是 column flex 的 stretch 项 → 白块通栏（260 宽）
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xF0FFFFFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      PosterQr(
                        data: d.qrData,
                        size: 52,
                        padding: 4,
                        background: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hint,
                            style: posterPlain(11,
                                color: PosterPalette.ink,
                                weight: FontWeight.w600),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            sub,
                            style: posterPlain(9,
                                color: PosterPalette.text3,
                                letterSpacing: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.only(top: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Color(0x47FFFFFF)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'LUMIRA · 如画',
                        style: posterSerifEn(10,
                            color: PosterPalette.goldSoft, letterSpacing: 3),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '如你所见，皆成画卷',
                        style: posterPlain(9,
                            color: const Color(0xB3FFFFFF), letterSpacing: 1),
                      ),
                    ],
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

已核实要点（无需再查）：
- `PosterQr` 容器边长 = `size + widgetPadding`，`widgetPadding => paddingAll * 2`，`paddingAll` 默认 0 → `size: 52` 即 52×52，`padding: 4` 是内部白留白。白块高 = 52 + 10×2 = 72；右侧两行文案高约 11+3+9 = 23 < 72，`Row` 交叉轴默认 center，无溢出风险。
- 二维码两行文案**直取 `d.qrHint` / `d.qrSub`**（空值回退 `posterQrHintOf/posterQrSubOf`），不用 `posterQrMiniLinesOf`（它按 `·` 拆行，只服务 36px `PosterQrMini`）。
- `PosterCatText` 的 `separatorColor` 默认 `goldDeep`，压照片必须显式传 `Colors.white`。
- 设计稿逐值补充（v12 `.d1`）：`.qbtxt .t` = 11px / ink / w600；`.qbtxt .s` = 9px / text3 / ls1；`.brand-foot .name` = 10px Georgia / goldSoft / **ls3**；`.brand-foot .slogan` = **9px** / rgba(255,255,255,.7) = `0xB3FFFFFF` / ls1。上述值已写入 Step 1 代码，若后续回归出现宽度溢出，优先缩窄 `.qbtxt` 字号并同步 v12 基准。

- [ ] **Step 2: 注册新款式并删除七款注册项**

`photo_poster_styles.dart` 注册列表改写为（9:16 区段）：

```dart
List<PosterStyle> photoPosterStyles() => [
      // —— 9:16 · 满版（唯一压字款，排首位即照片分享默认样式）——
      PosterStyle(
        id: 'f1',
        name: '满版照片',
        groupName: '满版 · 满版照片',
        group: '满版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _F1FullBleed(data: d),
      ),
      // —— 9:16 · 画刊（竖排刊）——
      PosterStyle(
        id: 'm3',
        name: '竖排刊',
        groupName: '画刊 · 竖排刊',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M3VerticalColumn(data: d),
      ),
      // —— 9:16 · 画卷（立轴）——
      PosterStyle(
        id: 'j1',
        name: '立轴',
        groupName: '画卷 · 立轴',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J1HangingScroll(data: d),
      ),
      // 3:4 / 1:1 / 16:9 / 4:3 legacy（d3 dA s1 pC dC dM）原样保留
```

删除 `n1 n2 n3 m1 m2 j2 j3` 七个 `PosterStyle(...)` 注册块及注释行 `// —— 9:16 · 方向一 净版...` 等。

- [ ] **Step 3: 删除死类**

删除类：`_N1FullBand` `_N2AlbumFrame` `_N3FloatCard` `_MastBrand` `_IssueLines` `_M1Masthead` `_M2TwinRails` `_J2PondTop` `_J3FacingTitle`（行号见「已核实的关键事实」；按行号**从后往前**删，避免行号漂移）。保留 `_k` `_FramedPhoto` `_VolNoInline` `_AuthorQrRow` `_FootBar`。

同步头注释（:9-15）改为：

```dart
/// 照片分享海报样式集合。
///
/// 9:16 为最终三款（满版照片 f1 / 竖排刊 m3 / 立轴 j1，
/// 视觉基准 docs/preview/poster-9-16-preview-v12.html）：画布与照片同为
/// 9:16（300 × 533.33），文字落在暖白实底/白卡上；唯一例外是 f1 满版照片
/// （用户点名的 stage2·方向1 历史选型稿），以四段压暗渐变保证压字可读。
```

- [ ] **Step 4: 更新渲染测试并运行**

`test/shared/widgets/poster/photo_poster_styles_test.dart:61`：`expect(styles.length, 9);` → `expect(styles.length, 3);`

Run: `flutter test --no-pub test/shared/widgets/poster/`
Expected: 注册表测试（Task 1）转绿；渲染测试 3 款全绿无溢出；poster 目录其余测试（registry/shared/seal/common）全绿。若 f1 出现 RenderFlex overflow，按 v12 数值收紧：标题 26→24、二维码块 vertical padding 10→8（改动记录在 commit message）。

- [ ] **Step 5: analyze + Commit**

```powershell
flutter analyze --no-pub lib
git add lib/shared/widgets/poster/photo_poster_styles.dart test/shared/widgets/poster/photo_poster_styles_test.dart
git commit -m "feat(poster): 9:16 照片海报收敛最终三款（新增满版照片 f1，删除净版/画刊/画卷余七款）"
```

---

### Task 4: 注释与文档同步

**Files:**
- Modify: `lib/shared/widgets/poster/poster_style_registry.dart:11-16`（doc 注释）
- Modify: `lib/shared/widgets/poster/poster_style_types.dart:92`（示例 id 注释 `'pA' / 'n1' / 'pE' / 'ckF'` → `'pA' / 'f1' / 'pE' / 'ckF'`）与 `:101`（分组示例 `净版 / 画刊 / 画卷` → `满版 / 画刊 / 画卷`）
- Modify: `lib/shared/widgets/poster/poster_style_picker.dart:138`（同上分组示例）
- Modify: `lib/shared/widgets/poster/poster_seal.dart:7`（`（⑦ 立轴款行 / ⑧ 诗塘题字 / ⑨ 对题栏尾）` → `（9:16 立轴 j1 款行）`）
- Modify: `docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md`（第 1 行标题后插横幅）
- Modify: `docs/superpowers/plans/2026-09-24-photo-poster-9-16-redesign.md` 不动（历史计划，不改写）

**Interfaces:**
- Consumes: Task 3 后的最终款式集合。
- Produces: 代码注释、设计文档口径 = 「最终三款」；无行为变化。

- [ ] **Step 1: 改四处 dart doc 注释**

`poster_style_registry.dart` 注释第二条改为：

```dart
/// 样式清单严格对应选型稿 `docs/design/poster_mockup_selected.html`
/// （模板 10 款 + 照片 9 款，其中 9:16 为最终选定三款：满版照片 f1 / 竖排刊 m3 / 立轴 j1，
/// 视觉基准 `docs/preview/poster-9-16-preview-v12.html`）；
```

其余三处按 Files 清单逐字替换（纯注释，无逻辑）。

- [ ] **Step 2: 设计文档加取代横幅**

在 spec 文件标题行（`# 如画 · 9:16 照片分享海报重设计（三方向九款）`）之后、`- 日期` 之前插入：

```markdown
> **状态更新（2026-09-24）：本九款方案已被「最终三款」取代。** 用户在九款实现 +
> v11 新四方向探索后，最终仅选定三款：**满版照片**（源自
> `docs/design/poster_mockup_selected.html` stage2·方向1）、**竖排刊**、**立轴**
> （后两者即本文 §4 的 ⑥/⑦），视觉基准为
> `docs/preview/poster-9-16-preview-v12.html`；其余六款（①-⑤、⑧、⑨）已从代码删除。
> 实现计划：`docs/superpowers/plans/2026-09-24-photo-poster-9-16-final-three.md`。
> 本文以下正文作为九款探索过程的历史记录保留。
```

- [ ] **Step 3: 验证 + Commit**

Run: `flutter analyze --no-pub lib` → 0 issue。

```powershell
git add lumira_app_flutter/lib/shared/widgets/poster/poster_style_registry.dart lumira_app_flutter/lib/shared/widgets/poster/poster_style_types.dart lumira_app_flutter/lib/shared/widgets/poster/poster_style_picker.dart lumira_app_flutter/lib/shared/widgets/poster/poster_seal.dart docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md docs/superpowers/plans/2026-09-24-photo-poster-9-16-final-three.md
git commit -m "docs(poster): 9:16 照片海报最终三款口径同步（注释/设计文档取代横幅）"
```

---

### Task 5: 全量验证与登记

**Files:**
- Modify: `docs/future-optimizations.md`（末尾追加）

- [ ] **Step 1: 海报模块全绿**

Run: `flutter test --no-pub test/shared/widgets/poster/`
Expected: PASS（含 f1 渲染）。

- [ ] **Step 2: 全量回归对齐基线**

Run: `flutter test --no-pub > ..\poster-final-three-test.log 2>&1; Select-String -Path ..\poster-final-three-test.log -Pattern 'Some tests failed|All tests passed'`
Expected: 失败数 == **基线 100** 且失败清单不含 `poster` 目录（基线 = 622 通过 / 100 失败，其中 3 例 `checkin_poster_generator_test` 为 BASE 既有失败；本次删掉 6 个 diag 渲染 case 会使总数 −6、若基线中无 photo 失败则失败数不变）。**若失败数 ≠ 100，diff 失败用例名与基线，修复本分支引入项后才可继续。**

- [ ] **Step 3: 登记后续优化**

`docs/future-optimizations.md` 末尾按既有格式追加：

```markdown
---

### [poster/f1 满版照片] 压暗渐变按照片亮度自适应

- **优先级**：P2 ｜ **模块**：Flutter · 海报
- **优化点**：f1 的 `PosterFullBleedScrim` 为固定四段压暗，浅亮照片（雪景/天空）底部 0.74 透明度仍可能压不住白色标题。
- **背景动机**：满版照片是用户点名的唯一压字款，当前逐值照抄 v12 静态设计稿，未做内容自适应。
- **目标状态**：对 `photoBuilder` 输出做粗采样亮度估计，暗图降低压暗强度、亮图提高（或标题区加局部色块），保持零裁切。
- **状态**：📝 登记待做（2026-09-24，随最终三款收敛落地）
```

- [ ] **Step 4: Commit**

```powershell
git add docs/future-optimizations.md
git commit -m "docs(poster): 登记 f1 满版照片压暗自适应后续优化"
```

---

## Self-Review 记录

1. **覆盖**：新增 f1（T2 共享件 + T3 款式）✅；保留 m3/j1 零改动 ✅；删 7 款+9 个死类（T3）✅；默认样式迁移（T1 断言 + T3 注册首位）✅；文档/注释（T4）✅；回归+登记（T5）✅。
2. **无占位**：所有新代码为完整可编译实现；**无「执行时再查」开放项**——`PosterBrandOnPhoto.scale` 已核实存在（`poster_common.dart:206-238`）、`PosterQr` 容器尺寸已核实（`:312-361`，容器 = `size + paddingAll*2`）、`posterQrMiniLinesOf` 已核实为按 `·` 拆行（f1 不使用）、m3/j1 注册块已逐字补入 T3。
3. **命名一致**：`PosterFullBleedScrim` / `f1` / `_F1FullBleed` / 组名「满版」在 T1-T5 全程一致。
