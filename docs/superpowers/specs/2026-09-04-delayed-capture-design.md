# 拍摄页延迟拍照（定时拍照）功能设计

日期：2026-09-04
模块：`lumira_app_flutter/lib/features/capture/`
主文件：`pages/capture_page.dart`、`data/capture_state.dart`

## 背景与动机

拍摄页（`CapturePage`，`ConsumerStatefulWidget`）当前为即时拍照：快门入口 `_onCapture()`（L757）直接调用 `cameraService.capture()` 并进入后处理队列。需要新增「延迟拍照（定时拍照）」能力，便于自拍、摆拍、合影等场景。项目无任何现有定时/延时代码，需全新实现。

## 目标

- 用户可在拍摄页选择延迟时长（关闭 / 3s / 5s / 10s）。

- 点快门后进入倒计时，中央显示大号数字并每秒播放快门声节拍，倒计时结束才真正拍照。

- 倒计时期间再次点快门取消延时，不发生拍照。

- 交互与视觉遵循 iOS 原生相机风格；UI 按当前主题 4 套风格自适应。

## 非目标（YAGNI）

- 不支持连拍；倒计时期间无连拍概念。

- 不新增独立的分镜/多张连拍/间隔拍摄。

- 不做跨省电/后台计时（离开页面即取消）。

## 状态设计

在 `CaptureState`（`data/capture_state.dart`）新增：

```dart
/// 延迟拍照时长（秒）：0 = 关闭（即时拍），可选 3 / 5 / 10
static final delayTimerProvider = StateProvider<int>((ref) => 0);
```

档位常量：`const delayOptions = [0, 3, 5, 10];`（0 显示为「关闭」）。

## UI 设计（iOS 原相机风格）

### 定时按钮

- 位置：取景器顶部居中、导航胶囊（`CaptureNav`）下方，浮动于取景器上的一个小号圆形「时钟」图标按钮（`Positioned` 于 Stack 中，位于导航栏之后）。

- 常态：半透明白色描边圆形图标。

- 激活态：高亮 + 角标显示所选秒数（如「3s」），秒数随档位变化。

- 点按：弹出锚定的气泡菜单，选项为 关闭 / 3s / 5s / 10s，选中项打勾。

- 全屏 / 普通模式均常驻显示（对齐 iOS 横竖屏均保留定时控件）。

- 试用模式隐藏（不允许拍照）。

- 视觉：复用既有「叠照片浮层」取向（`_NavIcon` 同款半透明暗底、无 blur/无外阴影风格），新拟态下同样禁止毛玻璃。

### 倒计时浮层

- 位置：取景器中央。

- 内容：大号数字（3、2、1）每秒递减；不额外加取消按钮（取消=再点快门，iOS 风格）。如需可读性，数字带轻微阴影/描边。

## 交互流程

1. 选择延时：点时钟图标 → 弹菜单选档 → `delayTimerProvider` 更新为对应秒数，按钮变激活态。
2. 点快门（`_onCapture` 入口）：

   - 现有 `_onCapture` 拆分为 **`_onCapture`（入口）+** **`_doCapture`（现有完整拍照体）**。

   - `_onCapture` 中读取 `delayTimerProvider`：

     - 若未在倒计时且延时 > 0 → 启动倒计时，**不立即拍照**。

     - 若正在倒计时 → **取消倒计时**，不发生拍照。

     - 若延时为 0 → 直接走 `_doCapture`。

   - 倒计时期间快门点击命中「取消」分支，避免相机服务重复调用。
3. 倒计时逻辑（`Timer.periodic`）：

   - `_delayRemaining` 从已选秒数开始；每 1s 递减并通过 `setState` 更新中央数字，播放 `SystemSound.click` 节拍。

   - 递减到 0 → `timer.cancel()`，清空中倒计时状态与数字，调用 `_doCapture()` 真正拍照。
4. 边界：

   - `dispose()` 取消计时器（离开页面或页面重建）。

   - 倒计时进行中尝试切换前后摄像头 / 比例 / 模板 → 直接取消倒计时（仓库语义：倒计时一旦开始即锁定，切换即中止）。

   - 试用模式隐藏入口。

   - 真正拍照的快门声仍走 `_doCapture` 原有逻辑；节拍仅延时期间生效。

## 错误处理与测试

- 相机服务 `capture()` 的异常继续由 `_doCapture` 现有 try/catch 处理（拍照失败 toast）。

- 倒计时阶段不触碰相机服务，仅在计到 0 时调用 `_doCapture`。

- 验证方式：`flutter analyze` 通过；手动验证各档位倒计时/取消/切换交互。

## 涉及文件

- `lumira_app_flutter/lib/features/capture/data/capture_state.dart`：新增 `delayTimerProvider` + 档位常量。

- `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`：

  - 拆分 `_onCapture` / `_doCapture`。

  - 新增倒计时状态字段、`Timer`、`_startDelayCountdown()` / `_cancelDelayCountdown()`。

  - build 中添加定时按钮（顶部居中）与倒计时数字浮层。

- 新增 `lumira_app_flutter/lib/features/capture/widgets/delay_timer_button.dart`（可选，若按钮较复杂，否则内联到 capture\_page 私有 widget）。

