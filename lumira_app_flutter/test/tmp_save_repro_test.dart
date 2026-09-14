import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:lumira_app_flutter/core/db/dao/scenes_dao.dart';
import 'package:lumira_app_flutter/core/db/database_provider.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_manage_providers.dart';
import 'package:lumira_app_flutter/features/capture/data/scene_record_mapper.dart';
import 'package:lumira_app_flutter/features/capture/domain/photo_template.dart';
import 'package:lumira_app_flutter/features/capture/domain/scene_preset.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  test('upsert 自定义场景应成功落库', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final dao = await container.read(scenesDaoProvider.future);

    final now = DateTime.now().millisecondsSinceEpoch;
    const bestTime = '';
    final preset = CustomScenePreset(
      id: 'custom_$now',
      name: '测试新场景',
      icon: 'ph-camera',
      category: SceneCategory.indoor,
      style: 'cafe',
      filter: const SceneFilter(lut: 'none', systemFilter: null, reason: ''),
      vibe: '慵懒午后',
      description: 'desc',
      exampleImages: const <String>[],
      tips: const <String>[],
      whereToShoot: '',
      bestTime: bestTime,
      sceneGuide: const SceneGuide(
        lightDirection: '自然光',
        shootingDistance: '1-2米',
        background: '简洁背景',
        props: [],
        bestTime: '',
        tips: [],
      ),
      relatedCategory: Target.portrait,
      tagIds: const <String>[],
      createdAt: now,
      updatedAt: now,
      cover: '',
    );

    try {
      await dao.upsert(customToRecord(preset, isFavorite: false));
      final rows = await dao.getCustomScenes();
      expect(rows.where((r) => r.id == preset.id).length, 1);
      // ignore: avoid_print
      print('UPSERT_OK: custom scenes count=${rows.length}');
    } catch (e, st) {
      // ignore: avoid_print
      print('UPSERT_FAILED: $e\n$st');
      rethrow;
    }
  });
}