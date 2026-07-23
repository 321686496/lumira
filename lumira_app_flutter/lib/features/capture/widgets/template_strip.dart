import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/template_registry.dart';

/// 模板横向滚动条。
/// `compact=true` 显示前 6 个模板（底部条），`compact=false` 显示前 12 个（展开面板）。
/// 点击模板卡片切换 `currentTemplateIdProvider`。
///
/// 修复 Bug 4：使用 TemplateMeta.cover 显示真实封面图，替代占位图标
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
            onTap: () {
              // toggle 行为：点击已选中模板则取消（回到自由拍摄），否则选中
              final next = active ? null : tpl.meta.id;
              ref
                  .read(CaptureState.currentTemplateIdProvider.notifier)
                  .state = next;
            },
            child: Container(
              width: compact ? 60 : 72,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: active
                    ? Border.all(color: Colors.amber, width: 2)
                    : Border.all(color: Colors.white12, width: 0.5),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 封面图
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: tpl.meta.cover.isEmpty
                        ? Container(
                            color: Colors.white12,
                            child: Icon(
                              Icons.image,
                              color: active ? Colors.amber : Colors.white54,
                              size: 24,
                            ),
                          )
                        : Image.network(
                            tpl.meta.cover,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.white12,
                              child: Icon(
                                Icons.image,
                                color: active ? Colors.amber : Colors.white54,
                                size: 24,
                              ),
                            ),
                          ),
                  ),
                  // 渐变遮罩，确保文字清晰
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(6),
                          bottomRight: Radius.circular(6),
                        ),
                      ),
                      child: Text(
                        tpl.meta.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  // 选中标记
                  if (active)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.black,
                          size: 12,
                        ),
                      ),
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
