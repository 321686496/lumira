// lib/features/home/services/tip_recommendation_service.dart
//
// 拍照小贴士推荐服务
//
// 算法：
// 1. 取最近 50 张照片（GalleryDao.getRecent）
// 2. 过滤最近 30 天
// 3. 统计 template.category 分布 → topCategory
// 4. 若 topCategory == 'portrait'：
//    - 检查 template.tags 是否含「自拍」关键词 → selfie 偏好
//    - 否则默认 other（他拍）
// 5. 从 TipKnowledgeBase 取 (topCategory, selfie/other) 对应贴士列表
// 6. 随机打乱取前 N 条
// 7. fallback：无数据时用 generalTips
//
// 注意：自拍/他拍判定依赖 template.tags。内置模板暂无「自拍」标签，
// 因此默认走 other 分支。用户自定义模板若有「自拍」标签则命中 selfie 分支。

import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../data/home_mock_data.dart';
import '../data/tip_knowledge_base.dart';

/// 自拍关键词判定（不区分大小写）
const List<String> _selfieKeywords = ['自拍', 'selfie', 'self-portrait'];

bool _isSelfieTemplate(TemplateRecord tpl) {
  final tags = tpl.tags;
  if (tags.isEmpty) return false;
  for (final tag in tags) {
    final lower = tag.toLowerCase();
    for (final kw in _selfieKeywords) {
      if (lower.contains(kw)) return true;
    }
  }
  return false;
}

class TipRecommendationService {
  TipRecommendationService({
    required GalleryDao galleryDao,
    required TemplatesDao templatesDao,
    this.maxTips = 6,
    this.recentLimit = 50,
    this.recentDays = 30,
  })  : _galleryDao = galleryDao,
        _templatesDao = templatesDao;

  final GalleryDao _galleryDao;
  final TemplatesDao _templatesDao;
  final int maxTips;
  final int recentLimit;
  final int recentDays;

  /// 构建推荐贴士列表
  /// 失败或无数据时返回 generalTips fallback
  Future<List<ShootingTip>> build() async {
    try {
      final recent = await _galleryDao.getRecent(limit: recentLimit);
      if (recent.isEmpty) {
        return _pickRandom(TipKnowledgeBase.generalTips, maxTips);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final threshold = now - recentDays * 24 * 3600 * 1000;
      final recentInWindow = recent.where((p) => p.createdAt >= threshold).toList();
      if (recentInWindow.isEmpty) {
        return _pickRandom(TipKnowledgeBase.generalTips, maxTips);
      }

      // 统计 category 分布：通过 templateId 反查 templates 表
      final categoryCounts = <String, int>{};
      final templateCache = <String, TemplateRecord>{};
      for (final p in recentInWindow) {
        final tplId = p.templateId;
        if (tplId == null || tplId.isEmpty) continue;
        TemplateRecord? tpl = templateCache[tplId];
        if (tpl == null) {
          tpl = await _templatesDao.getById(tplId);
          if (tpl != null) templateCache[tplId] = tpl;
        }
        if (tpl != null && tpl.category.isNotEmpty) {
          categoryCounts[tpl.category] = (categoryCounts[tpl.category] ?? 0) + 1;
        }
      }

      if (categoryCounts.isEmpty) {
        return _pickRandom(TipKnowledgeBase.generalTips, maxTips);
      }

      // 排序取 topCategory
      final sorted = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topCategory = sorted.first.key;

      // 自拍/他拍判定（仅 portrait 区分）
      ShootSubject subject = ShootSubject.other;
      if (topCategory == 'portrait') {
        // 检查 topCategory 的所有 template 是否含自拍标签
        int selfieCount = 0;
        int portraitTotal = 0;
        for (final entry in templateCache.entries) {
          if (entry.value.category == 'portrait') {
            portraitTotal++;
            if (_isSelfieTemplate(entry.value)) selfieCount++;
          }
        }
        // 自拍占比 >= 50% 视为自拍偏好
        if (portraitTotal > 0 && selfieCount * 2 >= portraitTotal) {
          subject = ShootSubject.selfie;
        }
      }

      final tips = TipKnowledgeBase.getTips(topCategory, subject);
      if (tips.isEmpty) {
        return _pickRandom(TipKnowledgeBase.generalTips, maxTips);
      }
      return _pickRandom(tips, maxTips);
    } catch (e) {
      debugPrint('TipRecommendationService failed: $e');
      return _pickRandom(TipKnowledgeBase.generalTips, maxTips);
    }
  }

  /// 随机取前 N 条
  List<ShootingTip> _pickRandom(List<ShootingTip> source, int n) {
    if (source.length <= n) return List.of(source);
    final rng = Random();
    final pool = List.of(source);
    pool.shuffle(rng);
    return pool.take(n).toList();
  }
}
