import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 复制邀请码：写入系统剪贴板并 toast 反馈。
Future<void> showInviteCopyToast(BuildContext context, String code) async {
  await Clipboard.setData(ClipboardData(text: code));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('邀请码已复制：$code'), duration: const Duration(seconds: 1)),
    );
  }
}

/// 复制测试夹具（避免直接打开 bottom sheet）。
class InviteCardScene extends StatelessWidget {
  const InviteCardScene({super.key, required this.code, required this.onCopy});
  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onCopy,
      behavior: HitTestBehavior.opaque,
      child: Container(color: Colors.white, alignment: Alignment.center, child: const Text('邀请卡片场景')),
    );
  }
}