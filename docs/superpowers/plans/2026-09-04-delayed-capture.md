# 拍摄页延迟拍照（定时拍照）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为拍摄页新增 iOS 原相机风格的延迟拍照：可选 关闭/3s/5s/10s，点快门进入倒计时，中央大数字 + 每秒快门声节拍，倒计时结束再真正拍照，倒计时中再点快门取消。

**Architecture:** 在 `CaptureState` 新增 `delayTimerProvider` 保存所选秒数；将拍摄页 `_onCapture` 拆分为入口（`_onCapture`：处理延时判断/取消）与原拍照体（`_doCapture`）；新增倒计时状态字段 + `Timer.periodic` 驱动数字与节拍；新增 `DelayTimerButton` 浮层按钮（iOS 顶部居中）提供档位选择气泡菜单。

**Tech Stack:** Flutter 3.7.12 / Dart 2.19.6，flutter_riverpod 2.3.6，`camerawesome_ohos`，现有 `SystemSound`、`LumiraToast`、主题 token。

## Global Constraints

- Dart 2.19.6，禁用 Dart 3 records 语法。
- Flutter 端 UI 必须遵循 AGENTS.md Flutter UI 设计规范：所有皮肤相关颜色/阴影/圆角从 `appThemeProvider`（`tokens.*`/`style`）+ `uiStyleProvider` 派生；禁止硬编码主题色。
- 叠在照片/相机上的浮层：新拟态下禁止 `BackdropFilter`（毛玻璃）、禁止外阴影；用半透明暗底 `Color(0xFF141416).withOpacity(...)` + 细描边。激活态强调色统一用现有胶囊色 `Color(0xFFC9A96E)`（与 `AspectRatioSelector`、`CaptureNav` 一致）。
- 改动仅限 `lumira_app_flutter/`；不要改动已废弃的 `lumira-app/`。
- 每次完成提交；本功能为 Flutter 端（非 backend/admin），仅本地 commit，不涉及双远程 push。
- 真实相机 `cameraPreviewOverrideProvider` 用于测试环境注入占位 widget。

---

### Task 1: 新增 `delayTimerProvider` 与档位常量

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/data/capture_state.dart`
- Test: `lumira_app_flutter/test/features/capture/data/capture_state_test.dart`

**Interfaces:**
- Produces:
  - `CaptureState.delayTimerProvider`：`StateProvider<int>`，默认 `0`（无 Provider 依赖）。
  - `CaptureState.delayOptions`：`static const List<int> delayOptions = [0, 3, 5, 10];`

- [ ] **Step 1: 写失败测试**

在 `test/features/capture/data/capture_state_test.dart` 内新增一组：

```dart
group('delayTimerProvider', () {
  test('defaults to 0 (disabled / instant capture)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(CaptureState.delayTimerProvider), 0);
  });

  test('can be set to a selected seconds value', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.delayTimerProvider.notifier).state = 5;
    expect(container.read(CaptureState.delayTimerProvider), 5);
  });

  test('delayOptions exposes off/3/5/10 seconds', () {
    expect(CaptureState.delayOptions, [0, 3, 5, 10]);
  });
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/capture/data/capture_state_test.dart --plain-name delayTimerProvider`
Expected: FAIL — `delayTimerProvider` / `delayOptions` 未定义。

- [ ] **Step 3: 实现**

在 `lib/features/capture/data/capture_state.dart` 中，靠近其他 `StateProvider`（例如 `zoomProvider` 附近）新增：

```dart
/// 延迟拍照可选档位（秒）：0 表示关闭（即时拍照）
static const List<int> delayOptions = [0, 3, 5, 10];

/// 延迟拍照时长（秒）：0 = 关闭（即时拍），可选 3 / 5 / 10
static final delayTimerProvider = StateProvider<int>((ref) => 0);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/capture/data/capture_state_test.dart --plain-name delayTimerProvider`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/capture/data/capture_state.dart lumira_app_flutter/test/features/capture/data/capture_state_test.dart
git commit -m "feat(capture): add delayTimerProvider and delay options"
```

---

### Task 2: 创建 `DelayTimerButton` 浮层按钮

**Files:**
- Create: `lumira_app_flutter/lib/features/capture/widgets/delay_timer_button.dart`
- Test: `lumira_app_flutter/test/features/capture/widgets/delay_timer_button_test.dart`

**Interfaces:**
- Consumes: `CaptureState.delayTimerProvider`、`CaptureState.delayOptions`（Task 1）。
- Produces: `DelayTimerButton`（`ConsumerWidget`，无参构造 `const DelayTimerButton({super.key})`），供 Task 3 渲染。

- [ ] **Step 1: 写失败测试**

创建 `test/features/capture/widgets/delay_timer_button_test.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/widgets/delay_timer_button.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester, {
    int delay = 0,
  }) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(CaptureState.delayTimerProvider.notifier).state = delay;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: DelayTimerButton())),
      ),
    );
    return container;
  }

  testWidgets('shows menu with 关闭/3秒/5秒/10秒 when tapped', (tester) async {
    await pump(tester);
    await tester.tap(find.byType(DelayTimerButton));
    await tester.pumpAndSettle();
    expect(find.text('关闭'), findsOneWidget);
    expect(find.text('3秒'), findsOneWidget);
    expect(find.text('5秒'), findsOneWidget);
    expect(find.text('10秒'), findsOneWidget);
  });

  testWidgets('selecting an option updates delayTimerProvider', (tester) async {
    final container = await pump(tester);
    await tester.tap(find.byType(DelayTimerButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5秒'));
    await tester.pumpAndSettle();
    expect(container.read(CaptureState.delayTimerProvider), 5);
  });

  testWidgets('active state shows selected seconds badge', (tester) async {
    await pump(tester, delay: 3);
    expect(find.text('3s'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/features/capture/widgets/delay_timer_button_test.dart`
Expected: FAIL — `DelayTimerButton` 文件/类不存在。

- [ ] **Step 3: 实现**

创建 `lib/features/capture/widgets/delay_timer_button.dart`：

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/capture_state.dart';

/// 延迟拍照按钮（iOS 原相机风格）
///
/// 取景器顶部居中的小号圆形「时钟」图标按钮。点按弹出锚定气泡菜单
/// （关闭 / 3s / 5s / 10s）。选中后高亮并显示所选秒数角标。
/// 视觉遵循项目「叠照片浮层」取向：半透明暗底 + 细描边，无 blur、无外阴影；
/// 激活态强调色统一用半球胶囊强调色 0xFFC9A96E。
class DelayTimerButton extends ConsumerWidget {
  const DelayTimerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delay = ref.watch(CaptureState.delayTimerProvider);
    final isActive = delay > 0;
    final isNeu = ref.watch(appThemeProvider).style == UIStyle.neumorphic;

    final Widget capsule = GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF141416).withOpacity(0.72),
          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.timer_outlined,
              size: 20,
              color: isActive ? const Color(0xFFC9A96E) : Colors.white,
            ),
            if (isActive)
              Positioned(
                right: 2,
                bottom: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: const BoxDecoration(
                    color: Color(0xFFC9A96E),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Text(
                    '${delay}s',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return PopupMenuButton<int>(
      tooltip: '延迟拍照',
      onSelected: (v) =>
          ref.read(CaptureState.delayTimerProvider.notifier).state = v,
      color: const Color(0xFF26262A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, -6),
      itemBuilder: (context) => [
        for (final d in CaptureState.delayOptions)
          PopupMenuItem(
            value: d,
            height: 40,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  d == 0 ? '关闭' : '$d秒',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                if (d == delay) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check, size: 16, color: Color(0xFFC9A96E)),
                ],
              ],
            ),
          ),
      ],
      child: isNeu ? capsule : capsule,
    );
  }
}
```

> 注：`isNeu` 变量目前两种风格透传同一 `capsule`（叠照片浮层本来就无 blur），保留该变量以显式表达"新拟态不引入毛玻璃"，与 `CaptureNav` 处理一致；未来若需差异化可在此扩展。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/features/capture/widgets/delay_timer_button_test.dart`
Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add lumira_app_flutter/lib/features/capture/widgets/delay_timer_button.dart lumira_app_flutter/test/features/capture/widgets/delay_timer_button_test.dart
git commit -m "feat(capture): add iOS-style DelayTimerButton with duration menu"
```

---

### Task 3: 接入拍摄页 —— 拆分快门、倒计时逻辑与 UI 浮层

**Files:**
- Modify: `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`
  - 状态字段区（约 L155 附近）
  - dispose（L549-566）
  - `_switchCamera`（L1361 附近）
  - build 顶部浮层列（L1835-1883）
  - build Stack 倒计时浮层（L1924 附近）
  - `_onCapture`（L757-936）拆分为 `_onCapture` + `_doCapture`
- Test: `lumira_app_flutter/test/features/capture/capture_page_test.dart`（回归）

**Interfaces:**
- Consumes: `DelayTimerButton`（Task 2）、`CaptureState.delayTimerProvider`（Task 1）、`SystemSound`（`dart:services`，已 import）。
- Produces: `_onCapture()`（快门入口，含延时/取消分支）、`_doCapture()`（原拍照体）、`_startDelayCountdown(int)`、`_cancelDelayCountdown()`、字段 `_delayRemaining` / `_delayTimer`。

- [ ] **Step 1: 先写回归测试确认现状可用**

在 `test/features/capture/capture_page_test.dart` 末尾追加一个冒烟用例（沿用该文件已有的 pump 辅助与 `cameraPreviewOverrideProvider` 注入方式，未 mock 时按住快门不触发真实相机即可）：

```dart
testWidgets('delayTimerProvider default is disabled (regression smoke)', (tester) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
  expect(container.read(CaptureState.delayTimerProvider), 0);
});
```

Run: `flutter test test/features/capture/capture_page_test.dart --plain-name "delayTimerProvider default is disabled"`
Expected: PASS（当前已可通过，确立基线）。

- [ ] **Step 2: 新增倒计时状态字段**

在 `capture_page.dart` 状态字段区（`_shutterTrigger` 附近，L155 后）新增：

```dart
/// 延迟拍照倒计时剩余秒数（>0 表示正在倒计时，0 表示无倒计时）。
int _delayRemaining = 0;

/// 延迟拍照倒计时定时器（1s 周期）。
Timer? _delayTimer;
```

确认顶部已有 `import 'dart:async';`（若缺失则补充，用于 `Timer`）。

- [ ] **Step 3: 新增倒计时启动/取消方法**

在 `_onCapture` 方法（L757）之前新增：

```dart
/// 启动延迟拍照倒计时：中央大数字每秒递减并播放快门声节拍，计时到 0 触发真正拍照。
void _startDelayCountdown(int seconds) {
  _delayTimer?.cancel();
  _delayRemaining = seconds;
  setState(() {});
  SystemSound.play(SystemSoundType.click);
  _delayTimer = Timer.periodic(const Duration(seconds: 1), (t) {
    if (!mounted) {
      t.cancel();
      return;
    }
    if (_delayRemaining <= 1) {
      t.cancel();
      _delayTimer = null;
      setState(() => _delayRemaining = 0);
      _doCapture();
    } else {
      setState(() => _delayRemaining--);
      SystemSound.play(SystemSoundType.click);
    }
  });
}

/// 取消正在进行的延时倒计时（不发生拍照）。幂等，无倒计时时安全。
void _cancelDelayCountdown() {
  _delayTimer?.cancel();
  _delayTimer = null;
  if (_delayRemaining > 0) {
    setState(() => _delayRemaining = 0);
  }
}
```

- [ ] **Step 4: 拆分 `_onCapture` 为入口 + `_doCapture`**

将现有 `_onCapture`（L757 方法签名到 L936 结束）整体重命名为 `_doCapture`（签名 `Future<void> _doCapture() async {`，其余正文不变）。然后在其上方新增入口：

```dart
/// 快门入口：处理延迟拍照。
/// - 正在倒计时 → 再次点击取消延时（不发生拍照，iOS 风格）
/// - 已选延时(>0) 且未在倒计时 → 启动倒计时，不立即拍照
/// - 延时为 0 → 直接拍照
Future<void> _onCapture() async {
  if (_delayRemaining > 0) {
    debugPrint('[capture] _onCapture() cancel delay countdown');
    _cancelDelayCountdown();
    return;
  }
  final delay = ref.read(CaptureState.delayTimerProvider);
  if (delay > 0) {
    debugPrint('[capture] _onCapture() start delay: ${delay}s');
    _startDelayCountdown(delay);
    return;
  }
  await _doCapture();
}
```

> 原有 `_doCapture` 正文首部的试用模式检查、快门声、参数读取等逻辑保持不变，延时路径结束时同样走 `_doCapture`（内部会重新校验试用模式，安全）。

- [ ] **Step 5: dispose 时取消倒计时**

在 `dispose()`（L549-566）中，`_devicePortraitSub?.cancel();` 之后新增：

```dart
_delayTimer?.cancel();
_delayTimer = null;
```

- [ ] **Step 6: 切换摄像头时取消倒计时**

在 `_switchCamera()`（L1361 附近）方法体开头新增：

```dart
// 倒计时进行中切换前后摄像头 → 取消延时
_cancelDelayCountdown();
```

- [ ] **Step 7: build 中插入定时按钮与倒计时浮层**

a. 导入按钮：顶部 import 区（与其他 capture widget import 相邻）新增：

```dart
import '../widgets/delay_timer_button.dart';
```

b. 顶部浮层列（L1835-1883 的 Column 中，`AspectRatioSelector` 之前）第一个子项插入定时按钮（试用模式隐藏，全屏仍常驻显示）：

```dart
// 延迟拍照按钮（iOS 原相机：取景器顶部居中，导航胶囊下方；试用模式隐藏）
if (!isTrialMode) const Padding(
  padding: EdgeInsets.only(bottom: 8),
  child: Center(child: DelayTimerButton()),
),
```

c. 倒计时大数字浮层：在 build 的 Stack 中，`ShutterFeedback`（L1922-1924）之后新增 `Positioned.fill` + `IgnorePointer`（指针穿透到快门，支持"再点快门取消"）：

```dart
// 延时倒计时：全屏中央大数字（IgnorePointer 使其点击穿透到快门按钮 → 点快门取消）
if (_delayRemaining > 0)
  Positioned.fill(
    child: IgnorePointer(
      child: Center(
        child: Text(
          '$_delayRemaining',
          style: const TextStyle(
            fontSize: 120,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            height: 1,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.45),
                blurRadius: 16,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
```

> 中央数字颜色固定为白 + 阴影叠加在照片上，属规范允许的"叠加视觉"，不视为主题色。

- [ ] **Step 8: flutter analyze**

Run: `cd lumira_app_flutter && flutter analyze`
Expected: 无新增 error / warning（仅与本次改动相关的清理项）。

- [ ] **Step 9: 运行测试确认通过**

Run: `flutter test test/features/capture/capture_page_test.dart test/features/capture/widgets/delay_timer_button_test.dart test/features/capture/data/capture_state_test.dart`
Expected: 全部 PASS，确认链路集成与规范回归无破坏。

- [ ] **Step 10: 提交**

```bash
git add lumira_app_flutter/lib/features/capture/pages/capture_page.dart lumira_app_flutter/test/features/capture/capture_page_test.dart
git commit -m "feat(capture): delayed/timed capture with countdown and cancel"
```

---

## Self-Review

**Spec coverage:**
- 状态 `delayTimerProvider` 档位 0/3/5/10 → Task 1 ✅
- iOS 风格顶部定时按钮 + 档位菜单 → Task 2 ✅
- 点快门即倒计时、数字+快门节拍、倒计时结束才拍照 → Task 3 (Steps 3,4) ✅
- 再点快门取消（不进相机）→ Task 3 Step 4 入口分支 ✅
- dispose 取消 / 切镜头取消 → Task 3 Steps 5,6 ✅
- 试用模式隐藏 → Task 3 Step 7b（`!isTrialMode`）✅
- 叠照片浮层规范（暗底细边、禁毛玻璃）、激活色 0xFFC9A96E → Task 2 实现 ✅

**Placeholder scan:** 无 TBD/TODO/空步骤；每步含具体代码与命令。
**Type consistency:** 接口名 `delayTimerProvider`、`delayOptions`、`DelayTimerButton`、`_delayRemaining`、`_delayTimer`、`_startDelayCountdown`、`_cancelDelayCountdown`、`_doCapture` 全篇一致，Task 依赖关系正确。