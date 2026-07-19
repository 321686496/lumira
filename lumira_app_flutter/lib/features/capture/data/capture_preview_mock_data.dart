import 'package:flutter/material.dart';

import '../../templates/data/templates_editor_mock_data.dart';

/// 心情标签选项（对应 preview.vue line 117-125 的 moods 数组）
class MoodOption {
  const MoodOption({
    required this.name,
    required this.icon,
    this.active = false,
  });
  final String name;
  final IconData icon;
  final bool active;

  MoodOption copyWith({bool? active}) => MoodOption(
        name: name,
        icon: icon,
        active: active ?? this.active,
      );
}

/// 场景标签选项（对应 preview.vue line 130-134 的 sceneOptions）
class ScenePillOption {
  const ScenePillOption({required this.id, required this.name, required this.icon});
  final String id;
  final String name;
  final IconData icon;
}

/// 预览页 mock 数据
class CapturePreviewMockData {
  CapturePreviewMockData._();

  // 心情标签（7 个，对应 preview.vue line 117-125）
  // Phosphor 图标 → Material 图标映射（与 Task 2.6 inspiration 页同类问题）
  // ph-smiley → Icons.sentiment_satisfied
  // ph-sunglasses → Icons.wb_sunny_outlined
  // ph-flower → Icons.local_florist_outlined
  // ph-film-strip → Icons.movie_outlined
  // ph-leaf → Icons.eco_outlined
  // ph-palette → Icons.palette_outlined
  // ph-plant → Icons.grass_outlined
  static const List<MoodOption> moods = [
    MoodOption(name: '开心', icon: Icons.sentiment_satisfied, active: true),
    MoodOption(name: '甜酷', icon: Icons.wb_sunny_outlined),
    MoodOption(name: '温柔', icon: Icons.local_florist_outlined),
    MoodOption(name: '复古', icon: Icons.movie_outlined),
    MoodOption(name: '清新', icon: Icons.eco_outlined),
    MoodOption(name: '文艺', icon: Icons.palette_outlined),
    MoodOption(name: '治愈', icon: Icons.grass_outlined),
  ];

  // 场景标签（8 个，对应 preview.vue sceneOptions — mock 数据，与 HomeMockData.scenes 一致）
  static const List<ScenePillOption> sceneOptions = [
    ScenePillOption(id: 'cafe', name: '咖啡馆', icon: Icons.coffee_outlined),
    ScenePillOption(id: 'street', name: '街头', icon: Icons.location_city_outlined),
    ScenePillOption(id: 'park', name: '公园', icon: Icons.park_outlined),
    ScenePillOption(id: 'home', name: '居家', icon: Icons.home_outlined),
    ScenePillOption(id: 'studio', name: '工作室', icon: Icons.camera_alt_outlined),
    ScenePillOption(id: 'restaurant', name: '餐厅', icon: Icons.restaurant_outlined),
    ScenePillOption(id: 'travel', name: '旅行', icon: Icons.flight_outlined),
    ScenePillOption(id: 'night', name: '夜景', icon: Icons.nights_stay_outlined),
  ];

  /// 最近拍摄照片 URL（mock：picsum 占位图）
  /// 真实接入 Task 2.3 的 CaptureState 后改为 StateProvider 读取
  static const String lastCapturedPhotoUrl =
      'https://picsum.photos/seed/lumira-capture-preview/800/1067';

  /// 加载模板（委托给 TemplatesEditorMockData）
  /// 用于 preview-template 页的 onLoad 逻辑
  static EditorForm? loadTemplateById(String? templateId) {
    if (templateId == null || templateId.isEmpty) return null;
    return TemplatesEditorMockData.loadTemplateById(templateId);
  }

  /// 加载草稿（委托给 TemplatesEditorMockData）
  static EditorForm? loadDraftById(String? draftId) {
    if (draftId == null || draftId.isEmpty) return null;
    return TemplatesEditorMockData.loadDraftById(draftId);
  }
}

/// 选项数据（对应 preview-template.vue line 387-417 的 wbOptions / flashOptions / focusOptions / lutOptions）
class PreviewTemplateOption {
  const PreviewTemplateOption({required this.label, required this.value});
  final String label;
  final String value;
}

class PreviewTemplateOptions {
  PreviewTemplateOptions._();

  // wbOptions（5 个，preview-template.vue line 387-393）
  static const List<PreviewTemplateOption> whiteBalance = [
    PreviewTemplateOption(label: '日光', value: 'daylight'),
    PreviewTemplateOption(label: '阴天', value: 'cloudy'),
    PreviewTemplateOption(label: '阴影', value: 'shade'),
    PreviewTemplateOption(label: '白炽灯', value: 'tungsten'),
    PreviewTemplateOption(label: '自定义', value: 'custom'),
  ];

  // flashOptions（4 个，preview-template.vue line 395-400）
  static const List<PreviewTemplateOption> flashMode = [
    PreviewTemplateOption(label: '关', value: 'off'),
    PreviewTemplateOption(label: '开', value: 'on'),
    PreviewTemplateOption(label: '自动', value: 'auto'),
    PreviewTemplateOption(label: '常亮', value: 'torch'),
  ];

  // focusOptions（3 个，preview-template.vue line 402-406）
  static const List<PreviewTemplateOption> focusMode = [
    PreviewTemplateOption(label: '自动', value: 'auto'),
    PreviewTemplateOption(label: '手动', value: 'manual'),
    PreviewTemplateOption(label: '连续', value: 'continuous'),
  ];

  // lutOptions（8 个，preview-template.vue line 408-417）
  static const List<PreviewTemplateOption> lutPreset = [
    PreviewTemplateOption(label: '原图', value: 'none'),
    PreviewTemplateOption(label: '电影感', value: 'cinematic'),
    PreviewTemplateOption(label: '复古', value: 'vintage'),
    PreviewTemplateOption(label: '黑白', value: 'bw'),
    PreviewTemplateOption(label: '暖色', value: 'warm_film'),
    PreviewTemplateOption(label: '冷色', value: 'cool_film'),
    PreviewTemplateOption(label: '柔色', value: 'pastel'),
    PreviewTemplateOption(label: '富士', value: 'fuji'),
  ];
}
