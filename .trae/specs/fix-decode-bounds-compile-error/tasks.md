# Tasks
- [x] Task 1: 修复 decodeBounds 编译错误
  - [x] SubTask 1.1: 在 `capture_page.dart` 中将 `decoder?.decodeBounds(fb)` 改为 `decoder?.startDecode(fb)`
  - [x] SubTask 1.2: 确认日志输出字段（`info?.width` / `info?.height`）与 `DecodeInfo` 一致
- [x] Task 2: 验证编译通过
  - [x] SubTask 2.1: 在 OHOS 目标运行 `flutter run` 确认无该编译错误

# Task Dependencies
- [Task 2] depends on [Task 1]