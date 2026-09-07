import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_controller.dart';

/// 监听系统明暗模式变化，同步到 [systemBrightnessProvider]。
///
/// 包在 MaterialApp 外层：初始值已由 provider 直接读取
/// platformDispatcher.platformBrightness（避免首帧闪变），
/// 此处负责在系统运行时切换深浅色时实时更新，让「跟随系统」即时换肤。
class SystemBrightnessWatcher extends StatefulWidget {
  const SystemBrightnessWatcher({super.key, required this.child});

  final Widget child;

  @override
  State<SystemBrightnessWatcher> createState() =>
      _SystemBrightnessWatcherState();
}

class _SystemBrightnessWatcherState extends State<SystemBrightnessWatcher>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _sync();
  }

  void _sync() {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final container = ProviderScope.containerOf(context, listen: false);
    if (container.read(systemBrightnessProvider) != brightness) {
      container.read(systemBrightnessProvider.notifier).state = brightness;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
