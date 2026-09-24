import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_ratio.dart';
import 'poster_seal.dart';
import 'poster_style_types.dart';
import 'poster_styles_shared.dart';

/// 照片详情分享海报样式。
///
/// 9:16 为重设计三方向九款（净版 n1-n3 / 画刊 m1-m3 / 画卷 j1-j3，
/// 设计文档见 docs/superpowers/specs/2026-09-24-photo-poster-9-16-redesign-design.md）：
/// 画布与照片同为 9:16（300 × 533.33），文字全部落在暖白实底或白卡上。
/// 统一落款 `@小满`，二维码语义为「查看高清原图」。每个样式按 kind=photo +
/// 支持的 ratio 注册到 [PosterStyleRegistry]。
List<PosterStyle> photoPosterStyles() => [
      // —— 9:16 · 方向一 净版（信息与照片彻底分区，文字落在暖白实底/白卡上）——
      PosterStyle(
        id: 'n1',
        name: '满幅净版',
        groupName: '净版 · 满幅净版',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N1FullBand(data: d),
      ),
      PosterStyle(
        id: 'n2',
        name: '画册相框',
        groupName: '净版 · 画册相框',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N2AlbumFrame(data: d),
      ),
      PosterStyle(
        id: 'n3',
        name: '浮卡叠影',
        groupName: '净版 · 浮卡叠影',
        group: '净版',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _N3FloatCard(data: d),
      ),
      // —— 9:16 · 方向二 画刊（杂志编辑感：刊头 / VOL 期号 / 发丝线 / 竖排标题）——
      PosterStyle(
        id: 'm1',
        name: '刊头装裱',
        groupName: '画刊 · 刊头装裱',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M1Masthead(data: d),
      ),
      PosterStyle(
        id: 'm2',
        name: '双轨夹窗',
        groupName: '画刊 · 双轨夹窗',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M2TwinRails(data: d),
      ),
      PosterStyle(
        id: 'm3',
        name: '竖排刊',
        groupName: '画刊 · 竖排刊',
        group: '画刊',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _M3VerticalColumn(data: d),
      ),
      // —— 9:16 · 方向三 画卷（装裱语汇：天头/画心/地头/诗塘/题跋/小印）——
      PosterStyle(
        id: 'j1',
        name: '立轴',
        groupName: '画卷 · 立轴',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J1HangingScroll(data: d),
      ),
      PosterStyle(
        id: 'j2',
        name: '诗塘',
        groupName: '画卷 · 诗塘',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J2PondTop(data: d),
      ),
      PosterStyle(
        id: 'j3',
        name: '对题',
        groupName: '画卷 · 对题',
        group: '画卷',
        kind: PosterKind.photo,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _J3FacingTitle(data: d),
      ),
      // —— 3:4 / 1:1 / 横图既有款（不动）——
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

/// 金线装裱照片框：1px 金线外框（可选裱边底色/留白与轻投影），
/// 内部按 9:16 推导照片尺寸并居中，照片零变形（n2/m1/m2/m3/j1/j2/j3 共用）。
class _FramedPhoto extends StatelessWidget {
  const _FramedPhoto({
    required this.data,
    this.mountColor,
    this.mountPadding = EdgeInsets.zero,
    this.boxShadow,
    this.borderRadius = 0,
  });

  final PosterStyleData data;

  /// 裱边底色（画卷方向的 surfaceAlt 装裱）。
  final Color? mountColor;

  /// 裱边留白（画心与金线之间的装裱宽度）。
  final EdgeInsets mountPadding;

  /// 轻投影（双轨夹窗照片窗；单层柔和，非双向浮雕）。
  final List<BoxShadow>? boxShadow;

  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: mountColor,
        border: Border.all(color: PosterPalette.line),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availW = constraints.maxWidth - 2 - mountPadding.horizontal;
          final availH = constraints.maxHeight - 2 - mountPadding.vertical;
          var pw = availH * 9 / 16;
          var ph = availH;
          if (pw > availW) {
            pw = availW;
            ph = availW * 16 / 9;
          }
          return Padding(
            padding: mountPadding,
            child: Center(
              child: SizedBox(
                width: pw,
                height: ph,
                child: data.photoBuilder(pw, ph),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 底行（净版/画刊通用）：作者信息（左）+ 二维码迷你卡（右）。
class _AuthorQrRow extends StatelessWidget {
  const _AuthorQrRow({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        PosterAuthorRow(
          name: data.authorName,
          avatarSize: 18,
          whoSize: 10,
          withSize: 8,
          gap: 6,
        ),
        const Spacer(),
        PosterQrMini(data: data),
      ],
    );
  }
}

/// 金线品牌脚（净版/画刊底行）：LUMIRA · 如画 + 标语，顶部 1px 金线。
class _FootBar extends StatelessWidget {
  const _FootBar({this.paddingTop = 7});
  final double paddingTop;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: paddingTop),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: PosterPalette.line)),
      ),
      child: Row(
        children: [
          Text('LUMIRA',
              style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 3)),
          const SizedBox(width: 4),
          Text('· 如画', style: posterPlain(9, color: PosterPalette.text3)),
          const Spacer(),
          Text('如你所见，皆成画卷',
              style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
        ],
      ),
    );
  }
}

/// 满幅净版（9:16）：照片满幅零叠字 + 底部 160px 暖白实底信息带。
class _N1FullBand extends StatelessWidget {
  const _N1FullBand({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
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
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 160,
              decoration: const BoxDecoration(
                color: PosterPalette.surface,
                border: Border(top: BorderSide(color: PosterPalette.line)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PosterKicker(text: posterKickerOf(d)),
                      const Spacer(),
                      Text('如你所见，皆成画卷',
                          style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
                  const SizedBox(height: 4),
                  PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                  const Spacer(),
                  _AuthorQrRow(data: d),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 画册相框（9:16）：金线相框装裱 9:16 照片的画册内页。
class _N2AlbumFrame extends StatelessWidget {
  const _N2AlbumFrame({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const PosterBrandRow(),
              const Spacer(),
              Text('VOL.01',
                  style: posterSerifEn(9, color: PosterPalette.text3, letterSpacing: 2)),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: SizedBox(
              width: 172,
              height: 305.78,
              child: _FramedPhoto(data: d),
            ),
          ),
          const SizedBox(height: 12),
          PosterKicker(text: posterKickerOf(d)),
          const SizedBox(height: 3),
          PosterTitle(text: d.title, size: 22, letterSpacing: 2, height: 1.25),
          const SizedBox(height: 3),
          PosterCatText(category: d.category, size: 9, letterSpacing: 2),
          const SizedBox(height: 7),
          _AuthorQrRow(data: d),
          const SizedBox(height: 7),
          const _FootBar(paddingTop: 8),
        ],
      ),
    );
  }
}

/// 浮卡叠影（9:16）：照片满幅 + 白色信息卡悬浮叠底（单层柔和投影）。
class _N3FloatCard extends StatelessWidget {
  const _N3FloatCard({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
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
          Positioned(
            left: 22,
            right: 22,
            bottom: 18,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: PosterPalette.line),
                boxShadow: const [
                  // 设计稿：0 16px 36px -16px rgba(70,55,30,.45)
                  BoxShadow(
                    color: Color(0x7346371E),
                    offset: Offset(0, 16),
                    blurRadius: 36,
                    spreadRadius: -16,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosterKicker(text: posterKickerOf(d)),
                  const SizedBox(height: 5),
                  PosterTitle(text: d.title, size: 22, letterSpacing: 2, height: 1.25),
                  const SizedBox(height: 6),
                  PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                  const SizedBox(height: 8),
                  PosterAuthorRow(
                    name: d.authorName,
                    avatarSize: 20,
                    whoSize: 10,
                    withSize: 8,
                    gap: 6,
                  ),
                  const SizedBox(height: 10),
                  const PosterDivider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      PosterQrMini(data: d),
                      const Spacer(),
                      const PosterFootMini(),
                    ],
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

/// 刊头品牌行（m1 放大版）：logo 16 + LUMIRA 15px 墨色 + 如画。
class _MastBrand extends StatelessWidget {
  const _MastBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const PosterLogo(size: 16),
        const SizedBox(width: 8),
        Text('LUMIRA',
            style: posterSerifEn(15, color: PosterPalette.ink, letterSpacing: 4)),
        const SizedBox(width: 5),
        Text('如画', style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 2)),
      ],
    );
  }
}

/// 期号两行（m1 刊头右侧）：VOL.01（金）+ 第 028 期 · 2026 秋。
class _IssueLines extends StatelessWidget {
  const _IssueLines();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('VOL.01',
            style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 2)),
        Text('第 028 期 · 2026 秋',
            style: posterPlain(7.5,
                color: PosterPalette.text3, letterSpacing: 1, height: 1.5)),
      ],
    );
  }
}

/// 期号单行（m2/m3 刊头右侧）：VOL.01 + 第 028 期。
class _VolNoInline extends StatelessWidget {
  const _VolNoInline();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('VOL.01',
            style: posterSerifEn(9, color: PosterPalette.goldDeep, letterSpacing: 2)),
        const SizedBox(width: 8),
        Text('第 028 期',
            style: posterPlain(7.5, color: PosterPalette.text3, letterSpacing: 1)),
      ],
    );
  }
}

/// 刊头装裱（9:16）：杂志刊头 + VOL 期号 + 金线装裱照片 + 图注。
class _M1Masthead extends StatelessWidget {
  const _M1Masthead({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              _MastBrand(),
              Spacer(),
              _IssueLines(),
            ],
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: PosterPalette.gold),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(data: d),
                ),
              ),
            ),
          ),
          Text('摄于九月晴午 · 光落在草尖上',
              style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
          const SizedBox(height: 7),
          PosterKicker(text: posterKickerOf(d)),
          const SizedBox(height: 2),
          PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
          const SizedBox(height: 4),
          PosterCatText(category: d.category, size: 9, letterSpacing: 2),
          const SizedBox(height: 7),
          _AuthorQrRow(data: d),
          const SizedBox(height: 7),
          const _FootBar(),
        ],
      ),
    );
  }
}

/// 双轨夹窗（9:16）：上轨刊头 + 中段照片窗 + 下轨信息，分区最彻底。
class _M2TwinRails extends StatelessWidget {
  const _M2TwinRails({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Text('如你所见，皆成画卷',
                    style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                const SizedBox(width: 12),
                const _VolNoInline(),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(
                    data: d,
                    boxShadow: const [
                      // 设计稿：0 12px 26px -16px rgba(70,55,30,.4)
                      BoxShadow(
                        color: Color(0x6646371E),
                        offset: Offset(0, 12),
                        blurRadius: 26,
                        spreadRadius: -16,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 14),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterKicker(text: posterKickerOf(d)),
                const SizedBox(height: 2),
                PosterTitle(text: d.title, size: 20, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 3),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 7),
                _AuthorQrRow(data: d),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 竖排刊（9:16）：左侧竖排衬线标题轨 + 右侧照片，画刊内页感。
class _M3VerticalColumn extends StatelessWidget {
  const _M3VerticalColumn({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: const [
                PosterBrandRow(),
                Spacer(),
                _VolNoInline(),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 44,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: PosterPalette.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(0, 14, 0, 12),
                  child: Column(
                    children: [
                      PosterVerticalText(
                        text: d.title,
                        style: posterSerif(20, letterSpacing: 7),
                        charGap: 7,
                      ),
                      const SizedBox(height: 12),
                      Container(width: 1, height: 36, color: PosterPalette.gold),
                      const SizedBox(height: 12),
                      PosterVerticalText(
                        text: '如你所见，皆成画卷',
                        style: posterPlain(7.5,
                            color: PosterPalette.text3, letterSpacing: 2),
                        charGap: 2,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Center(
                            child: AspectRatio(
                              aspectRatio: 9 / 16,
                              child: _FramedPhoto(data: d),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        PosterKicker(text: posterKickerOf(d)),
                        const SizedBox(height: 3),
                        PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                        const SizedBox(height: 7),
                        _AuthorQrRow(data: d),
                        const SizedBox(height: 7),
                        const _FootBar(),
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

/// 立轴（9:16）：天头 / 裱边画心 / 地头三段式装裱结构。
class _J1HangingScroll extends StatelessWidget {
  const _J1HangingScroll({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('如你所见，皆成画卷',
                        style:
                            posterPlain(8, color: PosterPalette.text3, letterSpacing: 1)),
                    Text('No.028 · 2026 秋',
                        style: posterSerifEn(8,
                            color: PosterPalette.goldDeep, letterSpacing: 2)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(
                    data: d,
                    mountColor: PosterPalette.surfaceAlt,
                    mountPadding: const EdgeInsets.all(5),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PosterTitle(text: d.title, size: 20, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 3),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 6),
                const PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    PosterAuthorRow(
                      name: d.authorName,
                      avatarSize: 18,
                      whoSize: 10,
                      withSize: 8,
                      gap: 6,
                    ),
                    const Spacer(),
                    const PosterSeal(),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    PosterQrMini(data: d),
                    const Spacer(),
                    const PosterFootMini(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 诗塘（9:16）：顶部题字面板（诗塘）+ 画心 + 款行尾轨。
class _J2PondTop extends StatelessWidget {
  const _J2PondTop({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 13),
            decoration: const BoxDecoration(
              color: PosterPalette.surfaceAlt,
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const PosterBrandRow(),
                    const Spacer(),
                    Text('No.028 · 2026 秋',
                        style: posterSerifEn(8,
                            color: PosterPalette.goldDeep, letterSpacing: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                PosterKicker(text: posterKickerOf(d)),
                const SizedBox(height: 3),
                PosterTitle(text: d.title, size: 24, letterSpacing: 2, height: 1.25),
                const SizedBox(height: 4),
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    PosterPara(text: '九月晴午，光落草尖，见之成卷。'),
                    Spacer(),
                    PosterSeal(),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 9 / 16,
                  child: _FramedPhoto(data: d),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: _AuthorQrRow(data: d),
          ),
        ],
      ),
    );
  }
}

/// 对题（9:16）：左题跋栏 + 右画心并置 + 尾轨（分类 + 二维码）。
class _J3FacingTitle extends StatelessWidget {
  const _J3FacingTitle({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return PosterCanvas(
      width: posterCanvasWidth(d.ratio),
      height: posterFixedHeight(d.ratio),
      child: Column(
        children: [
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                const PosterBrandRow(),
                const Spacer(),
                Text('No.028 · 2026 秋',
                    style: posterSerifEn(8,
                        color: PosterPalette.goldDeep, letterSpacing: 2)),
              ],
            ),
          ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 88,
                  decoration: const BoxDecoration(
                    border: Border(right: BorderSide(color: PosterPalette.line)),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      PosterKicker(
                        text: posterKickerOf(d),
                        size: 8.5,
                        letterSpacing: 2,
                      ),
                      const SizedBox(height: 8),
                      PosterTitle(text: d.title, size: 19, letterSpacing: 1, height: 1.3),
                      const SizedBox(height: 8),
                      const PosterPara(
                        text: '九月晴午，光落草尖，见之成卷。',
                        size: 8.5,
                        letterSpacing: 1,
                        height: 1.8,
                      ),
                      const Spacer(),
                      const PosterSeal(),
                      const SizedBox(height: 8),
                      PosterAuthorRow(
                        name: d.authorName,
                        suffix: '',
                        avatarSize: 16,
                        whoSize: 8.5,
                        gap: 5,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Center(
                      child: SizedBox(
                        width: 184,
                        height: 327.11,
                        child: _FramedPhoto(data: d),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: PosterPalette.line)),
            ),
            child: Row(
              children: [
                PosterCatText(category: d.category, size: 9, letterSpacing: 2),
                const Spacer(),
                PosterQrMini(data: d),
              ],
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
