import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../domain/photo_template.dart';

/// 拍摄页套用模板后的可折叠模板信息卡。
///
/// - 折叠态：图标 + 模板名 + 展开箭头
/// - 展开态：简介（meta.description）+ 拍摄注意点列表（sceneGuide.tips）
/// - 套用模板默认展开；切换模板（id 变化）时重置为展开
/// - 视觉与 ChallengeOverlayBar 保持一致（深色半透明浮层 + 品牌色描边）
class TemplateInfoCard extends ConsumerStatefulWidget {
  const TemplateInfoCard({
    super.key,
    required this.template,
    this.isLandscape = false,
    this.quarterTurns = 0,
    this.onHide,
  });

  final PhotoTemplate template;

  /// 横持手机时为 true：卡片旋转到可读方向（由传感器驱动，UI 整体仍保持竖屏）。
  final bool isLandscape;

  /// 横屏时卡片需**顺时针**旋转的 90° 圈数（0/1/3），保证文字正向（左/右横适配）。
  final int quarterTurns;

  /// 用户点击卡内“隐藏”按钮时回调（由外层负责隐藏卡片并持久化偏好）。
  final VoidCallback? onHide;

  @override
  ConsumerState<TemplateInfoCard> createState() => _TemplateInfoCardState();
}

class _TemplateInfoCardState extends ConsumerState<TemplateInfoCard> {
  /// 默认展开，让用户第一时间看到拍摄要点
  bool _expanded = true;

  @override
  void didUpdateWidget(covariant TemplateInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换模板（id 变化）时重置为展开
    if (oldWidget.template.meta.id != widget.template.meta.id) {
      _expanded = true;
    }
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);

    // 竖屏：整卡顶部居中，占满屏宽。
    if (!widget.isLandscape) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: Material(
            color: Colors.transparent,
            child: _buildBody(appTheme),
          ),
        ),
      );
    }

    // 横屏：整卡按持机方向旋转到可读角（顺时针 quarterTurns 圈），并贴向用户视角的
    // 「上方」。旋转后卡片内容的顶部指向哪条画布边缘，哪条边缘就是用户视角的上方：
    // - quarterTurns=1（逆时针持机，手机顶部在用户左侧）→ 内容顶部指向画布右缘 → 贴右；
    // - quarterTurns=3（顺时针持机，手机顶部在用户右侧）→ 内容顶部指向画布左缘 → 贴左。
    // RotatedBox 会交换子项的布局宽高：子项「宽度」= 旋转后在画布上的纵向跨度，
    // 子项「高度」= 画布横向跨度（用户视角的卡片厚度）。
    final size = MediaQuery.of(context).size;
    final qTurns = (widget.quarterTurns == 0) ? 3 : widget.quarterTurns;
    // 距用户上方的留白（约 1/4 横屏视高，与竖屏时卡片距屏顶比例接近）：
    // 同时避开画布右缘约 40% 高度处的多姿势切换按钮（right:12 + 自宽约 72 + 间隙），
    // 保证两种持机方向下卡片展开/收起都不会被其遮挡。
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
            child: Material(
              color: Colors.transparent,
              child: _buildBody(appTheme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData appTheme) {
    final tokens = appTheme.tokens;
    final template = widget.template;
    final tips = template.sceneGuide.tips;
    // 无简介且无注意点时仅渲染标题条
    final hasContent =
        template.meta.description.isNotEmpty || tips.isNotEmpty;

    return AnimatedSize(
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
              decoration: appTheme.style == UIStyle.glass
                  ? BoxDecoration(
                      // 玻璃风格：半透明底色 + 细白描边 + 柔和投影
                      color: ThemeTokens.glassFill(tokens),
                      borderRadius:
                          BorderRadius.circular(_expanded ? 14 : 24),
                      border: Border.all(
                        color: ThemeTokens.glassBorder(tokens),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1F000000),
                          offset: Offset(0, 6),
                          blurRadius: 20,
                        ),
                      ],
                    )
                  : BoxDecoration(
                      color: const Color(0xF0171512).withOpacity(0.92),
                      borderRadius:
                          BorderRadius.circular(_expanded ? 14 : 24),
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
                  // 标题行：图标 + 模板名 + 箭头（折叠/展开共用）
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: tokens.brand),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          template.meta.name,
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
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 隐藏按钮：点击后整卡消失并持久化（仅当外层提供回调时显示）
                      if (widget.onHide != null)
                        GestureDetector(
                          onTap: widget.onHide,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ),
                    ],
                  ),
                  // 展开态：简介 + 注意点
                  if (_expanded && hasContent) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.12),
                    ),
                    if (template.meta.description.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        template.meta.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.78),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (tips.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      ...tips.map(
                        (tip) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.check_circle_outline,
                                  size: 13,
                                  color: tokens.brand,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  tip,
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
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
    );
  }
}
