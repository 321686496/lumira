# CP Task 06 — 合规门控收尾修复报告

## 改动内容

### Fix 1 — 深链不再绕过合规门控
文件：`lumira_app_flutter/lib/main.dart`，`_handleTemplateLink`
- 在函数最顶部新增：
  ```dart
  if (container.read(complianceAwaitingProvider)) return;
  ```
- 待同意时直接返回，既不导入模板、不弹导入面板、不发起任何导航；需同意后未处理该深链被视为可接受的合理取舍。

### Fix 2 — 同意落库失败不得继续数据采集
文件：`lumira_app_flutter/lib/features/splash/pages/splash_page.dart`，`_agreeCompliance`
- 捕获 `dao.setComplianceAgreed(...)` 成败到 `persisted`。
- 成功：行为与原先一致（关弹窗、awaiting=false、`runPostComplianceInit`、已注册则 `_maybeNavigate`）。
- 失败：不清 awaiting、不跑 `runPostComplianceInit`、不导航；仅关闭弹窗并重置 `_complianceDialogShown=false`，`mounted` 时重新弹出合规窗供重试。附注释说明意图。

### Fix 3 — v57 迁移补 try/catch
文件：`lumira_app_flutter/lib/core/db/database_provider.dart`
- v57 的 3 个 `_addColumnIfNotExists` 调用按 v55/v56 风格包裹 `try/catch` + `debugPrint('v57 migration failed (silent fallback): $e')`。

### 测试
文件：`lumira_app_flutter/test/features/splash/splash_page_test.dart`
- `_wrapWithRouter` 新增 `failCompliancePersist` 参数，覆盖 `settingsDaoProvider` 为抛错 future。
- 新增用例「同意落库失败：不清除 awaiting、不导航、重新弹窗可重试」。
- 实现细节：因 `SettingsDao` 构造函数要求非空 `Database`，改为让 `settingsDaoProvider` future 直接抛错，避免构造 stub 数据库。

## 验证结果
- `flutter test test/features/splash/splash_page_test.dart` → 10/10 全部通过（含既有 registered 回归用例与新增用例）。
- `flutter test test/core/db/compliance_agreement_test.dart` → 4/4 全部通过。
- `flutter analyze`（4 个改动文件）→ 仅既有 info 告警（splash_page.dart:14/104/111 及 splash_page_test.dart:170/178），未引入任何新问题。

## 改动文件
- `lumira_app_flutter/lib/main.dart`
- `lumira_app_flutter/lib/features/splash/pages/splash_page.dart`
- `lumira_app_flutter/lib/core/db/database_provider.dart`
- `lumira_app_flutter/test/features/splash/splash_page_test.dart`

## Commit
- `2d24a0c` fix(compliance): 深链与同意落库失败不再绕过合规门控 (+迁移 try/catch)

## 注意事项
- 工作区内存在无关的未提交改动（邀请/拼图海报相关工作），已严格只 stage/commit 上述 4 个本任务文件。