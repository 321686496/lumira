import 'dart:ffi';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart' show getApplicationDocumentsDirectory;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite3/open.dart' as sqlite3_open;
import 'package:sqlite3/sqlite3.dart' as sqlite3_api;

import 'app/router.dart';
import 'core/theme/theme_controller.dart';

/// 应用根 Widget（接入 ProviderScope + routerProvider + appThemeProvider）
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

/// 提取后 libsqlite3.so 在应用文件目录中的路径（由 _extractSqlite3So 填充）
String? _harmonySqlite3Path;

/// 从 Flutter assets 中提取 libsqlite3.so 到应用可写目录
/// HarmonyOS 系统不提供 libsqlite3.so，需自带并运行时提取
/// 不依赖 path_provider（避免 Hot Restart 时 MissingPluginException）
Future<void> _extractSqlite3So() async {
  try {
    // 从 assets 读取 .so 字节
    final data = await rootBundle.load('assets/native/libsqlite3.so');
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );
    debugPrint('[sqflite_ffi] 从 assets 读取 libsqlite3.so: ${bytes.length} bytes');

    // HarmonyOS 应用可写目录候选列表（不依赖 path_provider）
    // uid 20020063 是本应用的 UID（从 bm dump 获取），实际运行时遍历候选
    final candidates = <String>[
      '/data/app/el2/20020063/base/com.example.lumira_app_flutter/files',
      '/data/storage/el2/base/haps/entry/files',
      '/data/storage/el2/database/com.example.lumira_app_flutter',
      '/data/local/tmp',
    ];

    for (final dir in candidates) {
      final soPath = '$dir/libsqlite3.so';
      try {
        // 确保目录存在
        final dirObj = Directory(dir);
        if (!dirObj.existsSync()) {
          continue;
        }
        final soFile = File(soPath);
        await soFile.writeAsBytes(bytes, flush: true);
        // 验证写入成功
        if (soFile.existsSync() && soFile.lengthSync() == bytes.length) {
          _harmonySqlite3Path = soPath;
          debugPrint('[sqflite_ffi] 提取 libsqlite3.so 到 $soPath 成功');
          return;
        }
      } catch (e) {
        debugPrint('[sqflite_ffi] 写入 $soPath 失败: $e');
      }
    }

    // 如果所有候选路径都失败，尝试 path_provider 作为最后手段
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final soPath = '${appDir.path}/libsqlite3.so';
      final soFile = File(soPath);
      await soFile.writeAsBytes(bytes, flush: true);
      _harmonySqlite3Path = soPath;
      debugPrint('[sqflite_ffi] 通过 path_provider 提取到 $soPath');
    } catch (e) {
      debugPrint('[sqflite_ffi] path_provider 也失败: $e');
    }
  } catch (e) {
    debugPrint('[sqflite_ffi] 读取 assets/native/libsqlite3.so 失败: $e');
  }
}

/// HarmonyOS 平台 sqlite3 动态库加载函数（顶层函数，isolate 安全）
/// sqlite3 包的 _defaultOpen() 不识别 ohos 平台，需手动覆盖。
DynamicLibrary _harmonySqlite3Open() {
  // 1. 优先从应用文件目录加载（由 _extractSqlite3So 运行时提取）
  if (_harmonySqlite3Path != null) {
    try {
      final lib = DynamicLibrary.open(_harmonySqlite3Path!);
      final hasSym = lib.providesSymbol('sqlite3_open_v2');
      debugPrint(
        '[sqflite_ffi] open("$_harmonySqlite3Path") OK, '
        'has sqlite3_open_v2=$hasSym',
      );
      if (hasSym) {
        return lib;
      }
    } catch (e) {
      debugPrint('[sqflite_ffi] open("$_harmonySqlite3Path") failed: $e');
    }
  }

  // 2. 尝试系统 libsqlite3.so（某些 HarmonyOS 版本可能提供）
  try {
    final lib = DynamicLibrary.open('libsqlite3.so');
    if (lib.providesSymbol('sqlite3_open_v2')) {
      return lib;
    }
  } catch (_) {
    // ignore
  }

  // 3. 尝试进程内已加载的符号
  try {
    final proc = DynamicLibrary.process();
    if (proc.providesSymbol('sqlite3_open_v2')) {
      return proc;
    }
  } catch (_) {
    // ignore
  }

  // 兜底：返回 process()，让后续调用自行抛错
  debugPrint('[sqflite_ffi] 所有加载尝试失败，fallback to process()');
  return DynamicLibrary.process();
}

void main() async {
  // 确保 Flutter 绑定初始化（使用 rootBundle / path_provider 前必需）
  WidgetsFlutterBinding.ensureInitialized();

  // Forced fix: HarmonyOS 平台缺少 sqflite 原生插件，
  // 需用 sqflite_common_ffi（FFI 实现）替代。
  // sqlite3 包的 _defaultOpen() 不识别 HarmonyOS，
  // 需手动覆盖加载逻辑：从 assets 提取自带 libsqlite3.so 到应用目录
  if (!kIsWeb) {
    // 1. 从 assets 提取 libsqlite3.so 到应用可写目录
    await _extractSqlite3So();

    // 2. 覆盖 sqlite3 库加载逻辑（必须在 sqfliteFfiInit 之前）
    sqlite3_open.open.overrideForAll(_harmonySqlite3Open);
    sqfliteFfiInit();
    // 用 NoIsolate 版本，避免 isolate 中 overrideForAll 不生效
    databaseFactory = databaseFactoryFfiNoIsolate;

    // 3. 预初始化 sqlite3 单例，验证加载是否成功
    try {
      final db = sqlite3_api.sqlite3.openInMemory();
      db.dispose();
      debugPrint('[sqflite_ffi] sqlite3 预初始化成功');
    } catch (e) {
      debugPrint('[sqflite_ffi] sqlite3 预初始化失败: $e');
    }
  }

  runApp(const ProviderScope(child: MyApp()));
}
