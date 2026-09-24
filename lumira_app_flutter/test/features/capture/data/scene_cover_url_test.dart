import 'package:flutter_test/flutter_test.dart';

import 'package:lumira_app_flutter/features/capture/data/capture_scene_providers.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_presets_data.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart'
    show SceneGuide;
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';

/// sceneCoverUrl —— 场景封面取源优先级
///
/// 背景：场景管理页封面若直接取 exampleImages 首图，内置场景会落到 picsum
/// 网络图（海外 + 302 跳转），而 App 内已打包同名本地封面 assets/images/scenes/
/// scene_<id>.jpg。此处锁定「本地打包封面优先」的取源顺序，避免回归成网络加载。
void main() {
  const filter = SceneFilter(lut: 'none');
  const guide = SceneGuide(
    lightDirection: '',
    shootingDistance: '',
    background: '',
    props: [],
    bestTime: '',
    tips: [],
  );

  /// 构造 mock 形态的内置场景（示例图为 picsum 网络地址）。
  ScenePreset presetWithPicsum(String id) {
    final real = ScenePresetsData.getScenePreset(id);
    expect(real, isNotNull, reason: '$id 应为内置预设场景');
    return real!.copyWith(
      exampleImages: ['https://picsum.photos/seed/$id/600/800'],
    );
  }

  CustomScenePreset customScene({
    String cover = '',
    List<String> exampleImages = const [],
  }) {
    return CustomScenePreset(
      id: 'custom_1',
      name: '自定义场景',
      filter: filter,
      sceneGuide: guide,
      exampleImages: exampleImages,
      tagIds: const [],
      createdAt: 0,
      updatedAt: 0,
      cover: cover,
    );
  }

  group('sceneCoverUrl — 本地打包封面优先', () {
    test('内置场景示例图为 picsum 时，仍返回本地打包封面', () {
      final scene = presetWithPicsum('cafe-window');

      expect(sceneCoverUrl(scene), 'assets/images/scenes/scene_cafe-window.jpg');
    });

    test('内置场景本地封面与 id 一一对应（多个场景同样命中）', () {
      expect(
        sceneCoverUrl(presetWithPicsum('night-street')),
        'assets/images/scenes/scene_night-street.jpg',
      );
      expect(
        sceneCoverUrl(presetWithPicsum('rainy-window')),
        'assets/images/scenes/scene_rainy-window.jpg',
      );
    });
  });

  group('sceneCoverUrl — 兜底顺序', () {
    test('自定义场景已设置封面时，返回用户封面', () {
      final scene = customScene(
        cover: 'data:image/jpeg;base64,AAAA',
        exampleImages: const ['https://picsum.photos/seed/foo/600/800'],
      );

      expect(sceneCoverUrl(scene), 'data:image/jpeg;base64,AAAA');
    });

    test('自定义场景未设封面时，回退示例图首图', () {
      final scene = customScene(
        exampleImages: const ['https://picsum.photos/seed/foo/600/800'],
      );

      expect(sceneCoverUrl(scene), 'https://picsum.photos/seed/foo/600/800');
    });

    test('无本地封面且无示例图时，返回空串', () {
      expect(sceneCoverUrl(customScene()), '');
    });
  });
}