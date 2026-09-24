import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/usage_dao.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_scene_providers.dart';
import '../data/capture_state.dart';
import '../data/scene_presets_data.dart';
import '../domain/scene_preset.dart';
import '../../usage/usage_providers.dart';

/// 打开拍摄页「查看更多场景」底部抽屉。
Future<void> showSceneDrawerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (sheetCtx) {
      final keyboard = MediaQuery.of(sheetCtx).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: SafeArea(
          top: false,
          bottom: false,
          child: SceneDrawerPanel(anchor: context),
        ),
      );
    },
  );
}

class SceneDrawerPanel extends ConsumerStatefulWidget {
  const SceneDrawerPanel({super.key, required this.anchor});

  final BuildContext anchor;

  @override
  ConsumerState<SceneDrawerPanel> createState() => _SceneDrawerPanelState();
}

class _SceneDrawerPanelState extends ConsumerState<SceneDrawerPanel> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  CaptureOverlayVisual get _visual => LumiraThemeResolver.captureOverlayVisual(
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
    Navigator.of(context).pop();
  }

  void _select(ScenePreset scene) {
    ref.read(CaptureState.activeScenePresetIdProvider.notifier).state =
        scene.id;
    CaptureState.applySceneFilter(ref, scene.filter);
    _reportSceneSelect(scene);
    _collapse();
  }

  Future<void> _reportSceneSelect(ScenePreset scene) async {
    final isSystem = ScenePresetsData.getScenePreset(scene.id) != null;
    if (!isSystem && !scene.isCustom) return;
    try {
      final recorder = await ref.read(usageEventRecorderProvider.future);
      await recorder.recordScene(
        sceneId: scene.id,
        creator: isSystem ? 'system' : 'user',
        event: UsageEventType.sceneSelect,
      );
    } catch (_) {
      // 上报失败静默
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeId = ref.watch(CaptureState.activeScenePresetIdProvider);
    final scenesAsync = ref.watch(captureScenePresetsProvider);
    final keyword = _query.trim().toLowerCase();

    return scenesAsync.when(
      loading: () => _buildShell(
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _visual.foregroundMuted,
            ),
          ),
        ),
      ),
      error: (_, __) => _buildShell(
        child: Center(
          child: Text(
            '场景加载失败',
            style: TextStyle(color: _visual.foregroundMuted, fontSize: 13),
          ),
        ),
      ),
      data: (scenes) {
        final filtered = keyword.isEmpty
            ? scenes
            : scenes
                .where(
                  (scene) =>
                      scene.name.toLowerCase().contains(keyword) ||
                      scene.category.toLowerCase().contains(keyword) ||
                      scene.style.toLowerCase().contains(keyword),
                )
                .toList();

        return _buildShell(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              _buildSearchField(),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          '未找到匹配场景',
                          style: TextStyle(
                            color: _visual.foregroundMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : _buildGrid(filtered, activeId),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShell({required Widget child}) {
    final mq = MediaQuery.of(context);
    final keyboard = mq.viewInsets.bottom;
    final available = math.max(
      mq.size.height - mq.padding.top - mq.padding.bottom - keyboard - 16,
      160.0,
    );
    final panelHeight = math.min(available, mq.size.height * 0.6);

    return Container(
      height: panelHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        color: _visual.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          Text(
            '全部场景',
            style: TextStyle(
              color: _visual.foreground,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _collapse,
            icon: Icon(Icons.expand_more, color: _visual.foregroundSecondary),
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
                style: TextStyle(color: _visual.foreground, fontSize: 13),
                cursorColor: _visual.foregroundSecondary,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '搜索场景名称 / 分类 / 风格',
                  hintStyle: TextStyle(
                    color: _visual.foregroundMuted,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child:
                    Icon(Icons.clear, color: _visual.foregroundMuted, size: 18),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<ScenePreset> scenes, String? activeId) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.72,
      ),
      itemCount: scenes.length,
      itemBuilder: (ctx, i) {
        final scene = scenes[i];
        final active = scene.id == activeId;
        return GestureDetector(
          onTap: () => _select(scene),
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
                _buildCover(scene),
                Container(
                  alignment: Alignment.bottomLeft,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
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
                  child: Text(
                    scene.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (scene.isCustom)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '我的',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ),
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

  Widget _buildCover(ScenePreset scene) {
    final url = sceneCoverUrl(scene);
    if (url.isEmpty) {
      return Container(
        color: _visual.fillSubtle,
        child: Icon(
          Icons.place,
          color: _visual.foregroundMuted,
          size: 26,
        ),
      );
    }
    if (url.startsWith('data:')) {
      return Image.memory(
        UriData.parse(url).contentAsBytes(),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _visual.fillSubtle,
          child: Icon(
            Icons.place,
            color: _visual.foregroundMuted,
            size: 26,
          ),
        ),
      );
    }
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: _visual.fillSubtle,
          child: Icon(
            Icons.place,
            color: _visual.foregroundMuted,
            size: 26,
          ),
        ),
      );
    }
    return CachedNetworkImage(
      url: url,
      fit: BoxFit.cover,
      errorWidget: Container(
        color: _visual.fillSubtle,
        child: Icon(
          Icons.place,
          color: _visual.foregroundMuted,
          size: 26,
        ),
      ),
    );
  }
}
