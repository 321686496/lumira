import 'package:flutter/material.dart';

import '../../../shared/widgets/poster/poster_common.dart';
import '../../../shared/widgets/poster/poster_ratio.dart';
import '../../../shared/widgets/poster/poster_style_types.dart';

/// 精选集分享海报画布逻辑宽度（预览区 FittedBox 等比缩放）。
const double _kClW = 300;

/// 精选集分享海报样式：光影纸册（clPaper）。
///
/// 对应 v5 规格：暖白纸面 + 金色发丝内描边与四角金标 + 品牌行
/// 「LUMIRA — 如画 · 精选集」+ 衬线大标题 + 发丝分隔线 + 方形照片宫格
/// （照片固定 1:1 方图、cover 居中不拉伸、5-9 张三列）+ 页脚「共收录 N 张」
/// + 底部品牌签名。无二维码、无动画。配色为固定 PosterPalette 品牌色板。
List<PosterStyle> collectionPosterStyles() => [
      PosterStyle(
        id: 'clPaper',
        name: '光影纸册',
        groupName: '光影纸册',
        kind: PosterKind.collection,
        ratios: {PosterRatio.ratio34, PosterRatio.square},
        builder: _buildClPaper,
      ),
    ];

Widget _buildClPaper(PosterStyleData d) {
  final sq = d.ratio == PosterRatio.square;
  final double height = sq ? 300 : 400;
  final pad = sq
      ? const EdgeInsets.fromLTRB(16, 16, 16, 13)
      : const EdgeInsets.fromLTRB(20, 20, 20, 16);
  final thumbs = d.thumbBuilders ?? const <Widget Function(double, double)>[];
  final total = d.photoCount > 0 ? d.photoCount : thumbs.length;

  return PosterCanvas(
    width: _kClW,
    height: height,
    borderRadius: 6,
    color: PosterPalette.surface,
    borderColor: PosterPalette.line,
    child: Stack(
      children: [
        Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 品牌行：LUMIRA —渐隐金线— 如画 · 精选集
              Row(
                children: [
                  Text(
                    'LUMIRA',
                    style: posterSerifEn(11, color: PosterPalette.goldDeep, letterSpacing: 4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 1,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [PosterPalette.line, Color(0x0FC9A96E)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '如画 · 精选集',
                    style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 3),
                  ),
                ],
              ),
              SizedBox(height: sq ? 12 : 16),
              // 衬线大标题（空名回退「我的精选集」）
              Text(
                d.title.isEmpty ? '我的精选集' : d.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: posterSerif(
                  sq ? 19 : 21,
                  color: PosterPalette.ink,
                  letterSpacing: 2.5,
                  height: 1.35,
                ),
              ),
              // 描述（最多两行）
              if (d.note.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  d.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: posterPlain(10.5, color: PosterPalette.text2, letterSpacing: .5, height: 1.7),
                ),
              ],
              SizedBox(height: sq ? 9 : 13),
              // 发丝分隔线
              Container(
                height: 1,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PosterPalette.goldDeep,
                      PosterPalette.line,
                      Color(0x14C9A96E),
                    ],
                    stops: [0, .4, 1],
                  ),
                ),
              ),
              SizedBox(height: sq ? 8 : 12),
              // 照片宫格：方形照片，宫格整体居中，绝不溢出
              Expanded(
                child: thumbs.isEmpty
                    ? Center(
                        child: Text('暂无照片', style: posterPlain(11, color: PosterPalette.text3)),
                      )
                    : _ClPaperGrid(count: thumbs.length, thumbs: thumbs),
              ),
              SizedBox(height: sq ? 9 : 12),
              // 页脚：金线上「共收录 N 张」+ 日期
              Container(
                padding: EdgeInsets.only(top: sq ? 8 : 10),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: PosterPalette.line)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '共收录 ',
                            style: posterPlain(10, color: PosterPalette.text2, letterSpacing: 2),
                          ),
                          TextSpan(
                            text: '$total',
                            style: posterSerifEn(15, color: PosterPalette.goldDeep),
                          ),
                          TextSpan(
                            text: ' 张',
                            style: posterPlain(10, color: PosterPalette.text2, letterSpacing: 2),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      d.dateText,
                      style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 1.5),
                    ),
                  ],
                ),
              ),
              SizedBox(height: sq ? 9 : 11),
              // 底部品牌签名
              Center(
                child: Text(
                  '如画 LUMIRA',
                  style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 4),
                ),
              ),
            ],
          ),
        ),
        // 金色发丝内描边（距边 9px）+ 四角金标，叠于内容之上属「纸册装帧」叠加
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: PosterPalette.line, width: 1),
                      ),
                    ),
                  ),
                  const Positioned(top: -1, left: -1, child: _ClCorner(top: true, left: true)),
                  const Positioned(top: -1, right: -1, child: _ClCorner(top: true, left: false)),
                  const Positioned(bottom: -1, left: -1, child: _ClCorner(top: false, left: true)),
                  const Positioned(bottom: -1, right: -1, child: _ClCorner(top: false, left: false)),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 金色 L 角标（14×14，亮两条边），作为纸册装帧的四角。
class _ClCorner extends StatelessWidget {
  const _ClCorner({required this.top, required this.left});
  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            top: top ? const BorderSide(color: PosterPalette.goldDeep, width: 1.5) : BorderSide.none,
            left: left ? const BorderSide(color: PosterPalette.goldDeep, width: 1.5) : BorderSide.none,
            right: left ? BorderSide.none : const BorderSide(color: PosterPalette.goldDeep, width: 1.5),
            bottom: top ? BorderSide.none : const BorderSide(color: PosterPalette.goldDeep, width: 1.5),
          ),
        ),
      ),
    );
  }
}

/// 方形照片宫格：边长取「受宽/受高限制」的较小者，保证方形且不溢出，整体居中。
class _ClPaperGrid extends StatelessWidget {
  const _ClPaperGrid({required this.count, required this.thumbs});
  final int count;
  final List<Widget Function(double w, double h)> thumbs;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(1, 9);
    final int cols, rows;
    if (n == 1) {
      cols = 1;
      rows = 1;
    } else if (n == 2) {
      cols = 2;
      rows = 1;
    } else if (n <= 4) {
      cols = 2;
      rows = 2;
    } else if (n <= 6) {
      cols = 3;
      rows = 2;
    } else {
      cols = 3;
      rows = 3;
    }
    const gap = 4.0;

    return LayoutBuilder(
      builder: (context, con) {
        final availW = con.maxWidth;
        final availH = con.maxHeight;
        final colW = (availW - (cols - 1) * gap) / cols;
        final rowH = (availH - (rows - 1) * gap) / rows;
        final cell = (colW < rowH ? colW : rowH).clamp(8.0, double.infinity);

        final rowWidgets = <Widget>[];
        var idx = 0;
        for (var r = 0; r < rows && idx < n; r++) {
          final rowChildren = <Widget>[];
          for (var c = 0; c < cols && idx < n; c++, idx++) {
            if (c > 0) rowChildren.add(const SizedBox(width: gap));
            rowChildren.add(
              SizedBox(
                width: cell,
                height: cell,
                child: thumbs[idx](cell, cell),
              ),
            );
          }
          rowWidgets.add(Row(mainAxisAlignment: MainAxisAlignment.center, children: rowChildren));
          if (r < rows - 1) rowWidgets.add(const SizedBox(height: gap));
        }

        return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
        );
      },
    );
  }
}