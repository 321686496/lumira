# Checklist
- [x] capture_page.dart 中不再使用 `decodeBounds`
- [x] 使用 `startDecode` 返回的 `DecodeInfo` 读取 width/height
- [x] 日志输出格式保持 `[capture] 照片文件实际尺寸: WxH ratio=...`
- [x] OHOS 目标 `flutter run` 编译无该错误