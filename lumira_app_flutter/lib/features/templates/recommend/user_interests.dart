import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/user_interests_dao.dart';

/// 个性化反馈闭环：把用户行为按模板分类写回 user_interests 画像。
/// 时间衰减（半衰期 14 天），近期行为权重更高；失败静默。
class InterestService {
  /// 兴趣分半衰期（天）
  static const double kHalfLifeDays = 14;

  static const String scopeCategory = 'category';
  static const String scopeMajorStyle = 'major_style';
  static const String scopeStyle = 'style';

  final InterestDao _dao;
  final TemplatesDao _templatesDao;
  final Map<String, TemplateRecord> _templateCache = {};

  InterestService(this._dao, this._templatesDao);

  /// 纯函数：计算一次信号后的新兴趣分（便于单测与复用）。
  /// existing/lastAt 为空表示该维度首次出现。
  static double computeNewScore({
    required double? existing,
    required int? lastAt,
    required int nowMs,
    required double weight,
    required double halfLifeDays,
  }) {
    double base = existing ?? 0;
    if (existing != null && lastAt != null) {
      final elapsedDays = (nowMs - lastAt) / (24 * 3600 * 1000.0);
      base = base * math.pow(0.5, elapsedDays / halfLifeDays).toDouble();
    }
    return base + weight;
  }

  /// 记录一次正反馈，按模板分类把 weight 写入 category/majorStyle/style 三维。
  Future<void> recordSignal(String templateId, double weight) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final tpl = await _resolveTemplate(templateId);
      if (tpl == null) return;
      await _bump(scopeCategory, tpl.category, weight, now);
      final maj = tpl.classification['majorStyle'];
      if (maj is String) await _bump(scopeMajorStyle, maj, weight, now);
      final sty = tpl.classification['style'];
      if (sty is String) await _bump(scopeStyle, sty, weight, now);
    } catch (e) {
      debugPrint('[interest] recordSignal failed (silent): $e');
    }
  }

  Future<TemplateRecord?> _resolveTemplate(String id) async {
    if (_templateCache.containsKey(id)) return _templateCache[id];
    final t = await _templatesDao.getById(id);
    if (t != null) _templateCache[id] = t;
    return t;
  }

  Future<void> _bump(String scope, String key, double weight, int nowMs) async {
    if (key.trim().isEmpty) return;
    final existing = await _dao.read(scope, key);
    final updated = computeNewScore(
      existing: existing?.score,
      lastAt: existing?.lastSignalAt,
      nowMs: nowMs,
      weight: weight,
      halfLifeDays: kHalfLifeDays,
    );
    await _dao.upsert(scope: scope, key: key, score: updated, at: nowMs);
  }
}