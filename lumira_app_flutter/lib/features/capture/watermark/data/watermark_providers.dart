import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/watermark_settings.dart';
import '../models/watermark_template.dart';
import '../services/watermark_renderer.dart';
import 'preset_watermarks.dart';

/// 水印运行时设置（总开关 / 当前模板 id / 动画开关）。
///
/// 后续 UI 任务可读取此 Provider 决定是否启用水印；写入时通过 `ref.read(...).state =`
/// 切换。后续如需持久化，可在 settings 层加 WatermarkSettings 持久化逻辑。
final watermarkSettingsProvider = StateProvider<WatermarkSettings>((ref) {
  return const WatermarkSettings();
});

/// 水印渲染器单例（无状态，可直接复用）。
final watermarkRendererProvider = Provider<WatermarkRenderer>((ref) {
  return WatermarkRenderer();
});

/// 预置水印模板列表（5 款）。
///
/// 每次读取重新构造，避免外部误改污染缓存。若后续需要缓存，可改为
/// final 字段或 Provider.cacheTime。
final presetWatermarksProvider = Provider<List<WatermarkTemplate>>((ref) {
  return getPresetWatermarks();
});

/// 当前选中的水印模板（设置未启用 / 无选中模板 / 选中 id 不存在时返回 null）。
///
/// 当前仅查预置模板；后续自定义模板表接入后，可在此 Provider 内
/// 优先查 DAO，未命中再 fallback 预置列表。
final currentWatermarkTemplateProvider = Provider<WatermarkTemplate?>((ref) {
  final settings = ref.watch(watermarkSettingsProvider);
  if (!settings.enabled || settings.activeTemplateId == null) return null;
  final presets = ref.watch(presetWatermarksProvider);
  try {
    return presets.firstWhere((t) => t.id == settings.activeTemplateId);
  } catch (_) {
    return null;
  }
});
