import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/owned_templates_repository.dart';
import '../data/templates_browse_mock_data.dart';

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
  bool _tagSelectorVisible = false;

  TemplateDetail? get _template =>
      TemplatesBrowseMockData.findDetailById(widget.templateId ?? '');

  bool get _hasSilhouette {
    final pose = _template?.pose;
    if (pose == null) return false;
    if (pose.silhouetteType == 'builtin' && pose.silhouetteData == 'none') {
      return false;
    }
    return true;
  }

  bool get _canEditTags => _template?.id.startsWith('custom_') ?? false;

  /// 是否为"我的模板"（自定义创建或导入的模板），详情页显示编辑入口
  bool get _isMyTemplate {
    final id = _template?.id ?? '';
    return id.startsWith('custom_') || id.startsWith('imp_');
  }

  String get _wbLabel =>
      TemplatesBrowseMockData.wbLabel(_template!.camera.whiteBalance);
  String get _flashLabel =>
      TemplatesBrowseMockData.flashLabel(_template!.camera.flashMode);
  String get _focusLabel =>
      TemplatesBrowseMockData.focusLabel(_template!.camera.focusMode);
  String get _lensLabel =>
      TemplatesBrowseMockData.lensLabel(_template!.camera.lensSuggestion);
  String get _lutLabel =>
      TemplatesBrowseMockData.lutLabel(_template!.postProcess.lut);

  String get _evDisplay {
    final ev = _template?.camera.exposureCompensation;
    if (ev == null) return '';
    return ev > 0 ? '+$ev' : '$ev';
  }

  String get _wbDisplay {
    final k = _template?.camera.whiteBalanceK;
    return k != null ? '${k}K' : '';
  }

  String get _propsText =>
      (_template?.sceneGuide.props ?? []).join('、');

  String get _unlockText {
    final price = _template?.price ?? 0;
    return price == 0 ? '免费' : '精选 ¥$price';
  }

  String _signedNum(int v) => v > 0 ? '+$v' : '$v';

  void _goCapture() {
    final id = _template?.id;
    if (id == null) return;
    // 门禁：付费模板未拥有时跳解锁页
    final price = _template?.price ?? 0;
    final owned = ref.read(ownedTemplateIdsProvider);
    if (price > 0 && !owned.contains(id)) {
      GoRouter.of(context).push(
        '${RouteNames.templatesUnlock}?templateId=$id',
      );
      return;
    }
    GoRouter.of(context).push('/capture?templateId=$id');
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

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    // 触发已拥有模板列表加载（门禁判断依赖此缓存）
    ref.watch(ownedTemplatesLoaderProvider);
    final template = _template;

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
                  actions: _isMyTemplate
                      ? [
                          LumiraIconButton(
                            icon: Icons.edit_outlined,
                            onPressed: _goEdit,
                            color: tokens.textPrimary,
                            size: 20,
                          ),
                        ]
                      : null,
                ),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: template == null
                            ? _EmptyState(tokens: tokens)
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _PreviewImage(
                                    template: template,
                                    tokens: tokens,
                                  ),
                                  _TitleAndTags(
                                    template: template,
                                    tokens: tokens,
                                    canEditTags: _canEditTags,
                                    onAddTag: () => setState(
                                        () => _tagSelectorVisible = true),
                                  ),
                                  if (_tagSelectorVisible && _canEditTags)
                                    _TagSelector(
                                      tokens: tokens,
                                      onNewTag: () =>
                                          _showSnack('新建标签功能即将上线'),
                                    ),
                                  _SceneGuideCard(
                                    template: template,
                                    tokens: tokens,
                                    propsText: _propsText,
                                  ),
                                  _CameraParamsCard(
                                    template: template,
                                    tokens: tokens,
                                    evDisplay: _evDisplay,
                                    wbLabel: _wbLabel,
                                    wbDisplay: _wbDisplay,
                                    flashLabel: _flashLabel,
                                    focusLabel: _focusLabel,
                                    lensLabel: _lensLabel,
                                  ),
                                  _PostProcessCard(
                                    template: template,
                                    tokens: tokens,
                                    lutLabel: _lutLabel,
                                    signedNum: _signedNum,
                                  ),
                                  if (_hasSilhouette)
                                    _PoseReferenceCard(
                                      template: template,
                                      tokens: tokens,
                                    ),
                                  _UnlockStatus(
                                    tokens: tokens,
                                    unlockText: _unlockText,
                                    price: template.price,
                                  ),
                                  _ReferenceSource(
                                    template: template,
                                    tokens: tokens,
                                  ),
                                  const SizedBox(height: 100), // cta-spacer
                                ],
                              ),
                      ),
                      if (template != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: _FixedCta(
                            tokens: tokens,
                            onPressed: _goCapture,
                          ),
                        ),
                    ],
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
                Image.network(
                  'https://picsum.photos/seed/${template.coverSeed}/800/600',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
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

class _TitleAndTags extends StatelessWidget {
  const _TitleAndTags({
    required this.template,
    required this.tokens,
    required this.canEditTags,
    required this.onAddTag,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;
  final bool canEditTags;
  final VoidCallback onAddTag;

  @override
  Widget build(BuildContext context) {
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: template.price == 0
                        ? tokens.successSubtle
                        : tokens.brandSubtle,
                    borderRadius: BorderRadius.circular(9999),
                  ),
                  child: Text(
                    template.price == 0 ? '免费' : '精选 ¥${template.price}',
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in template.tags)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tokens.brandSubtle,
                      borderRadius: BorderRadius.circular(9999),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        color: tokens.brandText,
                      ),
                    ),
                  ),
                if (canEditTags)
                  GestureDetector(
                    onTap: onAddTag,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(
                            color: tokens.divider, width: 0.5),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 12, color: tokens.brand),
                          const SizedBox(width: 2),
                          Text(
                            '添加',
                            style: TextStyle(
                              fontSize: 11,
                              color: tokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TagSelector extends StatelessWidget {
  const _TagSelector({required this.tokens, required this.onNewTag});
  final ThemeTokens tokens;
  final VoidCallback onNewTag;

  @override
  Widget build(BuildContext context) {
    // 简化占位：一行 chips + 新建标签按钮（Task 2.8B/2.8C 接入真实 CRUD）
    return FadeUp(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: NeuCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择标签',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _TagChip('人像', tokens: tokens),
                    _TagChip('柔光', tokens: tokens),
                    _TagChip('日系', tokens: tokens),
                    _TagChip('胶片', tokens: tokens),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onNewTag,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border:
                              Border.all(color: tokens.brand, width: 0.5),
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 12, color: tokens.brand),
                            const SizedBox(width: 4),
                            Text(
                              '新建标签',
                              style: TextStyle(
                                fontSize: 12,
                                color: tokens.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _TagChip extends ConsumerWidget {
  const _TagChip(this.label, {required this.tokens});
  final String label;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isNeu = ref.watch(uiStyleProvider) == UIStyle.neumorphic;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isNeu ? tokens.surface : tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: isNeu ? tokens.shadowConvexSubtle : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: tokens.textSecondary,
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
                  Icon(Icons.wb_sunny_outlined,
                      size: 18, color: tokens.brand),
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

class _PoseReferenceCard extends StatelessWidget {
  const _PoseReferenceCard({
    required this.template,
    required this.tokens,
  });

  final TemplateDetail template;
  final ThemeTokens tokens;

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
                  Icon(Icons.accessibility_new,
                      size: 18, color: tokens.brand),
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
              // pose-preview-wrap：用 AspectRatio(1:1) 替代 padding-bottom 百分比
              AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    // 硬编码颜色，与 uni-app 一致
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color.fromRGBO(201, 169, 110, 0.08),
                        Color.fromRGBO(201, 169, 110, 0.02),
                      ],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // pose-layer：用 Align 百分比定位简化实现
                      // 简化原因：Flutter Positioned 不支持百分比，需 LayoutBuilder 计算
                      // 用 Alignment(x*2-1, y*2-1) 将 0..1 映射到 -1..1（位置 0.5 → Alignment.center）
                      // Task 2.8C 剪影编辑器会替换为完整 SVG 剪影组件
                      Align(
                        alignment: Alignment(
                          pose.positionX * 2 - 1,
                          pose.positionY * 2 - 1,
                        ),
                        child: FractionallySizedBox(
                          widthFactor: 0.2,
                          heightFactor: 0.32,
                          child: Container(
                            decoration: BoxDecoration(
                              // 硬编码颜色，与 uni-app 一致 — 简化灰色块占位
                              color: tokens.textTertiary.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
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
  const _FixedCta({required this.tokens, required this.onPressed});
  final ThemeTokens tokens;
  final VoidCallback onPressed;

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
      child: SizedBox(
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
