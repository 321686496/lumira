import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'core/theme/theme_controller.dart';

/// 应用根 Widget（接入 ProviderScope + routerProvider + appThemeProvider）
///
/// 修复 Minor finding #32：Task 2.2 遗留状态——main.dart 仍是初始模板，
/// 未接入 ProviderScope / routerProvider / appThemeProvider，导致真实运行
/// app 时无法启动到任何路由（所有 Riverpod provider 读取会抛异常）。
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appTheme = ref.watch(appThemeProvider);

    return MaterialApp.router(
      title: '如画 Lumira',
      debugShowCheckedModeBanner: false,
      theme: appTheme.toThemeData(),
      routerConfig: router,
    );
  }
}

void main() {
  runApp(const ProviderScope(child: MyApp()));
}
