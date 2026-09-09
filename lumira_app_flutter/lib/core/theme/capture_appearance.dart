/// 拍摄页/预览页外观模式（持久化到 user_settings.capture_appearance）。
enum CaptureAppearance {
  /// 沉浸式：纯黑取景/看图 + 跨风格统一的暗色浮层（默认）
  immersive,

  /// 跟随主题：画布与浮层按当前主题色 + UI 风格渲染
  theme,
}

/// 拍摄浮层角色（captureOverlayVisual 的输入）：
/// - pill：直接叠在取景器上的胶囊/圆钮/浮条（导航、比例切换、参数 pill、延时按钮、工具栏）
/// - panel：底部承载内容的面板/抽屉（模板抽屉、场景条、滤镜选择器、参数面板）
enum CaptureOverlayRole { pill, panel }
