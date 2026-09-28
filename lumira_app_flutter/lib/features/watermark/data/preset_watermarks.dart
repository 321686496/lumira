import 'package:flutter/painting.dart' show Color, TextAlign;

import '../models/watermark_template.dart';

/// 预置水印模板集合。
///
/// 6 款精选水印覆盖简约/胶片/艺术/杂志/画框/拍立得六种风格，元素坐标均为相对值
/// （0.0~1.0），由 [WatermarkRenderer] 按目标图像尺寸缩放为绝对像素。
/// 预置模板 id 以 `preset_` 前缀标识，type 固定为 [WatermarkTemplateType.preset]。
///
/// 排版约定（详见 `docs/specs/2026-09-24-watermark-preset-redesign-design.md`）：
/// - 日期元素一律用 [WatermarkElementType.dateTime]（不写死文本），
///   渲染时按照片真实拍摄日期格式化
/// - 叠在照片上的浅色文字统一挂深色柔光晕，保证亮底可读（不加底色块、不加描边）
/// - 拍立得白板内文字靠白板本身提供对比，不挂阴影
List<WatermarkTemplate> getPresetWatermarks() {
  return [
    _minimalDate(),
    _filmStamp(),
    _artSignature(),
    _magazineLayout(),
    _frameBorder(),
    _polaroid(),
  ];
}

/// 叠在照片上的文字统一阴影：不透明黑（实际强度 = 元素 opacity）。
const Color _onPhotoShadow = Color(0xFF000000);

/// 柔光晕半径 = 0.45 × 绝对字号（暗底不发虚）。
const double _onPhotoBlur = 0.45;

/// 01 简约日期：左下角单列，日期为主视觉、品牌为辅。
WatermarkTemplate _minimalDate() {
  return WatermarkTemplate(
    id: 'preset_minimal_date',
    name: '简约日期',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_minimal_date_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.06,
        y: 0.914,
        fontSize: 0.045,
        textAlign: TextAlign.left,
        bold: true,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
      WatermarkElement(
        id: 'preset_minimal_date_brand',
        type: WatermarkElementType.text,
        text: 'LUMIRA',
        x: 0.06,
        y: 0.962,
        fontSize: 0.023,
        textAlign: TextAlign.left,
        letterSpacing: 6.0,
        opacity: 0.80,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
    ],
  );
}

/// 02 胶片印记：右下角，琥珀色日期模拟胶片打印机等宽走纸。
WatermarkTemplate _filmStamp() {
  return WatermarkTemplate(
    id: 'preset_film_stamp',
    name: '胶片印记',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_film_stamp_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.94,
        y: 0.912,
        fontSize: 0.036,
        color: const Color(0xFFF0B45A),
        textAlign: TextAlign.right,
        bold: true,
        letterSpacing: 3.5,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
      WatermarkElement(
        id: 'preset_film_stamp_brand',
        type: WatermarkElementType.text,
        text: 'LUMIRA',
        x: 0.94,
        y: 0.955,
        fontSize: 0.018,
        textAlign: TextAlign.right,
        letterSpacing: 5.0,
        opacity: 0.82,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
    ],
  );
}

/// 03 艺术签名：右下角衬线斜体签名 + 小字距日期，整体微倾。
WatermarkTemplate _artSignature() {
  return WatermarkTemplate(
    id: 'preset_art_signature',
    name: '艺术签名',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_art_signature_brand',
        type: WatermarkElementType.text,
        text: 'Lumira',
        x: 0.93,
        y: 0.905,
        fontSize: 0.050,
        textAlign: TextAlign.right,
        italic: true,
        fontFamily: 'serif',
        rotation: -0.05,
        opacity: 0.95,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
      WatermarkElement(
        id: 'preset_art_signature_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.93,
        y: 0.945,
        fontSize: 0.017,
        textAlign: TextAlign.right,
        letterSpacing: 3.5,
        rotation: -0.05,
        opacity: 0.72,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
    ],
  );
}

/// 04 杂志排版：左上刊头（品牌大字距 + 日期），与「简约日期」的版面位置错开。
WatermarkTemplate _magazineLayout() {
  return WatermarkTemplate(
    id: 'preset_magazine_layout',
    name: '杂志排版',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_magazine_layout_brand',
        type: WatermarkElementType.text,
        text: 'LUMIRA',
        x: 0.06,
        y: 0.055,
        fontSize: 0.022,
        textAlign: TextAlign.left,
        letterSpacing: 9.0,
        opacity: 0.92,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
      WatermarkElement(
        id: 'preset_magazine_layout_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.06,
        y: 0.095,
        fontSize: 0.017,
        textAlign: TextAlign.left,
        letterSpacing: 3.0,
        opacity: 0.70,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
    ],
  );
}

/// 05 画框水印：真正的内描边画框 + 下缘居中日期（品牌由画框本身承担）。
WatermarkTemplate _frameBorder() {
  return WatermarkTemplate(
    id: 'preset_frame_border',
    name: '画框水印',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    frame: const WatermarkFrame(
      type: WatermarkFrameType.innerBorder,
      borderRatio: 0.012,
      borderRadius: 0.0,
      color: Color(0xE6FFFFFF),
    ),
    elements: [
      WatermarkElement(
        id: 'preset_frame_border_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.5,
        y: 0.947,
        fontSize: 0.026,
        textAlign: TextAlign.center,
        letterSpacing: 3.0,
        opacity: 0.95,
        shadowColor: _onPhotoShadow,
        shadowBlur: _onPhotoBlur,
      ),
    ],
  );
}

/// 06 拍立得：白色相纸 + 底部白板居中日期。
///
/// 日期元素 `space: frame` → 基准矩形为**整卡宽**的底部白板（见
/// [WatermarkLayout.plateRect]），`x: 0.5` 才真正居中。深灰字落在纯白板上，
/// 可读性由底板提供，故不挂任何阴影。
WatermarkTemplate _polaroid() {
  return WatermarkTemplate(
    id: 'preset_polaroid',
    name: '拍立得',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 20),
    frame: const WatermarkFrame(
      type: WatermarkFrameType.polaroid,
      color: Color(0xFFFFFFFF),
      borderRatio: 0.05,
      borderRadius: 0.0,
      bottomPlate: true,
      bottomRatio: 0.18,
      shadowColor: Color(0xFF000000),
      shadowOpacity: 0.22,
      shadowBlur: 0.02,
    ),
    elements: [
      WatermarkElement(
        id: 'preset_polaroid_date',
        type: WatermarkElementType.dateTime,
        text: '',
        x: 0.5,
        y: 0.54,
        fontSize: 0.035,
        color: const Color(0xFF3D3D3D),
        shadowColor: const Color(0x00000000),
        space: WatermarkElementSpace.frame,
        textAlign: TextAlign.center,
        fontFamily: 'serif',
        italic: true,
      ),
    ],
  );
}

/// 拍立得白边渐变预设：一次点击同时设好起始色 / 结束色 / 方向。
class WatermarkGradientPreset {
  /// 面板上的色卡名。
  final String label;

  /// 渐变起始色（落在 [WatermarkFrame.color]）。
  final Color start;

  /// 渐变结束色（落在 [WatermarkFrame.gradientEndColor]）。
  final Color end;

  /// 渐变方向。
  final WatermarkGradientDirection direction;

  const WatermarkGradientPreset({
    required this.label,
    required this.start,
    required this.end,
    this.direction = WatermarkGradientDirection.topToBottom,
  });

  /// 当前画框是否正使用该预设（含方向一致的判定，用于色卡选中态）。
  bool matches(WatermarkFrame frame) =>
      frame.borderFill == WatermarkBorderFill.gradient &&
      frame.color.value == start.value &&
      frame.gradientEndColor.value == end.value &&
      frame.gradientDirection == direction;
}

/// 4 款低饱和渐变：拍立得白边面积大，色彩必须克制（亮底起、微着色收）。
const List<WatermarkGradientPreset> watermarkGradientPresets = [
  WatermarkGradientPreset(
    label: '暖金',
    start: Color(0xFFFFFFFF),
    end: Color(0xFFF0DFB8),
  ),
  WatermarkGradientPreset(
    label: '奶油',
    start: Color(0xFFFFFCF6),
    end: Color(0xFFF1E3D0),
  ),
  WatermarkGradientPreset(
    label: '暖灰',
    start: Color(0xFFFFFFFF),
    end: Color(0xFFE9E3DB),
    direction: WatermarkGradientDirection.topLeftToBottomRight,
  ),
  WatermarkGradientPreset(
    label: '雾粉',
    start: Color(0xFFFFF9F5),
    end: Color(0xFFF5DFD8),
  ),
];