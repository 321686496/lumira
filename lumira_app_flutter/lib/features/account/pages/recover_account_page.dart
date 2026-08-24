import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/account_api.dart';
import '../widgets/account_common.dart';

/// 恢复账号页（新设备找回旧账号数据）
///
/// 页内提供两种找回方式（不再用 TabBar）：扫码/恢复码、邮箱。
/// - 扫码/恢复码：扫描旧设备「恢复二维码」页保存的二维码，或手动输入恢复码
/// - 邮箱：输入已绑定邮箱 → 发送验证码 → 6 位找回
///
/// 顶部给出清晰的使用说明；成功 → 拿到旧 deviceId → AuthController.recoverAccount。
enum _RecoverMethod { qrCode, email }

class RecoverAccountPage extends ConsumerStatefulWidget {
  const RecoverAccountPage({super.key});

  @override
  ConsumerState<RecoverAccountPage> createState() => _RecoverAccountPageState();
}

class _RecoverAccountPageState extends ConsumerState<RecoverAccountPage> {
  _RecoverMethod _method = _RecoverMethod.qrCode;
  AccountApi? _api;
  final _secretCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      if (mounted) setState(() => _api = api);
    });
  }

  @override
  void dispose() {
    _secretCtrl.dispose();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<AccountApi> _resolveApi() async =>
      _api ?? AccountApi(await ref.read(apiClientProvider.future));

  /// 以旧 deviceId 为身份注册，成功后回到首页。
  Future<void> _recover(String deviceId) async {
    final ok = await ref.read(authControllerProvider.notifier).recoverAccount(deviceId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      LumiraToast.show(context, '已恢复旧账号数据');
      GoRouter.of(context).go(RouteNames.home);
    } else {
      setState(() => _msg = '恢复失败，请重试');
    }
  }

  Future<void> _recoverByQr([String? presetSecret]) async {
    final secret = presetSecret ?? _secretCtrl.text.trim();
    if (secret.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await (await _resolveApi()).recoverByQr(secret);
      await _recover(r.deviceId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = '恢复失败：$e';
        });
      }
    }
  }

  Future<void> _sendRecoverCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    try {
      await (await _resolveApi()).sendCode(email: email, purpose: 'recover');
      if (mounted) setState(() => _msg = '验证码已发送（10 分钟内有效）');
    } catch (e) {
      if (mounted) setState(() => _msg = '发送失败：$e');
    }
  }

  Future<void> _recoverByEmail() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await (await _resolveApi()).recoverByEmail(
        email: _emailCtrl.text.trim(),
        code: _codeCtrl.text.trim(),
      );
      await _recover(r.deviceId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _msg = '恢复失败：$e';
        });
      }
    }
  }

  Future<void> _scan() async {
    final secret = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => const _ScannerPage(),
    ));
    if (!mounted || secret == null) return;
    final parsed = secret.isNotEmpty ? _extractSecret(secret) : '';
    if (parsed.isNotEmpty) {
      _secretCtrl.text = parsed;
      await _recoverByQr(parsed);
    } else {
      setState(() => _msg = '二维码格式不对，请手动输入恢复码');
    }
  }

  String _extractSecret(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri != null &&
        uri.host == 'account-recover' &&
        uri.queryParameters['secret'] != null) {
      return uri.queryParameters['secret']!;
    }
    return raw; // 允许直接粘贴恢复码
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '找回账号',
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
              // 用途 + 使用步骤
              const AccountGuideCard(
                icon: Icons.settings_backup_restore_outlined,
                title: '在新设备上找回账号',
                steps: [
                  '选择一种找回方式（二维码/恢复码 或 邮箱）',
                  '输入旧设备上保存的恢复码，或已绑定邮箱的验证码',
                  '找回成功后，旧账号数据会自动同步到当前设备',
                ],
                description: '需要先在旧设备的「账号保护」里做好备份（生成恢复二维码或绑定邮箱）。',
              ),
              const SizedBox(height: 20),
              // 方式一：扫码 / 恢复码
              _MethodCard(
                icon: Icons.qr_code_2_outlined,
                title: '扫码 / 恢复码',
                subtitle: '扫描旧设备保存的二维码，或手动输入恢复码',
                selected: _method == _RecoverMethod.qrCode,
                onTap: () => setState(() {
                  _method = _RecoverMethod.qrCode;
                  _msg = null;
                }),
                tokens: tokens,
                expanded: _method == _RecoverMethod.qrCode,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_method == _RecoverMethod.qrCode)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          LumiraButton(
                            variant: ButtonVariant.secondary,
                            onPressed: _busy ? null : _scan,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.qr_code_scanner),
                                SizedBox(width: 8),
                                Text('扫描恢复二维码'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          LumiraTextField(
                            controller: _secretCtrl,
                            labelText: '恢复码',
                            hintText: '在「恢复二维码」页生成的字符串',
                          ),
                          const SizedBox(height: 12),
                          LumiraButton(
                            variant: ButtonVariant.primary,
                            onPressed: _busy ? null : _recoverByQr,
                            child: const Text('用恢复码找回'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 方式二：邮箱
              _MethodCard(
                icon: Icons.mark_email_unread_outlined,
                title: '邮箱找回',
                subtitle: '输入已绑定邮箱 + 验证码',
                selected: _method == _RecoverMethod.email,
                onTap: () => setState(() {
                  _method = _RecoverMethod.email;
                  _msg = null;
                }),
                tokens: tokens,
                expanded: _method == _RecoverMethod.email,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_method == _RecoverMethod.email) ...[
                      LumiraTextField(
                        controller: _emailCtrl,
                        labelText: '已绑定邮箱',
                        hintText: '换机前绑定过的邮箱',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: LumiraTextField(
                              controller: _codeCtrl,
                              labelText: '6 位验证码',
                              hintText: '发送到上述邮箱',
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: LumiraButton(
                              variant: ButtonVariant.ghost,
                              onPressed: _busy ? null : _sendRecoverCode,
                              child: const Text('发送验证码'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LumiraButton(
                        variant: ButtonVariant.primary,
                        onPressed: _busy ? null : _recoverByEmail,
                        child: const Text('通过邮箱找回'),
                      ),
                    ],
                  ],
                ),
              ),
              if (_msg != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _msg!,
                    style: TextStyle(fontSize: 13, color: tokens.brand),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 找回方式选择卡片：选中态高亮 + 展开表单
class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    required this.tokens,
    required this.expanded,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final ThemeTokens tokens;
  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected ? tokens.brand : tokens.brandSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: selected ? tokens.textInverse : tokens.brand),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                size: 20,
                color: selected ? tokens.brand : tokens.textTertiary,
              ),
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 4),
            const Divider(height: 20),
            child,
          ],
        ],
      ),
    );
  }
}

/// 全屏扫描恢复二维码子页，解析成功后把原始结果回传给父页。
class _ScannerPage extends StatefulWidget {
  const _ScannerPage();

  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  final _key = GlobalKey();
  QRViewController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('扫描恢复二维码')),
      body: QRView(
        key: _key,
        overlay: QrScannerOverlayShape(
          overlayColor: Colors.black26,
          borderColor: Theme.of(context).colorScheme.primary,
        ),
        onQRViewCreated: (c) {
          _controller = c;
          c.scannedDataStream.listen((barcode) {
            final code = barcode.code;
            if (code != null && code.isNotEmpty) {
              Navigator.of(context).pop(code);
            }
          });
        },
      ),
    );
  }
}