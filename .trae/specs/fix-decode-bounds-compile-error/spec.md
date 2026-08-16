# 修复 capture_page 编译错误（decodeBounds）

## Why
`flutter run`（OHOS 目标）编译失败：`capture_page.dart:753` 调用 `decoder?.decodeBounds(fb)`，但 `image` 包 4.2.0 的 `Decoder` 类没有 `decodeBounds` 方法，导致 kernel_snapshot 失败、应用无法启动。

## What Changes
- 将诊断代码中 `decoder?.decodeBounds(fb)` 替换为 `decoder?.startDecode(fb)`（返回 `DecodeInfo?`，含 `width`/`height`），语义等价。
- 保持诊断日志输出格式不变（像素尺寸 + 宽高比），用于排查横向拉伸。

## Impact
- Affected specs: 拍摄页照片后处理诊断
- Affected code:
  - `lumira_app_flutter/lib/features/capture/pages/capture_page.dart`（753 行附近）

## ADDED Requirements
### Requirement: 读取照片文件尺寸的诊断代码可编译
系统 SHALL 使用 `image` 4.2.0 存在的 API 读取解码信息。

#### Scenario: 编译通过
- **WHEN** 运行 `flutter run`（OHOS 目标）
- **THEN** 编译成功，无 `decodeBounds isn't defined` 错误

#### Scenario: 诊断日志输出
- **WHEN** 拍照后进入后处理诊断代码
- **THEN** 控制台输出 `[capture] 照片文件实际尺寸: WxH ratio=...`

## MODIFIED Requirements
### Requirement: 诊断代码 API 迁移
原 `decodeBounds`（不存在）迁移为 `startDecode`，返回的 `DecodeInfo` 提供 `width`/`height` 字段。