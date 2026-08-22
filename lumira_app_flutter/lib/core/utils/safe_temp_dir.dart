import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// 安全获取临时目录，在 path_provider 插件未注册时降级到平台默认路径。
///
/// 鸿蒙设备上 pub.dev 版 path_provider 缺少 ohos 原生实现，
/// 调用 getTemporaryDirectory() 会抛出 MissingPluginException。
/// 此函数捕获异常后回退到平台默认临时目录。
Future<Directory> getSafeTemporaryDirectory() async {
  try {
    return await getTemporaryDirectory();
  } on MissingPluginException {
    debugPrint('[safe_temp_dir] path_provider 未注册，使用平台默认临时目录');
    return _platformTempDir();
  } catch (e) {
    debugPrint('[safe_temp_dir] getTemporaryDirectory 异常: $e');
    return _platformTempDir();
  }
}

Directory _platformTempDir() {
  if (Platform.isAndroid || Platform.isIOS) {
    // iOS/Android 不应走到这里，但保留兜底
    return Directory.systemTemp;
  }
  // HarmonyOS / 其他平台
  // 鸿蒙应用沙箱临时目录通常为 /data/app/el2/.../cache
  // 用 Directory.systemTemp 作为通用回退
  return Directory.systemTemp;
}

/// 安全获取应用文档目录，在 path_provider 插件未注册时降级到平台默认目录。
///
/// 鸿蒙设备上 pub.dev 版 path_provider 的 getApplicationDocumentsDirectory()
/// 缺少 ohos 原生实现，会抛出 MissingPluginException（见
/// [getSafeTemporaryDirectory]），此处同样捕获异常后回退。
Future<Directory> getSafeDocumentsDirectory() async {
  try {
    return await getApplicationDocumentsDirectory();
  } on MissingPluginException {
    debugPrint('[safe_temp_dir] path_provider 未注册，使用平台默认目录');
    return _platformDocsDir();
  } catch (e) {
    debugPrint('[safe_temp_dir] getApplicationDocumentsDirectory 异常: $e');
    return _platformDocsDir();
  }
}

Directory _platformDocsDir() {
  if (Platform.isAndroid || Platform.isIOS) {
    return Directory.systemTemp;
  }
  // HarmonyOS / 其他平台：回退到临时目录
  return Directory.systemTemp;
}
