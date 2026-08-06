import 'dart:io';

import 'package:file_picker/file_picker.dart' as io;
import 'package:file_picker_ohos/file_picker_ohos.dart' as ohos;
import 'package:flutter/services.dart' show PlatformException;

/// 文件选择服务（跨平台包装器）。
///
/// 解决 file_picker 8.0.6（pub.dev 标准版）不支持 OHOS 的问题。
/// 仓库 https://gitcode.com/CPF-Flutter/fluttertpc_file_picker 的根包与
/// ohos/ 子目录是两个独立 Flutter 包：
/// - 根包 `file_picker` 8.0.6：iOS/Android/Web/MacOS/Windows/Linux，无 OHOS
/// - 子目录 `file_picker_ohos` 1.0.1：仅 OHOS，Dart API 与根包完全一致
///
/// 因此本服务同时 import 两个包，运行时根据 [Platform.operatingSystem] 选择
/// 正确的实现，避免任一端抛 `UnimplementedError`。
///
/// 调用方应使用本服务的统一类型（[PickedFile] / [PickedResult]）而非
/// 直接引用 io/ohos 命名空间下的 PlatformFile/FilePickerResult，以隔离平台差异。
class FilePickerService {
  FilePickerService._();

  /// 当前是否走 OHOS 适配实现
  static bool get _isOhos =>
      !kIsWebEnv && Platform.operatingSystem == 'ohos';

  /// 选择单张图片。
  ///
  /// 返回 [PickedFile]，包含 name/bytes/path/extension/size。
  /// 用户取消或失败时返回 null。
  static Future<PickedFile?> pickSingleImage({
    bool withData = true,
  }) async {
    final result = await _pick(
      type: _FileType.image,
      allowMultiple: false,
      withData: withData,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  /// 选择单个文件（自定义扩展名）。
  ///
  /// [allowedExtensions] 例如 `['json', 'lumira', 'pptpl']`。
  /// 用户取消或失败时返回 null。
  static Future<PickedFile?> pickSingleFile({
    required List<String> allowedExtensions,
    bool withData = true,
  }) async {
    final result = await _pick(
      type: _FileType.custom,
      allowedExtensions: allowedExtensions,
      allowMultiple: false,
      withData: withData,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  /// 选择多张图片。
  static Future<List<PickedFile>?> pickImages({
    bool allowMultiple = true,
    bool withData = true,
  }) async {
    final result = await _pick(
      type: _FileType.image,
      allowMultiple: allowMultiple,
      withData: withData,
    );
    return result?.files;
  }

  /// 平台分发核心方法。
  ///
  /// 捕获用户取消选择时 file_picker 抛出的 PlatformException
  /// （Android 上 code 为 'unkown_activity'，为 plugin 沿用自 image_picker 的拼写错误），
  /// 将其统一转为 null 返回，避免调用方需要额外处理取消逻辑。
  static Future<PickedResult?> _pick({
    required _FileType type,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
    bool withData = true,
  }) async {
    try {
      if (_isOhos) {
        final result = await ohos.FilePicker.platform.pickFiles(
          type: _mapTypeOhos(type),
          allowedExtensions: allowedExtensions,
          allowMultiple: allowMultiple,
          withData: withData,
        );
        return result == null ? null : _wrapResultOhos(result);
      }
      final result = await io.FilePicker.platform.pickFiles(
        type: _mapTypeIo(type),
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        withData: withData,
      );
      return result == null ? null : _wrapResultIo(result);
    } on PlatformException catch (e) {
      // 用户取消选择（按返回键 / 点击空白区域）时 file_picker 在 Android 上
      // 抛 PlatformException(code: 'unkown_activity')，静默返回 null。
      final code = e.code.toLowerCase();
      if (code.contains('activity') || code.contains('cancel') ||
          code.contains('abort') || code.contains('unknown')) {
        return null;
      }
      rethrow;
    }
  }

  // ===== 类型映射 =====

  static io.FileType _mapTypeIo(_FileType t) {
    switch (t) {
      case _FileType.image:
        return io.FileType.image;
      case _FileType.custom:
        return io.FileType.custom;
    }
  }

  static ohos.FileType _mapTypeOhos(_FileType t) {
    switch (t) {
      case _FileType.image:
        return ohos.FileType.image;
      case _FileType.custom:
        return ohos.FileType.custom;
    }
  }

  // ===== 结果包装 =====

  static PickedResult _wrapResultIo(io.FilePickerResult r) {
    return PickedResult(
      files: r.files
          .map((f) => PickedFile(
                name: f.name,
                bytes: f.bytes,
                path: f.path,
                extension: f.extension,
                size: f.size,
              ))
          .toList(),
    );
  }

  static PickedResult _wrapResultOhos(ohos.FilePickerResult r) {
    return PickedResult(
      files: r.files
          .map((f) => PickedFile(
                name: f.name,
                bytes: f.bytes,
                path: f.path,
                extension: f.extension,
                size: f.size,
              ))
          .toList(),
    );
  }
}

/// 文件类型枚举（平台无关）
enum _FileType {
  image,
  custom,
}

/// 文件选择结果（平台无关）
class PickedResult {
  const PickedResult({required this.files});

  final List<PickedFile> files;
}

/// 单个被选中的文件（平台无关）
class PickedFile {
  const PickedFile({
    required this.name,
    this.bytes,
    this.path,
    this.extension,
    this.size = 0,
  });

  /// 文件名（含扩展名）
  final String name;

  /// 文件二进制数据；当 withData=true 时返回
  final List<int>? bytes;

  /// 文件绝对路径；OHOS 与桌面端通常返回，iOS/Android 受沙盒限制可能为 null
  final String? path;

  /// 扩展名（不含点）
  final String? extension;

  /// 文件大小（字节）
  final int size;
}

/// web 环境标识（避免 import 'package:flutter/foundation.dart' 的 kIsWeb 与 Platform 冲突）
const bool kIsWebEnv = bool.fromEnvironment('dart.library.html');
