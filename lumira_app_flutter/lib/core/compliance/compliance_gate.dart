import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前有效的合规文档版本。
///
/// 当《用户协议》《隐私政策》《个人信息清单与第三方SDK目录》任一内容更新时，
/// 递增此版本号（与 compliance_content.dart 最新 updateAt 对齐），
/// 使已同意用户在下一次启动时重新弹出并重新征得同意。
const String complianceCurrentVersion = '2026-08-24';

/// 是否处于「待合规同意」状态（true=需先同意再初始化/联网）。
///
/// 默认 false：由 main() 在启动时依据本地已同意版本与 [complianceCurrentVersion]
/// 是否一致来设置；Splash 依据它决定是否弹出合规窗。
final complianceAwaitingProvider = StateProvider<bool>((ref) => false);