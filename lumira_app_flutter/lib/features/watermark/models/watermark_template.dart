import 'dart:ui' as ui;

import 'package:flutter/painting.dart' show TextAlign;

/// 水印模板类型：preset（预置）/ custom（用户自定义）
enum WatermarkTemplateType { preset, custom }

/// 水印元素类型：text（纯文本）/ dateTime（日期时间）/ image（图片）
enum WatermarkElementType { text, dateTime, image }

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
}

/// 水印模板：一组 [WatermarkElement] 的命名集合。
class WatermarkTemplate {
  final String id;
  String name;
  WatermarkTemplateType type;
  List<WatermarkElement> elements;
  DateTime createdAt;

  WatermarkTemplate({
    required this.id,
    required this.name,
    required this.type,
    required this.elements,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'elements': elements.map((e) => e.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
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
