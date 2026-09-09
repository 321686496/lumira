import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../templates/data/owned_templates_repository.dart';

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

  /// 面板视觉：immersive=半透明暗底 / theme=当前风格面板底
  CaptureOverlayVisual get _visual =>
      LumiraThemeResolver.captureOverlayVisual(
        tokens: ref.watch(themeTokensProvider),
        style: ref.watch(appThemeProvider).style,
        appearance: ref.watch(CaptureState.captureAppearanceProvider),
        role: CaptureOverlayRole.panel,
        radiusDp: 0,
      );

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _collapse() {
    ref.read(CaptureState.templateDrawerExpandedProvider.notifier).state = false;
  }

  void _select(PhotoTemplate tpl) {
  final ownedIds = ref.read(ownedTemplateIdsProvider);
  // 付费模板未解锁：不直接应用，跳详情页并提示需多少积分解锁
  if (tpl.meta.price > 0 && !ownedIds.contains(tpl.meta.id)) {
    _collapse();
    LumiraToast.show(context, '这是付费模板，需 ${tpl.meta.price} 积分解锁');
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesDetail, tpl.meta.id),
    );
    return;
  }
  ref.read(CaptureState.currentTemplateIdProvider.notifier).state = tpl.meta.id;
  _collapse();
}

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(CaptureState.currentTemplateIdProvider);
    // 工具栏模板列表：当前使用的模板被提到第一位（含选中状态）
    final templates = ref.watch(CaptureState.toolbarTemplatesProvider);
    // 触发已拥有模板加载（付费模板门禁判断依赖 ownedTemplateIdsProvider）
    ref.watch(ownedTemplatesLoaderProvider);
    final ownedIds = ref.watch(ownedTemplateIdsProvider);

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
        color: _visual.background,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            _buildSearchField(),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配模板',
                        style: TextStyle(
                            color: _visual.foregroundMuted, fontSize: 13),
                      ),
                    )
                  : _buildGrid(filtered, currentId, ownedIds),
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
          Text(
            '全部模板',
            style: TextStyle(
              color: _visual.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // 收起，回到横向模板条
          IconButton(
            onPressed: _collapse,
            icon: Icon(Icons.expand_more,
                color: _visual.foregroundSecondary),
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
          color: _visual.fillSubtle,
          borderRadius: BorderRadius.circular(10),
          border: _visual.border,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(Icons.search, color: _visual.foregroundMuted, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                style: TextStyle(
                    color: _visual.foreground, fontSize: 13),
                cursorColor: _visual.foregroundSecondary,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索模板名称 / 分类 / 标签',
                  hintStyle: TextStyle(
                      color: _visual.foregroundMuted, fontSize: 13),
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
                child: Icon(Icons.clear,
                    color: _visual.foregroundMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(
    List<PhotoTemplate> templates,
    String? currentId,
    Set<String> ownedIds) {
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
        // 付费模板且当前用户未解锁 → 锁定（点按跳详情页，不直接应用）
        final isLocked = tpl.meta.price > 0 && !ownedIds.contains(tpl.meta.id);
        return GestureDetector(
          onTap: () => _select(tpl),
          behavior: HitTestBehavior.opaque,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: active ? _visual.accent : _visual.fillSubtle,
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
                // 付费模板锁定角标
                if (isLocked)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.lock, size: 9, color: Colors.white),
                          SizedBox(width: 3),
                          Text(
                            '付费',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
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
                      decoration: BoxDecoration(
                        color: _visual.accent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check,
                        color: _visual.onAccent,
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
        color: _visual.fillSubtle,
        child: Icon(Icons.image,
            color: _visual.foregroundMuted, size: 26),
      );
    }
    if (cover.startsWith('assets/')) {
      return Image.asset(
        cover,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _visual.fillSubtle,
          child: Icon(Icons.image,
              color: _visual.foregroundMuted, size: 26),
        ),
      );
    }
    return CachedNetworkImage(
      url: cover,
      fit: BoxFit.cover,
      errorWidget: Container(
        color: _visual.fillSubtle,
        child: Icon(Icons.image,
            color: _visual.foregroundMuted, size: 26),
      ),
    );
  }
}