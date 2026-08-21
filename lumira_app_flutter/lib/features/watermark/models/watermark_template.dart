import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextAlign;

/// 水印模板类型：preset（预置）/ custom（用户自定义）
enum WatermarkTemplateType { preset, custom }

/// 水印元素类型：text（纯文本）/ dateTime（日期时间）/ image（图片）
enum WatermarkElementType { text, dateTime, image }

/// 画框类型：none（无画框）/ polaroid（拍立得白边）/ innerBorder（内描边）
enum WatermarkFrameType { none, polaroid, innerBorder }

/// 拍立得白边填充方式：solid（纯色）/ gradient（渐变）
enum WatermarkBorderFill { solid, gradient }

/// 拍立得白边渐变方向
enum WatermarkGradientDirection {
  topToBottom,
  bottomToTop,
  leftToRight,
  rightToLeft,
  topLeftToBottomRight,
  bottomLeftToTopRight,
}

/// 元素定位坐标系：photo（相对照片区域，默认）/ frame（相对画框/白板区域）
enum WatermarkElementSpace { photo, frame }

/// 水印画框：描述照片四周的边框/白边。
///
/// polaroid：画布向外扩展（照片分辨率不变，四周加白边，底部可加宽白板），
///   四边可独立调宽，白边支持纯色 / 渐变填充，底部带投影；
/// innerBorder：画布与照片同尺寸，沿边缘画内描边（厚度 = [borderRatio]）；
/// none：无画框。
class WatermarkFrame {
  final WatermarkFrameType type;

  /// 拍立得白边基础色（纯色时即最终颜色，渐变时为起始色）。
  final ui.Color color;

  /// 内描边厚度比例 = borderRatio × 照片宽（0~0.2），仅 innerBorder 使用。
  final double borderRatio;

  /// 拍立得四边独立白边宽度比例 = value × 照片宽（0~1）。
  final double borderTop;
  final double borderRight;
  final double borderBottom;
  final double borderLeft;

  final double borderRadius; // 圆角（相对照片宽的比例，0~0.08）
  final bool bottomPlate; // 拍立得底部白板开关
  final double bottomRatio; // 白板高 = bottomRatio × 照片高

  final WatermarkBorderFill borderFill; // 白边填充：纯色 / 渐变
  final ui.Color gradientEndColor; // 渐变结束色（borderFill==gradient 时生效）
  final WatermarkGradientDirection gradientDirection; // 渐变方向

  final ui.Color shadowColor;
  final double shadowOpacity; // 0~1
  final double shadowBlur; // 投影模糊（相对照片宽的比例）

  const WatermarkFrame({
    this.type = WatermarkFrameType.none,
    this.color = const ui.Color(0xFFFFFFFF),
    this.borderRatio = 0.05,
    this.borderTop = 0.05,
    this.borderRight = 0.05,
    this.borderBottom = 0.05,
    this.borderLeft = 0.05,
    this.borderRadius = 0.0,
    this.bottomPlate = true,
    this.bottomRatio = 0.18,
    this.borderFill = WatermarkBorderFill.solid,
    this.gradientEndColor = const ui.Color(0xFFFFFFFF),
    this.gradientDirection = WatermarkGradientDirection.topToBottom,
    this.shadowColor = const ui.Color(0xFF000000),
    this.shadowOpacity = 0.25,
    this.shadowBlur = 0.02,
  });

  WatermarkFrame copyWith({
    WatermarkFrameType? type,
    ui.Color? color,
    double? borderRatio,
    double? borderTop,
    double? borderRight,
    double? borderBottom,
    double? borderLeft,
    double? borderRadius,
    bool? bottomPlate,
    double? bottomRatio,
    WatermarkBorderFill? borderFill,
    ui.Color? gradientEndColor,
    WatermarkGradientDirection? gradientDirection,
    ui.Color? shadowColor,
    double? shadowOpacity,
    double? shadowBlur,
  }) {
    return WatermarkFrame(
      type: type ?? this.type,
      color: color ?? this.color,
      borderRatio: borderRatio ?? this.borderRatio,
      borderTop: borderTop ?? this.borderTop,
      borderRight: borderRight ?? this.borderRight,
      borderBottom: borderBottom ?? this.borderBottom,
      borderLeft: borderLeft ?? this.borderLeft,
      borderRadius: borderRadius ?? this.borderRadius,
      bottomPlate: bottomPlate ?? this.bottomPlate,
      bottomRatio: bottomRatio ?? this.bottomRatio,
      borderFill: borderFill ?? this.borderFill,
      gradientEndColor: gradientEndColor ?? this.gradientEndColor,
      gradientDirection: gradientDirection ?? this.gradientDirection,
      shadowColor: shadowColor ?? this.shadowColor,
      shadowOpacity: shadowOpacity ?? this.shadowOpacity,
      shadowBlur: shadowBlur ?? this.shadowBlur,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'color': color.value,
        'borderRatio': borderRatio,
        'borderTop': borderTop,
        'borderRight': borderRight,
        'borderBottom': borderBottom,
        'borderLeft': borderLeft,
        'borderRadius': borderRadius,
        'bottomPlate': bottomPlate,
        'bottomRatio': bottomRatio,
        'borderFill': borderFill.name,
        'gradientEndColor': gradientEndColor.value,
        'gradientDirection': gradientDirection.name,
        'shadowColor': shadowColor.value,
        'shadowOpacity': shadowOpacity,
        'shadowBlur': shadowBlur,
      };

  factory WatermarkFrame.fromJson(Map<String, dynamic> json) {
    // 旧模板只有 borderRatio 时，四边默认继承该值，保证视觉不回退。
    final borderRatio = (json['borderRatio'] as num?)?.toDouble() ?? 0.05;
    final color = ui.Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF);
    return WatermarkFrame(
      type: _parseFrameType(json['type'] as String?),
      color: color,
      borderRatio: borderRatio,
      borderTop: (json['borderTop'] as num?)?.toDouble() ?? borderRatio,
      borderRight: (json['borderRight'] as num?)?.toDouble() ?? borderRatio,
      borderBottom: (json['borderBottom'] as num?)?.toDouble() ?? borderRatio,
      borderLeft: (json['borderLeft'] as num?)?.toDouble() ?? borderRatio,
      borderRadius: (json['borderRadius'] as num?)?.toDouble() ?? 0.0,
      bottomPlate: (json['bottomPlate'] as bool?) ?? true,
      bottomRatio: (json['bottomRatio'] as num?)?.toDouble() ?? 0.18,
      borderFill: _parseBorderFill(json['borderFill'] as String?),
      gradientEndColor: ui.Color(
        (json['gradientEndColor'] as num?)?.toInt() ?? color.value.toInt(),
      ),
      gradientDirection:
          _parseGradientDirection(json['gradientDirection'] as String?),
      shadowColor: ui.Color((json['shadowColor'] as num?)?.toInt() ?? 0xFF000000),
      shadowOpacity: (json['shadowOpacity'] as num?)?.toDouble() ?? 0.25,
      shadowBlur: (json['shadowBlur'] as num?)?.toDouble() ?? 0.02,
    );
  }

  static WatermarkFrameType _parseFrameType(String? value) {
    switch (value) {
      case 'polaroid':
        return WatermarkFrameType.polaroid;
      case 'innerBorder':
        return WatermarkFrameType.innerBorder;
      case 'none':
      default:
        return WatermarkFrameType.none;
    }
  }

  static WatermarkBorderFill _parseBorderFill(String? value) {
    switch (value) {
      case 'gradient':
        return WatermarkBorderFill.gradient;
      case 'solid':
      default:
        return WatermarkBorderFill.solid;
    }
  }

  static WatermarkGradientDirection _parseGradientDirection(String? value) {
    switch (value) {
      case 'bottomToTop':
        return WatermarkGradientDirection.bottomToTop;
      case 'leftToRight':
        return WatermarkGradientDirection.leftToRight;
      case 'rightToLeft':
        return WatermarkGradientDirection.rightToLeft;
      case 'topLeftToBottomRight':
        return WatermarkGradientDirection.topLeftToBottomRight;
      case 'bottomLeftToTopRight':
        return WatermarkGradientDirection.bottomLeftToTopRight;
      case 'topToBottom':
      default:
        return WatermarkGradientDirection.topToBottom;
    }
  }
}

/// 水印元素：单个可绘制单元（文本/日期/图片）。
///
/// 所有坐标与字号均为相对值（0.0~1.0），由 [WatermarkRenderer] 按目标
/// 图像尺寸缩放为绝对像素，保证不同分辨率输出一致。
class WatermarkElement {
  final String id;
  WatermarkElementType type;
  String text;
  double x; // 相对位置 0.0~1.0
  double y; // 相对位置 0.0~1.0
  double fontSize; // 相对字号
  ui.Color color;
  ui.Color shadowColor;
  double opacity;
  double rotation; // 弧度
  String fontFamily;
  TextAlign textAlign;
  bool bold;
  bool italic;
  double letterSpacing; // 字间距（像素）
  WatermarkElementSpace space; // 定位坐标系：photo（默认）/ frame

  WatermarkElement({
    required this.id,
    required this.type,
    required this.text,
    this.x = 0.0,
    this.y = 0.0,
    this.fontSize = 0.04,
    this.color = const ui.Color(0xFFFFFFFF),
    this.shadowColor = const ui.Color(0x66000000),
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.fontFamily = '',
    this.textAlign = TextAlign.left,
    this.bold = false,
    this.italic = false,
    this.letterSpacing = 0.0,
    this.space = WatermarkElementSpace.photo,
  });

  WatermarkElement copyWith({
    String? id,
    WatermarkElementType? type,
    String? text,
    double? x,
    double? y,
    double? fontSize,
    ui.Color? color,
    ui.Color? shadowColor,
    double? opacity,
    double? rotation,
    String? fontFamily,
    TextAlign? textAlign,
    bool? bold,
    bool? italic,
    double? letterSpacing,
    WatermarkElementSpace? space,
  }) {
    return WatermarkElement(
      id: id ?? this.id,
      type: type ?? this.type,
      text: text ?? this.text,
      x: x ?? this.x,
      y: y ?? this.y,
      fontSize: fontSize ?? this.fontSize,
      color: color ?? this.color,
      shadowColor: shadowColor ?? this.shadowColor,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      fontFamily: fontFamily ?? this.fontFamily,
      textAlign: textAlign ?? this.textAlign,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      space: space ?? this.space,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'text': text,
      'x': x,
      'y': y,
      'fontSize': fontSize,
      'color': color.value,
      'shadowColor': shadowColor.value,
      'opacity': opacity,
      'rotation': rotation,
      'fontFamily': fontFamily,
      'textAlign': textAlign.name,
      'bold': bold,
      'italic': italic,
      'letterSpacing': letterSpacing,
      'space': space.name,
    };
  }

  factory WatermarkElement.fromJson(Map<String, dynamic> json) {
    return WatermarkElement(
      id: json['id'] as String,
      type: _parseElementType(json['type'] as String),
      text: json['text'] as String? ?? '',
      x: (json['x'] as num?)?.toDouble() ?? 0.0,
      y: (json['y'] as num?)?.toDouble() ?? 0.0,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 0.04,
      color: ui.Color((json['color'] as num?)?.toInt() ?? 0xFFFFFFFF),
      shadowColor: ui.Color((json['shadowColor'] as num?)?.toInt() ?? 0x66000000),
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
      fontFamily: (json['fontFamily'] as String?) ?? '',
      textAlign: _parseTextAlign(json['textAlign'] as String?),
      bold: (json['bold'] as bool?) ?? false,
      italic: (json['italic'] as bool?) ?? false,
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble() ?? 0.0,
      space: _parseSpace(json['space'] as String?),
    );
  }

  static WatermarkElementType _parseElementType(String value) {
    switch (value) {
      case 'dateTime':
        return WatermarkElementType.dateTime;
      case 'image':
        return WatermarkElementType.image;
      case 'text':
      default:
        return WatermarkElementType.text;
    }
  }

  static TextAlign _parseTextAlign(String? value) {
    switch (value) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'justify':
        return TextAlign.justify;
      case 'left':
      default:
        return TextAlign.left;
    }
  }

  static WatermarkElementSpace _parseSpace(String? value) {
    switch (value) {
      case 'frame':
        return WatermarkElementSpace.frame;
      case 'photo':
      default:
        return WatermarkElementSpace.photo;
    }
  }
}

/// 水印模板：一组 [WatermarkElement] 的命名集合。
class WatermarkTemplate {
  final String id;
  String name;
  WatermarkTemplateType type;
  List<WatermarkElement> elements;
  DateTime createdAt;
  WatermarkFrame frame;

  WatermarkTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.elements,
    required this.createdAt,
    this.frame = const WatermarkFrame(),
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'elements': elements.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'frame': frame.toJson(),
    };
  }

  factory WatermarkTemplate.fromJson(Map<String, dynamic> json) {
    final elementsRaw = json['elements'] as List? ?? [];
    return WatermarkTemplate(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      type: _parseTemplateType(json['type'] as String?),
      elements: elementsRaw
          .map((e) => WatermarkElement.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      frame: json['frame'] != null
          ? WatermarkFrame.fromJson(json['frame'] as Map<String, dynamic>)
          : const WatermarkFrame(),
    );
  }

  static WatermarkTemplateType _parseTemplateType(String? value) {
    switch (value) {
      case 'custom':
        return WatermarkTemplateType.custom;
      case 'preset':
      default:
        return WatermarkTemplateType.preset;
    }
  }
}
