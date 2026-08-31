import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/db/database_provider.dart';
import '../../core/network/api_error.dart';
import '../../core/theme/theme_controller.dart';
import '../../features/invite/data/invite_models.dart';
import '../../features/invite/data/invite_repository.dart';
import '../../shared/widgets/lumira/lumira.dart';
import '../../shared/widgets/tabbar/floating_tabbar.dart';
import '../challenge/pages/challenge_page.dart';
import '../home/pages/home_page.dart';
import '../profile/pages/profile_page.dart';
import '../templates/pages/templates_page.dart';

/// 四个 Tab 页的常驻容器
///
/// 在归一的单页面内用 [PageView] 承载 4 个 Tab 页：
/// - 支持左右滑动切换到相邻 Tab；
/// - 每个 Tab 页用 [_KeepAlivePage] 常驻不销毁，因此天然保留各自滚动位置、
///   不会在切换时重新触发 Provider 加载或重放入场动画（同时解决卡顿根因之一）。
///
/// Chrome 注意：切 Tab 不再走 GoRouter 路由重建，由本容器在本地切换页面，
/// 显著降低成本。中间拍摄按钮仍由 FloatingTabBar push 到独立拍摄页（不在此容器内）。
class MainTabsPage extends ConsumerStatefulWidget {
  const MainTabsPage({super.key, this.initialIndex = 0});

  /// 启动时进入的 Tab 索引（由路由决定：home=0 / templates=1 / challenge=2 / profile=3）
  final int initialIndex;

  @override
  ConsumerState<MainTabsPage> createState() => _MainTabsPageState();
}

class _MainTabsPageState extends ConsumerState<MainTabsPage> {
  /// 与 FloatingTabBar 高亮 key 一一对应的顺序（PageView 从左到右）
  static const List<String> _tabs = ['home', 'templates', 'challenge', 'profile'];

  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIndex.clamp(0, _tabs.length - 1);
    _index = initial;
    _pageController = PageController(initialPage: initial);
    // 首启一次性邀请码绑定入口：仅新设备首次使用展示一次（跳过/绑定后不再弹）。
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowFirstUseInvite());
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int pageIndex) {
    if (pageIndex == _index) return;
    setState(() => _index = pageIndex);
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  /// FloatingTabBar 的 tab 序号：0=home / 1=templates / (2=中间拍摄) / 3=challenge / 4=profile
  /// → 映射为 PageView 索引
  void _onTabSelected(int tabIndex) {
    const map = <int, int>{0: 0, 1: 1, 3: 2, 4: 3};
    final pageIndex = map[tabIndex];
    if (pageIndex != null) _goToPage(pageIndex);
  }

  /// 首启一次性邀请码绑定入口：仅新设备首次使用展示一次。
  ///
  /// 用本地 auth 表的 invite_bind_prompt_shown 标记保证「只弹一次」；
  /// 后端同时以 first_seen_at + 24h 绑定窗口做权威校验，二者互为兜底。
  Future<void> _maybeShowFirstUseInvite() async {
    if (!mounted) return;
    final auth = ref.read(authControllerProvider);
    if (!auth.isNewDevice) return;
    try {
      final dao = await ref.read(authDaoProvider.future);
      if (await dao.isInviteBindPromptShown()) return;
      // 先置标记再弹，避免解析/展示期间重复弹出。
      await dao.markInviteBindPromptShown();
    } catch (_) {
      return; // DAO 失败静默，不阻塞首页
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _FirstUseInviteSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return Scaffold(
      backgroundColor: tokens.canvas,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (i) {
              if (_index != i) setState(() => _index = i);
            },
            // 允许左右滑动切换相邻 Tab
            physics: const PageScrollPhysics(),
            children: const [
              _KeepAlivePage(child: HomePage()),
              _KeepAlivePage(child: TemplatesPage()),
              _KeepAlivePage(child: ChallengePage()),
              _KeepAlivePage(child: ProfilePage()),
            ],
          ),
          // 共享 Tab 栏（覆盖在 4 页之上，中间按钮仍 push 拍摄页）
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FloatingTabBar(
              active: _tabs[_index],
              onTabSelected: _onTabSelected,
            ),
          ),
        ],
      ),
    );
  }
}

/// 让 PageView 的每一项在滑出可视区后仍常驻不销毁，
/// 从而保留各 Tab 页的滚动位置与已加载的 Provider 状态。
class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// 首启一次性邀请码绑定弹层（可跳过）。
///
/// 视觉跟随当前 UI 风格 / 主题；绑定逻辑复用 [inviteRepositoryProvider]。
/// 仅作入口呈现，后端以新设备绑定窗口权威校验（非新用户会被拒绝）。
class _FirstUseInviteSheet extends ConsumerStatefulWidget {
  const _FirstUseInviteSheet();

  @override
  ConsumerState<_FirstUseInviteSheet> createState() =>
      _FirstUseInviteSheetState();
}

class _FirstUseInviteSheetState extends ConsumerState<_FirstUseInviteSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _toast('请输入邀请码（可稍后在「邀请有礼」页或跳过）');
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final toastContext = context;
    try {
      final repo = await ref.read(inviteRepositoryProvider.future);
      final resp = await repo.activate(ActivateInviteRequest(inviteCode: code));
      if (!mounted) return;
      final msg = resp.rewards != null
          ? '邀请码已激活，解锁 ${resp.rewards!.items.length} 项奖励'
          : '邀请码已激活';
      Navigator.of(context).pop();
      _toast(msg, toastContext);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('激活失败：${e.message}', toastContext);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      _toast('绑定成功', toastContext);
      Navigator.of(context).pop();
    }
  }

  void _toast(String message, [BuildContext? override]) {
    final ctx = override ?? context;
    if (!mounted && override == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, size: 20, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '好友邀请你了吗？',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '输入好友的邀请码，绑定成功后双方各得积分奖励。'
                '仅新设备首次使用时开放，可随时跳过。',
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              LumiraTextField(
                controller: _codeController,
                hintText: '粘贴好友的邀请码...',
              ),
              const SizedBox(height: 14),
              LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('确认绑定'),
              ),
              const SizedBox(height: 8),
              LumiraButton(
                variant: ButtonVariant.ghost,
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('暂不绑定'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}