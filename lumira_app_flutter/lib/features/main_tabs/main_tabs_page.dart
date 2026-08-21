import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_controller.dart';
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