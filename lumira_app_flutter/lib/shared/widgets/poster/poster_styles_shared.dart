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
    final k = posterScale(data.ratio);
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
          Positioned(
            top: 16 * k,
            left: 20 * k,
            child: PosterBrandOnPhoto(logoSize: 15 * k, scale: k),
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
    final k = posterScale(d.ratio);
    return Padding(
      padding: EdgeInsets.fromLTRB(24 * k, 20 * k, 24 * k, 19 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          PosterKicker(text: posterKickerOf(d), size: 9 * k, letterSpacing: 3 * k),
          SizedBox(height: 6 * k),
          PosterTitle(text: d.title, size: 30 * k, letterSpacing: 2 * k),
          SizedBox(height: 8 * k),
          PosterCatText(category: d.category, size: 9 * k, letterSpacing: 3 * k),
          if (d.authorName.isNotEmpty) ...[
            SizedBox(height: 10 * k),
            PosterAuthorRow(name: d.authorName),
          ],
          SizedBox(height: 16 * k),
          Container(
            padding: EdgeInsets.only(top: 15 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: PosterQrTip(
              data: d.qrData,
              qrSize: 54,
              scale: k,
              hint: posterQrHintOf(d),
              sub: posterQrSubOf(d),
              qrBorderColor: PosterPalette.line,
            ),
          ),
          SizedBox(height: 13 * k),
          PosterBrandFoot(scale: k),
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
///
/// 设计稿：print 宽 = 内容宽（画布 − 边框 − 左右 padding 26）× 比例系数
/// （9:16=72%、3:4=88%、1:1=82%、4:3/16:9=100%）；照片高 = 照片自身宽 × 比例
/// （照片宽 = print 宽 − print 左右 padding 12）。
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
    final k = posterScale(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final isPhoto = d.authorName.isNotEmpty;
    // 内容宽 = 画布 − 1px 画布边框 ×2 − 左右 padding 26（设计稿 box-sizing 基准）。
    final contentW = w - 2 - 2 * 26 * k;
    final printW = contentW * _printWidthFactor;
    final innerW = printW - 2 * 12 * k;
    final phH = innerW / posterPhotoAspect(d.ratio);

    return PosterCanvas(
      width: w,
      color: const Color(0xFFF1EADF),
      child: Padding(
        padding: EdgeInsets.fromLTRB(26 * k, 32 * k, 26 * k, 26 * k),
        child: Column(
          children: [
            Transform.rotate(
              angle: _rotate * 3.1415927 / 180,
              child: Container(
                width: printW,
                padding: EdgeInsets.fromLTRB(12 * k, 12 * k, 12 * k, 0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3 * k),
                  boxShadow: [
                    // 设计稿：0 20px 44px -20px rgba(70,55,30,.5)
                    BoxShadow(
                      color: const Color(0x8046371E),
                      offset: Offset(0, 20 * k),
                      blurRadius: 44 * k,
                      spreadRadius: -20 * k,
                    ),
                    // 设计稿：0 2px 6px rgba(70,55,30,.14)
                    BoxShadow(
                      color: const Color(0x2446371E),
                      offset: Offset(0, 2 * k),
                      blurRadius: 6 * k,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        SizedBox(
                          width: innerW,
                          height: phH,
                          child: d.photoBuilder(innerW, phH),
                        ),
                        // 胶带贴纸：设计稿 inset 0 -2px 4px 阴影用下缘渐变模拟。
                        Positioned(
                          top: 10 * k,
                          left: 10 * k,
                          child: Opacity(
                            opacity: .9,
                            child: Container(
                              width: 22 * k,
                              height: 22 * k,
                              decoration: const ShapeDecoration(
                                shape: CircleBorder(),
                                color: Color(0xFFD9BC8B),
                              ),
                              child: const DecoratedBox(
                                decoration: ShapeDecoration(
                                  shape: CircleBorder(),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Colors.transparent, Color(0x1F000000)],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(8 * k, 12 * k, 8 * k, 15 * k),
                      child: Column(
                        children: [
                          PosterKicker(
                            text: isPhoto ? 'LUMIRA · 如画出品' : 'LUMIRA · 模板',
                            size: 8 * k,
                            letterSpacing: 3 * k,
                          ),
                          SizedBox(height: 5 * k),
                          PosterTitle(text: d.title, size: 22 * k, letterSpacing: 3 * k, height: 1.3),
                          if (isPhoto) ...[
                            SizedBox(height: 7 * k),
                            PosterAuthorRow(name: d.authorName, suffix: '用如画拍摄', avatarSize: 20, justifyCenter: true),
                          ] else ...[
                            SizedBox(height: 5 * k),
                            PosterCatText(category: d.category, size: 8 * k, letterSpacing: 2 * k, color: PosterPalette.text3),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 22 * k),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 14 * k, vertical: 10 * k),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16 * k),
                border: Border.all(color: const Color(0x73C9A96E)),
                boxShadow: [
                  // 设计稿：0 12px 26px -18px rgba(70,55,30,.45)
                  BoxShadow(
                    color: const Color(0x7346371E),
                    offset: Offset(0, 12 * k),
                    blurRadius: 26 * k,
                    spreadRadius: -18 * k,
                  ),
                ],
              ),
              child: PosterQrTip(
                data: d.qrData,
                qrSize: 50,
                scale: k,
                gap: 12,
                hint: posterQrHintOf(d),
                sub: posterQrSubOf(d),
              ),
            ),
            SizedBox(height: 14 * k),
            PosterBrandFoot(scale: k),
          ],
        ),
      ),
    );
  }
}
