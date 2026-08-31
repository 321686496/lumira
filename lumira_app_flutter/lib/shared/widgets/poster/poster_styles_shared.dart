import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';

/// 跨模板/照片海报样式复用的共享部件与文案派生。
///
/// 承载「经典面板（pA/s1 下半部分）」「相纸卡片（pC）」两大复用布局，
/// 及按 kind 派生的 kicker / 二维码提示文案。

/// 顶部 kicker：模板=「LUMIRA TEMPLATE · 模板」，照片=「LUMIRA · 如画出品」。
String posterKickerOf(PosterStyleData d) =>
    d.authorName.isEmpty ? 'LUMIRA TEMPLATE · 模板' : 'LUMIRA · 如画出品';

/// 二维码主提示：模板=「长按识别 · 查看完整模板」，照片=「长按识别 · 查看高清原图」。
String posterQrHintOf(PosterStyleData d) =>
    d.authorName.isEmpty ? '长按识别 · 查看完整模板' : '长按识别 · 查看高清原图';

/// 二维码副提示：模板=「打开如画，拍出同款」，照片=「打开如画 · 保存原图」。
String posterQrSubOf(PosterStyleData d) =>
    d.authorName.isEmpty ? '打开如画，拍出同款' : '打开如画 · 保存原图';

/// 照片顶部压暗渐变（保证浮层文字可读）。
class PosterScrim extends StatelessWidget {
  const PosterScrim({super.key, this.bottom = false, this.strong = false});
  final bool bottom;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    if (bottom) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: strong
                ? const [
                    Color(0x00100C07),
                    Color(0x80100C07),
                    Color(0xAD100C07),
                  ]
                : const [
                    Color(0x00141008),
                    Color(0x9E141008),
                    Color(0xBD141008),
                  ],
            stops: const [0.0, 0.74, 1.0],
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: strong
              ? const [Color(0x59201408), Color(0x00201408)]
              : const [Color(0x38201408), Color(0x00201408)],
          stops: const [0.0, 0.3],
        ),
      ),
    );
  }
}

/// 经典面板「照片区」：照片 + 顶部压暗 + 左上品牌浮层。
class PosterClassicPhoto extends StatelessWidget {
  const PosterClassicPhoto({super.key, required this.data, this.height});
  final PosterStyleData data;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = posterCanvasWidth(data.ratio);
    final h = height ?? w / posterPhotoAspect(data.ratio);
    return SizedBox(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          data.photoBuilder(w, h),
          const PosterScrim(),
          const Positioned(
            top: 16,
            left: 20,
            child: PosterBrandOnPhoto(logoSize: 15),
          ),
        ],
      ),
    );
  }
}

/// 经典面板「信息区」（kicker / 标题 / 分类 / 落款 / 二维码 / 品牌脚）。
class PosterClassicPanel extends StatelessWidget {
  const PosterClassicPanel({super.key, required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PosterKicker(text: posterKickerOf(d)),
          const SizedBox(height: 6),
          PosterTitle(text: d.title, size: 30),
          const SizedBox(height: 8),
          PosterCatText(category: d.category),
          if (d.authorName.isNotEmpty) ...[
            const SizedBox(height: 10),
            PosterAuthorRow(name: d.authorName),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.only(top: 15),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: PosterQrTip(
              data: d.qrData,
              hint: posterQrHintOf(d),
              sub: posterQrSubOf(d),
            ),
          ),
          const SizedBox(height: 13),
          const PosterBrandFoot(),
        ],
      ),
    );
  }
}

/// 经典面板整卡（pA）：照片区 + 信息区。
class PosterClassicCard extends StatelessWidget {
  const PosterClassicCard({super.key, required this.data, this.photoHeight});
  final PosterStyleData data;
  final double? photoHeight;

  @override
  Widget build(BuildContext context) {
    return PosterCanvas(
      width: posterCanvasWidth(data.ratio),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PosterClassicPhoto(data: data, height: photoHeight),
          PosterClassicPanel(data: data),
        ],
      ),
    );
  }
}

/// 相纸卡片（pC）：胶带贴纸 + 白底相片卡 + 手写标题 + 二维码条。
class PosterPrintCard extends StatelessWidget {
  const PosterPrintCard({super.key, required this.data});
  final PosterStyleData data;

  double get _rotate {
    switch (data.ratio) {
      case PosterRatio.fullScreen:
        return 1.5;
      case PosterRatio.ratio34:
        return -1.2;
      case PosterRatio.square:
        return -1;
      case PosterRatio.ratio43:
        return -1.3;
      case PosterRatio.ratio169:
        return -1.7;
    }
  }

  double get _printWidthFactor {
    switch (data.ratio) {
      case PosterRatio.fullScreen:
        return 0.72;
      case PosterRatio.ratio34:
        return 0.88;
      case PosterRatio.square:
        return 0.82;
      case PosterRatio.ratio43:
      case PosterRatio.ratio169:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final w = posterCanvasWidth(d.ratio);
    final isPhoto = d.authorName.isNotEmpty;
    final printW = w * _printWidthFactor;
    final phH = printW / posterPhotoAspect(d.ratio);

    return PosterCanvas(
      width: w,
      color: const Color(0xFFF1EADF),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
        child: Column(
          children: [
            Transform.rotate(
              angle: _rotate * 3.1415927 / 180,
              child: Container(
                width: printW,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8046371E),
                      offset: Offset(0, 20),
                      blurRadius: 44,
                    ),
                    BoxShadow(
                      color: Color(0x2446371E),
                      offset: Offset(0, 2),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: printW,
                          height: phH,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: d.photoBuilder(printW, phH),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFD9BC8B),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  offset: Offset(0, -2),
                                  blurRadius: 4,
                                  spreadRadius: -2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 12, 8, 15),
                      child: Column(
                        children: [
                          PosterKicker(
                            text: isPhoto ? 'LUMIRA · 如画出品' : 'LUMIRA · 模板',
                            size: 8,
                            letterSpacing: 3,
                          ),
                          const SizedBox(height: 5),
                          PosterTitle(text: d.title, size: 22, letterSpacing: 3, height: 1.3),
                          if (isPhoto) ...[
                            const SizedBox(height: 7),
                            PosterAuthorRow(name: d.authorName, suffix: '用如画拍摄', avatarSize: 20, justifyCenter: true),
                          ] else ...[
                            const SizedBox(height: 5),
                            PosterCatText(category: d.category, size: 8, letterSpacing: 2, color: PosterPalette.text3),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x73C9A96E)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x7346371E),
                    offset: Offset(0, 12),
                    blurRadius: 26,
                  ),
                ],
              ),
              child: PosterQrTip(
                data: d.qrData,
                qrSize: 50,
                hint: posterQrHintOf(d),
                sub: posterQrSubOf(d),
              ),
            ),
            const SizedBox(height: 14),
            const PosterBrandFoot(),
          ],
        ),
      ),
    );
  }
}
