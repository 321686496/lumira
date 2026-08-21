import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../data/template_registry.dart';
import '../domain/photo_template.dart';
import '../../../core/utils/image_cache.dart';

/// 模板横向滚动条。
/// `compact=true` 显示前 6 个模板（底部条），`compact=false` 显示前 10 个模板（展开面板）。
/// 点击模板卡片切换 `currentTemplateIdProvider`。
/// 当模板总数超过展示上限时，末尾追加一个「显示更多」按钮（触发 [onShowMore]）。
///
/// 修复 Bug 4：使用 TemplateMeta.cover 显示真实封面图，替代占位图标
class TemplateStrip extends ConsumerWidget {
  final bool compact;
  final VoidCallback? onShowMore;
  const TemplateStrip({super.key, this.compact = false, this.onShowMore});

  /// 展开面板模式下最多展示的模板条数（前 N 个按使用频率排序）
  static const _drawerMax = 10;
  static const _compactMax = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    final templatesAsync = ref.watch(CaptureState.sortedTemplatesProvider);

    // 统一解析模板列表，加载/错误时降级显示系统模板
    final templates = templatesAsync.maybeWhen(
      data: (list) => list,
      loading: () => TemplateRegistry.allTemplates,
      error: (_, __) => TemplateRegistry.allTemplates,
      orElse: () => TemplateRegistry.allTemplates,
    );
    final max = compact ? _compactMax : _drawerMax;
    // 「显示更多」入口仅在展开面板模式（compact=false）下显示，
    // compact 紧凑条保持纯前 N 个模板的语义。
    final hasMore = !compact && templates.length > max;
    final visible = templates.take(max).toList();

    if (visible.isEmpty) {
      return _buildEmptyState();
    }
    return _buildTemplateList(
      visible,
      currentId,
      ref,
      showMore: hasMore,
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

  /// 构建模板横向列表（末尾可按需追加「显示更多」入口）
  Widget _buildTemplateList(
    List<PhotoTemplate> templates,
    String? currentId,
    WidgetRef ref, {
    bool showMore = false,
  }) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: templates.length + (showMore ? 1 : 0),
      itemBuilder: (ctx, i) {
        // 末尾「显示更多」入口
        if (showMore && i == templates.length) {
          return _buildShowMoreItem();
        }
        final tpl = templates[i];
        final active = tpl.meta.id == currentId;
        // 仅用户自定义模板（source='custom'）标记「我的」，
        // 后端动态模板（source='remote'）与系统内置模板不再误标。
        final isCustom = tpl.meta.source == 'custom';
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

  /// 列表末尾「显示更多」按钮：展开带搜索的完整模板列表
  Widget _buildShowMoreItem() {
    return GestureDetector(
      onTap: () => onShowMore?.call(),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: compact ? 45 : 60,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white24, width: 0.5),
          color: Colors.white10,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.expand_more, color: Colors.white70, size: 20),
            const SizedBox(height: 2),
            const Text(
              '显示更多',
              style: TextStyle(color: Colors.white70, fontSize: 9),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
