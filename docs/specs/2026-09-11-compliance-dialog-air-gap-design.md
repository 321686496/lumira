# 合规检查弹窗（Splash 首启门控）设计

> 日期：2026-09-11
> 范围：Flutter 端（`lumira_app_flutter/`）
> 状态：已批准（用户确认「按这个方案来」）

## 1. 背景与目标

国内 App 上架合规要求：**在收集个人信息 / 联网注册设备之前，必须先征得用户同意**。

当前 [`main.dart`](../../lumira_app_flutter/lib/main.dart) 在 `runApp` **之前**即完成：
打开 SQLite、向服务器注册设备（采集设备信息）、发起设备信息上报与多项后台同步。

目标：新增「合规检查弹窗」，仅在安排时弹出（首启或协议版本更新），用户**同意后才进行数据初始化与联网/采集**，不同意则退出 App。

## 2. 需求要点（用户确认）

- **拦截级别：严格** —— 同意完成前，不注册设备、不上报设备信息、不发任何后台网络同步。
- **弹窗形式：链接式 + 同意/不同意** —— 正文提示 + 可点击《用户协议》《隐私政策》《个人信息清单与第三方SDK目录》，按钮为「不同意并退出」/「同意并开始使用」。
- **版本重问** —— 持久化已同意时的文档版本；文档内容更新后，下次启动重新弹出再次征得同意。

## 3. 架构

遵循既有 `user_settings` 单行表 + Riverpod Provider 模式，新增「合规门控」模块，把启动拆为「同意前」与「同意后」两段。

```
main() 启动
 ├─ 本地阶段(合规无关)：打开 SQLite、读 compliance 状态、bootstrap AuthController(读本地 token)
 ├─ 分岔：awaitingCompliance = 未同意 或 已同意版本 ≠ 当前版本
 │    ├─ 是 → 跳过注册/联网同步，注入 awaitingCompliance=true，runApp
 │    │       Splash 弹窗； 同意→落库→触发 runPostComplianceInit()； 不同意→退出
 │    └─ 否 → 维持现状：即刻 registerIfNeeded + runPostComplianceInit()，Splash 正常跳转
 └─ runPostComplianceInit(container)：设备信息上报 + 个人资料/使用次数/内置数据同步
```

## 4. 改动点

| 文件 | 改动 |
|------|------|
| `lib/core/db/tables.dart` | `user_settings` 新增列：`compliance_agreed`(INT 0)、`compliance_version`(TEXT)、`compliance_agreed_at`(INT) |
| `lib/core/db/database_provider.dart` | DB 版本 `_kDbVersion` 56→57；`_onCreate` 表结构加 3 列；`_onUpgrade` 用现有 `_addColumnIfNotExists` 加 3 列（幂等） |
| `lib/core/db/dao/settings_dao.dart` | `getComplianceAgreement()`（版本/时间，默认未同意）与 `setComplianceAgreed(version, [...timestamp])` |
| `lib/core/compliance/compliance_gate.dart`（新） | `ComplianceGate.version` 常量（对齐 `ComplianceDocs` 更新日期）；`awaitingComplianceProvider`(StateProvider)；`runPostComplianceInit(ProviderContainer)`（从 main() 抽出） |
| `lib/features/splash/pages/splash_page.dart` | 判定 awaiting → 首帧后弹窗；同意/退出逻辑 |
| `lib/features/splash/widgets/compliance_dialog.dart`（新） | 合规弹窗 UI（链接式+同意/不同意），按当前 UI 风格/主题自适应 |
| `lib/main.dart` | 开机读状态 → awaiting 时跳过注册/同步；同步链抽到 `runPostComplianceInit` |

> 依赖 API：`WidgetRef.container`（Riverpod 2.3.6 支持），供 Splash 在同意后触发 `runPostComplianceInit(ref.container)`。

## 5. 弹窗交互（链接式 + 同意/不同意）

- **标题**：「用户协议与隐私政策」
- **正文**：隐私强调文案 + 可点击链接《用户协议》《隐私政策》《个人信息清单与第三方SDK目录》（点击走现有 `ComplianceDocPage` 路由，弹窗保持打开）。
- **按钮**：「不同意并退出」（次要）/「同意并开始使用」（主按钮）。
- **样式**：遵循 `appThemeProvider`(tokens) + `uiStyleProvider` 四套 UI 风格，不硬编码颜色。
- **退出**：`exit(0)`（`dart:io`）；HarmonyOS/Android 亦可用 `SystemNavigator.pop()`。

## 6. 数据流

- **首次安装**：无同意记录 → awaiting=true → 弹窗；同意→写库(记录版本+时间)→`registerIfNeeded`→`runPostComplianceInit`→auth registered→跳转（questionnaire 或 home）。
- **老用户（已有本地数据/token）**：同意记录版本≠当前版本 → 弹一次；同意后走注册（已有 token 则 `ensureRegistered` 直接返回）。
- **版本更新**：`ComplianceGate.version` 随文档更新递增 → 已同意用户下次启动重新弹。

## 7. 错误 / 边界处理

- **写库失败**：不阻塞——仍继续初始化并跳转，避免用户被卡死。
- **不同意退出**：本地保持未同意，下次启动仍弹。
- **DB 迁移**：`_addColumnIfNotExists` 幂等，升级不丢数据。
- **`_maybeNavigate` 早退安全**：awaiting 时 auth 未注册，splash 既有 redirect 逻辑 no-op，不会提前跳转。

## 8. 不做（YAGNI）

- 不做服务端记录同意时间/IP。
- 不做强制阅读倒计时 / 勾选强制项（用户已选链接式，无需强制勾选）。
- 不调整 `ComplianceDocPage` 现有渲染与路由。

## 9. 测试

- `flutter analyze` 通过。
- 手动：全新安装首次启动弹窗；同意后正常进入；不同意退出；模拟老用户/版本变更后再弹一次。