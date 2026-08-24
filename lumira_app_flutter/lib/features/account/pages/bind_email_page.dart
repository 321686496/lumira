import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/account_api.dart';
import '../widgets/account_common.dart';

/// 绑定邮箱页
///
/// 绑定邮箱作为备用找回方式：换机/重装时，可用「已绑定邮箱 + 验证码」找回账号。
/// 顶部展示当前绑定状态（已绑定则显示脱敏邮箱并可重新绑定；未绑定则提示），
/// 下方为绑定表单（输入邮箱 → 发送验证码 → 6 位 → 绑定）。
class BindEmailPage extends ConsumerStatefulWidget {
  const BindEmailPage({super.key});

  @override
  ConsumerState<BindEmailPage> createState() => _BindEmailPageState();
}

class _BindEmailPageState extends ConsumerState<BindEmailPage> {
  AccountApi? _api;
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _bindLoading = false;
  String? _emailMsg;

  AccountStatus? _status;
  bool _statusLoading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final api = AccountApi(await ref.read(apiClientProvider.future));
      if (!mounted) return;
      setState(() => _api = api);
      await _loadStatus(api);
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

  Future<void> _loadStatus(AccountApi api) async {
    setState(() => _statusLoading = true);
    try {
      final status = await api.getStatus();
      if (mounted) {
        setState(() {
          _status = status;
          _statusLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusLoading = false;
          _emailMsg = '获取绑定状态失败：$e';
        });
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
        final api = await _resolveApi();
        setState(() {
          _bindLoading = false;
          _emailMsg = '绑定成功';
        });
        await _loadStatus(api);
        if (mounted) LumiraToast.show(context, '邮箱绑定成功');
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

  /// 邮箱脱敏显示：abc@xx.com → a**@xx.com
  String _maskEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 1) return email;
    final local = email.substring(0, at);
    final domain = email.substring(at);
    final head = local.substring(0, 1);
    return '$head${''.padLeft(local.length - 1, '*')}$domain';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final boundEmail = _status?.email;
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '绑定邮箱',
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
                icon: Icons.mark_email_unread_outlined,
                title: '为什么绑定邮箱？',
                steps: [
                  '输入邮箱并完成验证，换机时即可用它找回账号',
                  '换机/重装后，在「找回账号」选择邮箱找回',
                  '输入已绑定邮箱 + 验证码，即可取回全部数据',
                ],
                description: '与恢复二维码互为备份，推荐两者都设置一份，更加稳妥。',
                tip: '请使用您常用且能正常收发邮件的邮箱。一个邮箱只能绑定一个账号。',
              ),
              const SizedBox(height: 20),
              // 绑定状态卡片
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: _buildStatusRow(tokens, boundEmail),
              ),
              const SizedBox(height: 20),
              // 绑定表单
              NeuCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      boundEmail != null ? '重新绑定' : '绑定邮箱',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LumiraTextField(
                      controller: _emailCtrl,
                      labelText: '邮箱',
                      hintText: '用于换机时找回账号',
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
                            onPressed: _bindLoading ? null : _sendCode,
                            child: const Text('发送验证码'),
                          ),
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
                    const SizedBox(height: 10),
                    LumiraButton(
                      variant: ButtonVariant.primary,
                      onPressed: _bindLoading ? null : _bind,
                      child: Text(boundEmail != null ? '重新绑定' : '绑定邮箱'),
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

  Widget _buildStatusRow(ThemeTokens tokens, String? boundEmail) {
    if (_statusLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(tokens.brand),
          ),
        ),
      );
    }
    // 已绑定
    if (boundEmail != null && boundEmail.isNotEmpty) {
      return Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: tokens.successSubtle,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.verified_outlined, size: 20, color: tokens.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '当前已绑定邮箱',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: tokens.successSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已绑定',
                        style: TextStyle(fontSize: 10, color: tokens.success, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _maskEmail(boundEmail),
                  style: TextStyle(fontSize: 14, color: tokens.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  '换机时可用该邮箱 + 验证码找回账号',
                  style: TextStyle(fontSize: 12, color: tokens.textTertiary),
                ),
              ],
            ),
          ),
        ],
      );
    }
    // 未绑定
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tokens.brandSubtle,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.mark_email_unread_outlined, size: 20, color: tokens.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '当前未绑定邮箱',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tokens.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                '在下方输入邮箱并完成绑定，换机时即可用来找回账号。',
                style: TextStyle(fontSize: 12, height: 1.4, color: tokens.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}