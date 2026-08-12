// lumira_app_flutter/lib/features/templates/recommend/recommendation_providers.dart
//
// 推荐装配层：DAO 数据 -> 引擎信号 -> RecommendationResult。
// 页面只需 watch recommendationProvider。

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../templates/data/owned_templates_repository.dart';
import 'recommendation_engine.dart';
import 'recommendation_models.dart';

/// 「为你推荐」页数据源
///
/// 组装步骤：
/// 1. 等待已拥有模板加载完成（ownedTemplatesLoaderProvider）
/// 2. 读取本地照片（最近 500 张）、模板候选池（builtin + remote）、场景、问卷
/// 3. 转换为引擎信号，调用 RecommendationEngine.build
final recommendationProvider = FutureProvider<RecommendationResult>((ref) async {
  // 确保已拥有模板列表加载完成，避免推荐误含已拥有模板
  await ref.watch(ownedTemplatesLoaderProvider.future);
  final owned = ref.watch(ownedTemplateIdsProvider);

  final galleryDao = await ref.watch(galleryDaoProvider.future);
  final templatesDao = await ref.watch(templatesDaoProvider.future);
  final scenesDao = await ref.watch(scenesDaoProvider.future);
  final questionnaireDao = await ref.watch(questionnaireDaoProvider.future);

  // 并行读取本地数据
  final photos = await galleryDao.getAll(limit: 500);
  final templateRecords = await templatesDao.getBuiltinAndRemote();
  final sceneRecords = await scenesDao.getAll();
  final questionnaire = await questionnaireDao.getAnswers();

  // 场景信号
  final scenes = <String, SceneSignal>{
    for (final s in sceneRecords)
      s.id: SceneSignal(
        id: s.id,
        style: s.style,
        relatedCategory: s.relatedCategory,
      ),
  };

  // 模板信号
  final templates = templateRecords
      .map((t) => TemplateSignal(
            id: t.id,
            name: t.name,
            category: t.category,
            tags: t.tags,
            tagIds: t.tagIds,
            classification: t.classification,
            postProcess: t.postProcess,
            cover: t.cover,
            coverData: t.coverData,
            price: t.price,
            updatedAt: t.updatedAt,
          ))
      .toList();

  // 照片信号
  final photoSignals = photos.map((p) {
    final pp = p.postProcess;
    return PhotoSignal(
      createdAt: p.createdAt,
      templateId: p.templateId,
      sceneId: p.sceneId,
      isFavorite: p.isFavorite,
      postProcess: pp == null
          ? null
          : PostProcessVector(
              saturation: pp.color.saturation,
              temperature: pp.color.temperature,
              contrast: pp.color.contrast,
              brightness: pp.color.brightness,
            ),
    );
  }).toList();

  final engine = RecommendationEngine();
  return engine.build(RecommendationEngineInput(
    photos: photoSignals,
    scenes: scenes,
    templates: templates,
    ownedTemplateIds: owned,
    questionnaire: questionnaire,
    nowMs: DateTime.now().millisecondsSinceEpoch,
  ));
});
