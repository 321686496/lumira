import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/template_registry.dart';

/// 模板横向滚动条。
/// `compact=true` 显示前 6 个模板（底部条），`compact=false` 显示前 12 个（展开面板）。
/// 点击模板卡片切换 `currentTemplateIdProvider`。
class TemplateStrip extends ConsumerWidget {
  final bool compact;
  const TemplateStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    final templates = TemplateRegistry.getRecentTemplates(compact ? 6 : 12);

    return SizedBox(
      height: compact ? 80 : 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: templates.length,
        itemBuilder: (ctx, i) {
          final tpl = templates[i];
          final active = tpl.meta.id == currentId;
          return GestureDetector(
            onTap: () =>
                ref.read(CaptureState.currentTemplateIdProvider.notifier).state = tpl.meta.id,
            child: Container(
              width: compact ? 60 : 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: active ? Border.all(color: Colors.amber, width: 2) : null,
                color: Colors.white12,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    color: active ? Colors.amber : Colors.white54,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tpl.meta.name,
                    style: TextStyle(
                      color: active ? Colors.amber : Colors.white70,
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
