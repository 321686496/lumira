import 'package:flutter/painting.dart' show TextAlign;

import '../models/watermark_template.dart';

/// 预置水印模板集合。
///
/// 5 款精选水印覆盖简约/胶片/艺术/杂志/画框五种风格，元素坐标均为相对值
/// （0.0~1.0），由 [WatermarkRenderer] 按目标图像尺寸缩放为绝对像素。
/// 预置模板 id 以 `preset_` 前缀标识，type 固定为 [WatermarkTemplateType.preset]。
List<WatermarkTemplate> getPresetWatermarks() {
  return [
    _minimalDate(),
    _filmStamp(),
    _artSignature(),
    _magazineLayout(),
    _frameBorder(),
  ];
}

WatermarkTemplate _minimalDate() {
  return WatermarkTemplate(
    id: 'preset_minimal_date',
    name: '简约日期',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_minimal_date_date',
        type: WatermarkElementType.text,
        text: '2026.08.08',
        x: 0.05,
        y: 0.88,
        fontSize: 0.045,
        textAlign: TextAlign.left,
        bold: true,
      ),
      WatermarkElement(
        id: 'preset_minimal_date_sep',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.05,
        y: 0.93,
        fontSize: 0.03,
        textAlign: TextAlign.left,
      ),
      WatermarkElement(
        id: 'preset_minimal_date_brand',
        type: WatermarkElementType.text,
        text: 'LUMIRA',
        x: 0.05,
        y: 0.965,
        fontSize: 0.028,
        textAlign: TextAlign.left,
        letterSpacing: 4.0,
      ),
    ],
  );
}

WatermarkTemplate _filmStamp() {
  return WatermarkTemplate(
    id: 'preset_film_stamp',
    name: '胶片印记',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_film_stamp_date',
        type: WatermarkElementType.text,
        text: '2026.08.08',
        x: 0.95,
        y: 0.91,
        fontSize: 0.035,
        textAlign: TextAlign.right,
      ),
      WatermarkElement(
        id: 'preset_film_stamp_device',
        type: WatermarkElementType.text,
        text: 'iPhone 15 Pro',
        x: 0.95,
        y: 0.955,
        fontSize: 0.028,
        textAlign: TextAlign.right,
        letterSpacing: 1.0,
      ),
    ],
  );
}

WatermarkTemplate _artSignature() {
  return WatermarkTemplate(
    id: 'preset_art_signature',
    name: '艺术签名',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_art_signature_dot',
        type: WatermarkElementType.text,
        text: '●',
        x: 0.95,
        y: 0.92,
        fontSize: 0.025,
        textAlign: TextAlign.right,
        rotation: -0.08,
      ),
      WatermarkElement(
        id: 'preset_art_signature_brand',
        type: WatermarkElementType.text,
        text: '© Lumira',
        x: 0.95,
        y: 0.955,
        fontSize: 0.032,
        textAlign: TextAlign.right,
        rotation: -0.08,
        italic: true,
      ),
    ],
  );
}

WatermarkTemplate _magazineLayout() {
  return WatermarkTemplate(
    id: 'preset_magazine_layout',
    name: '杂志排版',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_magazine_layout_sep_top',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.5,
        y: 0.91,
        fontSize: 0.03,
        textAlign: TextAlign.center,
      ),
      WatermarkElement(
        id: 'preset_magazine_layout_main',
        type: WatermarkElementType.text,
        text: '2026.08.08  ·  MOMENT  ·  LUMIRA',
        x: 0.5,
        y: 0.945,
        fontSize: 0.028,
        textAlign: TextAlign.center,
        letterSpacing: 2.0,
        bold: true,
      ),
      WatermarkElement(
        id: 'preset_magazine_layout_sep_bottom',
        type: WatermarkElementType.text,
        text: '——',
        x: 0.5,
        y: 0.98,
        fontSize: 0.03,
        textAlign: TextAlign.center,
      ),
    ],
  );
}

WatermarkTemplate _frameBorder() {
  return WatermarkTemplate(
    id: 'preset_frame_border',
    name: '画框水印',
    type: WatermarkTemplateType.preset,
    createdAt: DateTime(2026, 8, 8),
    elements: [
      WatermarkElement(
        id: 'preset_frame_border_tl',
        type: WatermarkElementType.text,
        text: '┌',
        x: 0.04,
        y: 0.04,
        fontSize: 0.06,
        textAlign: TextAlign.left,
      ),
      WatermarkElement(
        id: 'preset_frame_border_tr',
        type: WatermarkElementType.text,
        text: '┐',
        x: 0.96,
        y: 0.04,
        fontSize: 0.06,
        textAlign: TextAlign.right,
      ),
      WatermarkElement(
        id: 'preset_frame_border_bl',
        type: WatermarkElementType.text,
        text: '└',
        x: 0.04,
        y: 0.94,
        fontSize: 0.06,
        textAlign: TextAlign.left,
      ),
      WatermarkElement(
        id: 'preset_frame_border_br',
        type: WatermarkElementType.text,
        text: '┘',
        x: 0.96,
        y: 0.94,
        fontSize: 0.06,
        textAlign: TextAlign.right,
      ),
      WatermarkElement(
        id: 'preset_frame_brand',
        type: WatermarkElementType.text,
        text: 'LUMIRA  |  2026.08.08',
        x: 0.5,
        y: 0.98,
        fontSize: 0.026,
        textAlign: TextAlign.center,
        letterSpacing: 1.5,
      ),
    ],
  );
}
