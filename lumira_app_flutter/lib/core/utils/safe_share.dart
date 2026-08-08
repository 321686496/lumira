import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// 安全分享包装器，在 share_plus 插件未注册时降级到剪贴板复制。
///
/// 鸿蒙设备上 pub.dev 版 share_plus 缺少 ohos 原生实现，
/// 调用 shareXFiles() / share() 会抛出 MissingPluginException。
/// 此包装器捕获异常后回退到将内容复制到剪贴板。
class SafeShare {
  /// 分享多个文件，失败时降级为复制第一个文件路径到剪贴板。
  static Future<void> shareXFiles(
    List<XFile> files, {
    String? subject,
    String? text,
  }) async {
    try {
      await Share.shareXFiles(
        files,
        subject: subject,
        text: text,
      );
    } on MissingPluginException {
      debugPrint('[safe_share] share_plus 未注册，降级到剪贴板');
      await _fallbackToClipboard(files.first.path);
    } catch (e) {
      debugPrint('[safe_share] shareXFiles 异常: $e');
      await _fallbackToClipboard(files.first.path);
    }
  }

  /// 分享文本，失败时降级到剪贴板复制。
  static Future<void> share(
    String text, {
    String? subject,
  }) async {
    try {
      await Share.share(text, subject: subject);
    } on MissingPluginException {
      debugPrint('[safe_share] share_plus 未注册，降级到剪贴板');
      await _fallbackToClipboardText(text);
    } catch (e) {
      debugPrint('[safe_share] share 异常: $e');
      await _fallbackToClipboardText(text);
    }
  }

  static Future<void> _fallbackToClipboard(String filePath) async {
    try {
      await Clipboard.setData(ClipboardData(text: filePath));
      debugPrint('[safe_share] 已复制文件路径到剪贴板: $filePath');
    } catch (e) {
      debugPrint('[safe_share] 剪贴板降级也失败: $e');
    }
  }

  static Future<void> _fallbackToClipboardText(String text) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      debugPrint('[safe_share] 已复制文本到剪贴板');
    } catch (e) {
      debugPrint('[safe_share] 剪贴板降级也失败: $e');
    }
  }
}
