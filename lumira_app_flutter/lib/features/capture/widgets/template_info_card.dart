import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/capture_appearance.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/lumira/_internal/lumira_theme_resolver.dart';
import '../data/capture_state.dart';
import '../domain/photo_template.dart';

/// 拍摄页套用模板后的可折叠模板信息卡。
///
/// - 折叠态：图标 + 模板名 + 展开箭头
/// - 展开态：标题栏右侧 tab 切换三个分区（展示顺序固定：场景指南 / 道具信息 / 姿势描述）
///   - 场景指南：光线 / 距离 / 背景 / 时段 + 拍摄注意点（sceneGuide.tips）
///   - 道具信息：sceneGuide.props 道具标签
///   - 姿势描述：当前姿势的描述（多姿势模板跟随当前姿势下标）
/// - tab 按钮与内容区左右滑动（PageView）双向同步切换分区
/// - 内容区有最大高度限制（见 _maxContentHeight）：未超限按内容自收缩，超限则内部滚动查看
/// - 仅渲染「当前模板有内容」的分区；默认选中优先级：姿势描述 > 场景指南 > 道具信息
/// - 用户手动选中的 tab 会持久化（user_settings），下次进入拍摄页沿用；
///   若该 tab 在当前模板无内容，则回落到默认优先级
/// - 套用模板默认展开；切换模板（id 变化）时重置为展开
/// - 视觉与 ChallengeOverlayBar 保持一致（双模式浮层 + 品牌色描边）：
///   immersive=暗色半透明 / theme=当前风格的叠照片浮层取向
class TemplateInfoCard extends ConsumerStatefulWidget {
  const TemplateInfoCard({
    super.key,
    required this.template,
    this.isLandscape = false,
    this.quarterTurns = 0,
    this.onHide,
  });

  final PhotoTemplate template;

  /// 横持手机时为 true：卡片旋转到可读方向（由传感器驱动，UI 整体仍保持竖屏）。
  final bool isLandscape;

  /// 横屏时卡片需**顺时针**旋转的 90° 圈数（0/1/3），保证文字正向（左/右横适配）。
  final int quarterTurns;

  /// 用户点击卡内“隐藏”按钮时回调（由外层负责隐藏卡片并持久化偏好）。
  final VoidCallback? onHide;

  @override
  ConsumerState<TemplateInfoCard> createState() => _TemplateInfoCardState();
}

/// 信息卡内容分区（对应标题栏右侧的 tab）。
enum _InfoTab {
  scene,
  props,
  pose;

  /// 展示顺序即上方声明顺序：场景指南 → 道具信息 → 姿势描述。
  String get label {
    switch (this) {
      case _InfoTab.scene:
        return '场景';
      case _InfoTab.props:
        return '道具';
      case _InfoTab.pose:
        return '姿势';
    }
  }

  /// 持久化/恢复用的 key（与 DAO 存储值一致）。
  String get key => name;

  static _InfoTab? fromKey(String? raw) {
    for (final tab in _InfoTab.values) {
      if (tab.key == raw) return tab;
    }
    return null;
  }
}

class _TemplateInfoCardState extends ConsumerState<TemplateInfoCard> {
  /// 内容区 PageView 控制器（与 tab 双向同步）。
  late PageController _pageController = PageController();

  /// 分辨何时需要重建控制器（模板 id / 姿势下标 / 可用分区变化时重建，恢复选中页）。
  String _pageKey = '';

  /// 内容区 CSS 式 max-height 的「视口高度」：= 当前可见页面的自然高度被上限截断后的值。
  /// 0 表示尚未测量，先用上限占位；滑动翻页 / 切换姿势后自动重新自适应。
  double _pageHeight = 0;

  /// 最近一次 build 的可用分区，供滑动回调（onPageChanged）使用。
  List<_InfoTab> _lastAvailable = const <_InfoTab>[];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TemplateInfoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 切换模板（id 变化）时重置为展开
    if (oldWidget.template.meta.id != widget.template.meta.id) {
      ref.read(CaptureState.templateInfoCardExpandedProvider.notifier).state =
          true;
    }
  }

  void _toggle() {
    final expanded = ref.read(CaptureState.templateInfoCardExpandedProvider);
    ref.read(CaptureState.templateInfoCardExpandedProvider.notifier).state =
        !expanded;
  }

  void _selectTab(_InfoTab tab, {bool animate = true}) {
    ref.read(CaptureState.templateInfoCardTabProvider.notifier).state = tab.key;
    CaptureState.persistTemplateInfoCardTab(
      ProviderScope.containerOf(context, listen: false),
      tab.key,
    );
    if (animate) {
      final idx = _lastAvailable.indexOf(tab);
      final current = _pageController.page?.round() ?? -1;
      if (idx >= 0 && idx != current) {
        _pageController.animateToPage(
          idx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  /// 内容区滑动切换：仅持久化选中态，不再动画（页面已滑动到位）。
  void _onPageChanged(int index) {
    if (index < 0 || index >= _lastAvailable.length) return;
    final tab = _lastAvailable[index];
    if (tab.key == ref.read(CaptureState.templateInfoCardTabProvider)) return;
    _selectTab(tab, animate: false);
  }

  /// 内容区最大高度：竖屏取屏高的一定比例；横屏卡片已被 RotatedBox 旋转，
  /// 内容纵向对应画布横向跨度，故按屏宽取比例（值仅左右视觉观感，越界由内部滚动兜底）。
  double _maxContentHeight() {
    final size = MediaQuery.of(context).size;
    return size.height >= size.width
        ? size.height * 0.36
        : size.width * 0.5;
  }

  /// 当前模板下「有内容」的分区（按展示顺序）。
  List<_InfoTab> _availableTabs(Pose pose) {
    final guide = widget.template.sceneGuide;
    final hasScene = guide.lightDirection.isNotEmpty ||
        guide.shootingDistance.isNotEmpty ||
        guide.background.isNotEmpty ||
        guide.bestTime.isNotEmpty ||
        (guide.bestTimeFrom != null && guide.bestTimeTo != null) ||
        guide.tips.isNotEmpty;
    return <_InfoTab>[
      if (hasScene) _InfoTab.scene,
      if (guide.props.isNotEmpty) _InfoTab.props,
      if (pose.description.trim().isNotEmpty) _InfoTab.pose,
    ];
  }

  /// 默认选中优先级：姿势描述 > 场景指南 > 道具信息（取第一个可用的）。
  _InfoTab? _defaultTab(List<_InfoTab> available) {
    for (final tab in const <_InfoTab>[
      _InfoTab.pose,
      _InfoTab.scene,
      _InfoTab.props,
    ]) {
      if (available.contains(tab)) return tab;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    // 双模式视觉：immersive=暗色胶囊 / theme=当前风格的叠照片浮层取向
    // （与 ChallengeOverlayBar 同构：底色/阴影/毛玻璃走 resolver，品牌描边保留）
    final visual = LumiraThemeResolver.captureOverlayVisual(
      tokens: appTheme.tokens,
      style: appTheme.style,
      appearance: ref.watch(CaptureState.captureAppearanceProvider),
      role: CaptureOverlayRole.pill,
      radiusDp: 24,
    );

    // 竖屏：整卡顶部居中，占满屏宽。
    if (!widget.isLandscape) {
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: double.infinity),
          child: Material(
            color: Colors.transparent,
            child: _buildBody(appTheme, visual),
          ),
        ),
      );
    }

    // 横屏：整卡按持机方向旋转到可读角（顺时针 quarterTurns 圈），并贴向用户视角的
    // 「上方」。旋转后卡片内容的顶部指向哪条画布边缘，哪条边缘就是用户视角的上方：
    // - quarterTurns=1（逆时针持机，手机顶部在用户左侧）→ 内容顶部指向画布右缘 → 贴右；
    // - quarterTurns=3（顺时针持机，手机顶部在用户右侧）→ 内容顶部指向画布左缘 → 贴左。
    // RotatedBox 会交换子项的布局宽高：子项「宽度」= 旋转后在画布上的纵向跨度，
    // 子项「高度」= 画布横向跨度（用户视角的卡片厚度）。
    final size = MediaQuery.of(context).size;
    final qTurns = (widget.quarterTurns == 0) ? 3 : widget.quarterTurns;
    // 距用户上方的留白（约 1/4 横屏视高，与竖屏时卡片距屏顶比例接近）：
    // 同时避开画布右缘约 40% 高度处的多姿势切换按钮（right:12 + 自宽约 72 + 间隙），
    // 保证两种持机方向下卡片展开/收起都不会被其遮挡。
    const double userTopInset = 96;
    return Align(
      alignment: qTurns == 1 ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: qTurns == 1
            ? const EdgeInsets.only(right: userTopInset)
            : const EdgeInsets.only(left: userTopInset),
        child: RotatedBox(
          quarterTurns: qTurns,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: size.height * 0.5, // 旋转后为画布纵向跨度，限制避免过长
              maxHeight: size.width * 0.86, // 旋转后为画布横向跨度，避免越出画布短边
            ),
            child: Material(
              color: Colors.transparent,
              child: _buildBody(appTheme, visual),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeData appTheme, CaptureOverlayVisual visual) {
    final tokens = appTheme.tokens;
    final template = widget.template;
    // 展开态跟随共享 provider（拍摄页据此显隐姿势切换提示标签）
    final expanded = ref.watch(CaptureState.templateInfoCardExpandedProvider);

    // 多姿势模板跟随「当前姿势下标」（与拍摄页姿势切换按钮同源）
    final poses = template.poses;
    final rawIndex = ref.watch(CaptureState.currentPoseIndexProvider);
    final poseIndex =
        poses.isEmpty ? 0 : rawIndex.clamp(0, poses.length - 1).toInt();
    final pose = poses.isEmpty ? const Pose() : poses[poseIndex];

    final available = _availableTabs(pose);
    final persisted =
        _InfoTab.fromKey(ref.watch(CaptureState.templateInfoCardTabProvider));
    final selected = (persisted != null && available.contains(persisted))
        ? persisted
        : _defaultTab(available);
    final selectedIndex =
        selected == null ? -1 : available.indexOf(selected);

    // 控制器生命周期：模板 / 姿势 / 可用分区变化时重建（初始页=选中 tab）。
    final pageKey = '${template.meta.id}|$poseIndex|${available.join('/')}';
    if (pageKey != _pageKey) {
      _pageKey = pageKey;
      _pageController.dispose();
      _pageController = PageController(
        initialPage: selectedIndex < 0 ? 0 : selectedIndex,
      );
    }
    _lastAvailable = available;

    final radius = BorderRadius.circular(expanded ? 14 : 24);

    final Widget card = AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: GestureDetector(
            onTap: _toggle,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: expanded ? 12 : 10,
              ),
              // 统一走 resolver：immersive=暗色 / theme=当前风格浮层；
              // 品牌描边两模式均保留（tokens.brand 已随主题变化）
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: radius,
                border: Border.all(
                  color: tokens.brand.withOpacity(0.35),
                  width: 1,
                ),
                boxShadow: visual.shadows,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题行：图标 + 模板名 + tab（右侧）+ 箭头 + 隐藏
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, size: 16, color: tokens.brand),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          template.meta.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: visual.foreground,
                            height: 1.2,
                          ),
                        ),
                      ),
                      // tab 仅在展开态 + 存在多个分区时出现（单个分区无需切换）
                      if (expanded && selected != null && available.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _buildTabs(available, selected, visual),
                        ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          size: 18,
                          color: visual.foregroundSecondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // 隐藏按钮：点击后整卡消失并持久化（仅当外层提供回调时显示）
                      if (widget.onHide != null)
                        GestureDetector(
                          onTap: widget.onHide,
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 15,
                              color: visual.foregroundSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  // 展开态：整个内容区为可左右滑动的 PageView（每页可独立上下滚动）
                  if (expanded && selected != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      height: 1,
                      color: visual.fillSubtle,
                    ),
                    const SizedBox(height: 10),
                    _buildTabPager(
                      available: available,
                      selectedIndex: selectedIndex,
                      guide: template.sceneGuide,
                      pose: pose,
                      poseIndex: poseIndex,
                      poseCount: poses.length,
                      visual: visual,
                      tokens: tokens,
                    ),
                  ],
                ],
              ),
            ),
          ),
    );
    // backdropBlurSigma>0 才包毛玻璃；新拟态 sigma=0 直接呈现卡体
    return visual.backdropBlurSigma > 0
        ? ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: visual.backdropBlurSigma,
                sigmaY: visual.backdropBlurSigma,
              ),
              child: card,
            ),
          )
        : card;
  }

  /// 标题栏右侧的 tab 按钮组（点击切换分区并持久化）。
  Widget _buildTabs(
    List<_InfoTab> tabs,
    _InfoTab selected,
    CaptureOverlayVisual visual,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < tabs.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _selectTab(tabs[i]),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tabs[i] == selected
                    ? visual.accent.withOpacity(0.18)
                    : visual.fillSubtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: tabs[i] == selected
                      ? visual.accent.withOpacity(0.55)
                      : Colors.transparent,
                  width: 0.8,
                ),
              ),
              child: Text(
                tabs[i].label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight:
                      tabs[i] == selected ? FontWeight.w600 : FontWeight.w400,
                  color:
                      tabs[i] == selected ? visual.accent : visual.foregroundSecondary,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 内容区：可左右滑动的 PageView + CSS 式 max-height 自适应高度。
  ///
  /// - 不设固定高度：PageView 的视口高度 = 当前可见页面「自然高度 与 [_maxContentHeight] 的较小值」。
  /// - 内容未到上限 → 高度即内容高度（卡片自收缩）；内容超过上限 → 卡在上限、内部上下滚动。
  /// - 滑动翻页 / 切换姿势后重新测量，经外层 AnimatedSize 平滑伸缩。
  Widget _buildTabPager({
    required List<_InfoTab> available,
    required int selectedIndex,
    required SceneGuide guide,
    required Pose pose,
    required int poseIndex,
    required int poseCount,
    required CaptureOverlayVisual visual,
    required ThemeTokens tokens,
  }) {
    final cap = _maxContentHeight();
    final currentIndex = available.isEmpty
        ? 0
        : (selectedIndex >= 0 && selectedIndex < available.length
            ? selectedIndex
            : 0);
    final currentTab = available[currentIndex];
    final measureKey = GlobalKey();

    // 每页内容（自然高度，供展示页与测量复用）
    Widget buildNatural(_InfoTab tab) => _buildNaturalTabContent(
          tab: tab,
          guide: guide,
          pose: pose,
          poseIndex: poseIndex,
          poseCount: poseCount,
          visual: visual,
          tokens: tokens,
        );

    // 视口宽需有界（内容页内部用 Expanded / 换行），故在 LayoutBuilder 中取卡片内容宽并统一约束。
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // CSS 式测量：把「当前页」放进 ConstrainedBox(maxHeight)+SingleChildScrollView，
        // 其尺寸自动 = min(自然高度, 上限) —— 这正是 max-height 的布局结果，无需手算。
        // 每帧后读取并更新视口高度（仅当有差异才 setState，动画由外层 AnimatedSize 承担）。
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ctx = measureKey.currentContext;
          if (ctx == null) return;
          final height = ctx.size?.height;
          if (height == null) return;
          if ((_pageHeight - height).abs() > 0.5) {
            setState(() => _pageHeight = height);
          }
        });

        final measureCurrent = ConstrainedBox(
          constraints: BoxConstraints(maxHeight: cap),
          child: SingleChildScrollView(child: buildNatural(currentTab)),
        );

        return Stack(
          fit: StackFit.passthrough,
          children: [
            SizedBox(
              width: width,
              height: _pageHeight > 0 ? _pageHeight : cap,
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                children: [
                  for (final tab in available)
                    SingleChildScrollView(child: buildNatural(tab)),
                ],
              ),
            ),
            // 离屏测量当前页：同名宽约束下结果 = min(自然高度, 上限)
            Offstage(
              offstage: true,
              child: SizedBox(key: measureKey, width: width, child: measureCurrent),
            ),
          ],
        );
      },
    );
  }

  /// 单个分区的「自然高度」内容（不带滚动容器，供 PageView 与测量复用）。
  Widget _buildNaturalTabContent({
    required _InfoTab tab,
    required SceneGuide guide,
    required Pose pose,
    required int poseIndex,
    required int poseCount,
    required CaptureOverlayVisual visual,
    required ThemeTokens tokens,
  }) {
    switch (tab) {
      case _InfoTab.scene:
        return _buildSceneContent(guide, visual, tokens);
      case _InfoTab.props:
        return _buildPropsContent(guide.props, visual);
      case _InfoTab.pose:
        return _buildPoseContent(pose, poseIndex, poseCount, visual);
    }
  }

  /// 场景指南：紧凑 label:value 行 + 拍摄注意点
  Widget _buildSceneContent(
    SceneGuide guide,
    CaptureOverlayVisual visual,
    ThemeTokens tokens,
  ) {
    final time = (guide.bestTimeFrom != null && guide.bestTimeTo != null)
        ? '${guide.bestTimeFrom} - ${guide.bestTimeTo}'
        : guide.bestTime;
    final rows = <MapEntry<String, String>>[
      if (guide.lightDirection.isNotEmpty)
        MapEntry('光线', guide.lightDirection),
      if (guide.shootingDistance.isNotEmpty)
        MapEntry('距离', guide.shootingDistance),
      if (guide.background.isNotEmpty) MapEntry('背景', guide.background),
      if (time.isNotEmpty) MapEntry('时段', time),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...rows.map(
          (row) => Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 30,
                  child: Text(
                    row.key,
                    style: TextStyle(
                      fontSize: 11,
                      color: visual.foregroundMuted,
                      height: 1.5,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    row.value,
                    style: TextStyle(
                      fontSize: 11,
                      color: visual.foreground,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (guide.tips.isNotEmpty) ...[
          if (rows.isNotEmpty) const SizedBox(height: 2),
          ...guide.tips.map(
            (tip) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.check_circle_outline,
                      size: 13,
                      color: tokens.brand,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(
                        fontSize: 11,
                        color: visual.foreground,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// 道具信息：道具标签（无道具时不渲染本分区，故此处恒非空）
  Widget _buildPropsContent(List<String> props, CaptureOverlayVisual visual) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final prop in props)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: visual.fillSubtle,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: visual.accent.withOpacity(0.28), width: 0.8),
            ),
            child: Text(
              prop,
              style: TextStyle(
                fontSize: 11,
                color: visual.foreground,
                height: 1.3,
              ),
            ),
          ),
      ],
    );
  }

  /// 姿势描述：多姿势时带「姿势 n/N」前缀 + 姿势名，随后是描述正文
  Widget _buildPoseContent(
    Pose pose,
    int poseIndex,
    int poseCount,
    CaptureOverlayVisual visual,
  ) {
    final titleParts = <String>[
      if (poseCount > 1) '姿势 ${poseIndex + 1}/$poseCount',
      if (pose.name.trim().isNotEmpty) pose.name.trim(),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titleParts.isNotEmpty) ...[
          Text(
            titleParts.join(' · '),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: visual.accent,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          pose.description.trim(),
          style: TextStyle(
            fontSize: 12,
            color: visual.foreground,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
