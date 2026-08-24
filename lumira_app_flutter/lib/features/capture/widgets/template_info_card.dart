import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../domain/photo_template.dart';

/// 拍摄页套用模板后的可折叠模板信息卡。
///
/// - 折叠态：图标 + 模板名 + 展开箭头
/// - 展开态：简介（meta.description）+ 拍摄注意点列表（sceneGuide.tips）
/// - 套用模板默认展开；切换模板（id 变化）时重置为展开
/// - 视觉与 ChallengeOverlayBar 保持一致（深色半透明浮层 + 品牌色描边）
class TemplateInfoCard extends ConsumerStatefulWidget {
  const TemplateInfoCard({super.key, required this.template, this.onHide});

  final PhotoTemplate template;

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
    final tokens = ref.watch(themeTokensProvider);
    final template = widget.template;
    final tips = template.sceneGuide.tips;
    // 无简介且无注意点时仅渲染标题条
    final hasContent =
        template.meta.description.isNotEmpty || tips.isNotEmpty;

    // 横屏时卡片宽度受限于屏宽的 ~70%，整体居中展示（避免全宽拉伸，呈“横屏样式”）
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final maxWidth = isLandscape
        ? MediaQuery.of(context).size.width.clamp(0.0, 560.0).toDouble()
        : double.infinity;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Material(
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
        ),
      ),
    ),
    );
  }
}
