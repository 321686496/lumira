import '../../capture/data/capture_scene_mock_data.dart';
import '../../capture/data/template_registry.dart';

/// 场景 ID → 展示名称。
///
/// 用于相册筛选 pill 与拍摄统计排行：优先用内置/自定义场景预设名称
/// （CaptureSceneMockData.allScenes），未知场景回退为 sceneId。
String sceneDisplayName(String sceneId) {
  if (sceneId == 'uncategorized') return '未设置场景';
  final scene = CaptureSceneMockData.getSceneById(sceneId);
  if (scene != null && scene.name.isNotEmpty) return scene.name;
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