/// 分享积分上报 hook。
///
/// SafeShare 调起分享后调用 [notify]，由 main.dart 在启动时 wire 到
/// pointsRepository.earn(type: 'share')（每日首享 +2，fire-and-forget）。
/// 保持无状态静态类 + 可选 hook，便于测试不 wire 或 mock。
class ShareReporter {
  ShareReporter._();

  static Future<void> Function()? onShare;

  static void notify() {
    final hook = onShare;
    if (hook == null) return;
    // fire-and-forget：上报失败不影响分享主流程
    // ignore: unawaited_futures
    hook();
  }
}
