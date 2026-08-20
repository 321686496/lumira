# Task 2 Report: 数据模型扩展（WatermarkFrame + space + manageLayout）

**Status:** DONE

## 实现内容

按 TDD 完成了水印 V2 数据模型扩展，全部保持现有 immutable + copyWith 风格：

1. **`watermark_template.dart`**
   - 新增 `enum WatermarkFrameType { none, polaroid, innerBorder }`
   - 新增 `enum WatermarkElementSpace { photo, frame }`
   - 新增 `WatermarkFrame` 类（全 final 字段 + `copyWith` / `toJson` / `fromJson` + `_parseFrameType`）
   - `WatermarkElement` 新增 `space` 字段（默认 `photo`），构造参数 / `copyWith` / `toJson` / `fromJson` / `_parseSpace` 同步扩展
   - `WatermarkTemplate` 新增 `frame` 字段（默认 `const WatermarkFrame()`），`toJson` / `fromJson`（旧 JSON 缺省 frame 回退 none）扩展

2. **`watermark_settings.dart`**
   - 新增 `enum WatermarkManageLayout { list, grid }`
   - `WatermarkSettings` 新增 `manageLayout` 字段（默认 `list`），构造参数 / `copyWith` / `toJson` / `fromJson` / `_parseLayout` 同步扩展

## TDD 证据

### RED
命令：`flutter test test/features/watermark/watermark_model_test.dart`
结果：**编译失败**（exit code 1）
```
test/features/watermark/watermark_model_test.dart:11:28: Error: Undefined name 'WatermarkElementSpace'.
test/features/watermark/watermark_model_test.dart:23:17: Error: Method not found: 'WatermarkFrame'.
...
00:00 +0 -1: Some tests failed.
```

> 注：brief 中测试里的 import `package:lumira_app/...` 与本项目实际包名 `lumira_app_flutter` 不符，首次运行时无法解析。已修正为 `package:lumira_app_flutter/...`。修正后重新运行仍 RED（缺 `WatermarkElementSpace`/`WatermarkFrame`/`WatermarkManageLayout` 符号），符合预期。

### GREEN
命令：`flutter test test/features/watermark/watermark_model_test.dart`
结果：**8 项测试全部通过**（exit code 0）
```
00:00 +8: All tests passed!
```

### flutter analyze
- 定向：`flutter analyze lib/features/watermark test/features/watermark` → **No issues found!**
- 全量：`flutter analyze` 无 error，仅 1 条 pre-existing warning（`test/core/auth/auth_controller_test.dart`，与本任务无关）+ 大量既有 info 级 lint。
- 已清理测试文件里未使用的 `import 'package:flutter/painting.dart' show TextAlign;`。

## 文件变更

| 文件 | 变更 |
|---|---|
| `lumira_app_flutter/lib/features/watermark/models/watermark_template.dart` | 修改 |
| `lumira_app_flutter/lib/features/watermark/models/watermark_settings.dart` | 修改 |
| `lumira_app_flutter/test/features/watermark/watermark_model_test.dart` | 新建 |

Git status：3 files changed, 219 insertions(+), 1 deletion(-)

## Commit

```
a9e258b feat(watermark): add frame model, element space, manage layout setting
```

仅 staged `lib/features/watermark/models` + `test/features/watermark` 两个目录；未触碰工作区中其他无关未提交改动（app_theme/neu_card/lumira_button/floating_tabbar/usage/ 等）。未执行 push（任务未要求）。

## 自查发现

- brief 测试里的 import 包名为 `package:lumira_app/`，与项目实际包名 `lumira_app_flutter` 不符，已修正。
- 测试草案中未使用的 `TextAlign` import 会触发 lint，已移除。
- 初始化后任务说明要求"本任务相关测试全绿"——已通过定向测试确认；未跑全量测试套件（范围外）。

## 备注

提交时 git 提示 `LF will be replaced by CRLF`（Windows 换行符）属正常告警，非错误。