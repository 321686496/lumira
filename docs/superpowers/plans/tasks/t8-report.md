# Task 8 Report: Flutter 依赖 + 相机权限声明

**Status: DONE**

## 变更内容

### 1. pubspec.yaml 新增依赖

在 `dependencies`（`dio` 之后）新增两个依赖：

```yaml
# 二维码渲染（纯 Dart，Dart 2.19 兼容）
qr_flutter: ^4.1.0
# 扫码（CPF-Flutter 鸿蒙适配 fork，源库 qr_code_scanner 0.7.0）
qr_code_scanner:
  git:
    url: https://gitcode.com/CPF-Flutter/fluttertpc_qr_code_scanner.git
    ref: master
```

- `qr_flutter: ^4.1.0` **未被降级**：实测解析到 4.1.0，与 Dart 2.19.6 / SDK `>=2.19.6 <3.0.0` 完全兼容，无需按 brief 备选方案收紧到 4.0.0。
- `qr_code_scanner` 通过 git fork（`fluttertpc_qr_code_scanner`）直接引用，**无需额外加 dependency_overrides**：因为 fork 直接作为主 `dependencies` 下的 git 依赖声明，与既有 `camerawesome_ohos`、`sqflite` 的 git 引用模式一致，pub 直接解析成功。无需像 file_picker 那样加 override。

### 2. flutter pub get

`flutter pub get` 成功，无任何冲突。

- 新增解析依赖：`qr 3.0.1`（transitive）、`qr_flutter 4.1.0`、`qr_code_scanner 0.7.0 (from git ...fb9104)`。
- 既有 12 项 overridden 依赖（path/meta/js/mime/path_provider/uuid + 6 个 gitcode fork）本次解析不受影响，警告列表与历史一致，无新增 override。

### 3. 相机权限确认（均已在，无需改动）

- **Android** `android/app/src/main/AndroidManifest.xml` 第 6 行：`<uses-permission android:name="android.permission.CAMERA"/>` ✅（已存在）
- **iOS** `ios/Runner/Info.plist` 第 51-52 行：`NSCameraUsageDescription` value 为「需要使用相机拍摄模板封面图」，**非空且已是中文** ✅
- **OHOS** `ohos/entry/src/main/module.json5` 第 54 行：`"ohos.permission.CAMERA"` ✅

无平台权限文件需要修改。brief 提到的 Android 可选项 `<uses-feature ... camera ... required="false"/>` 未强制要求，故未新增。

### 4. 提交

- Commit：`2f267d8` — `feat(account): add qr_flutter & qr_code_scanner deps and camera permissions`
- 仅暂存并提交 `pubspec.yaml` + `pubspec.lock`（2 files changed, 33 insertions）。
- **未 push**（Flutter 改动由用户决定是否推送）。

### 5. flutter analyze

运行 `flutter analyze`：**339 issues，全部为 info 级 lint**，均位于并行 session 的无关文件（`test/template_mapper_test.dart`、`verify_scale.dart` 等），无 error、无新增依赖相关错误。本任务未新增任何引用 qr 的代码，故依赖仅做解析验证，编译无碍。

## 关键发现 / Concerns

- 无新增 dependency_overrides；`qr_code_scanner` 走 git 直接引用，与既有 CPF-Flutter fork 模式一致。
- 并行 session 的其他未提交改动（`lib/...`、`ohos/EntryAbility.ets`、untracked `test/`、`debuglog.txt` 等）未被触碰/提交。

## 涉及文件

- 修改：`lumira_app_flutter/pubspec.yaml`、`lumira_app_flutter/pubspec.lock`
- 报告：`docs/superpowers/plans/tasks/t8-report.md`