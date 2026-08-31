import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';
import 'poster_styles_shared.dart';

/// 模板详情分享海报样式（10 款）。
///
/// 每个样式为一个 [PosterStyle]，按 kind=template + 支持的 ratio 注册到
/// [PosterStyleRegistry]。选型稿以 330 宽画布设计，固定高度/固定尺寸元素
/// 通过 [posterScale] 按当前画布宽度等比缩放，保证 5 种比例下排版一致。
List<PosterStyle> templatePosterStyles() => [
      PosterStyle(
        id: 'pA',
        name: '经典面板',
        groupName: '样式一 · 经典面板',
        kind: PosterKind.template,
        ratios: const {
          PosterRatio.fullScreen,
          PosterRatio.ratio34,
          PosterRatio.ratio169,
          PosterRatio.ratio43,
        },
        builder: (d) => PosterClassicCard(data: d),
      ),
      PosterStyle(
        id: 'pC',
        name: '相纸卡片',
        groupName: '样式二 · 相纸卡片',
        kind: PosterKind.template,
        ratios: const {
          PosterRatio.fullScreen,
          PosterRatio.ratio34,
          PosterRatio.square,
          PosterRatio.ratio169,
          PosterRatio.ratio43,
        },
        builder: (d) => PosterPrintCard(data: d),
      ),
      PosterStyle(
        id: 's3',
        name: '全出血浮层',
        groupName: '样式三 · 全出血浮层',
        kind: PosterKind.template,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _S3FullBleed(data: d),
      ),
      PosterStyle(
        id: 'dK',
        name: '居中极简',
        groupName: '样式四 · 居中极简',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _DKCentered(data: d),
      ),
      PosterStyle(
        id: 'v2a',
        name: '取景器角标',
        groupName: '样式五 · 取景器角标',
        kind: PosterKind.template,
        ratios: const {PosterRatio.square},
        builder: (d) => _V2aViewfinder(data: d),
      ),
      PosterStyle(
        id: 'dE',
        name: '国风水墨',
        groupName: '样式六 · 国风水墨',
        kind: PosterKind.template,
        ratios: const {PosterRatio.square},
        builder: (d) => _DEInk(data: d),
      ),
      PosterStyle(
        id: 'dD',
        name: '电影海报',
        groupName: '样式七 · 电影海报',
        kind: PosterKind.template,
        ratios: const {PosterRatio.square},
        builder: (d) => _DDCinema(data: d),
      ),
      PosterStyle(
        id: 'p3',
        name: '画廊陈列',
        groupName: '样式八 · 画廊陈列',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio169},
        builder: (d) => _P3Gallery(data: d),
      ),
      PosterStyle(
        id: 'pE',
        name: '大标题压图',
        groupName: '样式九 · 大标题压图',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio169, PosterRatio.ratio43},
        builder: (d) => _PETitleOverlay(data: d),
      ),
      PosterStyle(
        id: 'stage1',
        name: '典雅简净',
        groupName: '样式十 · 典雅简净',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio43},
        builder: (d) => _Stage1Sketch(data: d),
      ),
    ];

/// 等比缩放系数（选型稿 330 宽 → 当前画布宽）。
double _k(PosterRatio r) => posterScale(r);

/// 全出血浮层（9:16）：照片满幅 + 底部压暗 + 信息浮层。
class _S3FullBleed extends StatelessWidget {
  const _S3FullBleed({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          d.photoBuilder(w, h),
          const PosterScrim(bottom: true, strong: true),
          Positioned(
            top: 22 * k,
            left: 24 * k,
            child: PosterBrandOnPhoto(logoSize: 15 * k),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Padding(
              padding: EdgeInsets.fromLTRB(26 * k, 0, 26 * k, 22 * k),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosterKicker(
                    text: posterKickerOf(d),
                    color: const Color(0xFFE8CFA4),
                    size: 10 * k,
                    letterSpacing: 4 * k,
                  ),
                  SizedBox(height: 8 * k),
                  PosterTitle(
                    text: d.title,
                    color: Colors.white,
                    size: 40 * k,
                    letterSpacing: 2 * k,
                    height: 1.2,
                  ),
                  SizedBox(height: 12 * k),
                  PosterCatText(
                    category: d.category,
                    color: Colors.white.withOpacity(.85),
                    size: 10 * k,
                    letterSpacing: 3 * k,
                    separatorColor: const Color(0xFFE8CFA4),
                  ),
                  SizedBox(height: 22 * k),
                  Container(
                    padding: EdgeInsets.all(14 * k),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.94),
                      borderRadius: BorderRadius.circular(14 * k),
                    ),
                    child: PosterQrTip(
                      data: d.qrData,
                      qrSize: 60 * k,
                      hint: posterQrHintOf(d),
                      sub: posterQrSubOf(d),
                    ),
                  ),
                  SizedBox(height: 18 * k),
                  Container(
                    padding: EdgeInsets.only(top: 14 * k),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(.28)),
                      ),
                    ),
                    child: PosterFootOnPhoto(
                      nameColor: const Color(0xFFE8CFA4),
                      zhColor: Colors.white.withOpacity(.75),
                      sloganColor: Colors.white.withOpacity(.65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 居中极简（3:4）：照片圆角框 + 居中标题 + 居中二维码。
class _DKCentered extends StatelessWidget {
  const _DKCentered({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(28 * k, 30 * k, 28 * k, 22 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PosterBrandRow(),
          SizedBox(height: 34 * k),
          Stack(
            children: [
              Container(
                width: 230 * k,
                height: 276 * k,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18 * k),
                  border: Border.all(color: PosterPalette.line),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18 * k),
                  child: d.photoBuilder(230 * k, 276 * k),
                ),
              ),
              Positioned.fill(
                child: Container(
                  margin: EdgeInsets.all(10 * k),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10 * k),
                    border: Border.all(color: Colors.white.withOpacity(.5)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 32 * k),
          PosterTitle(text: d.title, size: 30 * k, letterSpacing: 4 * k, height: 1.3),
          SizedBox(height: 12 * k),
          PosterKicker(
            text: posterKickerOf(d),
            size: 10 * k,
            letterSpacing: 4 * k,
          ),
          SizedBox(height: 6 * k),
          PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
          SizedBox(height: 28 * k),
          Container(
            padding: EdgeInsets.all(8 * k),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12 * k),
              border: Border.all(color: PosterPalette.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x668C6F40),
                  offset: Offset(0, 10),
                  blurRadius: 22,
                  spreadRadius: -14,
                ),
              ],
            ),
            child: PosterQr(
              data: d.qrData,
              size: 78 * k,
              padding: 0,
              radius: 6 * k,
            ),
          ),
          SizedBox(height: 10 * k),
          Text(
            posterQrHintOf(d),
            style: posterPlain(9 * k, color: PosterPalette.text3, letterSpacing: 2 * k),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 20 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: const Center(child: PosterBrandFoot()),
          ),
        ],
      ),
    );
  }
}

/// 取景器角标（1:1）：照片四周金色 L 角标 + 标题压照片 + 二维码。
class _V2aViewfinder extends StatelessWidget {
  const _V2aViewfinder({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final photoW = w * 0.66;
    final photoH = photoW * 4 / 3;
    return PosterCanvas(
      width: w,
      height: h,
      child: Stack(
        children: [
          // 柔和光束背景
          Positioned(
            top: -70 * k,
            left: -60 * k,
            child: Container(
              width: 300 * k,
              height: 460 * k,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0x24C9A96E), Color(0x00C9A96E)],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 30 * k,
            child: const Center(child: PosterBrandRow()),
          ),
          // 照片 + 四角角标
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: 76 * k),
              child: Stack(
                children: [
                  Container(
                    width: photoW,
                    height: photoH,
                    decoration: BoxDecoration(
                      border: Border.all(color: PosterPalette.line),
                    ),
                    child: d.photoBuilder(photoW, photoH),
                  ),
                  _VfCorner(size: 26 * k, top: -4 * k, left: -4 * k, isTop: true, isLeft: true),
                  _VfCorner(size: 26 * k, top: -4 * k, right: -4 * k, isTop: true, isLeft: false),
                  _VfCorner(size: 26 * k, bottom: -4 * k, left: -4 * k, isTop: false, isLeft: true),
                  _VfCorner(size: 26 * k, bottom: -4 * k, right: -4 * k, isTop: false, isLeft: false, withDot: true),
                ],
              ),
            ),
          ),
          // 标题压照片 + 信息区
          Positioned(
            left: 26 * k,
            right: 26 * k,
            bottom: 34 * k,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                PosterTitle(
                  text: d.title,
                  size: 36 * k,
                  letterSpacing: 2 * k,
                  height: 1.2,
                  align: TextAlign.center,
                ),
                SizedBox(height: 10 * k),
                PosterCatText(
                  category: d.category,
                  size: 10 * k,
                  letterSpacing: 3 * k,
                  align: TextAlign.center,
                ),
                SizedBox(height: 30 * k),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '扫码查看完整模板',
                      style: posterPlain(10 * k, color: PosterPalette.text3, letterSpacing: 1 * k),
                    ),
                    SizedBox(width: 14 * k),
                    PosterQr(
                      data: d.qrData,
                      size: 66 * k,
                      padding: 4 * k,
                      radius: 8 * k,
                    ),
                  ],
                ),
                SizedBox(height: 30 * k),
                const PosterBrandFoot(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 单个金色 L 角标（取景器）。
class _VfCorner extends StatelessWidget {
  const _VfCorner({
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.isTop,
    required this.isLeft,
    this.withDot = false,
  });

  final double size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final bool isTop;
  final bool isLeft;
  final bool withDot;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: isTop ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
                  left: isLeft ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
                  right: !isLeft ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
                  bottom: !isTop ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
                ),
              ),
            ),
            if (withDot)
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 7 * (size / 26),
                  height: 7 * (size / 26),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PosterPalette.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 国风水墨（1:1）：渐变底 + 圆月照片 + 印章 + 竖排大标题。
class _DEInk extends StatelessWidget {
  const _DEInk({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      color: const Color(0xFFF6F0E3),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 山水弧线 + 点缀
          Positioned(
            bottom: -60 * k,
            left: -40 * k,
            child: Container(
              width: 260 * k,
              height: 260 * k,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border(
                  bottom: BorderSide(color: PosterPalette.gold.withOpacity(.3), width: 2),
                ),
              ),
              transform: Matrix4.rotationZ(0.44),
            ),
          ),
          Positioned(top: 120 * k, right: 60 * k, child: _InkDot(5 * k)),
          Positioned(top: 320 * k, left: 44 * k, child: _InkDot(4 * k)),
          Padding(
            padding: EdgeInsets.fromLTRB(26 * k, 26 * k, 26 * k, 20 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PosterBrandRow(),
                SizedBox(height: 26 * k),
                // 圆月照片 + 印章
                SizedBox(
                  width: 214 * k,
                  height: 214 * k,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.all(10 * k),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: PosterPalette.gold.withOpacity(.5)),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.all(18 * k),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: PosterPalette.gold.withOpacity(.35)),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: ClipOval(
                          child: d.photoBuilder(214 * k, 214 * k),
                        ),
                      ),
                      Positioned(
                        right: -6 * k,
                        bottom: 6 * k,
                        child: Container(
                          width: 42 * k,
                          height: 42 * k,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PosterPalette.goldDeep,
                            borderRadius: BorderRadius.circular(4 * k),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x66A87432),
                                offset: Offset(0, 6),
                                blurRadius: 14,
                                spreadRadius: -6,
                              ),
                            ],
                          ),
                          child: Text(
                            '如画',
                            style: posterPlain(13 * k, color: const Color(0xFFFBF4E4), letterSpacing: 2 * k),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 38 * k),
                PosterTitle(
                  text: d.title,
                  size: 34 * k,
                  letterSpacing: 14 * k,
                  height: 1.2,
                  align: TextAlign.center,
                ),
                SizedBox(height: 14 * k),
                PosterKicker(
                  text: posterKickerOf(d),
                  size: 10 * k,
                  letterSpacing: 4 * k,
                ),
                SizedBox(height: 8 * k),
                PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    PosterQr(
                      data: d.qrData,
                      size: 62 * k,
                      padding: 6 * k,
                      radius: 10 * k,
                      background: Colors.white.withOpacity(.75),
                    ),
                    SizedBox(width: 14 * k),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          posterQrHintOf(d),
                          style: posterPlain(11 * k, color: PosterPalette.ink, weight: FontWeight.w600, letterSpacing: 1 * k),
                        ),
                        SizedBox(height: 3 * k),
                        Text(
                          posterQrSubOf(d),
                          style: posterPlain(9 * k, color: PosterPalette.text3, letterSpacing: 1 * k),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 18 * k),
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.only(top: 16 * k),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: PosterPalette.line)),
                  ),
                  child: const PosterBrandFoot(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InkDot extends StatelessWidget {
  const _InkDot(this.size);
  final double size;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: PosterPalette.gold.withOpacity(.4),
      ),
    );
  }
}

/// 电影海报（1:1）：片头带 + 片名 + 电影画框 + 演职员表 + 二维码。
class _DDCinema extends StatelessWidget {
  const _DDCinema({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(26 * k, 28 * k, 26 * k, 20 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PosterBrandRow(),
          SizedBox(height: 34 * k),
          // 片头带
          Row(
            children: [
              const Expanded(child: Divider(color: PosterPalette.line, height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 14 * k),
                child: Text(
                  'LUMIRA 呈现 · 摄影模板',
                  style: posterPlain(10 * k, color: PosterPalette.goldDeep, weight: FontWeight.w600, letterSpacing: 4 * k),
                ),
              ),
              const Expanded(child: Divider(color: PosterPalette.line, height: 1)),
            ],
          ),
          SizedBox(height: 18 * k),
          PosterTitle(text: d.title, size: 32 * k, letterSpacing: 4 * k, height: 1.3),
          SizedBox(height: 10 * k),
          Text(
            'PHOTO MOMENT',
            style: posterSerifEn(10 * k, color: PosterPalette.text2, letterSpacing: 3 * k),
          ),
          SizedBox(height: 26 * k),
          // 电影画框
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12 * k),
              border: Border.all(color: PosterPalette.line),
            ),
            child: Column(
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11 * k),
                      child: d.photoBuilder(w - 54 * k, 250 * k),
                    ),
                    Positioned.fill(
                      child: Container(
                        margin: EdgeInsets.all(8 * k),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8 * k),
                          border: Border.all(color: Colors.white.withOpacity(.28)),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2 * k, vertical: 12 * k),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LUMIRA TEMPLATE',
                        style: posterPlain(9 * k, color: PosterPalette.goldDeep, weight: FontWeight.w600, letterSpacing: 3 * k),
                      ),
                      Text(
                        d.category,
                        style: posterPlain(9 * k, color: PosterPalette.text3, letterSpacing: 2 * k),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 26 * k),
          // 演职员表
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line), bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _credit('导演', d.authorName.isEmpty ? 'LUMIRA' : d.authorName),
                SizedBox(width: 28 * k),
                _credit('摄影', 'LUMIRA'),
                SizedBox(width: 28 * k),
                _credit('模板', d.title),
              ],
            ),
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PosterQr(
                data: d.qrData,
                size: 60 * k,
                padding: 6 * k,
                radius: 10 * k,
              ),
              SizedBox(width: 14 * k),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    posterQrHintOf(d),
                    style: posterPlain(11 * k, color: PosterPalette.ink, weight: FontWeight.w600, letterSpacing: 1 * k),
                  ),
                  SizedBox(height: 3 * k),
                  Text(
                    posterQrSubOf(d),
                    style: posterPlain(9 * k, color: PosterPalette.text3, letterSpacing: 1 * k),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 18 * k),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 16 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: const PosterBrandFoot(),
          ),
        ],
      ),
    );
  }

  Widget _credit(String k, String v) {
    return Column(
      children: [
        Text(k, style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 2)),
        const SizedBox(height: 5),
        Text(v, style: posterSerifEn(11, color: PosterPalette.ink, letterSpacing: 1)),
      ],
    );
  }
}

/// 画廊陈列（16:9）：挂绳 + 相框照片 + 展签 + 二维码。
class _P3Gallery extends StatelessWidget {
  const _P3Gallery({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final photoW = 276 * k;
    final photoH = 155 * k;
    return PosterCanvas(
      width: w,
      height: h,
      color: const Color(0xFFEDE7DC),
      child: Stack(
        children: [
          // 顶部挂绳
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 180 * k,
                height: 1,
                color: const Color(0xFFB9AB93),
              ),
            ),
          ),
          Positioned(
            top: -4 * k,
            left: w / 2 - 90 * k,
            child: _wireEnd(8 * k),
          ),
          Positioned(
            top: -4 * k,
            right: w / 2 - 90 * k,
            child: _wireEnd(8 * k),
          ),
          Positioned(
            top: 12 * k,
            left: w / 2 - 7 * k,
            child: Container(
              width: 14 * k,
              height: 14 * k,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFB9AB93))),
                shape: BoxShape.circle,
              ),
            ),
          ),
          // 品牌
          Positioned(
            top: 18 * k,
            left: 20 * k,
            child: const PosterBrandRow(),
          ),
          // 相框照片
          Positioned(
            top: 66 * k,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.all(15 * k),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD6CCB9)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x663C301C),
                      offset: Offset(0, 22),
                      blurRadius: 48,
                      spreadRadius: -24,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: photoW,
                  height: photoH,
                  child: d.photoBuilder(photoW, photoH),
                ),
              ),
            ),
          ),
          // 展签
          Positioned(
            top: 66 * k + 30 * k + photoH,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 26 * k, vertical: 13 * k),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFD6CCB9)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LUMIRA · NO. 001',
                      style: posterPlain(8 * k, color: PosterPalette.goldDeep, letterSpacing: 3 * k),
                    ),
                    SizedBox(height: 5 * k),
                    Text(
                      d.title,
                      style: posterSerif(21 * k, letterSpacing: 3 * k, height: 1.2),
                    ),
                    SizedBox(height: 6 * k),
                    Text(
                      d.category,
                      style: posterPlain(8 * k, color: PosterPalette.text3, letterSpacing: 2 * k),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 右下二维码
          Positioned(
            right: 20 * k,
            bottom: 18 * k,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '长按识别',
                      style: posterPlain(8 * k, color: PosterPalette.text3, letterSpacing: 1 * k, height: 1.5),
                    ),
                    Text(
                      '查看完整模板',
                      style: posterPlain(8 * k, color: PosterPalette.text3, letterSpacing: 1 * k, height: 1.5),
                    ),
                  ],
                ),
                SizedBox(width: 8 * k),
                Container(
                  padding: EdgeInsets.all(4 * k),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8 * k),
                    border: Border.all(color: const Color(0xFFD6CCB9)),
                  ),
                  child: PosterQr(
                    data: d.qrData,
                    size: 56 * k,
                    padding: 0,
                    radius: 4 * k,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _wireEnd(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFB9AB93),
      ),
    );
  }
}

/// 大标题压图（16:9 / 4:3）：暗底满幅照片 + 底部大标题 + 右上小二维码。
class _PETitleOverlay extends StatelessWidget {
  const _PETitleOverlay({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = w / posterPhotoAspect(d.ratio);
    return PosterCanvas(
      width: w,
      height: h,
      borderRadius: 18,
      child: Stack(
        fit: StackFit.expand,
        children: [
          d.photoBuilder(w, h),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x59201408),
                  Color(0x00201408),
                  Color(0x99201408),
                  Color(0xD1201408),
                ],
                stops: [0, .4, .76, 1],
              ),
            ),
          ),
          Positioned(
            top: 12 * k,
            left: 16 * k,
            child: PosterBrandOnPhoto(logoSize: 14 * k),
          ),
          Positioned(
            top: 12 * k,
            right: 14 * k,
            child: Container(
              padding: EdgeInsets.all(4 * k),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6 * k),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66000000),
                    offset: Offset(0, 6),
                    blurRadius: 16,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: PosterQr(
                data: d.qrData,
                size: 56 * k,
                padding: 0,
                radius: 3 * k,
              ),
            ),
          ),
          Positioned(
            left: 18 * k,
            right: 18 * k,
            bottom: 15 * k,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                PosterKicker(
                  text: posterKickerOf(d),
                  color: const Color(0xFFE8CFA4),
                  size: 8 * k,
                  letterSpacing: 4 * k,
                ),
                SizedBox(height: 3 * k),
                PosterTitle(
                  text: d.title,
                  color: Colors.white,
                  size: 32 * k,
                  letterSpacing: 3 * k,
                  height: 1.05,
                ),
                SizedBox(height: 5 * k),
                PosterCatText(
                  category: d.category,
                  color: Colors.white.withOpacity(.7),
                  size: 8 * k,
                  letterSpacing: 3 * k,
                  separatorColor: const Color(0xFFE8CFA4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 典雅简净 / 早期手绘（4:3）：圆角照片 + 居中小标题 + 二维码。
class _Stage1Sketch extends StatelessWidget {
  const _Stage1Sketch({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final photoW = w * 0.68;
    final photoH = photoW * 0.72;
    return PosterCanvas(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(28 * k, 30 * k, 28 * k, 22 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(4 * k),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14 * k),
              border: Border.all(color: PosterPalette.gold, width: 1.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10 * k),
              child: d.photoBuilder(photoW, photoH),
            ),
          ),
          SizedBox(height: 34 * k),
          PosterKicker(
            text: posterKickerOf(d),
            size: 10 * k,
            letterSpacing: 4 * k,
          ),
          SizedBox(height: 10 * k),
          PosterTitle(text: d.title, size: 34 * k, letterSpacing: 3 * k, height: 1.2),
          SizedBox(height: 10 * k),
          PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
          SizedBox(height: 32 * k),
          Container(
            padding: EdgeInsets.all(9 * k),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12 * k),
              border: Border.all(color: PosterPalette.line),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x44C9A96E),
                  offset: Offset(0, 8),
                  blurRadius: 18,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: PosterQr(
              data: d.qrData,
              size: 84 * k,
              padding: 0,
              radius: 5 * k,
            ),
          ),
          SizedBox(height: 12 * k),
          Text(
            posterQrHintOf(d),
            style: posterPlain(10 * k, color: PosterPalette.text3, letterSpacing: 2 * k),
          ),
          const Spacer(),
          const PosterBrandFoot(),
        ],
      ),
    );
  }
}
