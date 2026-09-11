import 'dart:math';

import 'package:flutter/material.dart';

import '../../../shared/widgets/brand/lumira_logo.dart';
import '../../../shared/widgets/poster/poster_common.dart';

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

/// 顶部装饰图带内置资源（固定横图，Export 稳定，不依赖网络）。
const String invitePosterArtwork = 'assets/images/templates/golden_landscape.jpg';

/// 情绪文案一对（主句 / 副句）。
class EmoOption {
  const EmoOption(this.main, this.sub);
  final String main;
  final String sub;
}

/// 情绪文案候选，每次打开随机取一组。
const List<EmoOption> inviteEmoOptions = [
  EmoOption('套上模板，一键就出片', '不会拍，也能记录下最想留住的美好'),
  EmoOption('不用学、不用调，套上模板就出片', '一按快门，美好随手可留存'),
  EmoOption('关键时刻，套模板一键出片', '再瞬间的美好，也不怕拍不住'),
  EmoOption('套上模板一键出片，拍照本就这么简单', '你的照片，也配被好好记录'),
];

/// 邀请卡片分享海报（9:16 竖版固定品牌，与模板/照片等分享海报同一语言）。
///
/// 与其它分享海报一致：固定 LUMIRA 品牌色板（[PosterPalette]），不随 App
/// 主题/UI 风格切换；二维码为 [PosterQr] 真编码 6 位邀请码，扫码即可被
/// 首页「扫一扫」识别为邀请码。导出经 [PosterGenerator] 捕获 300×533（9:16）。
/// 布局严格对齐设计稿 D3：顶部装饰图带 → 衬线标题 → 双栏（左痛点/右功能卡带
/// 左分隔线）→ 留白情绪文案 → 奖励（金色 +30 · 邀请码横排二维码）→ 积分小字。
/// 情绪文案每次打开时从 [inviteEmoOptions] 随机选一组（预览与导出一致）。
class InvitePosterCard extends StatefulWidget {
  const InvitePosterCard({super.key, required this.code});
  final String code;

  @override
  State<InvitePosterCard> createState() => _InvitePosterCardState();
}

class _InvitePosterCardState extends State<InvitePosterCard> {
  late final EmoOption _emo = inviteEmoOptions[Random().nextInt(inviteEmoOptions.length)];

  @override
  Widget build(BuildContext context) {
    return PosterCanvas(
      width: 300,
      height: 533,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _ArtworkBand(),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _TitleZone(),
                  const SizedBox(height: 16),
                  const _DualColumns(),
                  const Spacer(),
                  _EmoCopyBlock(mainText: _emo.main, subText: _emo.sub),
                  const Spacer(),
                  _RewardZone(code: widget.code),
                  const SizedBox(height: 8),
                  const _PointsNote(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 顶部图片装饰带：满宽金色风景 + 底部渐变换 + 左上纯文字品牌标。
class _ArtworkBand extends StatelessWidget {
  const _ArtworkBand();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 146,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(invitePosterArtwork, fit: BoxFit.cover),
          // 底部渐变换（surface 羽毛融进下方文字区）——叠加在图片上的过渡遮罩，
          // 属跨风格通用的「叠加视觉」例外，使用品牌 surface 色。
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, PosterPalette.surface],
                stops: [0.42, 1.0],
              ),
            ),
          ),
          const Positioned(
            top: 14,
            left: 16,
            child: _BandBrandmark(),
          ),
        ],
      ),
    );
  }
}

/// 带内品牌标：取景器符号 + LUMIRA（英文衬线）+ 如 画（中文衬线），白色 + 轻投影。
class _BandBrandmark extends StatelessWidget {
  const _BandBrandmark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        // 品牌暖白 → 透明 的从左向右渐变，如墨笔扫过；配金色细边 + 小圆角
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            PosterPalette.surface.withOpacity(.92),
            PosterPalette.surface.withOpacity(0.0),
          ],
        ),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: PosterPalette.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          // 品牌符号标（金色取景器符号，品牌主色）
          LumiraLogo.symbol(size: 15),
          SizedBox(width: 7),
          Text(
            'LUMIRA',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 8,
              letterSpacing: 3,
              color: PosterPalette.goldDeep,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 9),
          Text(
            '如 画',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontFamilyFallback: ['Songti SC', 'SimSun', 'STSong'],
              fontSize: 10,
              letterSpacing: 4,
              color: PosterPalette.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 标题区：衬线大标题（金色强调「亦成作品」），设计稿无 kicker。
class _TitleZone extends StatelessWidget {
  const _TitleZone();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: posterSerif(29, height: 1.22, letterSpacing: 2),
        children: const [
          TextSpan(text: '随手一拍，'),
          TextSpan(text: '亦成作品', style: TextStyle(color: PosterPalette.goldDeep)),
        ],
      ),
      textAlign: TextAlign.left,
    );
  }
}

/// 双栏对开：左侧三痛点，右侧三功能卡（带左分隔线）。
class _DualColumns extends StatelessWidget {
  const _DualColumns();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Expanded(flex: 12, child: _PainsColumn()),
        SizedBox(width: 14),
        Expanded(flex: 10, child: _FeatureCards()),
      ],
    );
  }
}

/// 痛点一对（强调词 / 描述 / 解法小注）。
class _PainEntry {
  const _PainEntry(this.key, this.desc, this.sub, this.index);
  final String key;
  final String desc;
  final String sub;
  final int index;
}

/// 左侧：三大痛点（金色衬线强调词 + 墨色描述 + 灰色解法小注）。
class _PainsColumn extends StatelessWidget {
  const _PainsColumn();

  static const List<_PainEntry> _pains = [
    _PainEntry('调参', '太麻烦', '模板已调好', 0),
    _PainEntry('构图', '不会', '打开即好看', 1),
    _PainEntry('摆姿', '难题', '照着剪影', 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final p in _pains) ...[
          if (p.index > 0) const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: PosterPalette.gold,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: posterPlain(10, color: PosterPalette.ink, height: 1.35, letterSpacing: 1),
                        children: [
                          TextSpan(
                            text: p.key,
                            style: posterSerif(10, color: PosterPalette.goldDeep, height: 1.35),
                          ),
                          TextSpan(text: p.desc),
                        ],
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(p.sub, style: posterPlain(8.5, color: PosterPalette.text3, letterSpacing: .5, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// 功能卡一对（标题 / 描述）。
class _FeatureEntry {
  const _FeatureEntry(this.title, this.sub, this.index);
  final String title;
  final String sub;
  final int index;
}

/// 右侧：三条功能小卡（垂直：衬线标题在上，小字在下，垂直居中）。
class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  static const List<_FeatureEntry> _features = [
    _FeatureEntry('套上模板', '一键出片', 0),
    _FeatureEntry('多款风格', '随手挑', 1),
    _FeatureEntry('剪影跟摆', '照做就行', 2),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: const BoxDecoration(border: Border(left: BorderSide(color: PosterPalette.line))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final f in _features) ...[
            if (f.index > 0) const SizedBox(height: 6),
            SizedBox(
              height: 36,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
                decoration: BoxDecoration(
                  color: PosterPalette.surfaceAlt,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: PosterPalette.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.title,
                        style: posterSerif(10.5, color: PosterPalette.ink, height: 1.2, letterSpacing: .5)),
                    const SizedBox(height: 2),
                    Text(f.sub,
                        style: posterPlain(7, color: PosterPalette.text3, height: 1.4, letterSpacing: .5)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 留白区情绪文案：金线 + 衬线主句（单行）+ 副句。
class _EmoCopyBlock extends StatelessWidget {
  const _EmoCopyBlock({required this.mainText, required this.subText});
  final String mainText;
  final String subText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PosterRule(width: 26, thickness: 1),
        const SizedBox(height: 12),
        Text(
          mainText,
          textAlign: TextAlign.center,
          style: posterSerif(13.5, letterSpacing: .5),
        ),
        const SizedBox(height: 8),
        Text(
          subText,
          textAlign: TextAlign.center,
          style: posterPlain(8.5, color: PosterPalette.text3, height: 1.7, letterSpacing: 1.5),
        ),
      ],
    );
  }
}

/// 奖励 + 二维码区：左「新人礼 +30 积分」，右邀请码 + 二维码（横排）。
class _RewardZone extends StatelessWidget {
  const _RewardZone({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: PosterPalette.line))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _RewardText()),
          const SizedBox(width: 8),
          _CodeAndQr(code: code),
        ],
      ),
    );
  }
}

/// 左侧奖励文案：新人礼 + 金色大号 +30 积分。
class _RewardText extends StatelessWidget {
  const _RewardText();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('新人礼',
            style: TextStyle(
                fontSize: 7, letterSpacing: 3, color: PosterPalette.goldDeep, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('+', style: posterSerifEn(11, color: PosterPalette.goldDeep, weight: FontWeight.w700)),
              Text('30', style: posterSerifEn(24, color: PosterPalette.goldDeep, weight: FontWeight.w700)),
              const SizedBox(width: 5),
              const Text('积分 双方同得',
                  style: TextStyle(
                      fontSize: 8.5, color: PosterPalette.text2, letterSpacing: 1, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

/// 右侧：邀请码（上）+ 长按识别提示（下），再横排二维码。
class _CodeAndQr extends StatelessWidget {
  const _CodeAndQr({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 92),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(code,
                    style: posterSerifEn(11, color: PosterPalette.ink, letterSpacing: 2, weight: FontWeight.w700)),
              ),
              const SizedBox(height: 3),
              const Text('长按识别加入',
                  style: TextStyle(fontSize: 6.5, letterSpacing: 1.5, color: PosterPalette.text3)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        PosterQr(
          data: code,
          size: 52,
          padding: 3,
          radius: 7,
          background: Colors.white,
          borderColor: PosterPalette.line,
        ),
      ],
    );
  }
}

/// 底部积分用途小字。
class _PointsNote extends StatelessWidget {
  const _PointsNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      '积分用于解锁付费模板：双方各 +30，首次绑定邀请码并完拍一张到账',
      textAlign: TextAlign.center,
      style: posterPlain(6.8, color: PosterPalette.text3, height: 1.7, letterSpacing: .5),
    );
  }
}