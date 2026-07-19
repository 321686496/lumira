import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 姿势剪影渲染组件（简化版）
///
/// 视觉规格来源：lumira-app/src/components/PoseSilhouette.vue
///
/// 简化说明（brief §3.2 + §8.1 已知简化决策 #1）：
/// - 当前 mock 数据中 SVG 字符串为空，无法渲染真实 SVG
/// - builtin：用 `Icon(Icons.person_outline)` 占位（仅当 data != 'none'）
/// - svg：用 `Icon(Icons.brush_outlined)` 占位
/// - image：用 `Image.memory(base64Decode(data))` 渲染（若 data 为空则不渲染）
/// - Task 2.9 接入 flutter_svg 后实现真实 SVG 渲染
class PoseSilhouette extends StatelessWidget {
  const PoseSilhouette({
    super.key,
    required this.silhouetteType,
    required this.silhouetteData,
    this.scale = 1.0,
    this.rotation = 0.0,
    this.color,
  });

  /// 'builtin' / 'image' / 'svg'
  final String silhouetteType;

  /// builtin: silhouette key; image: base64 data URL; svg: inline SVG string
  final String silhouetteData;

  /// 0.5 ~ 1.5
  final double scale;

  /// -45 ~ 45
  final double rotation;

  /// 默认 Color.fromRGBO(255, 255, 255, 0.85)（与项目记忆规则"剪影包装元素 color: rgba(255,255,255,0.85)"一致）
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? const Color.fromRGBO(255, 255, 255, 0.85);

    Widget content = _buildContent(effectiveColor);

    // 用 Transform 应用缩放和旋转
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..rotateZ(rotation * math.pi / 180.0)
        ..scale(scale),
      child: content,
    );
  }

  Widget _buildContent(Color effectiveColor) {
    switch (silhouetteType) {
      case 'builtin':
        if (silhouetteData.isEmpty || silhouetteData == 'none') {
          // builtin 'none'：渲染空 SizedBox（与 brief §3.2 一致）
          return const SizedBox(width: 80, height: 80);
        }
        // 简化：用 Icon 占位（Task 2.9 接入真实 SVG 库后替换）
        return Icon(
          Icons.person_outline,
          color: effectiveColor,
          size: 80,
        );

      case 'image':
        if (silhouetteData.isEmpty) {
          // mock 数据为空时不渲染（避免 base64Decode 异常）
          return const SizedBox(width: 80, height: 80);
        }
        // image 类型：解析 base64 数据 URL（如 `data:image/png;base64,xxxx`）
        return Image.memory(
          _decodeBase64DataUrl(silhouetteData),
          width: 80,
          height: 80,
          color: effectiveColor,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => Icon(
            Icons.broken_image_outlined,
            color: effectiveColor,
            size: 80,
          ),
        );

      case 'svg':
        // TODO: Task 2.9 接入 flutter_svg 渲染真实 SVG
        return Icon(
          Icons.brush_outlined,
          color: effectiveColor,
          size: 80,
        );

      default:
        return const SizedBox(width: 80, height: 80);
    }
  }

  /// 解析 base64 data URL，strip `data:image/...;base64,` 前缀
  static Uint8List _decodeBase64DataUrl(String data) {
    String raw = data;
    final commaIdx = data.indexOf(',');
    if (commaIdx >= 0 && data.startsWith('data:')) {
      raw = data.substring(commaIdx + 1);
    }
    return base64Decode(raw);
  }
}
