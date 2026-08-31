import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

/// 邀请卡片分享海报
class InvitePosterCard extends ConsumerWidget {
  const InvitePosterCard({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final p = _InvitePalette.of(appTheme.style);
    return Container(
      width: 400,
      clipBehavior: Clip.antiAlias,
      decoration: _sceneDecoration(appTheme.style, p),
      child: Stack(
        children: [
          Positioned.fill(child: _sceneBackground(appTheme.style, p)),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Center(child: _InviteCard(style: appTheme.style, palette: p, code: code)),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _sceneDecoration(UIStyle style, _InvitePalette p) {
  Border border;
  List<BoxShadow> shadow;
  switch (style) {
    case UIStyle.neumorphic:
      border = Border.all(color: const Color(0x1AC9A96E), width: 1);
      shadow = const [];
      break;
    case UIStyle.flat:
      border = Border.all(color: const Color(0x1FC9A96E), width: 1);
      shadow = const [];
      break;
    case UIStyle.glass:
      border = Border.all(color: const Color(0x66FFFFFF), width: 1);
      shadow = const [BoxShadow(color: Color(0x805B3428), blurRadius: 40, offset: Offset(0, 20))];
      break;
    case UIStyle.female:
      border = Border.all(color: const Color(0x2EB48CAA), width: 1);
      shadow = const [BoxShadow(color: Color(0x7380506E), blurRadius: 40, offset: Offset(0, 20))];
      break;
  }
  return BoxDecoration(color: p.sceneBase, borderRadius: BorderRadius.circular(30), border: border, boxShadow: shadow);
}

Widget _sceneBackground(UIStyle style, _InvitePalette p) {
  switch (style) {
    case UIStyle.neumorphic:
      return Stack(children: [
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFAF7F2), Color(0xFFF2EEE6)])))),
        Positioned(top: -120, left: -120, child: _RadialTint(size: 300, color: const Color(0x33C9A96E))),
      ]);
    case UIStyle.flat:
      return const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF5F1E7), Color(0xFFECE7DA)])));
    case UIStyle.glass:
      return Stack(children: [
        const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.bottomRight, colors: [Color(0xFFF6D9C7), Color(0xFFE8C8C0), Color(0xFFCDD5EC), Color(0xFFBAE1DC)], stops: [0.0, 0.34, 0.7, 1.0])))),
        Positioned(top: -40, right: -50, child: _RadialTint(size: 180, color: const Color(0x80FFAA96))),
        Positioned(bottom: -70, left: -60, child: _RadialTint(size: 220, color: const Color(0x7396BBEB))),
      ]);
    case UIStyle.female:
      return const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFBE3DC), Color(0xFFF0D4E6), Color(0xFFDCE3F3)], stops: [0.0, 0.55, 1.0])));
  }
}

class _RadialTint extends StatelessWidget {
  const _RadialTint({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(radius: 0.9, colors: [color, color.withOpacity(0)], stops: const [0.0, 0.7]))));
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({required this.style, required this.palette, required this.code});
  final UIStyle style;
  final _InvitePalette palette;
  final String code;

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: p.cardPadH, vertical: p.cardPadV),
      clipBehavior: Clip.antiAlias,
      decoration: _cardDecoration(style, p),
      child: Stack(children: [
        if (style == UIStyle.female)
          Positioned(top: -40, left: -30, child: _RadialTint(size: 180, color: const Color(0x8CFFFFFF))),
        if (style == UIStyle.glass)
          Positioned(top: 0, left: 0, right: 0, height: 42, child: const IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x80FFFFFF), Color(0x00FFFFFF)]))))),
        Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildBrandRow(p),
          const SizedBox(height: 32),
          _buildTitle(p),
          const SizedBox(height: 10),
          _buildSubtitle(p),
          const SizedBox(height: 18),
          _buildGainPill(p),
          const SizedBox(height: 30),
          _buildQrZone(p),
          const SizedBox(height: 28),
          _buildCodeBlock(p),
          const SizedBox(height: 24),
          _buildFooter(p),
        ]),
      ]),
    );
  }

  BoxDecoration _cardDecoration(UIStyle style, _InvitePalette p) {
    switch (style) {
      case UIStyle.neumorphic:
        return BoxDecoration(color: p.cardBg!, borderRadius: BorderRadius.circular(22), boxShadow: const [
          BoxShadow(color: Color(0xD9D8D4CC), offset: Offset(6, 6), blurRadius: 14),
          BoxShadow(color: Colors.white, offset: Offset(-6, -6), blurRadius: 14),
        ]);
      case UIStyle.flat:
        return BoxDecoration(color: p.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFEAE5DC), width: 1));
      case UIStyle.glass:
        return BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: const [Color(0x9EFFFFFF), Color(0x61FFFFFF)]), borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0x99FFFFFF), width: 1), boxShadow: const [
          BoxShadow(color: Color(0x733C342A), blurRadius: 34, offset: Offset(0, 14)),
        ]);
      case UIStyle.female:
        return BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFDF4EE), Color(0xFFF9EBF2), Color(0xFFEFE9F7)], stops: [0.0, 0.45, 1.0]), borderRadius: BorderRadius.circular(24), border: Border.all(color: const Color(0x73C8A0B2), width: 1), boxShadow: const [
          BoxShadow(color: Color(0x66A06E8C), blurRadius: 30, offset: Offset(0, 14)),
        ]);
    }
  }

  Widget _buildBrandRow(_InvitePalette p) {
    return Row(children: [
      Text('LUMIRA', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 6, fontFamily: 'Georgia', fontFamilyFallback: kSerifFallback, color: p.brandEn)),
      const SizedBox(width: 16),
      Expanded(child: Container(height: 1, decoration: BoxDecoration(gradient: LinearGradient(colors: p.brandLine)))),
      const SizedBox(width: 16),
      Text('如 画', style: TextStyle(fontSize: 11, letterSpacing: 4, color: p.brandZh)),
    ]);
  }

  Widget _buildTitle(_InvitePalette p) {
    return Text('邀请好友 · 一起来拍照', textAlign: TextAlign.center, style: TextStyle(fontSize: 27, fontWeight: FontWeight.w600, letterSpacing: 2, height: 1.4, color: p.title));
  }

  Widget _buildSubtitle(_InvitePalette p) {
    return Text('和你一起，把生活拍成想要的样子', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, letterSpacing: 1, height: 1.5, color: p.sub));
  }

  Widget _buildGainPill(_InvitePalette p) {
    return Align(alignment: Alignment.center, child: Container(padding: EdgeInsets.symmetric(horizontal: p.gainPadH, vertical: 8), decoration: BoxDecoration(color: p.gainBg, borderRadius: BorderRadius.circular(p.gainRadius), border: p.gainBorder, boxShadow: p.gainShadow), child: Text('好友首次激活，双方各得 +30 积分', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 1, color: p.gainText))));
  }

  Widget _buildQrZone(_InvitePalette p) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Align(alignment: Alignment.center, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: p.qrBg, borderRadius: BorderRadius.circular(p.qrRadius), border: p.qrBorder, boxShadow: p.qrShadow), child: _MockupQr(moduleColor: p.qrModule))),
      const SizedBox(height: 12),
      Text('长按识别二维码 · 立即加入', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, letterSpacing: 1, color: p.tip)),
    ]);
  }

  Widget _buildCodeBlock(_InvitePalette p) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: p.codeBg, borderRadius: BorderRadius.circular(p.codeRadius), border: p.codeBorder, boxShadow: p.codeShadow), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text('我的邀请码', style: TextStyle(fontSize: 10, letterSpacing: 3, color: p.lab)),
      const SizedBox(height: 7),
      Text(code, textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: 3, color: p.val)),
    ]));
  }

  Widget _buildFooter(_InvitePalette p) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('LUMIRA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 5, fontFamily: 'Georgia', fontFamilyFallback: kSerifFallback, color: p.footEn)),
      const SizedBox(width: 10),
      Text('·', style: TextStyle(fontSize: 9, color: p.footDot)),
      const SizedBox(width: 10),
      Text('如 画 · 记录每一帧美好', style: TextStyle(fontSize: 9, letterSpacing: 3, color: p.footZh)),
    ]);
  }
}

const List<String> kSerifFallback = [
  'Georgia', 'Times New Roman', 'Noto Serif', 'Noto Serif CJK SC', 'Songti SC', 'SimSun', 'serif',
];

/// 设计稿固定 17×17 装饰二维码图案：三定位角 + 密布信息模块。
class _MockupQr extends StatelessWidget {
  const _MockupQr({required this.moduleColor, this.size = 150});
  final Color moduleColor;
  final double size;

  static const List<String> _segments = [
    '1/1/5/5', '1/9/2/11', '1/13/5/16', '1/3/2/4', '3/1/4/2', '3/3/4/4',
    '6/1/7/3', '6/4/7/5', '6/6/7/8', '6/9/7/11', '6/12/7/14',
    '7/1/8/4', '7/6/8/7', '7/8/8/9', '7/11/8/13',
    '8/3/9/4', '8/5/9/6', '8/10/9/11',
    '9/1/10/2', '9/6/10/8', '9/12/10/13',
    '10/1/11/3', '10/8/11/9', '10/11/11/13',
    '11/4/12/5', '11/6/12/7', '11/10/12/11',
    '12/1/13/3', '12/5/13/6', '12/11/13/12',
    '13/1/15/2', '13/2/15/4', '13/8/15/10', '13/12/14/15',
    '15/5/16/6', '15/9/16/10',
  ];

  @override
  Widget build(BuildContext context) {
    const gap = 1.5;
    final track = (size - 16 * gap) / 17;
    final rects = <Rect>[];
    for (final seg in _segments) {
      final parts = seg.split('/');
      final r1 = int.parse(parts[0]);
      final c1 = int.parse(parts[1]);
      final r2 = int.parse(parts[2]);
      final c2 = int.parse(parts[3]);
      final left = (c1 - 1) * (track + gap);
      final right = left + (c2 - c1 - 1) * (track + gap) + track;
      final top = (r1 - 1) * (track + gap);
      final bottom = top + (r2 - r1 - 1) * (track + gap) + track;
      rects.add(Rect.fromLTRB(left, top, right, bottom));
    }
    return CustomPaint(size: Size(size, size), painter: _MockupQrPainter(moduleColor, rects));
  }
}

class _MockupQrPainter extends CustomPainter {
  _MockupQrPainter(this.moduleColor, this.rects);
  final Color moduleColor;
  final List<Rect> rects;
  final Paint _paint = Paint()..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    _paint.color = moduleColor;
    for (final r in rects) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1)), _paint);
    }
  }

  @override
  bool shouldRepaint(_MockupQrPainter oldDelegate) => oldDelegate.moduleColor != moduleColor || !listEquals(oldDelegate.rects, rects);
}

/// 每套风格的固定色板（取自 poster_mockup_invite.html）。
class _InvitePalette {
  const _InvitePalette({
    this.sceneBase, required this.cardPadH, required this.cardPadV, this.cardBg,
    required this.brandEn, required this.brandZh, required this.brandLine,
    required this.title, required this.sub, required this.gainText, required this.gainBg,
    required this.gainBorder, required this.gainRadius, required this.gainPadH, required this.gainShadow,
    required this.qrBg, required this.qrBorder, required this.qrRadius, required this.qrShadow,
    required this.qrModule, required this.tip, required this.codeBg, required this.codeBorder,
    required this.codeRadius, required this.codeShadow, required this.lab, required this.val,
    required this.footEn, required this.footDot, required this.footZh,
  });

  final Color? sceneBase;
  final double cardPadH;
  final double cardPadV;
  final Color? cardBg;
  final Color brandEn;
  final Color brandZh;
  final List<Color> brandLine;
  final Color title;
  final Color sub;
  final Color gainText;
  final Color gainBg;
  final Border? gainBorder;
  final double gainRadius;
  final double gainPadH;
  final List<BoxShadow> gainShadow;
  final Color qrBg;
  final Border? qrBorder;
  final double qrRadius;
  final List<BoxShadow> qrShadow;
  final Color qrModule;
  final Color tip;
  final Color codeBg;
  final Border? codeBorder;
  final double codeRadius;
  final List<BoxShadow> codeShadow;
  final Color lab;
  final Color val;
  final Color footEn;
  final Color footDot;
  final Color footZh;

  static _InvitePalette of(UIStyle style) {
    switch (style) {
      case UIStyle.neumorphic:
        return _InvitePalette(
          cardPadH: 26, cardPadV: 30, cardBg: Color(0xFFFDFBF7),
          brandEn: Color(0xFF1A1A1A), brandZh: Color(0xFFC9A96E),
          brandLine: [Color(0x73C9A96E), Color(0x0DC9A96E)],
          title: Color(0xFF1A1A1A), sub: Color(0xFF9C9690),
          gainText: Color(0xFFA88550), gainBg: Color(0xFFF5EDDB),
          gainBorder: null, gainRadius: 1000, gainPadH: 18, gainShadow: [],
          qrBg: Colors.white, qrBorder: Border.all(color: Color(0xFFEAE5DC), width: 1), qrRadius: 16,
          qrShadow: [BoxShadow(color: Color(0xFF5A4E3C), blurRadius: 26, offset: Offset(0, 10))],
          qrModule: Color(0xFF1A1A1A), tip: Color(0xFF9C9690),
          codeBg: Color(0xFFFAF7F2), codeBorder: null, codeRadius: 16,
          codeShadow: [BoxShadow(color: Color(0xB3DAD4CC), offset: Offset(2, 2), blurRadius: 6), BoxShadow(color: Colors.white, offset: Offset(-2, -2), blurRadius: 6)],
          lab: Color(0xFFA99A78), val: Color(0xFF1A1A1A),
          footEn: Color(0xFFC9A96E), footDot: Color(0xFFC9A96E), footZh: Color(0xFFA29479),
        );
      case UIStyle.flat:
        return _InvitePalette(
          cardPadH: 28, cardPadV: 32, cardBg: Color(0xFFF2EEE6),
          brandEn: Color(0xFF3D352A), brandZh: Color(0xFFB08D4F),
          brandLine: [Color(0xFFE0D9C8), Color(0x00E0D9C8)],
          title: Color(0xFF3D352A), sub: Color(0xFF8A7F6E),
          gainText: Color(0xFF8C7340), gainBg: Colors.white,
          gainBorder: Border.all(color: Color(0xFFE0D9C8), width: 1), gainRadius: 14, gainPadH: 18, gainShadow: [],
          qrBg: Colors.white, qrBorder: Border.all(color: Color(0xFFE0D9C8), width: 1), qrRadius: 0,
          qrShadow: [], qrModule: Color(0xFF2E2A24), tip: Color(0xFF8A7F6E),
          codeBg: Colors.white, codeBorder: Border.all(color: Color(0xFFE0D9C8), width: 1), codeRadius: 0,
          codeShadow: [], lab: Color(0xFFA08A5F), val: Color(0xFF3D352A),
          footEn: Color(0xFFB08D4F), footDot: Color(0xFFC9A96E), footZh: Color(0xFFA29479),
        );
      case UIStyle.glass:
        return _InvitePalette(
          sceneBase: Color(0xFFCDD5EC), cardPadH: 26, cardPadV: 30,
          brandEn: Color(0xE63C2D1E), brandZh: Color(0xCC785A37),
          brandLine: [Color(0xCCFFFFFF), Color(0x00FFFFFF)],
          title: Color(0xF232261A), sub: Color(0xBF46382A),
          gainText: Color(0xFF8A5F33), gainBg: Color(0x8CFFFFFF),
          gainBorder: Border.all(color: Color(0xB3FFFFFF), width: 1), gainRadius: 1000, gainPadH: 18,
          gainShadow: [BoxShadow(color: Color(0x663C2D1E), offset: Offset(0, 6), blurRadius: 16)],
          qrBg: Color(0xD9FFFFFF), qrBorder: Border.all(color: Color(0xCCFFFFFF), width: 1), qrRadius: 16,
          qrShadow: [BoxShadow(color: Color(0x803C3223), blurRadius: 26, offset: Offset(0, 10))],
          qrModule: Color(0xFF1A1A1A), tip: Color(0xB33D3828),
          codeBg: Color(0x80FFFFFF), codeBorder: Border.all(color: Color(0xA6FFFFFF), width: 1), codeRadius: 16,
          codeShadow: [], lab: Color(0xBF6E583C), val: Color(0xF232261A),
          footEn: Color(0xD95A4632), footDot: Color(0xB36E583C), footZh: Color(0xB364523C),
        );
      case UIStyle.female:
        return _InvitePalette(
          cardPadH: 28, cardPadV: 32,
          brandEn: Color(0xFF5A4050), brandZh: Color(0xFFB07A96),
          brandLine: [Color(0x80BE8CA5), Color(0x00BE8CA5)],
          title: Color(0xFF5A4050), sub: Color(0xFFA28296),
          gainText: Color(0xFFB07A96), gainBg: Colors.white,
          gainBorder: Border.all(color: Color(0x80D2AABE), width: 1), gainRadius: 1000, gainPadH: 20,
          gainShadow: [BoxShadow(color: Color(0x99A06E8C), offset: Offset(0, 8), blurRadius: 18)],
          qrBg: Colors.white, qrBorder: Border.all(color: Color(0xFFF0DFE7), width: 1), qrRadius: 18,
          qrShadow: [BoxShadow(color: Color(0x80A06E8C), blurRadius: 24, offset: Offset(0, 10))],
          qrModule: Color(0xFF5A4050), tip: Color(0xFFA28296),
          codeBg: Color(0xB3FFFFFF), codeBorder: Border.all(color: Color(0xFFF0DFE7), width: 1), codeRadius: 16,
          codeShadow: [], lab: Color(0xFFC49AB1), val: Color(0xFF5A4050),
          footEn: Color(0xFFB07A96), footDot: Color(0xFFD3A8BC), footZh: Color(0xFFB08CA0),
        );
    }
  }
}