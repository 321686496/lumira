import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../capture/data/capture_scene_mock_data.dart';

/// 场景库页面分类 pill（与 uni-app scenes/index.vue categories 一致）
///
/// 5 项：全部 / 光线 / 室外 / 室内 / 情绪
/// 注意：与 capture_scene_guide_page 的「光线氛围/室外环境/室内空间/情绪氛围」不同，
/// scenes 页使用短名（与 uni-app 源页面一致）。
class ScenesCategoryPill {
  const ScenesCategoryPill({
    required this.id,
    required this.name,
    this.category,
  });

  /// 'all' 或 SceneCategory 字符串常量
  final String id;
  final String name;
  final String? category;
}

const List<ScenesCategoryPill> scenesCategoryPills = [
  ScenesCategoryPill(id: 'all', name: '全部'),
  ScenesCategoryPill(id: 'light', name: '光线', category: SceneCategory.light),
  ScenesCategoryPill(
      id: 'outdoor', name: '室外', category: SceneCategory.outdoor),
  ScenesCategoryPill(id: 'indoor', name: '室内', category: SceneCategory.indoor),
  ScenesCategoryPill(id: 'mood', name: '情绪', category: SceneCategory.mood),
];

/// 场景列表 Provider
///
/// 默认返回 CaptureSceneMockData.allScenes（跨模块复用 Task 2.10 已有数据）。
/// 测试可 override 以验证空状态等场景。
final scenesListProvider = Provider<List<ScenePreset>>((ref) {
  return CaptureSceneMockData.allScenes;
});
