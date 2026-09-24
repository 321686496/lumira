import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_preview_mock_data.dart';

/// 拍摄预览页底部「心情 | 场景」双行标记带。
///
/// 第一行：心情 —— 「图标 + 文案」胶囊，横向滑动（点选中项再点一次 = 取消，语义等同旧「跳过」）。
/// 第二行：场景 —— 「图标 + 场景名」轻量胶囊 Tab，横向滑动（首项「不标记」= null）。
///
/// 心情与场景都使用「图标 + 文案」胶囊，保持两行选择区一致且低视觉负担。
class PreviewTagPillRow extends StatelessWidget {
  const PreviewTagPillRow({
    Key? key,
    required this.moods,
    required this.selectedSceneId,
    required this.onSelectMood,
    required this.onSelectScene,
    required this.tokens,
  }) : super(key: key);

  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    const scenes = CapturePreviewMockData.sceneOptions;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        // 第 1 行：心情（icon + text 胶囊，横向滑动）
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: moods.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => Center(
              child: _TagPill(
                label: moods[i].name,
                icon: moods[i].icon,
                active: moods[i].active,
                tokens: tokens,
                onTap: () => onSelectMood(moods[i]),
              ),
            ),
          ),
        ),
        Container(width: double.infinity, height: 1, color: tokens.divider),
        // 第 2 行：场景（轻量胶囊 Tab，横向滑动，首项「不标记」）
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            physics: const BouncingScrollPhysics(),
            itemCount: scenes.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              if (i == 0) {
                return Center(
                  child: _TagPill(
                    label: '不标记',
                    active: selectedSceneId == null,
                    tokens: tokens,
                    onTap: () => onSelectScene(null),
                  ),
                );
              }
              final scene = scenes[i - 1];
              return _SceneTab(
                scene: scene,
                active: selectedSceneId == scene.id,
                tokens: tokens,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelectScene(scene.id);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

/// 单个「图标 + 文案」胶囊：选中 = 品牌弱底 + 品牌前景；
/// 未选 = surfaceAlt 底 + 次级文字/图标。
class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final fg = active ? tokens.brand : tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: icon == null ? 12 : 8, vertical: 6),
        decoration: BoxDecoration(
          color: active ? tokens.brandSubtle : tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: fg,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: fg,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单个场景胶囊 Tab：图标 + 文案，视觉更轻、命中率更稳。
class _SceneTab extends StatelessWidget {
  const _SceneTab({
    required this.scene,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final ScenePillOption scene;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? tokens.brand : tokens.textSecondary;
    final subtleFg = active ? tokens.brand : tokens.textTertiary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Semantics(
        selected: active,
        button: true,
        label: scene.name,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? tokens.brandSubtle : tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                scene.icon,
                size: 16,
                color: subtleFg,
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 160),
                style: TextStyle(
                  fontSize: 12,
                  color: fg,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  height: 1,
                ),
                child: Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
