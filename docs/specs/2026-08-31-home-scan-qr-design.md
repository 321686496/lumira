# 首页「扫一扫」入口设计

- 日期：2026-08-31
- 范围：Flutter 端（`lumira_app_flutter/`）
- 状态：已确认，待实现

## 背景与目标

首页右上角目前有通知、礼盒两个入口。需要新增一个「扫一扫」入口，点击进入全屏扫码页，扫描 app 内**所有种类**的码并执行相应操作。

目标：
1. 首页右上角新增扫一扫图标入口，交互与现有 `_NavAction` 一致。
2. 统一扫码页：相机实时扫码 + 相册选图识别（海报/截图里的二维码）。
3. 统一分发：识别文本按格式分类，执行对应操作；恢复码/邀请码跳转对应页面预填，由用户确认。

## 现状梳理（可复用资产）

### App 内所有可解析的码

| 码类型 | 格式 | 现有解析器 | 对应操作 |
|---|---|---|---|
| 模板分享码 | `LUMIRA-{分类}-{名称}` | `TemplateShareCode.parseCode` | 导入模板（离线） |
| 模板离线链接 | `lumira://tpl/{base64}` / `https://lumira.app/tpl?...` | `TemplateShareCode.parseLink` | 离线导入模板 |
| 模板在线 token | `lumira://imp/{token}` / `https://lumira.app/imp/{token}` | `TemplateShareService.parseTokenFromScannedText` | 后端拉取后导入 |
| 恢复码/恢复二维码 | `{scheme}://account-recover?secret=xxx`（或裸 secret） | `recover_account_page._extractSecret` | 找回账号（跳转预填） |
| 邀请码 | 6 位大写字母数字（排除 O/0/I/1，如 `A3B9CK`） | `/invite/activate` | 激活邀请（跳转预填） |

### 现有扫码能力

- `qr_code_scanner` 本地化插件（android/iOS/ohos 原生扫码；web 走引导卡）。
- `TemplateQrScannerPage`：模板扫码导入专用，返回原始文本。
- 恢复页 `_ScannerPage`：含相册选图（zxing2 解码）。
- 模板导入分发逻辑在 `TemplateImportSheet._handleQrImport`。

## 设计方案

### 1. 首页入口

在 `home_page.dart` 的 `LumiraNav` actions 中，通知图标之前新增一个扫一扫图标按钮：

- `_NavAction(icon: Icons.qr_code_scanner, onTap: ...)`，样式与现有 `_NavAction` 完全一致（不新增新组件）。
- 点击 push 全屏扫码页 `ScanQrPage`。

### 2. 统一扫码页 `ScanQrPage`（新建）

- 文件：`lib/features/home/widgets/scan_qr_page.dart`（或按现有组织放 `lib/shared/...`，实现时确认）。
- 复用 `qr_code_scanner` 原生相机扫码（android/iOS/ohos），web 平台沿用引导卡。
- 提供「从相册选择二维码」按钮：调起系统相册选图，用 zxing2 解码（复用恢复页 `_ScannerPage` 的做法），识别海报/截图里的二维码。
- 扫码或选图成功后返回原始文本（`Navigator.pop(context, text)`）。
- UI 遵循 App 设计规范（跟随 `appThemeProvider` / `uiStyleProvider`，不硬编码主题色）。

### 3. 扫码分发器 `ScanCodeDispatcher`（新建）

- 文件：`lib/features/home/services/scan_code_dispatcher.dart`（纯逻辑，可单测）。
- 输入：扫描到的原始文本；输出：识别类型 + 数据 + 执行动作。
- 分类规则（按顺序匹配）：

| 顺序 | 规则 | 类型 | 执行动作 |
|---|---|---|---|
| 1 | 以 `LUMIRA-` 开头 | 模板分享码 | 复用现有分享码导入逻辑导入模板 |
| 2 | 含 `lumira://tpl` 或 `https://lumira.app/tpl` | 模板离线链接 | 复用 `parseLink` + 离线导入 |
| 3 | 含 `lumira://imp` 或 `https://lumira.app/imp` | 模板在线 token | 复用 `parseTokenFromScannedText` + 后端拉取导入 |
| 4 | 含 `account-recover` / `secret=` | 恢复码 | 跳转找回账号页并预填恢复码 |
| 5 | 匹配 6 位安全字母表邀请码 | 邀请码 | 跳转邀请激活页并预填 |
| 6 | 其他 | 未知 | Toast「无法识别的码」 |

### 安全策略

恢复码、邀请码**不直接执行**（避免误操作/账号安全风险），改为跳转到对应页面预填，由用户确认后再触发。模板三类码直接复用现有导入流程（与现有「扫码导入」行为一致）。

## 测试

- `ScanCodeDispatcher` 单测：覆盖 6 种分类分支（分享码/离线链接/在线 token/恢复码/邀请码/未知）+ 边界输入（空串、大小写、多行文本等）。
- 现有模板导入相关测试需保持通过。
- `flutter analyze` 无新增错误。

## 非目标（YAGNI）

- 不改动现有 `TemplateQrScannerPage` / 恢复页 `_ScannerPage` 的内部实现（除非发现必须复用其私有逻辑）。
- 不新增后端接口。
- 不处理 web 端真实扫码（沿用现有 web 引导卡行为）。
- 邀请海报二维码当前为占位图（`_MockupQr`），本次**不**改造为真实二维码，仅让扫一扫能识别邀请码文本并跳转预填。

## 设计自审

- 无 TODO/占位符。
- 范围聚焦单实现计划：3 个改动点（入口 + 扫码页 + 分发器）。
- 各码格式均有既有解析器可复用，分类规则唯一无歧义。
