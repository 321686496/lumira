import 'package:flutter/material.dart';

import 'poster_common.dart';
import 'poster_ratio.dart';
import 'poster_style_types.dart';

/// 自定义模板「扫码导入」海报样式（5 款）。
///
/// 对应选型稿 `docs/design/poster_mockup_import_v3.html`：海报画布**固定竖版
/// 340×566**，封面图比例决定整套排版构图 —— 5 种比例 = 5 种完全不同布局：
///
/// | 比例 | id | 布局 |
/// |---|---|---|
/// | 9:16 全屏 | [impV] | 左图满高 · 右列竖文 |
/// | 3:4 | [impP] | 上居中图 · 下居中文字 |
/// | 1:1 | [impS] | 左方图 · 右栏文 |
/// | 4:3 | [impL] | 文字在上 · 横幅图在下 |
/// | 16:9 | [impC] | 电影通栏 · 标题压图 |
///
/// 与「分享模板」海报不同：本组为二维码**导入**用途，文案固定为
/// 「扫码导入模板 / 打开如画 App」，并展示推导的序列号（№）与有效期
/// （当前时间 +7 天）。颜色严格遵循选型稿暖白纸感 + 金色细线 + 衬线大标题。
List<PosterStyle> templateImportPosterStyles() => [
      PosterStyle(
        id: 'impV',
        name: '竖幅导入',
        groupName: '扫码导入 · 9:16 竖幅',
        kind: PosterKind.template,
        ratios: const {PosterRatio.fullScreen},
        builder: (d) => _ImportC1(data: d),
      ),
      PosterStyle(
        id: 'impP',
        name: '竖幅居中',
        groupName: '扫码导入 · 3:4 竖幅',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio34},
        builder: (d) => _ImportC2(data: d),
      ),
      PosterStyle(
        id: 'impS',
        name: '方形分栏',
        groupName: '扫码导入 · 1:1 方形',
        kind: PosterKind.template,
        ratios: const {PosterRatio.square},
        builder: (d) => _ImportC3(data: d),
      ),
      PosterStyle(
        id: 'impL',
        name: '横幅上图',
        groupName: '扫码导入 · 4:3 横幅',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio43},
        builder: (d) => _ImportC4(data: d),
      ),
      PosterStyle(
        id: 'impC',
        name: '宽幅电影',
        groupName: '扫码导入 · 16:9 宽幅',
        kind: PosterKind.template,
        ratios: const {PosterRatio.ratio169},
        builder: (d) => _ImportC5(data: d),
      ),
    ];

/// 选型稿暖白纸感 + 金色色板（照抄 design tokens，与 [PosterPalette] 一致处复用）。
const Color _surface = PosterPalette.surface; // #FDFBF7
const Color _ink = PosterPalette.ink; // #1A1A1A
const Color _gold = PosterPalette.gold; // #C9A96E
const Color _goldDeep = PosterPalette.goldDeep; // #B08D4F
const Color _text2 = Color(0xFF6B645C);
const Color _text3 = Color(0xFF979080);
const Color _line = Color(0x61C9A96E); // rgba(201,169,110,.38)
const Color _lineSoft = Color(0x33C9A96E); // rgba(201,169,110,.20)

/// 海报画布：固定竖版 340×566，暖白纸感底、无圆角无外描边（设计稿为全出血卡）。
Widget _importCanvas(Widget child) {
  return PosterCanvas(
    width: 340,
    height: 566,
    color: _surface,
    borderColor: Colors.transparent,
    borderRadius: 0,
    child: Stack(
      fit: StackFit.expand,
      children: [child],
    ),
  );
}

/// 顶部水印：LUMIRA · 如画（浅底深金 / 压图白）。
Widget _wm({bool onPhoto = false}) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'LUMIRA',
        style: posterSerifEn(
          9,
          color: onPhoto ? Colors.white : _goldDeep,
          letterSpacing: 3,
          weight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 4),
      Text(
        '· 如画',
        style: posterPlain(
          9,
          color: onPhoto ? Colors.white70 : _text3,
          letterSpacing: 2,
        ),
      ),
    ],
  );
}

/// 顶部序列号：№ XXX（衬线小字）。
Widget _serial(String s, {bool onPhoto = false}) {
  return Text(
    s,
    style: posterSerifEn(
      9,
      color: onPhoto ? Colors.white70 : _text3,
      letterSpacing: 1,
      weight: FontWeight.w500,
    ),
  );
}

/// 序列号：由标题稳定派生（0~999 三位）。
String _serialOf(String title) {
  var h = title.runes.fold<int>(0, (a, c) => (a * 31 + c) & 0xFFFFFF);
  return '№ ${(h % 1000).toString().padLeft(3, '0')}';
}

/// 有效期文案：当前时间 +7 天，格式 `MM-dd HH:mm`。
String _expiryValue() {
  final t = DateTime.now().add(const Duration(days: 7));
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.month)}-${two(t.day)} ${two(t.hour)}:${two(t.minute)}';
}

/// 有效期条目：`有效期至 MM-dd HH:mm`（label 弱化、value 深金加粗）。
Widget _expiry() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Text('有效期至 ', style: posterPlain(8, color: _text3, letterSpacing: 2)),
      Text(
        _expiryValue(),
        style: posterPlain(8, color: _goldDeep, letterSpacing: 2, weight: FontWeight.w600),
      ),
    ],
  );
}

/// 上下带金线的 kicker（模板分享），对应设计 `.kicker`。
Widget _kicker() {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(width: 14, height: 1, child: ColoredBox(color: _gold)),
      const SizedBox(width: 8),
      Text(
        '模板分享',
        style: posterPlain(9, color: _goldDeep, letterSpacing: 3, weight: FontWeight.w600),
      ),
      const SizedBox(width: 8),
      const SizedBox(width: 14, height: 1, child: ColoredBox(color: _gold)),
    ],
  );
}

/// 竖排文字：逐字纵向堆叠（等效 CSS writing-mode: vertical-rl）。
Widget _verticalText(
  String text, {
  required double size,
  Color color = _ink,
  FontWeight weight = FontWeight.w700,
  double letterSpacing = 0,
  double spacing = 8,
}) {
  final chars = text
      .replaceAll(' ', '')
      .runes
      .map((r) => String.fromCharCode(r))
      .toList();
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < chars.length; i++)
        Padding(
          padding: EdgeInsets.only(bottom: i == chars.length - 1 ? 0 : spacing),
          child: Text(
            chars[i],
            style: posterSerif(size, color: color, letterSpacing: letterSpacing, weight: weight),
          ),
        ),
    ],
  );
}

/// 分类文案（横排，`·` 分隔符用深金）。
Widget _cat(String category, {double size = 9}) {
  final segs = category
      .split('·')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final base = posterPlain(size, color: _text2, letterSpacing: 3);
  final spans = <TextSpan>[];
  for (var i = 0; i < segs.length; i++) {
    if (i > 0) {
      spans.add(TextSpan(text: ' · ', style: base.copyWith(color: _goldDeep, fontWeight: FontWeight.w600)));
    }
    spans.add(TextSpan(text: segs[i]));
  }
  return Text.rich(TextSpan(children: spans, style: base));
}

/// 照片框：cover 填充 + 金色外框 + 内层白色描边（对应 `.img` + `.img::after`）。
Widget _photoBox(Widget photo, {required Size size}) {
  return SizedBox(
    width: size.width,
    height: size.height,
    child: Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: _line.withOpacity(.9))),
          child: photo,
        ),
        Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(border: Border.all(color: Colors.white.withOpacity(.55))),
        ),
      ],
    ),
  );
}

/// 二维码（白底 + 金边 + 轻投影），对应 `.qr`。
Widget _qr(PosterStyleData d, {required double size, double padding = 6}) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      boxShadow: [
        BoxShadow(
          color: Color(0x50403824),
          offset: Offset(0, 8),
          blurRadius: 16,
          spreadRadius: -10,
        ),
      ],
    ),
    child: PosterQr(
      data: d.qrData,
      size: size - padding - padding,
      padding: padding,
      radius: 0,
      background: Colors.white,
      borderColor: _line,
    ),
  );
}

/// 构图 1 · 9:16 左图满高 + 右列竖文。
class _ImportC1 extends StatelessWidget {
  const _ImportC1({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    const photoSize = Size(196, 348);
    return _importCanvas(
      Stack(
        children: [
          Positioned(top: 16, left: 22, child: _wm()),
          Positioned(top: 18, right: 22, child: _serial(_serialOf(d.title))),
          // 左图满高
          Positioned(
            left: 24,
            top: 78,
            child: _photoBox(d.photoBuilder(photoSize.width, photoSize.height), size: photoSize),
          ),
          // 右列竖文
          Positioned(
            left: 240,
            top: 78,
            right: 20,
            bottom: 40,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('模板分享', style: posterPlain(8, color: _goldDeep, letterSpacing: 3, weight: FontWeight.w600)),
                const SizedBox(height: 16),
                // 标题区：可变高度，标题过长时整体缩放贴合，杜绝 RenderFlex 溢出
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _verticalText(d.title, size: 32, letterSpacing: 8, spacing: 10),
                        const SizedBox(height: 20),
                        const SizedBox(width: 26, height: 1, child: ColoredBox(color: _gold)),
                        const SizedBox(height: 16),
                        _verticalText(d.category.replaceAll(' ', ''), size: 8, color: _text2, weight: FontWeight.normal, letterSpacing: 4, spacing: 6),
                      ],
                    ),
                  ),
                ),
                _qr(d, size: 70, padding: 6),
                const SizedBox(height: 8),
                Text(
                  '扫码导入模板\n打开如画 App',
                  textAlign: TextAlign.center,
                  style: posterPlain(8, color: _text3, letterSpacing: 1, height: 1.7),
                ),
              ],
            ),
          ),
          // 有效期
          Positioned(left: 24, bottom: 26, child: _expiry()),
        ],
      ),
    );
  }
}

/// 构图 2 · 3:4 上居中图 + 下居中文字。
class _ImportC2 extends StatelessWidget {
  const _ImportC2({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    const photoSize = Size(184, 246);
    return _importCanvas(
      Stack(
        children: [
          Positioned(top: 16, left: 22, child: _wm()),
          Positioned(top: 18, right: 22, child: _serial(_serialOf(d.title))),
          // 上居中图
          Positioned(
            left: (340 - 184) / 2,
            top: 64,
            child: _photoBox(d.photoBuilder(photoSize.width, photoSize.height), size: photoSize),
          ),
          // 下居中文字
          Positioned(
            left: 0,
            right: 0,
            top: 342,
            bottom: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  _kicker(),
                  const SizedBox(height: 10),
                  PosterTitle(text: d.title, size: 32, letterSpacing: 4, height: 1.2),
                  const SizedBox(height: 8),
                  _cat(d.category),
                  const SizedBox(height: 14),
                  const SizedBox(width: 46, height: 1, child: ColoredBox(color: _gold)),
                  const SizedBox(height: 16),
                  _qr(d, size: 86, padding: 7),
                  const SizedBox(height: 9),
                  Text('扫码导入模板 · 打开如画 App', style: posterPlain(8, color: _text3, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  _expiry(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 构图 3 · 1:1 左方图 + 右栏文。
class _ImportC3 extends StatelessWidget {
  const _ImportC3({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    const photoSize = Size(196, 196);
    return _importCanvas(
      Stack(
        children: [
          Positioned(top: 16, left: 22, child: _wm()),
          Positioned(top: 18, right: 22, child: _serial(_serialOf(d.title))),
          // 左方图
          Positioned(
            left: 28,
            top: 118,
            child: _photoBox(d.photoBuilder(photoSize.width, photoSize.height), size: photoSize),
          ),
          // 右栏文
          Positioned(
            left: 248,
            top: 118,
            right: 22,
            bottom: 44,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('模板分享', style: posterPlain(8, color: _goldDeep, letterSpacing: 3, weight: FontWeight.w600)),
                const SizedBox(height: 10),
                PosterTitle(text: d.title, size: 26, letterSpacing: 3, height: 1.3),
                const SizedBox(height: 8),
                Text(
                  '人像写真\n${d.category.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty).join('·')}',
                  style: posterPlain(8, color: _text2, letterSpacing: 2, height: 1.8),
                ),
                const SizedBox(height: 14),
                const SizedBox(width: 26, height: 1, child: ColoredBox(color: _gold)),
                const Spacer(),
                _qr(d, size: 76, padding: 6),
                const SizedBox(height: 9),
                Text(
                  '扫码导入模板\n打开如画 App',
                  style: posterPlain(8, color: _text3, letterSpacing: 1, height: 1.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 构图 4 · 4:3 文字在上 + 横幅图在下。
class _ImportC4 extends StatelessWidget {
  const _ImportC4({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    const photoSize = Size(288, 216);
    return _importCanvas(
      Stack(
        children: [
          Positioned(top: 16, left: 22, child: _wm()),
          Positioned(top: 18, right: 22, child: _serial(_serialOf(d.title))),
          // 文字在上
          Positioned(
            left: 0,
            right: 0,
            top: 74,
            child: Column(
              children: [
                _kicker(),
                const SizedBox(height: 10),
                PosterTitle(text: d.title, size: 30, letterSpacing: 4, height: 1.2),
                const SizedBox(height: 8),
                _cat(d.category),
              ],
            ),
          ),
          // 横幅图在下
          Positioned(
            left: (340 - 288) / 2,
            top: 180,
            child: _photoBox(d.photoBuilder(photoSize.width, photoSize.height), size: photoSize),
          ),
          // 底部二维码 + 提示
          Positioned(
            left: 0,
            right: 0,
            bottom: 30,
            child: Column(
              children: [
                _qr(d, size: 80, padding: 7),
                const SizedBox(height: 8),
                Text('扫码导入模板 · 打开如画 App', style: posterPlain(8, color: _text3, letterSpacing: 1.5)),
                const SizedBox(height: 7),
                _expiry(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 构图 5 · 16:9 电影通栏 + 标题压图。
class _ImportC5 extends StatelessWidget {
  const _ImportC5({required this.data});
  final PosterStyleData data;

  @override
  Widget build(BuildContext context) {
    final d = data;
    return _importCanvas(
      Stack(
        children: [
          // 通栏照片 + 压暗 + 胶片线
          Positioned(
            left: 0,
            right: 0,
            top: 58,
            height: 186,
            child: Stack(
              fit: StackFit.expand,
              children: [
                d.photoBuilder(340, 186),
                // 顶部压暗（保证白色水印可读）
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x4714100A), Color(0x0014100A)],
                      stops: [0, .55],
                    ),
                  ),
                ),
                // 底部金色胶片线
                const Positioned(left: 0, right: 0, bottom: 0, height: 1, child: ColoredBox(color: _gold)),
                // 顶部胶片齿孔
                Positioned(
                  top: 0,
                  child: Row(
                    children: const [
                      SizedBox(width: 14, height: 1, child: ColoredBox(color: _gold)),
                      SizedBox(width: 340 - 14, height: 1),
                      SizedBox(width: 14, height: 1, child: ColoredBox(color: _gold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 白色水印 + 序列号
          Positioned(top: 20, left: 24, child: _wm(onPhoto: true)),
          Positioned(top: 22, right: 24, child: _serial(_serialOf(d.title), onPhoto: true)),
          // 大标题压图
          Positioned(
            left: 24,
            top: 226,
            child: PosterTitle(text: d.title, size: 40, letterSpacing: 6, height: 1.15),
          ),
          // meta：分类 + 金线 + 有效期
          Positioned(
            left: 26,
            right: 26,
            top: 300,
            child: Row(
              children: [
                Flexible(child: _cat(d.category)),
                const SizedBox(width: 12),
                const Expanded(child: SizedBox(height: 1, child: ColoredBox(color: _lineSoft))),
                const SizedBox(width: 12),
                _expiry(),
              ],
            ),
          ),
          // 底部：二维码 + 提示 + 标语
          Positioned(
            left: 26,
            right: 26,
            bottom: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _qr(d, size: 78, padding: 6),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('扫码导入模板', style: posterPlain(9, color: _ink, letterSpacing: 2, weight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text('打开如画 App 扫码即可导入', style: posterPlain(8, color: _text3, letterSpacing: 1.5, height: 1.8)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('LUMIRA', style: posterSerifEn(9, color: _goldDeep, letterSpacing: 2, weight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text('如你所见 · 皆成画卷', style: posterPlain(8, color: _text3, letterSpacing: 1)),
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