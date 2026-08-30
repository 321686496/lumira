import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/utils/safe_temp_dir.dart';

/// 自定义模板图片的落盘 / 读回 / 删除服务。
///
/// 将表单内 `data:image/...;base64,` 图片解码后写入应用文档目录，
/// 以**绝对路径**形式存入 RDB，绕开 OHOS RDB 单条记录 2MB 上限。
/// 图片目录结构：`<documents>/lumira/templates/<templateId>/` 下
/// `cover.<ext>` / `img_<i>.<ext>` / `silhouette_<i>.<ext>`。
class TemplateImageStore {
  TemplateImageStore._();

  /// 基础目录（正常路径），测试可用 @visibleForTesting 覆盖。
  @visibleForTesting
  static String? overrideBaseDir;

  /// 匹配 `data:image/<mime>;base64,<data>` 的 data URL。
  static final RegExp _dataUrlRe =
      RegExp(r'^data:image/([A-Za-z0-9.+\-]+);base64,(.+)$', dotAll: true);

  /// 图片根目录：<documents>/lumira/templates
  static Future<Directory> _templatesRoot() async {
    if (overrideBaseDir != null) {
      return Directory('$overrideBaseDir/lumira/templates');
    }
    final docs = await getSafeDocumentsDirectory();
    return Directory('${docs.path}/lumira/templates');
  }

  /// mime → 扩展名；未知 / 不支持的类型统一落到 `.png`。
  static String _extForMime(String mime) {
    switch (mime) {
      case 'image/png':
        return '.png';
      case 'image/jpeg':
        return '.jpg';
      case 'image/webp':
        return '.webp';
      default:
        return '.png';
    }
  }

  /// 扩展名 → mime（供 [toDataUrl] 反推）。未知扩展名回退 `application/octet-stream`。
  static String _mimeForExt(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }

  /// 解码 data URL 写文件，返回绝对路径。
  /// 非 `data:image/...;base64,` 输入（内置 key / SVG / http / assets / 空）原样返回。
  static Future<String> saveDataUrl(
      String templateId, String kind, int index, String dataUrl) async {
    final m = _dataUrlRe.firstMatch(dataUrl);
    if (m == null) return dataUrl;
    final ext = _extForMime(m.group(1)!);
    Uint8List bytes;
    try {
      bytes = base64Decode(m.group(2)!);
    } catch (_) {
      // base64 解码失败 fail-open：原样返回，不写文件。
      return dataUrl;
    }
    final fileName = kind == 'cover' ? 'cover$ext' : '${kind}_$index$ext';
    final root = await _templatesRoot();
    final dir = Directory('${root.path}/$templateId');
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.absolute.path;
  }

  /// 读文件字节，路径不存在返回 null。
  static Future<Uint8List?> readBytes(String path) async {
    final file = File(path);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  /// 本地路径 → base64 data URL；非本地引用原样返回。
  /// 文件缺失时也原样返回原引用。
  static Future<String> toDataUrl(String ref) async {
    if (!isLocalImageRef(ref)) return ref;
    final bytes = await readBytes(ref);
    if (bytes == null) return ref;
    final mime = _mimeForExt(ref);
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

  /// 判定是否为「本地文件路径」引用。
  ///
  /// 排除 `data:` / `http://` / `https://` / `assets/` / 空串 / `'none'` /
  /// 纯 key（无路径分隔符）后视为本地路径。
  static bool isLocalImageRef(String s) {
    if (s.isEmpty) return false;
    if (s == 'none') return false;
    if (s.startsWith('data:')) return false;
    if (s.startsWith('http://') || s.startsWith('https://')) return false;
    if (s.startsWith('assets/')) return false;
    // 纯 key（如内置剪影 `standing-profile`）不含路径分隔符，不是本地路径。
    if (!s.contains(RegExp(r'[/\\]'))) return false;
    return true;
  }

  /// 删除模板整个图片目录（删除模板时调用），不存在的目录静默通过。
  static Future<void> deleteAll(String templateId) async {
    final root = await _templatesRoot();
    final dir = Directory('${root.path}/$templateId');
    if (!await dir.exists()) return;
    await dir.delete(recursive: true);
  }
}
