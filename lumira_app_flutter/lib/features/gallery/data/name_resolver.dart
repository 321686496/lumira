import '../../capture/data/capture_preview_mock_data.dart';
import '../../capture/data/capture_scene_mock_data.dart';
import '../../capture/data/scene_presets_data.dart';
import '../../capture/data/template_registry.dart';

/// 场景 ID → 展示名称。
///
/// 用于相册筛选 pill 与拍摄统计排行。解析顺序：
/// 1. 内置/自定义场景预设名称（CaptureSceneMockData.allScenes，如 cafe-window）
/// 2. 内置预设全量场景名称（ScenePresetsData，如 home-cozy）。
///    拍摄统计页只拿到 scene_id、没有 DB 场景表，必须靠这里兜底，
///    否则会直接显示英文 id。
/// 3. 拍摄预览页的场景胶囊名称（CapturePreviewMockData.sceneOptions，如 home/cafe/street）。
///    拍摄后落库的 scene_id 用的就是这一套短 id。
/// 4. 未知场景回退为 sceneId。
String sceneDisplayName(String sceneId) {
  if (sceneId == 'uncategorized') return '未设置场景';
  final mockScene = CaptureSceneMockData.getSceneById(sceneId);
  if (mockScene != null && mockScene.name.isNotEmpty) return mockScene.name;
  final preset = ScenePresetsData.getScenePreset(sceneId);
  if (preset != null && preset.name.isNotEmpty) return preset.name;
  for (final option in CapturePreviewMockData.sceneOptions) {
    if (option.id == sceneId && option.name.isNotEmpty) return option.name;
  }
  return sceneId;
}

/// 模板 ID → 展示名称。
///
/// 用于拍摄统计的模板排行：优先用内置模板注册表名称
/// （TemplateRegistry.allTemplates），未知模板回退为 templateId。
String templateDisplayName(String templateId) {
  final tpl = TemplateRegistry.getTemplate(templateId);
  if (tpl != null && tpl.meta.name.isNotEmpty) return tpl.meta.name;
  return templateId;
}