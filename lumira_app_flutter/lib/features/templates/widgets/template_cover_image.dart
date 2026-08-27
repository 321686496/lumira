import 'package:flutter/material.dart';

import '../../../shared/widgets/images/lumira_image.dart';

/// 模板封面图统一渲染组件。
///
/// 解决：自定义模板的封面图以 base64 data URL 形式存储在 `coverData` 字段，
/// 内置模板的封面图以 assets 路径存储在 `cover` 字段，远程模板可能用 http URL。
/// 之前各页面分别用不同组件渲染，且 base64 每次 build 都重新解码导致加载慢。
///
/// 本组件统一委托 [LumiraImage] 加载四种来源：
/// 1. [coverData] 非空 → base64（字节级缓存 + 按需降采样，不再反复解码）
/// 2. [cover] 以 `data:` 开头 → base64
/// 3. [cover] 以 `assets/` 开头 → 打包资源（+ 降采样）
/// 4. [cover] 以 `http` 开头 → 远程 URL（磁盘缓存 + 降采样）
/// 5. 其它 → 本地文件路径；兜底 [fallback] 或默认占位
class TemplateCoverImage extends StatelessWidget {
  const TemplateCoverImage({
    super.key,
    this.cover,
    this.coverData,
    this.fit = BoxFit.cover,
    this.fallback,
    this.errorFallback,
  });

  /// 内置模板 assets 路径或远程模板 http URL（可能为空字符串）
  final String? cover;

  /// 自定义模板 base64 data URL（如 `data:image/jpeg;base64,xxx`）
  final String? coverData;

  /// 图片 fit 模式
  final BoxFit fit;

  /// 无任何封面数据时的占位 widget
  final Widget? fallback;

  /// 图片加载/解码失败时的占位 widget
  final Widget? errorFallback;

  @override
  Widget build(BuildContext context) {
    // 1. coverData 优先（自定义模板 base64）
    final cd = coverData;
    if (cd != null && cd.isNotEmpty) {
      return LumiraImage(
        _asDataUrl(cd),
        fit: fit,
        errorWidget: errorFallback ?? _defaultError(context),
      );
    }

    // 2. cover 字段（LumiraImage 自动识别 data:/assets//http/本地文件）
    final c = cover;
    if (c != null && c.isNotEmpty) {
      return LumiraImage(
        c,
        fit: fit,
        errorWidget: errorFallback ?? _defaultError(context),
      );
    }

    // 3. 兜底
    return fallback ?? _defaultEmpty(context);
  }

  /// 纯 base64（无 `data:` 前缀）时补上 data URL 前缀，交给 [LumiraImage] 识别。
  static String _asDataUrl(String s) =>
      s.startsWith('data:') ? s : 'data:image/jpeg;base64,$s';

  Widget _defaultEmpty(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.photo_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
        size: 32,
      ),
    );
  }

  Widget _defaultError(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        Icons.broken_image_outlined,
        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
        size: 32,
      ),
    );
  }
}