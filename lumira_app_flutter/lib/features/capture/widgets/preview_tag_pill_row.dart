import 'package:flutter/material.dart';

import 'package:lumira_app_flutter/core/theme/theme_tokens.dart';
import 'package:lumira_app_flutter/features/capture/data/capture_preview_mock_data.dart';

/// 拍摄预览页底部「心情 | 场景」紧凑 pill 行。
///
/// 左半区横向滑动选择心情（点选中项再点一次 = 取消，语义等同旧「跳过」），
/// 右半区横向滑动选择拍摄场景（首项「不标记」= null）。
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
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // 左：心情
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: moods.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Center(
                child: _TagPill(
                  label: moods[i].name,
                  active: moods[i].active,
                  tokens: tokens,
                  onTap: () => onSelectMood(moods[i]),
                ),
              ),
            ),
          ),
          // 中：细分隔线
          Container(width: 1, height: 20, color: tokens.divider),
          const SizedBox(width: 8),
          // 右：场景（首项「不标记」）
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                return Center(
                  child: _TagPill(
                    label: scene.name,
                    active: selectedSceneId == scene.id,
                    tokens: tokens,
                    onTap: () => onSelectScene(scene.id),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// 单个标签 pill：选中 = 品牌渐变底 + 反色文字；未选 = surfaceAlt 底 + 次级文字
class _TagPill extends StatelessWidget {
  const _TagPill({
    required this.label,
    required this.active,
    required this.tokens,
    required this.onTap,
  });

  final String label;
  final bool active;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: active ? tokens.textInverse : tokens.textSecondary,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
