import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_preview_mock_data.dart';

/// 拍摄预览页底部「心情 | 场景」双行标记带。
///
/// 第一行：心情 —— 「图标 + 文案」胶囊，横向滑动（点选中项再点一次 = 取消，语义等同旧「跳过」）。
/// 第二行：场景 —— 「圆角缩略图 + 场景名」卡片，横向滑动（首项「不标记」= null）。
///
/// 相比旧的单行纯文字 pill，本组件为心情补上图标、为场景补上场景图，
/// 提升选择区的存在感，同时保持卡片内「纯色 + 细描边」的简洁分层语义。
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
        // 第 2 行：场景（缩略图卡横向滑动，首项「不标记」）
        SizedBox(
          height: 78,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
              return _SceneCard(
                scene: scene,
                active: selectedSceneId == scene.id,
                tokens: tokens,
                onTap: () => onSelectScene(scene.id),
              );
            },
          ),
        ),
        const SizedBox(height: 2),
      ],
    );
  }
}

/// 单个「图标 + 文案」胶囊：选中 = 品牌渐变底 + 反色文字/图标；
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
    final isDarkOnActive = active;
    final fg = isDarkOnActive ? tokens.textInverse : tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: icon == null ? 12 : 8, vertical: 6),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  colors: [tokens.brand, tokens.brandDeep],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: active ? null : tokens.surfaceAlt,
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

/// 单个场景缩略图卡：上方圆角场景图 + 下方场景名。
class _SceneCard extends StatelessWidget {
  const _SceneCard({
    required this.scene,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final ScenePillOption scene;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  static const double _thumbSize = 56;

  @override
  Widget build(BuildContext context) {
    final image = scene.image;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 缩略图 + 选中描边 / 勾标
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active ? tokens.brand : tokens.surfaceAlt,
                    width: active ? 2 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (image != null)
                      Image.asset(
                        image,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    else
                      _placeholder(),
                    if (active)
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: tokens.brand,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.check, color: tokens.textInverse, size: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            // 场景名
            Text(
              scene.name,
              style: TextStyle(
                fontSize: 10,
                color: active ? tokens.brand : tokens.textSecondary,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                height: 1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: tokens.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(
        scene.icon,
        color: tokens.textSecondary,
        size: 22,
      ),
    );
  }
}