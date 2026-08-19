import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/network/api_client.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/account_api.dart';

/// 账号保护页
///
/// spec：docs/superpowers/specs/2026-08-19-account-recovery-design.md §5.1
/// 两个区块：
/// 1. 恢复二维码：生成/刷新 → 渲染 QR + 展示恢复码文本（可手动输入，供换机/重装后找回）
/// 2. 绑定邮箱：输入邮箱 → 发送验证码 → 6 位绑定，换机时用邮箱找回
class AccountProtectionPage extends ConsumerStatefulWidget {
  const AccountProtectionPage({super.key});

  @override
  ConsumerState<AccountProtectionPage> createState() => _AccountProtectionPageState();
}

class _AccountProtectionPageState extends ConsumerState<AccountProtectionPage> {
  static const _secretStyle = TextStyle(
    fontFamily: 'Courier New',
    fontSize: 12,
  );

  RecoveryQrData? _qr;
  bool _qrLoading = false;
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _bindLoading = false;
  String? _emailMsg;
  AccountApi? _api;

  @override
  void initState() {
    super.initState();
    // apiClientProvider 是 FutureProvider，异步取一次组装
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      if (mounted) setState(() => _api = api);
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() => _qrLoading = false);
        LumiraToast.show(context, '生成失败：$e');
      }
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      await (await _resolveApi()).sendCode(email: email, purpose: 'bind');
      if (mounted) setState(() => _emailMsg = '验证码已发送（10 分钟内有效）');
    } catch (e) {
      if (mounted) setState(() => _emailMsg = '发送失败：$e');
    }
  }

  Future<void> _bind() async {
    setState(() => _bindLoading = true);
    try {
      await (await _resolveApi()).bindEmail(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _bindLoading = false;
          _emailMsg = '绑定成功';
        });
        LumiraToast.show(context, '邮箱绑定成功');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bindLoading = false;
          _emailMsg = '绑定失败：$e';
        });
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
        title: '账号保护',
        transparent: true,
        leading: _BackButton(tokens: tokens),
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
              Text(
                '把恢复二维码保存到安全处。换机或重装后，在新设备「恢复账号」即可取回本账号全部数据。',
                style: TextStyle(fontSize: 13, color: tokens.textTertiary),
              ),
              const SizedBox(height: 16),
              // 区块一：恢复二维码
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '恢复二维码',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _qrLoading ? null : _generateQr,
                          child: Text(_qr == null ? '生成二维码' : '刷新二维码'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_qrLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_qr != null) ...[
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
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
                      Text(
                        '恢复码（可手动输入）',
                        style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _qr!.secret,
                              style: _secretStyle.copyWith(color: tokens.textPrimary),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy, size: 18),
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
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 区块二：绑定邮箱
              _GroupTitle(text: '绑定邮箱', tokens: tokens),
              const SizedBox(height: 8),
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: '邮箱',
                        hintText: '用于换机时找回账号',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _codeCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            decoration: const InputDecoration(labelText: '6 位验证码'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _bindLoading ? null : _sendCode,
                          child: const Text('发送验证码'),
                        ),
                      ],
                    ),
                    if (_emailMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _emailMsg!,
                          style: TextStyle(fontSize: 12, color: tokens.brand),
                        ),
                      ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _bindLoading ? null : _bind,
                      child: const Text('绑定邮箱'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: () =>
                      GoRouter.of(context).push(RouteNames.accountRecover),
                  child: const Text(
                    '在新设备上恢复账号',
                    style: TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.profile);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.arrow_back_ios_new, size: 20, color: tokens.textPrimary),
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle({required this.text, required this.tokens});
  final String text;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: tokens.textTertiary,
          letterSpacing: 0.04 * 13,
        ),
      ),
    );
  }
}