import 'package:flutter/material.dart';

import '../../../shared/widgets/poster/poster_common.dart';

// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

/// 邀请卡片分享海报（3:4 固定品牌，与模板/照片等分享海报同一语言）。
///
/// 与其它分享海报一致：固定 LUMIRA 品牌色板（[PosterPalette]），不随 App
/// 主题/UI 风格切换；二维码为 [PosterQr] 真编码 6 位邀请码，扫码即可被
/// 首页「扫一扫」识别为邀请码。导出经 [PosterGenerator] 捕获 300×400（3:4）。
class InvitePosterCard extends StatelessWidget {
  const InvitePosterCard({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return PosterCanvas(
      width: 300,
      height: 400,
      padding: EdgeInsets.fromLTRB(22, 22, 22, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PosterBrandRow(logoSize: 15),
          const Spacer(),
          const _KickerRule(),
          const SizedBox(height: 9),
          const PosterTitle(
            text: '随手拍，亦成作品',
            size: 26,
            height: 1.12,
            letterSpacing: 2,
            align: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '一套模板 · 一键出片',
            textAlign: TextAlign.center,
            style: posterPlain(12, color: PosterPalette.text2, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          const PosterDivider(),
          const SizedBox(height: 11),
          const _RewardBlock(),
          const Spacer(),
          _QrZone(code: code),
          const SizedBox(height: 13),
          _CodeBlock(code: code),
          const Spacer(),
          const PosterBrandFoot(borderTop: true, paddingTop: 8),
        ],
      ),
    );
  }
}

/// 金色发丝线 + kicker（两侧短线夹居中字），品牌式小标题。
class _KickerRule extends StatelessWidget {
  const _KickerRule();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        PosterRule(width: 16, thickness: 1),
        SizedBox(width: 8),
        PosterKicker(text: '邀请好友 · 一起出片', size: 9, letterSpacing: 3),
        SizedBox(width: 8),
        PosterRule(width: 16, thickness: 1),
      ],
    );
  }
}

/// 邀请奖励一句：主次两行，克制可读。
class _RewardBlock extends StatelessWidget {
  const _RewardBlock();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '加入即得 · 双份新手礼',
          textAlign: TextAlign.center,
          style: posterPlain(12, color: PosterPalette.goldDeep, weight: FontWeight.w700, letterSpacing: 1),
        ),
        const SizedBox(height: 3),
        Text(
          '双方各得 +30 积分 · 免费解锁付费模板',
          textAlign: TextAlign.center,
          style: posterPlain(9, color: PosterPalette.text3, letterSpacing: 0.5),
        ),
      ],
    );
  }
}

/// 真二维码 + 提示文案（居中）。
class _QrZone extends StatelessWidget {
  const _QrZone({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PosterQr(
          data: code,
          size: 124,
          padding: 7,
          radius: 12,
          borderColor: PosterPalette.line,
        ),
        const SizedBox(height: 10),
        Text(
          '长按识别 · 扫码领双份新手礼',
          textAlign: TextAlign.center,
          style: posterPlain(10, color: PosterPalette.text3, letterSpacing: 1),
        ),
      ],
    );
  }
}

/// 邀请码块：暖白纸底 + 金色细边，衬线大字展示邀请码。
class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 18),
      decoration: BoxDecoration(
        color: PosterPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: PosterPalette.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '我的邀请码',
            style: posterPlain(8, color: PosterPalette.text3, letterSpacing: 3),
          ),
          const SizedBox(height: 4),
          Text(
            code,
            textAlign: TextAlign.center,
            style: posterSerif(20, letterSpacing: 3),
          ),
        ],
      ),
    );
  }
}