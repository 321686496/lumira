import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_state.dart';
import 'package:lumira_app_flutter/features/capture/data/template_registry.dart';

void main() {
  test('allTemplatesProvider returns system templates even when DAO is unavailable', () async {
    final container = ProviderContainer();
    final result = await container.read(CaptureState.allTemplatesProvider.future);
    // 系统模板始终可用（12 个），DAO 加载失败时降级为仅系统模板
    expect(result.length, greaterThanOrEqualTo(12));
    // 验证包含已知系统模板
    final ids = result.map((t) => t.meta.id).toList();
    expect(ids, contains('soft_portrait'));
    expect(ids, contains('neon_portrait'));
  });

  test('templateCacheProvider contains all system templates by id', () {
    final container = ProviderContainer();
    final cache = container.read(CaptureState.templateCacheProvider);
    // 降级策略：DAO 未加载完成时仅含系统模板
    expect(cache['soft_portrait'], isNotNull);
    expect(cache['neon_portrait'], isNotNull);
    expect(cache.length, greaterThanOrEqualTo(12));
  });
}
