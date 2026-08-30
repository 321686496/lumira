import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../shared/services/poster_generator.dart';
import 'invite_card_scene.dart';
import 'invite_poster_card.dart';

/// 打开邀请卡片分享海报底部弹层。
///
/// 复用 [PosterGenerator.showPoster] 的捕获/保存/分享能力；底部操作条最前
/// 插入「复制邀请码」按钮。卡片内容为 [InvitePosterCard]（跟随当前 UI 风格）。
Future<void> showInvitePosterSheet({
  required BuildContext context,
  required String code,
  required ThemeTokens tokens,
}) async {
  // 卡片级捕获键：导入导出分享严格 3:4（1080×1440）的卡片本体，
  // 而非整页预览容器（外层 posterKey 自持，二者为不同 GlobalKey 实例）。
  final plainContentKey = GlobalKey();
  await PosterGenerator.showPoster(
    context: context,
    tokens: tokens,
    title: '邀请卡片',
    content: InvitePosterCard(code: code),
    posterKey: GlobalKey(),
    plainContentKey: plainContentKey,
    shareSubject: '如画 LUMIRA · 邀请好友',
    shareText: '一起拍照，把生活拍成想要的样子',
    fileNamePrefix: 'lumira_invite',
    extraAction: _CopyAction(code: code, tokens: tokens),
  );
}

/// 复制邀请码操作按钮（紧邻保存/分享）。
class _CopyAction extends StatelessWidget {
  const _CopyAction({required this.code, required this.tokens});
  final String code;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showInviteCopyToast(context, code),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.copy_rounded, size: 16, color: tokens.brandText),
            const SizedBox(width: 5),
            Text(
              '复制邀请码',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.brandText),
            ),
          ],
        ),
      ),
    );
  }
}