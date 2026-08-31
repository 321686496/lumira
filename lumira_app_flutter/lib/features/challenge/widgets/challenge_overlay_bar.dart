import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../data/challenge_models.dart';
import '../data/challenge_pool.dart';

/// 拍摄页挑战悬浮条（可折叠）
///
/// 仅在挑战拍摄模式（capturePage.challengeId 非空）下显示。
/// - 折叠态：顶部小条，显示挑战标题 + 奖励 XP + 展开图标
/// - 展开态：标题 + 描述 + 拍摄提示，背景半透明
/// - 拍照时（captureInProgress=true）自动折叠，避免遮挡取景器
class ChallengeOverlayBar extends ConsumerStatefulWidget {
  const ChallengeOverlayBar({
    super.key,
    required this.challengeId,
    required this.captureInProgress,
    this.isLandscape = false,
    this.quarterTurns = 0,
  });

  final String challengeId;

  /// 是否正在拍照（用于自动折叠）
  final bool captureInProgress;

  /// 横持手机时为 true：面板旋转到可读方向（由传感器驱动，UI 整体仍保持竖屏）。
  final bool isLandscape;

  /// 横屏时面板需**顺时针**旋转的 90° 圈数（0/1/3），保证文字正向（左/右横适配）。
  final int quarterTurns;

  @override
  ConsumerState<ChallengeOverlayBar> createState() =>
      _ChallengeOverlayBarState();
}

class _ChallengeOverlayBarState extends ConsumerState<ChallengeOverlayBar>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  ChallengePoolItem? _item;

  @override
  void initState() {
    super.initState();
    _item = ChallengePool.byId(widget.challengeId);
  }

  @override
  void didUpdateWidget(covariant ChallengeOverlayBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challengeId != widget.challengeId) {
      _item = ChallengePool.byId(widget.challengeId);
    }
    // 拍照开始时自动折叠
    if (widget.captureInProgress && !oldWidget.captureInProgress) {
      setState(() => _expanded = false);
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    if (_item == null) return const SizedBox.shrink();
    final tokens = ref.watch(themeTokensProvider);

    // 竖屏：整卡顶部居中，占满屏宽。
    if (!widget.isLandscape) {
      return Align(
        alignment: Alignment.topCenter,
        child: _buildCard(tokens),
      );
    }

    // 横屏：整卡按持机方向旋转到可读角（顺时针 quarterTurns 圈），并贴向用户视角的
    // 「上方」。旋转后卡片内容顶部指向哪条画布边缘，哪条边缘就是用户视角的上方：
    // - quarterTurns=1（顶部在右）→ 内容顶部指向画布右缘 → 贴右；
    // - quarterTurns=3（顶部在左）→ 内容顶部指向画布左缘 → 贴左。
    // RotatedBox 会交换子项布局宽高，因此子项「宽度」= 旋转后画布纵向跨度、
    // 「高度」= 画布横向跨度（用户视角的卡片厚度）。
    final size = MediaQuery.of(context).size;
    final qTurns = (widget.quarterTurns == 0) ? 3 : widget.quarterTurns;
    // 距用户上方的留白（约 1/4 横屏视高，与竖屏时卡片距屏顶比例接近）
    const double userTopInset = 96;
    return Align(
      alignment: qTurns == 1 ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: qTurns == 1
            ? const EdgeInsets.only(right: userTopInset)
            : const EdgeInsets.only(left: userTopInset),
        child: RotatedBox(
          quarterTurns: qTurns,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.height * 0.5, // 旋转后为画布纵向跨度，限制避免过长
              maxHeight: size.width * 0.86, // 旋转后为画布横向跨度，避免越出画布短边
            ),
            child: _buildCard(tokens),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(ThemeTokens tokens) {
    final item = _item!;
    return Material(
      color: Colors.transparent,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
                vertical: _expanded ? 12 : 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xF0171512).withOpacity(0.92),
                borderRadius: BorderRadius.circular(_expanded ? 14 : 24),
                border: Border.all(
                  color: tokens.brand.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.30),
                    offset: const Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部行：图标 + 标题 + XP + 展开按钮（折叠/展开共用）
                  Row(
                    children: [
                      Icon(Icons.flag_outlined,
                          size: 16, color: tokens.brand),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // XP 徽标
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tokens.brand.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.stars_outlined,
                                size: 11, color: tokens.brand),
                            const SizedBox(width: 2),
                            Text(
                              '+${item.rewardXP}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tokens.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 展开/折叠图标
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  // 展开态：描述 + 拍摄提示
                  if (_expanded) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.78),
                        height: 1.5,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: tokens.brand.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              size: 14, color: tokens.brand),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.tip,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.85),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
  }
}
