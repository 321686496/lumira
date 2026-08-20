import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/template_registry.dart';
import '../domain/photo_template.dart';
import '../../../core/utils/image_cache.dart';

/// 模板横向滚动条。
/// `compact=true` 显示前 6 个模板（底部条），`compact=false` 显示全部模板（展开面板）。
/// 点击模板卡片切换 `currentTemplateIdProvider`。
///
/// 修复 Bug 4：使用 TemplateMeta.cover 显示真实封面图，替代占位图标
class TemplateStrip extends ConsumerWidget {
  final bool compact;
  const TemplateStrip({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    final templatesAsync = ref.watch(CaptureState.sortedTemplatesProvider);

    return SizedBox(
      height: compact ? 60 : 75,
      child: templatesAsync.when(
        // 加载完成：显示排序后的模板列表
        data: (templates) {
          final list = compact ? templates.take(6).toList() : templates;
          if (list.isEmpty) {
            return _buildEmptyState();
          }
          return _buildTemplateList(list, currentId, ref);
        },
        // 加载中：降级显示系统模板
        loading: () {
          final fallback = TemplateRegistry.allTemplates;
          final list = compact ? fallback.take(6).toList() : fallback;
          return _buildTemplateList(list, currentId, ref);
        },
        // 错误：降级显示系统模板
        error: (_, __) {
          final fallback = TemplateRegistry.allTemplates;
          final list = compact ? fallback.take(6).toList() : fallback;
          return _buildTemplateList(list, currentId, ref);
        },
      ),
    );
  }

  /// 空状态占位
  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        '暂无模板',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  /// 根据路径类型选择加载方式（本地资源 vs 网络 URL）
  Widget _buildCoverImage(String cover, bool active) {
    final isAsset = cover.startsWith('assets/');
    final placeholder = Container(
      color: Colors.white12,
      child: Icon(
        Icons.image,
        color: active ? Colors.amber : Colors.white54,
        size: 24,
      ),
    );
    if (isAsset) {
      return Image.asset(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }
    return CachedNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      errorWidget: placeholder,
    );
  }

  /// 构建模板横向列表
  Widget _buildTemplateList(
    List<PhotoTemplate> templates,
    String? currentId,
    WidgetRef ref,
  ) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: templates.length,
      itemBuilder: (ctx, i) {
        final tpl = templates[i];
        final active = tpl.meta.id == currentId;
        // 判断是否为自定义模板（不在 TemplateRegistry 中则为自定义）
        final isCustom = TemplateRegistry.getTemplate(tpl.meta.id) == null;
        return GestureDetector(
          onTap: () {
            final next = active ? null : tpl.meta.id;
            ref
                .read(CaptureState.currentTemplateIdProvider.notifier)
                .state = next;
          },
          child: Container(
            width: compact ? 45 : 54,
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
                // 封面图（本地资源用 Image.asset，网络 URL 用 Image.network）
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
                      : _buildCoverImage(tpl.meta.cover, active),
                ),
                // 渐变遮罩
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
                // 自定义模板标记
                if (isCustom)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '我的',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                        ),
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
    );
  }
}
