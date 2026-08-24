# Task 0 简报 — OHOS camerawesome 本地化（前置，无功能）

来源计划：`docs/superpowers/plans/2026-08-22-white-balance.md` 的 Task 0。

## 目的
当前 `camerawesome_ohos` 是 pubspec `git:` 依赖（解析自全局 pub 缓存）。出于后续要为它加原生白平衡且 `flutter pub clear` 会清除缓存改动，必须把它**本地化**为 path 依赖（与 `packages/camerawesome` 的 vendor 方式一致）。

## 文件
- Create: `lumira_app_flutter/packages/camerawesome_ohos/`（从 pubcache fork 整体拷贝）
- Modify: `lumira_app_flutter/pubspec.yaml` 中 `camerawesome_ohos` 依赖（当前为 `git:`）
- `pubspec.lock`：`flutter pub get` 后自动更新

## 步骤
1. 源目录：`E:\flutter\pubcache\git\fluttertpc_camerawesome-5a68c67ecbb192f1abbce5578c1c823a50d37ddc\ohos`。先校验 `Test-Path '...\ohos\pubspec.yaml'` 为 `True`。
2. 拷贝（PowerShell）：
   `Copy-Item -Recurse -Force '<源>\ohos' 'e:\Project\photo_post\lumira_app_flutter\packages\camerawesome_ohos'`
   然后删除拷贝里可能残留的 `.git`（`Remove-Item -Recurse -Force '...\camerawesome_ohos\.git' -ErrorAction SilentlyContinue`；若不存在忽略）。**不要拷贝 build/oh_modules 等产物**——源是 pubcache clone，通常无；若发现 `camerawesome_ohos/ohos/build` 与 `camerawesome_ohos/ohos/oh_modules` 存在则一并删除（应为干净源码）。
3. 校验拷贝完整：`packages\camerawesome_ohos\pubspec.yaml`、`packages\camerawesome_ohos\lib\camerawesome_plugin.dart`、`packages\camerawesome_ohos\ohos\src\main\ets\components\plugin\CameraAwesomeX.ets` 均应存在。
4. 改 `pubspec.yaml`：把
   ```yaml
   camerawesome_ohos:
     git:
       url: https://gitcode.com/CPF-Flutter/fluttertpc_camerawesome.git
       ref: master
       path: ohos
   ```
   替换为
   ```yaml
   camerawesome_ohos:
     path: packages/camerawesome_ohos
   ```
5. `cd lumira_app_flutter; flutter pub get` 成功、无 git fetch 报错。`pubspec.lock` 中 `camerawesome_ohos` 的 source 变本地、出现 `path` 字段。
6. 冒烟：`flutter analyze` 不新增错误（本地化不改代码，应 0 净变化）。
7. Commit：
   `git add lumira_app_flutter/pubspec.yaml lumira_app_flutter/pubspec.lock lumira_app_flutter/packages/camerawesome_ohos`
   `git commit -m "chore(camera): 本地化 camerawesome_ohos 依赖以扩展原生白平衡"`
   **然后 push**：`git push origin master ; git push github master`（PowerShell 用 `;` 分隔）。

## 注意
- 全程 PowerShell（Windows，无 bash）。不要用 heredoc。
- 不要改动 `camerawesome`（iOS/Android 本地包）与任何 App 业务代码。
- 完成后把结果写入报告文件 `docs/superpowers/plans/reports/task-0-report.md`。