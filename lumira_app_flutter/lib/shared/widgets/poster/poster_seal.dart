import 'package:flutter/material.dart';

import 'poster_common.dart';

/// 画卷小印：22 × 22 金框圆角方章，竖排两字（默认「如 / 画」）。
///
/// 用于画卷方向（⑦ 立轴款行 / ⑧ 诗塘题字 / ⑨ 对题栏尾）的款行小印：
/// 色板取 [PosterPalette.goldDeep]，衬线字形，固定品牌资产不随主题切换。
class PosterSeal extends StatelessWidget {
  const PosterSeal({
    super.key,
    this.chars = '如画',
    this.size = 22,
    this.fontSize = 8,
  });

  /// 印文（取前两个字竖排）。
  final String chars;

  /// 印章边长。
  final double size;

  /// 单字字号。
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final glyphs = chars.characters.take(2).toList();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: PosterPalette.goldDeep),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < glyphs.length; i++) ...[
            if (i > 0) const SizedBox(height: 1),
            Text(
              glyphs[i],
              style: posterSerif(
                fontSize,
                color: PosterPalette.goldDeep,
                weight: FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
