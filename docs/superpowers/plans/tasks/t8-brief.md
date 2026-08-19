# Task 8: Flutter 依赖 + 相机权限声明

**Goal:** 为二维码渲染与扫码添加依赖，并确认相机权限声明齐全。

## 关键事实（已核验）

- **Android** `android/app/src/main/AndroidManifest.xml` 已含 `android.permission.CAMERA`（第 6 行）。可在此行后补一条 `<uses-feature android:name="android.hardware.camera" android:required="false" />`（可选，不必强加）。
- **iOS** `ios/Runner/Info.plist` 已含 `NSCameraUsageUsageDescription`/`NSCameraUsageDescription`（第 51 行附近），内容已存在，无需新增；仅确认其 value 为非空即可，可改为中文「用于扫描恢复账号二维码」。
- **OHOS** `ohos/entry/src/main/module.json5` 已含 `ohos.permission.CAMERA`（第 54 行），无需新增。

所以本任务核心 = 加依赖 + `flutter pub get` 解析。

## Step 1: pubspec.yaml 加依赖

在 `d:\app\projects\photo_post\lumira_app_flutter\pubspec.yaml` 的 `dependencies`（dio 之后）加：

```yaml
  # 二维码渲染（纯 Dart，Dart 2.19 兼容）
  qr_flutter: ^4.1.0
  # 扫码（CPF-Flutter 鸿蒙适配 fork，源库 qr_code_scanner 0.7.0）
  qr_code_scanner:
    git:
      url: https://gitcode.com/CPF-Flutter/fluttertpc_qr_code_scanner.git
      ref: master
```

> 若 `qr_flutter ^4.1.0` 解析出的版本需 Dart 3（SDK 本工程为 `>=2.19.6 <3.0.0`），则收紧为 `qr_flutter: 4.0.0`（Dart 2.14+）。不要为它加意外覆盖。
> 不要改动其他既有依赖/覆盖。

## Step 2: flutter pub get

```bash
cd lumira_app_flutter
flutter pub get
```
Expected: 成功。若有依赖冲突（尤其是与既有 CPF-Flutter fork 覆盖），如实报告状态（尤其 qr_code_scanner 是否需要像 file_picker 那样加 ohos path 或 dependency_overrides）。当前 `dependency_overrides` 里无 qr 相关项——若 fork 解析报错，按既有模式（仿 file_picker）在 override 或注释里处理，并说明理由。

## Step 3: 权限确认（如本节已覆盖则跳过）

- iOS Info.plist 若 value 为空或英文，可改中文描述（非必须）。
- 其余已满足，不必改动。

## Step 4: 提交

```bash
git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock
# 若改了平台权限文件，再加入对应路径
git commit -m "feat(account): add qr_flutter & qr_code_scanner deps and camera permissions"
```
只提交本任务相关文件。**不要** add 工作区里其他未提交的改动（有其他任务/agent 的 Flutter 文件在变更）。不要 push（flutter 改动由用户决定是否推送；若确有推送需求再问）。
工作目录：`d:\app\projects\photo_post`。