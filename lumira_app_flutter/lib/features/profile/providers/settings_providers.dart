/// 用户设置相关的 Riverpod providers
///
/// 历史说明：
/// 此前文件提供 autoDeblurProvider（自动去模糊开关）和
/// loadAutoDeblurFromDb（启动时从 DB 加载历史值）。
/// 因 Unsharp Mask 去模糊效果不佳，曾改为多帧连拍 + 选最清晰帧方案，
/// 但该方案效果同样不佳且实现复杂、延迟高，已彻底移除，恢复为单帧拍照。
/// 相关 provider 已删除。
///
/// SettingsDao 仍保留 getAutoDeblur/setAutoDeblur 方法，
/// 以兼容已存在的 DB schema，但不再有代码调用。
class SettingsProviders {
  SettingsProviders._();
}
