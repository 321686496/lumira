import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_style_types.dart';
import 'poster_styles_shared.dart';

/// 海报样式切换条（底部紧凑缩略条）。
///
/// 横向「小缩略卡」列表：每项为一张小型海报缩略卡 + 样式名，选中态以品牌金
/// 描边 + 右上 ✓ 角标高亮。尺寸被刻意压缩，把视觉重心留给上方的主效果卡片；
/// 用户可在主卡片上左右滑动切换，也可点此条的缩略卡跳转。
///
/// 通过 [_PosterStylePickerState] **缓存每个样式的缩略图**：切换选中样式时
/// 仅重建选中态，缩略图子树不重建，显著降低切换卡顿。
class PosterStylePicker extends StatefulWidget {
  const PosterStylePicker({
    super.key,
    required this.styles,
    required this.data,
    required this.selectedId,
    required this.onSelect,
  });

  /// 当前 kind + ratio 下可选的样式列表。
  final List<PosterStyle> styles;

  /// 海报展示数据（所有样式共享同一份数据，仅版式不同）。
  final PosterStyleData data;

  /// 当前选中样式 id。
  final String selectedId;

  /// 切换选中样式。
  final ValueChanged<String> onSelect;

  @override
  State<PosterStylePicker> createState() => _PosterStylePickerState();
}

class _PosterStylePickerState extends State<PosterStylePicker> {
  /// 底部紧凑缩略卡尺寸（有意做小，视觉重心留给主效果卡片）。
  static const double _thumbWidth = 58;
  static const double _thumbHeight = 72;
  static const double _stripHeight = _thumbHeight + 20;
  static const double _groupLabelWidth = 18;

  /// 每个样式的缩略图在 initState 时构建一次并缓存，
  /// 后续选中切换不再重建（仅外层选中态装饰变化）。
  late final Map<String, Widget> _thumbs;

  /// 横向滚动项：分组标签（同组首款前插入一次）+ 缩略卡。
  late final List<_PickerItem> _items;

  @override
  void initState() {
    super.initState();
    _thumbs = {for (final s in widget.styles) s.id: s.builder(widget.data)};
    _items = _buildItems();
  }

  List<_PickerItem> _buildItems() {
    final items = <_PickerItem>[];
    String? current;
    for (final s in widget.styles) {
      if (s.group.isEmpty) {
        current = null;
      } else if (s.group != current) {
        items.add(_PickerItem.group(s.group));
        current = s.group;
      }
      items.add(_PickerItem.style(s));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            children: [
              const Text(
                '选择版式',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PosterPalette.ink,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '左右滑动卡片切换',
                style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: _stripHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: _items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = _items[index];
              final style = item.style;
              if (style == null) return _GroupLabel(item.label!);
              return _CompactTab(
                name: style.name,
                selected: style.id == widget.selectedId,
                onTap: () => widget.onSelect(style.id),
                child: _thumbs[style.id]!,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 选择条横向滚动项：分组标签或缩略卡。
class _PickerItem {
  const _PickerItem.group(this.label) : style = null;
  const _PickerItem.style(this.style) : label = null;

  final String? label;
  final PosterStyle? style;
}

/// 分组标签：金色短竖条 + 竖排组名（净版 / 画刊 / 画卷）。
class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _PosterStylePickerState._groupLabelWidth,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(width: 2, height: 8, color: PosterPalette.gold),
          const SizedBox(height: 3),
          PosterVerticalText(
            text: label,
            style: posterPlain(
              9,
              color: PosterPalette.goldDeep,
              weight: FontWeight.w600,
              letterSpacing: 1,
            ),
            charGap: 1,
          ),
        ],
      ),
    );
  }
}

/// 单个紧凑缩略选项卡：小海报缩略卡 + 样式名 + 选中态。
class _CompactTab extends StatelessWidget {
  const _CompactTab({
    required this.name,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final String name;
  final bool selected;
  final VoidCallback onTap;

  /// 已缓存的海报缩略图。
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            width: _PosterStylePickerState._thumbWidth,
            height: _PosterStylePickerState._thumbHeight,
            padding: const EdgeInsets.all(3),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected ? PosterPalette.gold : PosterPalette.line,
                width: selected ? 1.6 : 1,
              ),
              boxShadow: selected
                  ? const [
                      BoxShadow(
                        color: Color(0x38C9A96E),
                        blurRadius: 10,
                        offset: Offset(0, 3),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x12000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Stack(
              children: [
                // 缩略图作用域 + RepaintBoundary：渲染占位二维码且隔离重绘
                Positioned.fill(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: IgnorePointer(
                      child: RepaintBoundary(
                        child: PosterThumbnailScope(child: child),
                      ),
                    ),
                  ),
                ),
                // 选中角标
                if (selected)
                  Positioned(
                    top: 2,
                    right: 2,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: PosterPalette.gold,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 10,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            width: _PosterStylePickerState._thumbWidth + 4,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? PosterPalette.goldDeep : PosterPalette.text2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}