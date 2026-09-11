// lumira_app_flutter/lib/core/startup/post_compliance_init.dart
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/network/api_client.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/usage/usage_providers.dart';

/// 同意合规后（或已同意直接进入）才执行的数据初始化链：
/// 触发注册 → 等 token → 补传设备信息 + 同步个人资料/使用次数/内置模板/内置场景。
/// 由 main()（非首启）与 Splash「同意后」共同调用，fire-and-forget，失败静默。
Future<void> runPostComplianceInit(ProviderContainer container) async {
  final auth = container.read(authControllerProvider.notifier);
  // ignore: invalid_use_of_protected_member
  if (auth.state.needsRegistration) {
    // ignore: unawaited_futures
    auth.registerIfNeeded();
  }
  final ok = await auth.ensureRegistered();
  if (!ok) return;

  await reportDeviceInfo(container, defaultResolveOs());
  try { await (await container.read(profileSyncServiceProvider.future)).ensureLoadedIfMissing(); } catch (_) {}
  try { await (await container.read(profileSyncServiceProvider.future)).syncPendingIfNeeded(); } catch (_) {}
  try { await (await container.read(usageSyncServiceProvider.future)).runSync(); } catch (_) {}
  try { await (await container.read(builtinTemplateSyncServiceProvider.future)).syncBuiltinTemplates(); } catch (_) {}
  try { await (await container.read(builtinSceneSyncServiceProvider.future)).syncBuiltinScenes(); } catch (_) {}
}

/// 已注册设备启动时补传设备信息（PATCH /device/info，JWT 鉴权，失败静默）
Future<void> reportDeviceInfo(ProviderContainer container, String os) async {
  try {
    final client = await container.read(apiClientProvider.future);
    final info = await collectDeviceInfo(os);
    await client.patch<bool>('/device/info', body: info, fromJson: (_) => true);
  } catch (_) {}
}

/// 采集设备信息
///
/// 注意：鸿蒙（HarmonyOS）环境下 Platform.isAndroid / isIOS 均为 false，
/// 若按平台分支填充字段会导致平台、系统版本、型号全部缺失。
/// 故始终填充 platform（= os）与 appVersion，版本/型号用 try-catch 尽力采集：
/// 鸿蒙 Flutter 提供 androidInfo 兼容实现，失败再回退 iosInfo，最终回退 os。
Future<Map<String, dynamic>> collectDeviceInfo(String os) async {
  final deviceInfo = DeviceInfoPlugin();
  final data = <String, dynamic>{'platform': os, 'appVersion': '1.0.0'};
  try {
    final androidInfo = await deviceInfo.androidInfo;
    data['osVersion'] = '${androidInfo.version.release} (API ${androidInfo.version.sdkInt})';
    data['deviceModel'] = '${androidInfo.manufacturer} ${androidInfo.model}';
  } catch (_) {
    try {
      final iosInfo = await deviceInfo.iosInfo;
      data['osVersion'] = '${iosInfo.systemName} ${iosInfo.systemVersion}';
      data['deviceModel'] = iosInfo.utsname.machine;
    } catch (_) {
      data['osVersion'] = os;
    }
  }
  return data;
}
