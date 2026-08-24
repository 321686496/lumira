import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart' as lumira;
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../points/data/points_repository.dart';
import '../../points/widgets/points_earn_ways.dart';
import '../../redeem/data/redeem_repository.dart';
import '../../redeem/data/redeem_models.dart';
import '../data/owned_templates_repository.dart';
import '../data/templates_browse_mock_data.dart';
import '../widgets/template_cover_image.dart';

/// 解锁模板页
///
/// 视觉规格来源：lumira-app/src/pages/templates/unlock.vue (585 行)
/// 6 个 section（根据 `_unlocked` 状态切换）：
/// 1. PreviewCard（始终显示）
/// 2. SubtitleWrap（锁定态）
/// 3. OptionsList 5 个解锁选项（锁定态）
/// 4. BottomNote（锁定态）
/// 5. SuccessCard（解锁态）
/// 6. PayPopup（showLumiraDialog，购买时弹出）
class TemplatesUnlockPage extends ConsumerStatefulWidget {
  const TemplatesUnlockPage({super.key, this.templateId, this.price});

  /// 路由参数：模板 id
  final String? templateId;

  /// 路由参数：积分价格（由详情页传入，内置模板用）
  final int? price;

  @override
  ConsumerState<TemplatesUnlockPage> createState() =>
      _TemplatesUnlockPageState();
}

class _TemplatesUnlockPageState extends ConsumerState<TemplatesUnlockPage> {
  bool _unlocked = false;

  /// 购买请求进行中标记：防重入（仅方法内串行保护，不参与 UI 渲染）
  bool _purchasing = false;

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  void _onShare() {
    // 分享给好友 → 跳转邀请有礼页，通过邀请获取积分 / 兑换模板
    GoRouter.of(context).push(RouteNames.profileInvite);
  }

  Future<void> _onInputCode() async {
    final controller = TextEditingController();
    final code = await lumira.showLumiraDialog<String>(
      context: context,
      builder: (ctx) => lumira.LumiraAlertDialog(
        title: const Text('输入兑换码'),
        content: lumira.LumiraTextField(
          controller: controller,
          hintText: '请输入兑换码',
        ),
        actions: [
          lumira.LumiraButton(
            variant: ButtonVariant.ghost,
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          lumira.LumiraButton(
            variant: ButtonVariant.primary,
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    if (!mounted) return;
    try {
      final repo = await ref.read(redeemRepositoryProvider.future);
      final resp = await repo.redeem(RedeemCodeRequest(code: code));
      if (!mounted) return;
      lumira.LumiraToast.show(
        context,
        '兑换成功：${resp.campaignName}，获得 ${resp.rewardPoints} 积分，余额 ${resp.balance}',
      );
      // 兑换码发的是积分，不直接解锁模板，刷新 owned 列表后让用户用积分兑换
      ref.invalidate(ownedTemplatesLoaderProvider);
    } catch (e) {
      if (!mounted) return;
      lumira.LumiraToast.show(context, '兑换失败：$e');
    }
  }

  Future<void> _onPurchase() async {
    if (_purchasing) return; // 防重入：请求进行中忽略重复点击
    _purchasing = true;
    try {
      final templateId = widget.templateId;
      final price = widget.price;
      if (templateId == null || templateId.isEmpty) {
        lumira.LumiraToast.show(context, '缺少模板信息');
        return;
      }
      if (price == null || price < 1) {
        lumira.LumiraToast.show(context, '缺少模板积分价格');
        return;
      }

      // 预检余额：不足时直接弹「积分不足 + 获取积分方式」弹窗，不进入确认弹窗
      final balance = await _fetchBalance();
      if (balance != null && balance < price) {
        await _showInsufficientCreditsDialog(price: price, balance: balance);
        return;
      }
      if (!mounted) return;

      final confirmed = await lumira.showLumiraDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => _PayPopupContent(
          price: price,
          onCancel: () => Navigator.pop(context, false),
          onConfirm: () => Navigator.pop(context, true),
        ),
      );
      if (confirmed != true) return;
      if (!mounted) return;
      final repo = await ref.read(ownedTemplatesRepositoryProvider.future);
      final result = await repo.exchange(templateId, priceCredits: price);
      if (!mounted) return;
      // 刷新 owned 缓存
      ref.invalidate(ownedTemplatesLoaderProvider);
      setState(() => _unlocked = true);
      lumira.LumiraToast.show(
        context,
        '解锁成功！消耗 ${result.spentCredits} 积分，余额 ${result.balance}',
      );
    } catch (e) {
      if (!mounted) return;
      // 服务端兜底：余额不足（预检后并发扣减等竞态）同样弹积分不足弹窗
      if (_isInsufficientCreditsError(e)) {
        await _showInsufficientCreditsDialog(price: widget.price ?? 0);
      } else {
        lumira.LumiraToast.show(context, '兑换失败：$e');
      }
    } finally {
      _purchasing = false;
    }
  }

  /// 拉取当前积分余额；失败返回 null（不阻塞购买流程，交由 exchange 兜底报错）。
  Future<int?> _fetchBalance() async {
    try {
      final repo = await ref.read(pointsRepositoryProvider.future);
      final b = await repo.getBalance();
      return b.balance;
    } catch (_) {
      return null;
    }
  }

  /// 判断是否为「积分不足」错误（后端返回 400 + Insufficient points balance）。
  bool _isInsufficientCreditsError(Object e) {
    if (e is ApiException) {
      final msg = e.message.toLowerCase();
      return msg.contains('insufficient') || msg.contains('余额不足');
    }
    return false;
  }

  /// 弹出「积分不足」弹窗：告知当前余额不足 + 列出获取积分方式。
  /// 点击「去赚积分」跳转积分钱包页（该页含获取积分/签到/邀请入口）。
  Future<void> _showInsufficientCreditsDialog({
    required int price,
    int? balance,
  }) async {
    final goWallet = await lumira.showLumiraDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _InsufficientCreditsContent(
        price: price,
        balance: balance,
        onCancel: () => Navigator.pop(ctx, false),
        onGoWallet: () => Navigator.pop(ctx, true),
      ),
    );
    if (goWallet == true && mounted) {
      GoRouter.of(context).push(RouteNames.pointsWallet);
    }
  }

  void _onStartUse() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    // 使用真实模板封面（本地资源），替代原 picsum 网络占位图
    final cover = widget.templateId == null
        ? null
        : TemplatesBrowseMockData.findDetailById(widget.templateId!)?.cover;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                LumiraNav(
                  title: '解锁模板',
                  transparent: true,
                  leading: _CloseButton(tokens: tokens, onTap: _back),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                    child: _unlocked
                        ? _SuccessCard(
                            tokens: tokens,
                            onStartUse: _onStartUse,
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _PreviewCard(
                                tokens: tokens,
                                unlocked: _unlocked,
                                cover: cover,
                              ),
                              _SubtitleWrap(tokens: tokens),
                              _OptionsList(
                                tokens: tokens,
                                price: widget.price,
                                onShare: _onShare,
                                onInputCode: _onInputCode,
                                onPurchase: _onPurchase,
                              ),
                              _BottomNote(tokens: tokens),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.6, -0.8),
              radius: 1.4,
              colors: [
                tokens.brandSubtle.withOpacity(0.45),
                tokens.canvas.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.tokens, required this.onTap});
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.close,
          size: 22,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

class _PreviewCard extends ConsumerWidget {
  const _PreviewCard({
    required this.tokens,
    required this.unlocked,
    this.cover,
  });
  final ThemeTokens tokens;
  final bool unlocked;
  final String? cover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return FadeUp(
      child: Container(
        decoration: BoxDecoration(
          // neumorphic 风格下：tokens.canvas 改为 tokens.surface，移除 border
          color: isNeumorphic ? tokens.surface : tokens.canvas,
          borderRadius: BorderRadius.circular(14),
          border: isNeumorphic
              ? null
              : Border.all(color: tokens.divider, width: 1),
          boxShadow: tokens.shadowConvex,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TemplateCoverImage(
                    cover: cover,
                    fit: BoxFit.cover,
                    fallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.image_outlined,
                        size: 40,
                        color: tokens.textTertiary,
                      ),
                    ),
                    errorFallback: Container(
                      color: tokens.surfaceAlt,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        // 硬编码颜色，与 uni-app 一致 (rgba(26,26,26,0.6))
                        color: unlocked
                            ? tokens.success
                            : const Color.fromRGBO(26, 26, 26, 0.6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        unlocked ? Icons.lock_open : Icons.lock,
                        size: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: tokens.brand),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          '日系胶片 · 精选模板',
                          style: TextStyle(
                            fontFamily: 'Noto Serif SC',
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: tokens.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '包含 12 级胶片颗粒 · 暖调偏移 · 柔光晕影',
                    style: TextStyle(
                      fontSize: 13,
                      color: tokens.textTertiary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _PreviewTag.gold(tokens: tokens, label: '胶片'),
                      _PreviewTag.green(tokens: tokens, label: '日系'),
                      _PreviewTag.neutral(tokens: tokens, label: '人像'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewTag extends StatelessWidget {
  const _PreviewTag._({
    required this.tokens,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  factory _PreviewTag.gold({
    required ThemeTokens tokens,
    required String label,
  }) {
    return _PreviewTag._(
      tokens: tokens,
      label: label,
      backgroundColor: tokens.brandSubtle,
      textColor: tokens.brandText,
    );
  }

  factory _PreviewTag.green({
    required ThemeTokens tokens,
    required String label,
  }) {
    return _PreviewTag._(
      tokens: tokens,
      label: label,
      backgroundColor: tokens.successSubtle,
      textColor: tokens.success,
    );
  }

  factory _PreviewTag.neutral({
    required ThemeTokens tokens,
    required String label,
  }) {
    return _PreviewTag._(
      tokens: tokens,
      label: label,
      backgroundColor: tokens.surfaceAlt,
      textColor: tokens.textSecondary,
    );
  }

  final ThemeTokens tokens;
  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: textColor,
        ),
      ),
    );
  }
}

class _SubtitleWrap extends StatelessWidget {
  const _SubtitleWrap({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Text(
              '解锁方式任选其一',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '完成任意一项即可永久解锁',
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  const _OptionsList({
    required this.tokens,
    required this.price,
    required this.onShare,
    required this.onInputCode,
    required this.onPurchase,
  });

  final ThemeTokens tokens;
  final int? price;
  final VoidCallback onShare;
  final Future<void> Function() onInputCode;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FadeUp(
          delay: const Duration(milliseconds: 80),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.star, // Flutter 3.7.12 无 Icons.diamond_outlined，用 Icons.star 替代
            iconBgColor: tokens.brandSubtle,
            iconColor: tokens.brand,
            title: '${price ?? 0} 积分解锁',
            desc: '消耗积分，永久使用',
            titleStrong: true,
            brandBorder: true,
            button: _SmallBrandButton(
              tokens: tokens,
              label: '积分购买',
              onTap: onPurchase,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeUp(
          delay: const Duration(milliseconds: 160),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.vpn_key_outlined,
            iconBgColor: tokens.surfaceAlt,
            iconColor: tokens.brand,
            title: '输入兑换码',
            desc: '使用兑换码直接解锁模板',
            button: _SmallOutlineButton(
              tokens: tokens,
              label: '输入',
              onTap: onInputCode,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FadeUp(
          delay: const Duration(milliseconds: 240),
          child: _OptionCard(
            tokens: tokens,
            icon: Icons.send_outlined,
            iconBgColor: tokens.surfaceAlt,
            iconColor: tokens.brand,
            title: '分享给好友',
            desc: '邀请好友赚积分 / 兑换模板',
            button: _SmallOutlineButton(
              tokens: tokens,
              label: '去邀请',
              onTap: onShare,
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionCard extends ConsumerWidget {
  const _OptionCard({
    required this.tokens,
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.desc,
    required this.button,
    this.progress,
    this.titleStrong = false,
    this.brandBorder = false,
  });

  final ThemeTokens tokens;
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String desc;
  final Widget button;
  final double? progress;
  final bool titleStrong;
  final bool brandBorder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // neumorphic 风格下：tokens.canvas 改为 tokens.surface，移除 border
        color: isNeumorphic ? tokens.surface : tokens.canvas,
        borderRadius: BorderRadius.circular(14),
        border: isNeumorphic
            ? null
            : Border.all(
                color: brandBorder ? tokens.brand : tokens.divider,
                width: 1,
              ),
        boxShadow: tokens.shadowConvex,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            titleStrong ? FontWeight.w600 : FontWeight.w500,
                        color: tokens.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.textTertiary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              button,
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            lumira.LumiraProgress.linear(
              value: progress,
              minHeight: 6,
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallBrandButton extends StatelessWidget {
  const _SmallBrandButton({
    required this.tokens,
    required this.label,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: tokens.brand,
          borderRadius: BorderRadius.circular(8),
          boxShadow: tokens.shadowConvexBrand,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textInverse,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _SmallOutlineButton extends ConsumerWidget {
  const _SmallOutlineButton({
    required this.tokens,
    required this.label,
    required this.onTap,
  });

  final ThemeTokens tokens;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeumorphic = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          // neumorphic 风格下：移除 border，用 canvasDeep 背景 + shadowConcaveSubtle 内凹阴影
          color: isNeumorphic ? tokens.canvasDeep : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isNeumorphic
              ? null
              : Border.all(color: tokens.divider, width: 1),
          boxShadow:
              isNeumorphic ? tokens.shadowConcaveSubtle : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: tokens.textPrimary,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _BottomNote extends StatelessWidget {
  const _BottomNote({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_open, size: 12, color: tokens.textTertiary),
          const SizedBox(width: 4),
          Text(
            '解锁后永久使用',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuccessCard extends StatelessWidget {
  const _SuccessCard({required this.tokens, required this.onStartUse});
  final ThemeTokens tokens;
  final VoidCallback onStartUse;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: tokens.successSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                size: 32,
                color: tokens.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '解锁成功',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '日系胶片 · 精选模板已永久解锁',
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            lumira.LumiraButton(
              variant: ButtonVariant.primary,
              onPressed: onStartUse,
              child: const SizedBox(
                width: double.infinity,
                child: Text('开始使用'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PayPopupContent extends ConsumerWidget {
  const _PayPopupContent({
    required this.price,
    required this.onCancel,
    required this.onConfirm,
  });

  final int price;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '积分解锁',
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '$price 积分',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: tokens.brand,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '消耗 $price 积分，永久解锁该模板',
          style: TextStyle(
            fontSize: 12,
            color: tokens.textTertiary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    // neumorphic 风格下：移除 border，用 canvasDeep + shadowConcaveSubtle
                    color: isNeumorphic
                        ? tokens.canvasDeep
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isNeumorphic
                        ? null
                        : Border.all(color: tokens.divider, width: 1),
                    boxShadow: isNeumorphic
                        ? tokens.shadowConcaveSubtle
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onConfirm,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: tokens.shadowConvexBrand,
                  ),
                  child: Center(
                    child: Text(
                      '确认解锁',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.textInverse,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 积分不足弹窗内容
///
/// 付费模板解锁时积分不足以支付时展示：
/// - 头部：积分不足 + 差额说明
/// - 中部：获取积分方式列表（与积分钱包页共用同一数据源）
/// - 底部：「取消」/「去赚积分」（跳转积分钱包页）
class _InsufficientCreditsContent extends ConsumerWidget {
  const _InsufficientCreditsContent({
    required this.price,
    required this.balance,
    required this.onCancel,
    required this.onGoWallet,
  });

  final int price;

  /// 当前可用积分；为 null 时（余额拉取失败/服务端兜底）不展示差额数字
  final int? balance;
  final VoidCallback onCancel;
  final VoidCallback onGoWallet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;
    final isNeumorphic = appTheme.style == UIStyle.neumorphic;

    final String desc;
    if (balance != null) {
      final diff = price - balance!;
      desc = balance! >= price
          ? '解锁该模板需 $price 积分，当前可用 $balance 积分。'
          : '解锁该模板需 $price 积分，当前可用 $balance 积分，还差 $diff 积分。';
    } else {
      desc = '解锁该模板需 $price 积分，当前积分不足以完成解锁。';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: tokens.danger),
            const SizedBox(width: 8),
            Text(
              '积分不足',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          desc,
          style: TextStyle(
            fontSize: 13,
            color: tokens.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '获取积分方式',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              PointsEarnWaysList(
                tokens: tokens,
                dense: true,
                stacked: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: onCancel,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    // neumorphic 风格下：移除 border，用 canvasDeep + shadowConcaveSubtle
                    color: isNeumorphic
                        ? tokens.canvasDeep
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isNeumorphic
                        ? null
                        : Border.all(color: tokens.divider, width: 1),
                    boxShadow: isNeumorphic
                        ? tokens.shadowConcaveSubtle
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '取消',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.textSecondary,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: onGoWallet,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: tokens.shadowConvexBrand,
                  ),
                  child: Center(
                    child: Text(
                      '去赚积分',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: tokens.textInverse,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
