import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';

/// 自动去模糊开关（内存态，启动时从 DB 加载）
/// 默认 true（开启）。CapturePage 读取此值决定是否调用 DeblurProcessor。
/// ProfileSettingsPage 的 Switch 双向绑定此 provider。
final autoDeblurProvider = StateProvider<bool>((ref) => true);

/// 应用启动时从 DB 异步加载 autoDeblur 历史值
Future<void> loadAutoDeblurFromDb(ProviderContainer container) async {
  try {
    final dao = await container.read(settingsDaoProvider.future);
    final value = await dao.getAutoDeblur();
    container.read(autoDeblurProvider.notifier).state = value;
  } catch (e) {
    // 加载失败保持默认值 true
  }
}
