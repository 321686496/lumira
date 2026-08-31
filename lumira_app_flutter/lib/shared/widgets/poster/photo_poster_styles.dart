import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';
import 'poster_styles_shared.dart';

/// 照片详情分享海报样式（9 款）。
///
/// 统一落款 `@小满`，二维码语义为「查看高清原图」。照片样式仅使用单一成品照片，
/// 多图拼贴（dN）以同图不同裁切呈现副图。每个样式按 kind=photo + 支持的 ratio
/// 注册到 [PosterStyleRegistry]。
List<PosterStyle> photoPosterStyles() => [
      PosterStyle(
        id: 'd1',
        name: '满版照片',
        groupName: '样式一 · 满版照片',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _D1FullPhoto(data: d),
      ),
      PosterStyle(
        id: 'dN',
        name: '多图拼贴',
        groupName: '样式二 · 多图拼贴',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _DNCollage(data: d),
      ),
      PosterStyle(
        id: 'dL',
        name: '对角动态',
        groupName: '样式三 · 对角动态',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _DLDiagonal(data: d),
      ),
      PosterStyle(
        id: 'd3',
        name: '相纸拼贴',
        groupName: '样式四 · 相纸拼贴',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _D3Polaroid(data: d),
      ),
      PosterStyle(
        id: 'dA',
        name: '取景器镜头',
        groupName: '样式五 · 取景器镜头',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _DAViewfinder(data: d),
      ),
      PosterStyle(
        id: 's1',
        name: '大图出血',
        groupName: '样式六 · 大图出血',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => PosterClassicCard(data: d),
      ),
      PosterStyle(
        id: 'pC',
        name: '相纸卡片',
        groupName: '样式七 · 相纸卡片',
        kind: PosterKind.photo,
        ratios: const {
          PosterRatio.square,
          PosterRatio.ratio169,
          PosterRatio.ratio43,
        },
        builder: (d) => PosterPrintCard(data: d),
      ),
      PosterStyle(
        id: 'dC',
        name: '几何构成',
        groupName: '样式八 · 几何构成',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.square},
        builder: (d) => _DCGeometric(data: d),
      ),
      PosterStyle(
        id: 'dM',
        name: '底图倒置',
        groupName: '样式九 · 底图倒置',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.square},
        builder: (d) => _DMBottom(data: d),
      ),
    ];

/// 等比缩放系数（选型稿 330 宽 → 当前画布宽）。
double _k(PosterRatio r) => posterScale(r);

/// 满版照片（9:16）：照片满幅 + 底部压暗 + 居中信息浮层。
class _D1FullPhoto extends StatelessWidget {
  const _D1FullPhoto({required this.data});
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
      borderRadius: 0,
      borderColor: Colors.transparent,
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                    align: TextAlign.center,
                  ),
                  SizedBox(height: 12 * k),
                  PosterCatText(
                    category: d.category,
                    color: Colors.white.withOpacity(.85),
                    size: 10 * k,
                    letterSpacing: 3 * k,
                    align: TextAlign.center,
                    separatorColor: const Color(0xFFE8CFA4),
                  ),
                  SizedBox(height: 14 * k),
                  PosterAuthorRow(name: d.authorName, light: true),
                  SizedBox(height: 22 * k),
                  Container(
                    padding: EdgeInsets.all(14 * k),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.94),
                      borderRadius: BorderRadius.circular(14 * k),
                    ),
                    child: PosterQrTip(
                      data: d.qrData,
                      qrSize: 56 * k,
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
                    child: const PosterFootOnPhoto(),
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

/// 多图拼贴（9:16）：主图大 + 副图小（同图不同裁切）+ 底部信息。
class _DNCollage extends StatelessWidget {
  const _DNCollage({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final mainW = w * 0.56;
    final mainH = mainW * 1.2;
    final subW = mainW * 0.6;
    final subH = subW * 0.9;
    return PosterCanvas(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(24 * k, 26 * k, 24 * k, 20 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PosterBrandRow(),
          SizedBox(height: 24 * k),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: mainW,
                height: mainH,
                decoration: BoxDecoration(
                  border: Border.all(color: PosterPalette.line),
                ),
                child: d.photoBuilder(mainW, mainH),
              ),
              SizedBox(width: 12 * k),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: subW,
                      height: subH,
                      decoration: BoxDecoration(
                        border: Border.all(color: PosterPalette.line),
                      ),
                      child: d.photoBuilder(subW, subH),
                    ),
                    SizedBox(height: 6 * k),
                    Text(
                      '@${d.authorName} · 如画',
                      style: posterPlain(8 * k, color: PosterPalette.text3, letterSpacing: 1 * k),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 26 * k),
          PosterTitle(text: d.title, size: 32 * k, letterSpacing: 3 * k, height: 1.25),
          SizedBox(height: 10 * k),
          PosterRule(width: 42 * k),
          SizedBox(height: 10 * k),
          PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
          SizedBox(height: 12 * k),
          PosterAuthorRow(name: d.authorName, suffix: '用「如画」拍摄'),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(12 * k),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14 * k),
              border: Border.all(color: PosterPalette.line),
            ),
            child: PosterQrTip(
              data: d.qrData,
              qrSize: 56 * k,
              hint: posterQrHintOf(d),
              sub: posterQrSubOf(d),
            ),
          ),
          SizedBox(height: 14 * k),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 12 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: const PosterBrandFoot(),
          ),
        ],
      ),
    );
  }
}

/// 对角动态（9:16）：照片满幅 + 光束压暗 + 左下信息浮层。
class _DLDiagonal extends StatelessWidget {
  const _DLDiagonal({required this.data});
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
      borderRadius: 0,
      borderColor: Colors.transparent,
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
                  Color(0x00100C07),
                  Color(0x66100C07),
                  Color(0xD9100C07),
                ],
                stops: [0.0, 0.5, 1.0],
              ),
            ),
          ),
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
              padding: EdgeInsets.fromLTRB(26 * k, 0, 26 * k, 20 * k),
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
                    size: 38 * k,
                    letterSpacing: 2 * k,
                    height: 1.2,
                  ),
                  SizedBox(height: 12 * k),
                  PosterRule(width: 46 * k, thickness: 2 * k, color: const Color(0xFFE8CFA4)),
                  SizedBox(height: 12 * k),
                  PosterCatText(
                    category: d.category,
                    color: Colors.white.withOpacity(.85),
                    size: 10 * k,
                    letterSpacing: 3 * k,
                    separatorColor: const Color(0xFFE8CFA4),
                  ),
                  SizedBox(height: 12 * k),
                  PosterAuthorRow(name: d.authorName, light: true),
                  SizedBox(height: 20 * k),
                  Container(
                    padding: EdgeInsets.all(13 * k),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.94),
                      borderRadius: BorderRadius.circular(13 * k),
                    ),
                    child: PosterQrTip(
                      data: d.qrData,
                      qrSize: 54 * k,
                      hint: posterQrHintOf(d),
                      sub: posterQrSubOf(d),
                    ),
                  ),
                  SizedBox(height: 16 * k),
                  Container(
                    padding: EdgeInsets.only(top: 13 * k),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Colors.white.withOpacity(.28)),
                      ),
                    ),
                    child: const PosterFootOnPhoto(),
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

/// 相纸拼贴（3:4）：宝丽来相纸 + 分享文案 + 作者 + 二维码。
class _D3Polaroid extends StatelessWidget {
  const _D3Polaroid({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final phW = w * 0.58;
    final phH = phW * 4 / 3;
    final segs = d.category
        .split('·')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    final metaK = segs.isEmpty ? '人像写真' : segs.first;
    final metaV = segs.length > 1 ? '${segs.last} · VOL.01' : '摄影模板 · VOL.01';
    return PosterCanvas(
      width: w,
      height: h,
      padding: EdgeInsets.fromLTRB(26 * k, 26 * k, 26 * k, 20 * k),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const PosterBrandRow(),
          SizedBox(height: 24 * k),
          // 宝丽来相纸
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: phW + 22 * k,
                padding: EdgeInsets.fromLTRB(11 * k, 11 * k, 11 * k, 13 * k),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x8046371E),
                      offset: Offset(0, 20),
                      blurRadius: 44,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: phW,
                      height: phH,
                      child: d.photoBuilder(phW, phH),
                    ),
                    SizedBox(height: 10 * k),
                    Text(
                      d.title,
                      style: posterSerif(13 * k, letterSpacing: 2 * k),
                    ),
                  ],
                ),
              ),
              // 顶部胶带
              Positioned(
                top: -9 * k,
                left: phW / 2 - 2 * k,
                child: Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    width: 48 * k,
                    height: 18 * k,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8CFA4).withOpacity(.85),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
              // 图钉
              Positioned(
                top: -4 * k,
                right: 8 * k,
                child: Container(
                  width: 12 * k,
                  height: 12 * k,
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
          SizedBox(height: 24 * k),
          // meta：题材 + 卷号
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                metaK,
                style: posterPlain(10 * k, color: PosterPalette.goldDeep, weight: FontWeight.w600, letterSpacing: 3 * k),
              ),
              SizedBox(width: 8 * k),
              Text(
                '|',
                style: posterPlain(10 * k, color: PosterPalette.line),
              ),
              SizedBox(width: 8 * k),
              Text(
                metaV,
                style: posterPlain(10 * k, color: PosterPalette.text3, letterSpacing: 2 * k),
              ),
            ],
          ),
          SizedBox(height: 12 * k),
          Text(
            d.shareText,
            textAlign: TextAlign.center,
            style: posterPlain(10 * k, color: PosterPalette.text2, height: 1.7),
          ),
          SizedBox(height: 12 * k),
          PosterAuthorRow(name: d.authorName),
          SizedBox(height: 16 * k),
          // 分隔线
          Row(
            children: [
              const Expanded(child: Divider(color: PosterPalette.line, height: 1)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 10 * k),
                child: Container(
                  width: 4 * k,
                  height: 4 * k,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PosterPalette.gold,
                  ),
                ),
              ),
              const Expanded(child: Divider(color: PosterPalette.line, height: 1)),
            ],
          ),
          SizedBox(height: 14 * k),
          Container(
            padding: EdgeInsets.all(8 * k),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10 * k),
              border: Border.all(color: PosterPalette.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PosterQr(data: d.qrData, size: 56 * k, padding: 4 * k, radius: 6 * k),
                SizedBox(width: 12 * k),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '长按识别二维码',
                      style: posterPlain(10 * k, color: PosterPalette.ink, weight: FontWeight.w600, letterSpacing: 1 * k),
                    ),
                    SizedBox(height: 3 * k),
                    Text(
                      '查看高清原图',
                      style: posterPlain(9 * k, color: PosterPalette.text3, letterSpacing: 1 * k),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: 14 * k),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: const PosterBrandFoot(),
          ),
        ],
      ),
    );
  }
}

/// 取景器镜头（3:4）：取景器圆环 + 镜头相框 + 拍摄参数印章 + 信息区。
class _DAViewfinder extends StatelessWidget {
  const _DAViewfinder({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final phW = w * 0.62;
    final phH = phW * 4 / 3;
    return PosterCanvas(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景装饰：取景器圆环 + 光束 + 圆点
          Positioned(
            top: 20 * k,
            right: -26 * k,
            child: _VfRing(size: 170 * k),
          ),
          Positioned(
            top: 60 * k,
            right: 70 * k,
            child: _InkDot(6 * k),
          ),
          Positioned(
            bottom: 140 * k,
            left: -20 * k,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 220 * k,
                height: 40 * k,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0x0DC9A96E), Color(0x00C9A96E)],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(26 * k, 26 * k, 26 * k, 18 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PosterBrandRow(),
                SizedBox(height: 30 * k),
                // 镜头相框
                SizedBox(
                  width: phW,
                  height: phH,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: PosterPalette.gold, width: 1.5),
                          ),
                          child: d.photoBuilder(phW, phH),
                        ),
                      ),
                      // 四角角标
                      Positioned(top: 0, left: 0, child: _VfCorner(isTop: true, isLeft: true, size: 22 * k)),
                      Positioned(bottom: 0, right: 0, child: _VfCorner(isTop: false, isLeft: false, size: 22 * k)),
                      // 中央对焦点
                      Center(
                        child: Container(
                          width: 7 * k,
                          height: 7 * k,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 4)],
                          ),
                        ),
                      ),
                      // 参数印章
                      Positioned(
                        bottom: 8 * k,
                        right: 8 * k,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 6 * k, vertical: 3 * k),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.45),
                            borderRadius: BorderRadius.circular(2 * k),
                          ),
                          child: Text(
                            'LUMIRA · f/1.8 50mm',
                            style: posterPlain(7 * k, color: Colors.white, letterSpacing: 1 * k),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 26 * k),
                PosterKicker(text: posterKickerOf(d), size: 10 * k, letterSpacing: 4 * k),
                SizedBox(height: 8 * k),
                PosterTitle(text: d.title, size: 30 * k, letterSpacing: 3 * k, height: 1.3),
                SizedBox(height: 10 * k),
                PosterRule(width: 40 * k),
                SizedBox(height: 10 * k),
                PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
                SizedBox(height: 10 * k),
                PosterAuthorRow(name: d.authorName),
                const Spacer(),
                Container(
                  padding: EdgeInsets.all(11 * k),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13 * k),
                    border: Border.all(color: PosterPalette.line),
                  ),
                  child: PosterQrTip(
                    data: d.qrData,
                    qrSize: 50 * k,
                    hint: posterQrHintOf(d),
                    sub: posterQrSubOf(d),
                  ),
                ),
                SizedBox(height: 12 * k),
                const PosterBrandFoot(borderTop: true, paddingTop: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 取景器圆环装饰（带 4 向刻度）。
class _VfRing extends StatelessWidget {
  const _VfRing({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = size / 170;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: PosterPalette.line, width: 1.5),
            ),
          ),
          Positioned(top: 8 * t, left: size / 2 - t, child: Container(width: 2 * t, height: 10 * t, color: PosterPalette.line)),
          Positioned(bottom: 8 * t, left: size / 2 - t, child: Container(width: 2 * t, height: 10 * t, color: PosterPalette.line)),
          Positioned(left: 8 * t, top: size / 2 - t, child: Container(width: 10 * t, height: 2 * t, color: PosterPalette.line)),
          Positioned(right: 8 * t, top: size / 2 - t, child: Container(width: 10 * t, height: 2 * t, color: PosterPalette.line)),
        ],
      ),
    );
  }
}

/// 单个金色 L 角标（镜头相框）。
class _VfCorner extends StatelessWidget {
  const _VfCorner({required this.size, required this.isTop, required this.isLeft});
  final double size;
  final bool isTop;
  final bool isLeft;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        border: Border(
          top: isTop ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
          left: isLeft ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
          right: !isLeft ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
          bottom: !isTop ? const BorderSide(color: PosterPalette.gold, width: 2) : BorderSide.none,
        ),
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

/// 几何构成（1:1）：圆形照片 + 几何背景 + 信息区。
class _DCGeometric extends StatelessWidget {
  const _DCGeometric({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final dia = w * 0.58;
    return PosterCanvas(
      width: w,
      height: h,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 几何背景：圆环 + 半圆 + 点缀
          Positioned(
            top: -30 * k,
            right: -40 * k,
            child: Container(
              width: 170 * k,
              height: 170 * k,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PosterPalette.line, width: 1.5),
              ),
            ),
          ),
          Positioned(
            bottom: -50 * k,
            left: -34 * k,
            child: Container(
              width: 160 * k,
              height: 160 * k,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: PosterPalette.gold.withOpacity(.07),
              ),
            ),
          ),
          Positioned(top: 100 * k, right: 30 * k, child: _InkDot(5 * k)),
          Positioned(bottom: 130 * k, left: 34 * k, child: _InkDot(4 * k)),
          Padding(
            padding: EdgeInsets.fromLTRB(26 * k, 26 * k, 26 * k, 18 * k),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const PosterBrandRow(),
                SizedBox(height: 28 * k),
                // 圆形照片 + 金环 + 作者章 + 对焦点
                SizedBox(
                  width: dia,
                  height: dia,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Container(
                          margin: EdgeInsets.all(8 * k),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: PosterPalette.gold, width: 1.5),
                          ),
                        ),
                      ),
                      Positioned.fill(child: ClipOval(child: d.photoBuilder(dia, dia))),
                      Positioned(
                        right: 2 * k,
                        bottom: 12 * k,
                        child: PosterAvatar(
                          char: d.authorName.isEmpty ? '满' : d.authorName.characters.first,
                          size: 26 * k,
                        ),
                      ),
                      const Center(
                        child: SizedBox(
                          width: 7,
                          height: 7,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 28 * k),
                PosterKicker(text: posterKickerOf(d), size: 10 * k, letterSpacing: 4 * k),
                SizedBox(height: 8 * k),
                PosterTitle(text: d.title, size: 30 * k, letterSpacing: 3 * k, height: 1.3),
                SizedBox(height: 10 * k),
                PosterRule(width: 40 * k),
                SizedBox(height: 10 * k),
                PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
                SizedBox(height: 12 * k),
                PosterAuthorRow(name: d.authorName),
                const Spacer(),
                Container(
                  padding: EdgeInsets.all(11 * k),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13 * k),
                    border: Border.all(color: PosterPalette.line),
                  ),
                  child: PosterQrTip(
                    data: d.qrData,
                    qrSize: 50 * k,
                    hint: posterQrHintOf(d),
                    sub: posterQrSubOf(d),
                  ),
                ),
                SizedBox(height: 12 * k),
                const PosterBrandFoot(borderTop: true, paddingTop: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 底图倒置（1:1）：上半信息 + 下半照片（底部二维码条 + 落款）。
class _DMBottom extends StatelessWidget {
  const _DMBottom({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    final k = _k(d.ratio);
    final w = posterCanvasWidth(d.ratio);
    final h = posterFixedHeight(d.ratio);
    final phH = h * 0.4;
    return PosterCanvas(
      width: w,
      height: h,
      borderRadius: 0,
      borderColor: Colors.transparent,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(28 * k, 26 * k, 28 * k, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PosterBrandRow(),
                  SizedBox(height: 26 * k),
                  PosterKicker(text: posterKickerOf(d), size: 10 * k, letterSpacing: 4 * k),
                  SizedBox(height: 8 * k),
                  PosterTitle(text: d.title, size: 32 * k, letterSpacing: 3 * k, height: 1.25),
                  SizedBox(height: 6 * k),
                  Text(
                    'LAZY FRENCH MOMENT',
                    style: posterSerifEn(10 * k, color: PosterPalette.text2, letterSpacing: 3 * k),
                  ),
                  SizedBox(height: 12 * k),
                  PosterRule(width: 44 * k),
                  SizedBox(height: 12 * k),
                  PosterCatText(category: d.category, size: 10 * k, letterSpacing: 3 * k),
                  SizedBox(height: 16 * k),
                  Text(
                    d.shareText,
                    style: posterPlain(10 * k, color: PosterPalette.text2, height: 1.7),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: phH,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                d.photoBuilder(w, phH),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(16 * k, 12 * k, 16 * k, 12 * k),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00100C07), Color(0xCC100C07)],
                      ),
                    ),
                    child: Row(
                      children: [
                        PosterQr(
                          data: d.qrData,
                          size: 56 * k,
                          padding: 4 * k,
                          radius: 6 * k,
                          background: Colors.white,
                        ),
                        SizedBox(width: 12 * k),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                posterQrHintOf(d),
                                style: posterPlain(10 * k, color: Colors.white, weight: FontWeight.w600, letterSpacing: 1 * k),
                              ),
                              SizedBox(height: 2 * k),
                              Text(
                                posterQrSubOf(d),
                                style: posterPlain(8 * k, color: Colors.white70, letterSpacing: 1 * k),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '@${d.authorName} · 如画',
                          style: posterPlain(9 * k, color: Colors.white70, letterSpacing: 1 * k),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
