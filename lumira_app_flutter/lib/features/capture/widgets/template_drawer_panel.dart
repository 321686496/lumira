import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import '../../../core/utils/image_cache.dart';

/// 「显示更多」展开的完整模板面板（约 60% 页面高度）。
///
/// 顶部为标题 + 收起按钮 + 搜索输入框，下方为按使用频率排序、可搜索过滤的模板网格。
/// 点击某模板 → 应用该模板（写 currentTemplateIdProvider）并收起面板回到横向条。
class TemplateDrawerPanel extends ConsumerStatefulWidget {
  const TemplateDrawerPanel({super.key});

  @override
  ConsumerState<TemplateDrawerPanel> createState() =>
      _TemplateDrawerPanelState();
}

class _TemplateDrawerPanelState extends ConsumerState<TemplateDrawerPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _collapse() {
    ref.read(CaptureState.templateDrawerExpandedProvider.notifier).state = false;
  }

  void _select(PhotoTemplate tpl) {
    ref.read(CaptureState.currentTemplateIdProvider.notifier).state = tpl.meta.id;
    _collapse();
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    // 工具栏模板列表：当前使用的模板被提到第一位（含选中状态）
    final templates = ref.watch(CaptureState.toolbarTemplatesProvider);

    final panelHeight = MediaQuery.of(context).size.height * 0.6;
    final keyword = _query.trim().toLowerCase();
    final filtered = keyword.isEmpty
        ? templates
        : templates
            .where((t) => t.meta.name.toLowerCase().contains(keyword) ||
                t.meta.category.toLowerCase().contains(keyword) ||
                (t.meta.tags.any((tag) =>
                    tag.toLowerCase().contains(keyword))))
            .toList();

    return SizedBox(
      height: panelHeight,
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSearchField(),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        '未找到匹配模板',
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    )
                  : _buildGrid(filtered, currentId),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          const Text(
            '全部模板',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 收起，回到横向模板条
          IconButton(
            onPressed: _collapse,
            icon: const Icon(Icons.expand_more, color: Colors.white70),
            tooltip: '收起',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Icon(Icons.search, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                cursorColor: Colors.white70,
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: '搜索模板名称 / 分类 / 标签',
                  hintStyle:
                      TextStyle(color: Colors.white38, fontSize: 13),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: const Icon(Icons.clear,
                    color: Colors.white54, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<PhotoTemplate> templates, String? currentId) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: templates.length,
      itemBuilder: (ctx, i) {
        final tpl = templates[i];
        final active = tpl.meta.id == currentId;
        final isCustom = tpl.meta.source == 'custom';
        return GestureDetector(
          onTap: () => _select(tpl),
          behavior: HitTestBehavior.opaque,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? Colors.amber : Colors.white12,
                width: active ? 2 : 0.5,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildCover(tpl.meta.cover),
                // 底部名称渐变
                Container(
                  alignment: Alignment.bottomLeft,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tpl.meta.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (isCustom)
                        const Text(
                          '我的',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 9,
                          ),
                        ),
                    ],
                  ),
                ),
                // 选中标记
                if (active)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.black,
                        size: 13,
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

  Widget _buildCover(String cover) {
    if (cover.isEmpty) {
      return Container(
        color: Colors.white12,
        child: const Icon(Icons.image, color: Colors.white54, size: 26),
      );
    }
    if (cover.startsWith('assets/')) {
      return Image.asset(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.white12,
          child: const Icon(Icons.image, color: Colors.white54, size: 26),
        ),
      );
    }
    return CachedNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      errorWidget: Container(
        color: Colors.white12,
        child: const Icon(Icons.image, color: Colors.white54, size: 26),
      ),
    );
  }
}