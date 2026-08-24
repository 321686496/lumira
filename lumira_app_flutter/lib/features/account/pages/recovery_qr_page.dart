import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/account_api.dart';
import '../widgets/account_common.dart';

/// 恢复二维码页（备份恢复凭证）
///
/// 在本设备生成并保存「恢复二维码 + 恢复码」。换机/重装后，到「找回账号」
/// 扫码或手动输入恢复码即可取回本账号数据。
/// 生成即代表轮换：旧恢复码立刻作废，请务必保存好最新一份。
class RecoveryQrPage extends ConsumerStatefulWidget {
  const RecoveryQrPage({super.key});

  @override
  ConsumerState<RecoveryQrPage> createState() => _RecoveryQrPageState();
}

class _RecoveryQrPageState extends ConsumerState<RecoveryQrPage> {
  static const _secretStyle = TextStyle(
    fontFamily: 'Courier New',
    fontSize: 12,
  );

  RecoveryQrData? _qr;
  bool _qrLoading = false;
  AccountApi? _api;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      if (mounted) setState(() => _api = api);
    });
  }

  Future<AccountApi> _resolveApi() async =>
      _api ?? AccountApi(await ref.read(apiClientProvider.future));

  Future<void> _generateQr() async {
    setState(() {
      _qrLoading = true;
      _qr = null;
    });
    try {
      final qr = await (await _resolveApi()).rotateRecoverySecret();
      if (mounted) {
        setState(() {
          _qr = qr;
          _qrLoading = false;
        });
        LumiraToast.show(context, '恢复凭证已生成，请妥善保存');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _qrLoading = false);
        LumiraToast.show(context, '生成失败：$e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '恢复二维码',
        transparent: true,
        leading: AccountBackButton(tokens: tokens),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -0.6),
            radius: 1.2,
            colors: [
              tokens.brandSubtle.withOpacity(0.35),
              tokens.canvas.withOpacity(0.0),
            ],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              // 用途 + 使用教程
              const AccountGuideCard(
                icon: Icons.qr_code_2_outlined,
                title: '为什么需要恢复二维码？',
                steps: [
                  '在本页生成二维码并保存，最好截图存到安全的地方',
                  '换手机或重装应用后，打开「找回账号」',
                  '扫描保存的二维码，或手动输入下面的恢复码',
                ],
                description: '即可在新设备上取回本账号的全部数据。',
                tip: '恢复码有效期为 30 天；每次重新生成，旧的恢复码都会立即失效。请勿把恢复码泄露给他人。',
              ),
              const SizedBox(height: 20),
              // 凭证卡片
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '恢复凭证',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _qrLoading ? null : _generateQr,
                          style: TextButton.styleFrom(
                            foregroundColor: tokens.brandText,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          child: Text(_qr == null ? '生成二维码' : '重新生成'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_qrLoading)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(tokens.brand),
                          ),
                        ),
                      )
                    else if (_qr != null) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            // 二维码需浅色底以保证扫码识别，属功能需要
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: QrImageView(
                            data: _qr!.qrPayload,
                            size: 200,
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            '恢复码（可手动输入）',
                            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                          ),
                          const Spacer(),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.copy, size: 18, color: tokens.brand),
                            onPressed: () async {
                              await Clipboard.setData(
                                  ClipboardData(text: _qr!.secret));
                              if (mounted) {
                                LumiraToast.show(context, '已复制恢复码');
                              }
                            },
                          ),
                        ],
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: tokens.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SelectableText(
                          _qr!.secret,
                          style: _secretStyle.copyWith(color: tokens.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}