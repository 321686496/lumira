import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/dao/tags_dao.dart';
import '../../../core/db/dao/usage_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/router/route_names.dart';
import '../../../features/gallery/data/gallery_models.dart';
import '../../../features/points/data/points_models.dart';
import '../../../features/points/data/points_repository.dart';
import '../../../features/usage/usage_providers.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_share.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../../shared/widgets/tags/tag_chip.dart' show TagChip, TagChipKind;
import '../../../shared/widgets/tags/user_tags_section.dart';
import '../data/owned_templates_repository.dart';
import '../data/remote_templates_providers.dart';
import '../data/templates_browse_mock_data.dart';
import '../data/templates_editor_mock_data.dart' show parseAspectRatio;
import '../services/template_exporter.dart';
import '../services/template_share_code.dart';
import '../widgets/ambience_badges.dart';
import '../widgets/ambience_label.dart';
import '../widgets/pose_silhouette.dart';
import '../widgets/template_cover_image.dart';
import '../../../features/gallery/widgets/photo_cell.dart';

/// 全量分类记录列表（供详情页分类面包屑解析）。
///
/// 用 List 而非 key→name 扁平 map：L3 拍法 key（如 normal / wide）在同一 key 下会
/// 出现在多个父分类（如 japanese→他拍、casual→随拍），扁平 map 会产生歧义，
/// 需要按父分类路径精确解析每个分段的中文名。
final templateCategoryProvider =
    FutureProvider<List<TemplateCategoryRecord>>((ref) async {
  final dao = await ref.watch(templatesDaoProvider.future);
  return dao.getCategories(activeOnly: false);
});

/// 姿势参考卡片内容宽高比：按模板宽高比**字面**解析（不随设备方向自适应）。
///
/// - '4:3' → 4/3、'16:9' → 16/9、'3:4' → 3/4、'1:1' → 1.0
/// - 'fullscreen' → 回退设备屏幕宽高比
double poseReferenceAspectRatio(String ratio, Size screenSize) {
  final raw = parseAspectRatio(ratio);
  if (raw < 0) return screenSize.width / screenSize.height;
  return raw;
}

/// 模板详情页
///
/// 视觉规格来源：lumira-app/src/pages/templates/detail.vue
/// 10 个 section：
/// 1. PreviewImage（封面图，aspectRatio 比例）
/// 2. TitleAndTags（标题 + tags + 可选+添加按钮）
/// 3. TagSelector（自定义模板可编辑标签，简化占位）
/// 4. SceneGuideCard（5 个 guide-item + tips）
/// 5. CameraParamsCard（7 个相机参数 mono 文字）
/// 6. PostProcessCard（11 个后期参数 mono 文字）
/// 7. PoseReferenceCard（仅 hasSilhouette 时显示，Align 百分比定位）
/// 8. UnlockStatus（免费 / 精选 ¥xx）
/// 9. ReferenceSource（参数参考来源）
/// 10. FixedCta（底部固定按钮，套用此模板拍摄 → push /capture?templateId=xxx）
class TemplatesDetailPage extends ConsumerStatefulWidget {
  const TemplatesDetailPage({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<TemplatesDetailPage> createState() =>
      _TemplatesDetailPageState();
}

class _TemplatesDetailPageState extends ConsumerState<TemplatesDetailPage> {
  /// 防止重复上报详情打开事件（同一实例只上报一次）。
  bool _openDetailReported = false;

  /// mock 快路径：从 [TemplatesBrowseMockData.findDetailById] 同步查找。
  /// 覆盖内置 29 模板 + mock 详情列表。返回 null 时走 [templateDetailProvider] 慢路径。
  TemplateDetail? get _template =>
      TemplatesBrowseMockData.findDetailById(widget.templateId ?? '');

  /// 是否为"我的模板"（自定义创建或导入的模板），详情页显示编辑入口。
  /// 仅基于 mock 快路径判断；remote 模板不显示编辑按钮（不可本地编辑）。
  bool get _isMyTemplate {
    final id = _template?.id ?? '';
    return id.startsWith('custom_') || id.startsWith('imp_');
  }

  /// 是否为可导出的自定义模板（user-created / custom / imported）。
  /// 与 [_isMyTemplate] 配合：导出按钮仅在两者均为 true 时显示。
  bool get _isCustomTemplate {
    final id = _template?.id ?? widget.templateId ?? '';
    // Custom templates: user-created or imported (not builtin/system)
    // source field is more reliable but id prefix is a simple heuristic
    return id.startsWith('user_') ||
        id.startsWith('custom_') ||
        id.startsWith('imported_');
  }

  /// 付费模板是否已被当前用户解锁（免费模板视为已解锁）。
  bool _isOwned(int price, Set<String> ownedIds, String id) {
    if (price <= 0) return true;
    return ownedIds.contains(id);
  }

  void _goCapture(TemplateDetail template, {bool trial = false}) {
    final id = template.id;
    // 试用模式：直接进入拍摄页试用（仅展示效果）
    if (trial) {
      GoRouter.of(context).push('/capture?templateId=$id&trial=1');
      return;
    }
    // 门禁：付费模板未拥有时跳解锁页
    final price = template.price;
    final owned = ref.read(ownedTemplateIdsProvider);
    if (price > 0 && !owned.contains(id)) {
      GoRouter.of(context).push(
        '${RouteNames.templatesUnlock}?templateId=$id&price=$price',
      );
      return;
    }
    GoRouter.of(context).push('/capture?templateId=$id');
  }

  void _goUnlock(TemplateDetail template) {
    GoRouter.of(context).push(
      '${RouteNames.templatesUnlock}?templateId=${template.id}&price=${template.price}',
    );
  }

  /// 跳转积分钱包页（右上角积分数点击入口）。
  void _goPointsWallet() {
    GoRouter.of(context).push(RouteNames.pointsWallet);
  }

  /// 顶部导航右侧操作组：
  /// - 我的模板（自定义/导入）→ 导出 + 编辑
  /// - 付费模板未解锁 → 右上角展示用户积分数（点击跳转积分钱包页）
  /// - 其余（免费模板 / 已解锁付费模板）→ 无右侧操作
  List<Widget>? _navActions(ThemeTokens tokens, bool isLocked) {
    if (_isMyTemplate) {
      return [
        if (_isCustomTemplate)
          LumiraIconButton(
            icon: Icons.ios_share,
            onPressed: _goExport,
            color: tokens.textPrimary,
            size: 20,
          ),
        LumiraIconButton(
          icon: Icons.edit_outlined,
          onPressed: _goEdit,
          color: tokens.textPrimary,
          size: 20,
        ),
      ];
    }
    if (isLocked) {
      return [_CreditBalanceChip(onTap: _goPointsWallet)];
    }
    return null;
  }

  void _goEdit() {
    final id = _template?.id;
    if (id == null) return;
    GoRouter.of(context).push(
      RouteNames.withTemplateId(RouteNames.templatesEditor, id),
    );
  }

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.templates);
    }
  }

  void _showSnack(String msg) {
    LumiraToast.show(
      context,
      msg,
      duration: const Duration(milliseconds: 1000),
    );
  }

  /// 导出当前模板：从 DAO 拉取完整 [TemplateRecord] 后弹出格式选择面板。
  Future<void> _goExport() async {
    final id = _template?.id ?? widget.templateId;
    if (id == null || id.isEmpty) return;
    try {
      final dao = await ref.read(templatesDaoProvider.future);
      final record = await dao.getById(id);
      if (record == null) {
        _showSnack('模板未找到');
        return;
      }
      if (!mounted) return;
      await _showExportFormatSheet(context, record);
    } catch (e) {
      _showSnack('导出失败：$e');
    }
  }

  /// 弹出导出格式选择面板（.pptpl 完整 / .lumira 简化）。
  Future<void> _showExportFormatSheet(
    BuildContext context,
    TemplateRecord record,
  ) async {
    final tokens = ref.watch(themeTokensProvider);
    final result = await showLumiraBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '选择导出格式',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
          ),
          LumiraListTile(
            leading: Icon(Icons.description_outlined, color: tokens.brand),
            title: const Text('完整 .pptpl（推荐）'),
            subtitle: const Text('含构图/姿势/相机/场景/后期全参数'),
            onTap: () => Navigator.pop(ctx, 'pptpl'),
          ),
          LumiraListTile(
            leading: Icon(Icons.code_outlined, color: tokens.brand),
            title: const Text('简化 .lumira'),
            subtitle: const Text('仅元信息+相机核心参数'),
            onTap: () => Navigator.pop(ctx, 'lumira'),
          ),
          LumiraListTile(
            leading: Icon(Icons.link_outlined, color: tokens.brand),
            title: const Text('复制分享链接'),
            subtitle: const Text('粘贴到微信/聊天，对方用如画导入'),
            onTap: () {
              Navigator.pop(ctx, null);
              _copyShareLink(record);
            },
          ),
          if (record.isBuiltin)
            LumiraListTile(
              leading: Icon(Icons.qr_code_2_outlined, color: tokens.brand),
              title: const Text('复制分享码'),
              subtitle: const Text('内置模板：对方输入分享码即可导入'),
              onTap: () {
                Navigator.pop(ctx, null);
                _copyShareCode(record);
              },
            ),
          LumiraListTile(
            leading: Icon(Icons.chat_bubble_outline, color: tokens.brand),
            title: const Text('以文本分享'),
            subtitle: const Text('发送模板名 + 链接 + 分享码'),
            onTap: () {
              Navigator.pop(ctx, null);
              _shareAsText(record);
            },
          ),
          LumiraListTile(
            title: Center(
              child: Text(
                '取消',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            onTap: () => Navigator.pop(ctx, null),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    final usePptpl = result == 'pptpl';
    LumiraToast.show(context, '正在导出 ${record.name}...');
    try {
      final filePath =
          await TemplateExporter.exportToTempFile(record, usePptpl: usePptpl);
      if (!mounted) return;
      GoRouter.of(context).push(
        RouteNames.templatesExportDetail,
        extra: {
          'filePath': filePath,
          'templateName': record.name,
          'usePptpl': usePptpl,
          'shareLink': TemplateShareCode.buildShareLink(record, usePptpl: usePptpl),
          'shareCode':
              record.isBuiltin ? TemplateShareCode.buildShareCode(record) : null,
        },
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '导出失败：$e');
    }
  }

  /// 复制分享链接到剪贴板（完整 JSON 形式，对方可用如画粘贴导入）。
  Future<void> _copyShareLink(TemplateRecord record) async {
    final link = TemplateShareCode.buildShareLink(record);
    await Clipboard.setData(ClipboardData(text: link));
    _showSnack('分享链接已复制');
  }

  /// 复制分享码到剪贴板（内置模板专用，对方输入分享码即可导入）。
  Future<void> _copyShareCode(TemplateRecord record) async {
    final code = TemplateShareCode.buildShareCode(record);
    await Clipboard.setData(ClipboardData(text: code));
    _showSnack('分享码已复制');
  }

  /// 以文本形式分享（模板名 + 链接 + 分享码）。
  Future<void> _shareAsText(TemplateRecord record) async {
    final link = TemplateShareCode.buildShareLink(record);
    final code = TemplateShareCode.buildShareCode(record);
    await SafeShare.share(
      '我用如画分享了模板「${record.name}」\n链接：$link\n分享码：$code',
      subject: '如画模板：${record.name}',
    );
  }

  /// 构建模板详情内容（v14 重构：接收 template 参数，支持 mock / DAO / remote 来源）。
  ///
  /// 将原 build 方法中的 Column widget tree 提取为此方法，
  /// 使 mock 快路径与 provider 慢路径共用同一渲染逻辑。
  /// 计算属性（_hasSilhouette / _wbLabel 等）改为局部变量，
  /// 避免依赖 `_template` getter（remote 模板不在 mock 中时 getter 返回 null）。
  ///
  /// v19：新增 [isLocked] —— 付费模板未解锁时隐藏相机/后期/滤镜参数
  /// （显示锁定提示），CTA 变为"购买 + 试用"。
  Widget _buildDetailContent(
    TemplateDetail template,
    ThemeTokens tokens, {
    required bool isLocked,
  }) {
    final hasSilhouette = () {
      final pose = template.pose;
      if (pose.silhouetteType == 'builtin' && pose.silhouetteData == 'none') {
        return false;
      }
      return true;
    }();
    final propsText = (template.sceneGuide.props).join('、');
    final ev = template.camera.exposureCompensation;
    final evDisplay = ev > 0 ? '+$ev' : '$ev';
    final wbK = template.camera.whiteBalanceK;
    final wbDisplay = wbK != null ? '${wbK}K' : '';
    final wbLabel =
        TemplatesBrowseMockData.wbLabel(template.camera.whiteBalance);
    final flashLabel =
        TemplatesBrowseMockData.flashLabel(template.camera.flashMode);
    final focusLabel =
        TemplatesBrowseMockData.focusLabel(template.camera.focusMode);
    final lensLabel =
        TemplatesBrowseMockData.lensLabel(template.camera.lensSuggestion);
    final lutLabel = TemplatesBrowseMockData.lutLabel(template.postProcess.lut);
    final unlockText = template.price == 0 ? '免费' : '${template.price} 积分';

    String signedNum(int v) => v > 0 ? '+$v' : '$v';

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewImage(
                template: template,
                tokens: tokens,
              ),
              _TitleAndTags(
                template: template,
                tokens: tokens,
              ),
              _MetaInfoCard(
                template: template,
                tokens: tokens,
              ),
              UserTagsSection(
                itemType: TagItemType.template,
                itemId: template.id,
              ),
              _SceneGuideCard(
                template: template,
                tokens: tokens,
                propsText: propsText,
              ),
              // 付费模板未解锁：相机/后期/滤镜参数隐藏为锁定提示
              if (isLocked)
                _LockedParamsCard(
                  tokens: tokens,
                  price: template.price,
                )
              else ...[
                _CameraParamsCard(
                  template: template,
                  tokens: tokens,
                  evDisplay: evDisplay,
                  wbLabel: wbLabel,
                  wbDisplay: wbDisplay,
                  flashLabel: flashLabel,
                  focusLabel: focusLabel,
                  lensLabel: lensLabel,
                ),
                _PostProcessCard(
                  template: template,
                  tokens: tokens,
                  lutLabel: lutLabel,
                  signedNum: signedNum,
                ),
                if (template.postProcess.fillLight != null &&
                    template.postProcess.fillLight!.enabled)
                  _FillLightCard(
                    fillLight: template.postProcess.fillLight!,
                    tokens: tokens,
                  ),
              ],
              if (hasSilhouette)
                _PoseReferenceCard(
                  template: template,
                  tokens: tokens,
                ),
              _UnlockStatus(
                tokens: tokens,
                unlockText: unlockText,
                price: template.price,
              ),
              _ReferenceSource(
                template: template,
                tokens: tokens,
              ),
              _TemplatePhotosSection(
                template: template,
                tokens: tokens,
              ),
              const SizedBox(height: 100), // cta-spacer
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _FixedCta(
            tokens: tokens,
            isLocked: isLocked,
            price: template.price,
            onPressed: () => _goCapture(template),
            onTrial: () => _goCapture(template, trial: true),
            onPurchase: () => _goUnlock(template),
          ),
        ),
      ],
    );
  }

  /// 上报模板详情打开事件（仅首次成功加载时上报一次，失败静默）。
  ///
  /// source 判定：mock 快路径（内置）直接传 [knownSource]；慢路径从库中
  /// 读取 [TemplateRecord.source]（'builtin'|'custom'|'remote'），自定义模板不写入。
  Future<void> _maybeReportOpenDetail(
    String templateId, {
    String? knownSource,
  }) async {
    if (_openDetailReported) return;
    _openDetailReported = true;
    try {
      final recorder = await ref.read(usageEventRecorderProvider.future);
      var source = knownSource;
      if (source == null) {
        final dao = await ref.read(templatesDaoProvider.future);
        final record = await dao.getById(templateId);
        source = record?.source;
      }
      if (source == null) return;
      await recorder.recordTemplate(
        templateId: templateId,
        source: source,
        event: UsageEventType.openDetail,
      );
      // 个性化反馈：查看详情 → 轻量加权（失败静默）
      final interest = await ref.read(interestServiceProvider.future);
      await interest.recordSignal(templateId, 0.6);
    } catch (_) {
      // 上报失败静默，不影响详情加载
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    // 触发已拥有模板列表加载（门禁判断依赖此缓存）
    ref.watch(ownedTemplatesLoaderProvider);
    final ownedIds = ref.watch(ownedTemplateIdsProvider);
    final mockTemplate = _template;
    // 埋点：mock 快路径（内置 29 模板）详情打开，source=builtin
    if (mockTemplate != null) {
      _maybeReportOpenDetail(mockTemplate.id, knownSource: 'builtin');
    }

    // 付费模板是否被锁定（未解锁）：已解锁或免费模板不锁定
    bool computeLocked(TemplateDetail t) => !_isOwned(t.price, ownedIds, t.id);

    // v14: mock 快路径（内置 29 模板 + mock 详情列表）
    // 若 mock 中找不到（custom / remote 模板），走 provider 慢路径
    final needsAsyncLoad = mockTemplate == null && widget.templateId != null;
    final asyncDetail = needsAsyncLoad
        ? ref.watch(templateDetailProvider(widget.templateId!))
        : const AsyncValue<TemplateDetail?>.data(null);

    // 当前模板是否处于「付费未解锁」锁定态（决定右上角是否展示积分余额）
    final TemplateDetail? effectiveTemplate =
        mockTemplate ?? asyncDetail.value;
    final effectiveLocked =
        effectiveTemplate != null && computeLocked(effectiveTemplate);

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
                  title: '模板详情',
                  transparent: true,
                  leading: _BackButton(tokens: tokens, onTap: _back),
                  actions: _navActions(tokens, effectiveLocked),
                ),
                Expanded(
                  child: mockTemplate != null
                      ? _buildDetailContent(
                          mockTemplate,
                          tokens,
                          isLocked: computeLocked(mockTemplate),
                        )
                      : asyncDetail.when(
                          loading: () => Center(
                            child: LumiraProgress.circular(),
                          ),
                          error: (e, _) => _RemoteLoadError(
                            tokens: tokens,
                            onRetry: () => ref.invalidate(
                              templateDetailProvider(widget.templateId!),
                            ),
                          ),
                          data: (detail) {
                            // 埋点：慢路径（remote/custom 模板）详情打开，source 从库读取
                            if (detail != null) {
                              _maybeReportOpenDetail(detail.id);
                            }
                            return detail == null
                                ? _EmptyState(tokens: tokens)
                                : _buildDetailContent(
                                    detail,
                                    tokens,
                                    isLocked: computeLocked(detail),
                                  );
                          },
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

class _BackButton extends StatelessWidget {
  const _BackButton({required this.tokens, required this.onTap});
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
          Icons.arrow_back_ios_new,
          size: 20,
          color: tokens.textPrimary,
        ),
      ),
    );
  }
}

/// 右上角积分余额胶囊：付费模板未解锁时展示当前积分数，点击跳转积分钱包页。
///
/// 余额来自 [pointsRepositoryProvider]（GET /points/balance），加载中显示占位「…」。
class _CreditBalanceChip extends ConsumerWidget {
  const _CreditBalanceChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final repoAsync = ref.watch(pointsRepositoryProvider);

    Widget chip(String label) => GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.brandSubtle,
              borderRadius: BorderRadius.circular(9999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.stars_outlined, size: 14, color: tokens.brand),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: tokens.brandText,
                  ),
                ),
              ],
            ),
          ),
        );

    return repoAsync.maybeWhen(
      data: (repo) => FutureBuilder<PointsBalance>(
        future: repo.getBalance(),
        builder: (context, snap) {
          final balance = snap.connectionState == ConnectionState.done
              ? snap.data?.balance
              : null;
          return chip(balance != null ? '$balance' : '…');
        },
      ),
      orElse: () => chip('…'),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      child: Column(
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.broken_image_outlined,
              size: 60,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '模板未找到',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '该模板可能已被删除或链接错误',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 远程模板详情加载失败（v14 新增）。
///
/// 当 [remoteTemplateDetailProvider] 拉取完整内容失败时显示，
/// 提供"重试"按钮通过 `ref.invalidate` 重新触发 provider。
class _RemoteLoadError extends StatelessWidget {
  const _RemoteLoadError({required this.tokens, required this.onRetry});

  final ThemeTokens tokens;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 40),
      child: Column(
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.cloud_off_outlined,
              size: 60,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '网络错误，无法加载完整内容',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请检查网络后重试',
            style: TextStyle(
              fontSize: 12,
              color: tokens.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: onRetry,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: tokens.brand,
                borderRadius: BorderRadius.circular(9999),
              ),
              child: const Text(
                '重试',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewImage extends StatelessWidget {
  const _PreviewImage({
    required this.template,
    required this.tokens,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;

  double get _aspectRatio {
    final parts = template.aspectRatio.split(':');
    final w = int.tryParse(parts[0]) ?? 4;
    final h = int.tryParse(parts[1]) ?? 3;
    return w / h;
  }

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(
            aspectRatio: _aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TemplateCoverImage(
                  cover: template.cover,
                  coverData: template.coverData,
                  fit: BoxFit.cover,
                  fallback: Container(
                    color: tokens.surfaceAlt,
                    child: Icon(
                      Icons.photo_outlined,
                      color: tokens.textTertiary,
                      size: 40,
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
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      // 硬编码颜色，与 uni-app 一致 (rgba(0,0,0,0.45))
                      color: const Color(0x73000000),
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      TemplatesBrowseMockData.categoryLabel(template.category),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleAndTags extends ConsumerWidget {
  const _TitleAndTags({
    required this.template,
    required this.tokens,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 分类 breadcrumb：完整分类路径（categoryLabel(category) · majorStyle · subStyle · method）
    final categories =
        ref.watch(templateCategoryProvider).value ?? const <TemplateCategoryRecord>[];
    // 按父分类路径精确解析名称：同 key 的 L3（如 normal）可能挂在不同父分类下，
    // 优先取 parentKey 匹配的分段，避免出现"随拍/他拍"错名。
    String? nameOf(String key, String? parentKey) {
      final matches = categories.where((c) => c.key == key).toList();
      if (matches.isEmpty) return null;
      if (parentKey == null) return matches.first.name;
      final byParent = matches.where((c) => c.parentKey == parentKey);
      return (byParent.isNotEmpty ? byParent.first : matches.first).name;
    }

    final segments = <String?>[
      TemplatesBrowseMockData.categoryLabel(template.category),
      if (template.majorStyle != null && template.majorStyle!.isNotEmpty)
        nameOf(template.majorStyle!, template.category),
      if (template.subStyle != null && template.subStyle!.isNotEmpty)
        nameOf(template.subStyle!, template.majorStyle),
      if (template.method != null && template.method!.isNotEmpty)
        nameOf(template.method!, template.majorStyle),
    ].whereType<String>().toList();

    return FadeUp(
      delay: const Duration(milliseconds: 80),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: tokens.textPrimary,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: template.price == 0
                        ? tokens.successSubtle
                        : tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    template.price == 0 ? '免费' : '${template.price} 积分',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: template.price == 0
                          ? tokens.success
                          : tokens.brandText,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 分类面包屑（完整分类路径）
            Row(
              children: [
                Icon(Icons.folder_outlined,
                    size: 13, color: tokens.textTertiary),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    segments.join('  ·  '),
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in template.tags) TagChip(label: tag, kind: TagChipKind.system),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneGuideCard extends StatelessWidget {
  const _SceneGuideCard({
    required this.template,
    required this.tokens,
    required this.propsText,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;
  final String propsText;

  Widget _item(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: tokens.textTertiary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 160),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.wb_sunny_outlined, size: 18, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '场景指南',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _item('光线', template.sceneGuide.lightDirection),
              _item('距离', template.sceneGuide.shootingDistance),
              _item('背景', template.sceneGuide.background),
              _item('道具', propsText.isEmpty ? '无' : propsText),
              _item('最佳时间', template.sceneGuide.bestTime),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tokens.brandSubtle.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0;
                        i < template.sceneGuide.tips.length;
                        i++) ...[
                      if (i > 0) const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '· ',
                            style: TextStyle(
                              fontSize: 12,
                              color: tokens.brand,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              template.sceneGuide.tips[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
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

class _CameraParamsCard extends StatelessWidget {
  const _CameraParamsCard({
    required this.template,
    required this.tokens,
    required this.evDisplay,
    required this.wbLabel,
    required this.wbDisplay,
    required this.flashLabel,
    required this.focusLabel,
    required this.lensLabel,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;
  final String evDisplay;
  final String wbLabel;
  final String wbDisplay;
  final String flashLabel;
  final String focusLabel;
  final String lensLabel;

  Widget _param(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'Courier New',
        color: tokens.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = template.camera;
    return FadeUp(
      delay: const Duration(milliseconds: 240),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_alt_outlined,
                      size: 18, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '相机参数',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _param('EV $evDisplay'),
                  _param('ISO ${c.iso}'),
                  _param('${c.shutterSpeed}s'),
                  _param('WB: $wbLabel $wbDisplay'),
                  _param('镜头: $lensLabel'),
                  _param('闪光: $flashLabel'),
                  _param('对焦: $focusLabel'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostProcessCard extends StatelessWidget {
  const _PostProcessCard({
    required this.template,
    required this.tokens,
    required this.lutLabel,
    required this.signedNum,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;
  final String lutLabel;
  final String Function(int) signedNum;

  Widget _param(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontFamily: 'Courier New',
        color: tokens.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = template.postProcess;
    return FadeUp(
      delay: const Duration(milliseconds: 320),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.tune_outlined, size: 18, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '后期参数',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _param('裁剪: ${p.cropRatio}'),
                  _param('LUT: $lutLabel'),
                  _param('亮度 ${signedNum(p.brightness)}'),
                  _param('对比 ${signedNum(p.contrast)}'),
                  _param('饱和 ${signedNum(p.saturation)}'),
                  _param('色温 ${signedNum(p.temperature)}'),
                  _param('色调 ${signedNum(p.tint)}'),
                  _param('平滑 ${p.smoothStrength}'),
                  _param('锐化 ${p.sharpen}'),
                  _param('暗角 ${p.vignette}'),
                  _param('颗粒 ${p.grain}'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 补光灯信息卡：独立成卡展示补光颜色 + 强度。
/// 颜色使用与拍摄页补光应用一致的 int 色值（Color(int)），确保所见即所得。
class _FillLightCard extends StatelessWidget {
  const _FillLightCard({
    required this.fillLight,
    required this.tokens,
  });

  final FillLightData fillLight;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    final color = Color(fillLight.color | 0xFF000000);
    final hex = '#${fillLight.color.toRadixString(16).toUpperCase().padLeft(8, '0')}';
    bool isLight = ThemeData.estimateBrightnessForColor(color) ==
        Brightness.light;
    final swatchText =
        isLight ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9);
    return FadeUp(
      delay: const Duration(milliseconds: 340),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 18, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '补光灯',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '强度 ${fillLight.intensity.toStringAsFixed(1)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 大矩形色块：用补光灯真实颜色填充，与拍摄页应用的颜色一致
              Container(
                width: double.infinity,
                height: 76,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tokens.divider),
                ),
                alignment: Alignment.bottomRight,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Text(
                  hex,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'Courier New',
                    color: swatchText,
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

class _PoseReferenceCard extends StatelessWidget {
  const _PoseReferenceCard({
    required this.template,
    required this.tokens,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;

  /// 姿势参考预览框比例：与模板宽高比一致（4:3 → 4:3、16:9 → 16:9），
  /// fullscreen 时回退设备屏幕宽高比。
  double _posePreviewRatio(BuildContext context) {
    return poseReferenceAspectRatio(
      template.aspectRatio,
      MediaQuery.of(context).size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pose = template.pose;
    return FadeUp(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.accessibility_new, size: 18, color: tokens.brand),
                  const SizedBox(width: 8),
                  Text(
                    '姿势参考',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // pose-preview-wrap：比例 = 模板宽高比（字面 W:H，4:3 → 4/3）
              // 剪影位置以该比例框为参考系（x:0,y:0 = 比例框左上角），
              // 剪影大小 = 比例框宽 40% × 1:1.6，中心锚定在位置百分比上，
              // scale/rotation 与模板一致（SilhouetteLayer 统一规则）。
              AspectRatio(
                key: const Key('pose_reference_card_aspect'),
                aspectRatio: _posePreviewRatio(context),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    // 品牌色浅渐变（色值跟随主题 brand，原与 uni-app 一致）
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        tokens.brand.withOpacity(0.08),
                        tokens.brand.withOpacity(0.02),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // pose-layer：统一剪影渲染规则（40% 宽 × 1:1.6 + 百分比中心定位）
                      Positioned.fill(
                        child: SilhouetteLayer(
                          silhouetteType: pose.silhouetteType,
                          silhouetteData: pose.silhouetteData,
                          positionX: pose.positionX,
                          positionY: pose.positionY,
                          scale: pose.scale,
                          rotation: pose.rotation,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (pose.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  pose.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UnlockStatus extends StatelessWidget {
  const _UnlockStatus({
    required this.tokens,
    required this.unlockText,
    required this.price,
  });

  final ThemeTokens tokens;
  final String unlockText;
  final int price;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Row(
          children: [
            Icon(
              price == 0 ? Icons.check_circle : Icons.lock_outline,
              size: 18,
              color: price == 0 ? tokens.success : tokens.brand,
            ),
            const SizedBox(width: 8),
            Text(
              unlockText,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: price == 0 ? tokens.success : tokens.brandText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReferenceSource extends StatelessWidget {
  const _ReferenceSource({required this.template, required this.tokens});
  final TemplateDetail template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        '参数参考来源：${template.referenceSource}',
        style: TextStyle(
          fontSize: 11,
          color: tokens.textTertiary,
        ),
      ),
    );
  }
}

class _FixedCta extends StatelessWidget {
  const _FixedCta({
    required this.tokens,
    required this.isLocked,
    required this.price,
    required this.onPressed,
    required this.onTrial,
    required this.onPurchase,
  });
  final ThemeTokens tokens;

  /// 付费模板未解锁：CTA 显示"试用 + 购买"
  final bool isLocked;
  final int price;
  final VoidCallback onPressed;
  final VoidCallback onTrial;
  final VoidCallback onPurchase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        // 渐变蒙层，硬编码颜色与 uni-app 一致
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tokens.canvas.withOpacity(0),
            tokens.canvas.withOpacity(0.6),
            tokens.canvas,
          ],
          stops: const [0, 0.4, 1],
        ),
      ),
      child: isLocked
          ? Row(
              children: [
                // 试用按钮（描边）
                Expanded(
                  child: GestureDetector(
                    onTap: onTrial,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tokens.brand, width: 1),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.visibility_outlined,
                              size: 18, color: tokens.brand),
                          const SizedBox(width: 6),
                          Text(
                            '试用',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: tokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 购买按钮（品牌色）
                Expanded(
                  child: LumiraButton(
                    variant: ButtonVariant.primary,
                    onPressed: onPurchase,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_open_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text('$price 积分解锁'),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: LumiraButton(
                variant: ButtonVariant.primary,
                onPressed: onPressed,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.camera_alt_outlined),
                    SizedBox(width: 8),
                    Text('套用此模板拍摄'),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 付费模板未解锁时的参数锁定提示卡
///
/// 替代相机参数/后期参数/滤镜参数卡片，仅提示解锁后可查看，
/// 不暴露任何具体参数值。
class _LockedParamsCard extends StatelessWidget {
  const _LockedParamsCard({required this.tokens, required this.price});

  final ThemeTokens tokens;
  final int price;

  @override
  Widget build(BuildContext context) {
    return FadeUp(
      delay: const Duration(milliseconds: 240),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tokens.brandSubtle,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.lock_outline, size: 22, color: tokens.brand),
              ),
              const SizedBox(height: 12),
              Text(
                '相机 / 后期 / 滤镜参数已锁定',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '解锁后即可查看并套用完整参数（含 LUT 滤镜、相机参数、后期调整）',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textTertiary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars_outlined, size: 14, color: tokens.brand),
                  const SizedBox(width: 4),
                  Text(
                    '$price 积分永久解锁',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tokens.brand,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 将毫秒时间戳格式化为 `yyyy-MM-dd`（模板更新日期展示用）。
String _formatDate(int ms) {
  if (ms <= 0) return '';
  final dt = DateTime.fromMillisecondsSinceEpoch(ms);
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// 模板信息卡（v35 新增，位于标题下）：短简介 + 氛围标签 + 更新日期。
class _MetaInfoCard extends ConsumerWidget {
  const _MetaInfoCard({required this.template, required this.tokens});

  final TemplateDetail template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final labels = AmbienceLabel.labelsFor(template.ambience);
    final updatedText = _formatDate(template.updatedAt);
    final hasUpdatedAt = updatedText.isNotEmpty;
    final hasShortDesc = template.shortDesc.isNotEmpty;
    final hasLongDesc =
        template.description.isNotEmpty && template.description != template.shortDesc;
    // 所有来源都为空时隐藏整卡
    if (!hasShortDesc &&
        !hasLongDesc &&
        labels.isEmpty &&
        !hasUpdatedAt) {
      return const SizedBox.shrink();
    }

    return FadeUp(
      delay: const Duration(milliseconds: 120),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasShortDesc) ...[
                Text(
                  template.shortDesc,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
              if (hasLongDesc) ...[
                if (hasShortDesc) const SizedBox(height: 8),
                Text(
                  template.description,
                  style: TextStyle(
                    fontSize: 13,
                    color: tokens.textSecondary,
                    height: 1.6,
                  ),
                ),
              ],
              if (labels.isNotEmpty) ...[
                const SizedBox(height: 12),
                AmbienceBadges(ambience: template.ambience, tokens: tokens),
              ],
              if (hasUpdatedAt) ...[
                const SizedBox(height: 12),
                Text(
                  '更新于 $updatedText',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 「用此模板拍摄的照片」区（v35 新增，页面底部）：本机该模板最近 4 张横滑预览，
/// 右上「查看全部」进入 [RouteNames.templatesPhotos] 网格页。
class _TemplatePhotosSection extends ConsumerWidget {
  const _TemplatePhotosSection({required this.template, required this.tokens});

  final TemplateDetail template;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daoAsync = ref.watch(galleryDaoProvider);
    return daoAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (dao) => FutureBuilder<List<GalleryItemRecord>>(
        future: dao.getByTemplate(template.id, limit: 4),
        builder: (context, snap) {
          final photos = snap.data ?? const <GalleryItemRecord>[];
          if (photos.isEmpty) return const SizedBox.shrink();
          return FadeUp(
            delay: const Duration(milliseconds: 200),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '用此模板拍摄的照片',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => GoRouter.of(context).push(
                          RouteNames.build(RouteNames.templatesPhotos, {
                            RouteNames.paramTemplateId: template.id,
                          }),
                        ),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '查看全部',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.brand,
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 16, color: tokens.brand),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final record = photos[i];
                        return SizedBox(
                          width: 96,
                          child: PhotoCell(
                            photo: GalleryPhoto.fromRecord(record),
                            onTap: () => GoRouter.of(context).push(
                              RouteNames.build(RouteNames.galleryDetail, {
                                RouteNames.paramPhotoId: record.id,
                              }),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
