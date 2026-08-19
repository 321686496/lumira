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
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/account_api.dart';

/// 恢复账号页（新设备找回旧账号数据）
///
/// spec：docs/superpowers/specs/2026-08-19-account-recovery-design.md §5.2
/// 两个 Tab：
/// 1. 扫码/恢复码：扫描「账号保护」页的恢复二维码或用恢复码字符串手动找回
/// 2. 邮箱：输入已绑定邮箱 → 发送验证码 → 6 位找回
/// 成功 → 拿到旧 deviceId → AuthController.recoverAccount → 旧数据恢复。
class RecoverAccountPage extends ConsumerStatefulWidget {
  const RecoverAccountPage({super.key});

  @override
  ConsumerState<RecoverAccountPage> createState() => _RecoverAccountPageState();
}

class _RecoverAccountPageState extends ConsumerState<RecoverAccountPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  AccountApi? _api;
  final _secretCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      if (mounted) setState(() => _api = api);
    });
  }

  @override
  void dispose() {
    _tab.dispose();
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('已恢复旧账号数据')));
      GoRouter.of(context).go(RouteNames.home);
    } else {
      setState(() => _msg = '恢复失败，请重试');
    }
  }

  Future<void> _recoverByQr() async {
    final secret = _secretCtrl.text.trim();
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
      if (mounted) {
        setState(() => _msg = '验证码已发送');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _msg = '发送失败：$e');
      }
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
      await _recoverByQr();
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
        title: '恢复账号',
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
          child: Column(
            children: [
              TabBar(
                controller: _tab,
                tabs: const [Tab(text: '扫码/恢复码'), Tab(text: '邮箱')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    // Tab 1：扫码 / 手动恢复码
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        OutlinedButton.icon(
                          onPressed: _busy ? null : _scan,
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('扫描恢复二维码'),
                        ),
                        const SizedBox(height: 20),
                        _GroupTitle(text: '手动输入恢复码', tokens: tokens),
                        const SizedBox(height: 8),
                        NeuCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _secretCtrl,
                                decoration: const InputDecoration(
                                  labelText: '恢复码',
                                  hintText: '在「账号保护」页生成的字符串',
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _busy ? null : _recoverByQr,
                                child: const Text('恢复'),
                              ),
                            ],
                          ),
                        ),
                        if (_msg != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _msg!,
                              style: TextStyle(color: tokens.brand),
                            ),
                          ),
                      ],
                    ),
                    // Tab 2：邮箱找回
                    ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(labelText: '已绑定邮箱'),
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
                              onPressed: _busy ? null : _sendRecoverCode,
                              child: const Text('发送验证码'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _busy ? null : _recoverByEmail,
                          child: const Text('通过邮箱找回'),
                        ),
                        if (_msg != null)
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _msg!,
                              style: TextStyle(color: tokens.brand),
                            ),
                          ),
                      ],
                    ),
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