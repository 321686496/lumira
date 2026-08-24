import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/scenes_dao.dart';
import '../../../core/db/dao/templates_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/number_format.dart';
import '../../../shared/widgets/cards/neu_card.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../templates/widgets/template_cover_image.dart';
import '../data/composition_kit_models.dart';
import '../providers/composition_kits_providers.dart';

/// 组合套件列表页
///
/// 视觉规格：对齐 ProfileMyTemplatesPage 结构
/// 1. 顶部 StatsBar：总数 / 总使用次数 / 最近使用
/// 2. 套件列表卡片：封面 + 名称 + 场景标签 + 模板标签 + 上次使用 + 使用次数
/// 3. FAB "新建套件"
/// 4. 卡片点击 → 详情页；长按 → ActionSheet（套用/编辑/复制/删除）
class CompositionKitsPage extends ConsumerWidget {
  const CompositionKitsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final kitsAsync = ref.watch(compositionKitsProvider);
    final statsAsync = ref.watch(compositionKitsStatsProvider);

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: '我的组合',
        transparent: true,
        leading: _BackButton(tokens: tokens),
      ),
      floatingActionButton: LumiraFloatingActionButton(
        onPressed: () => _showCreateKitSheet(context, ref),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: kitsAsync.when(
          loading: () => Center(child: LumiraProgress.circular()),
          error: (e, _) => Center(child: Text('加载失败：$e')),
          data: (kits) => RefreshIndicator(
            onRefresh: () async => ref.invalidate(compositionKitsProvider),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
              children: [
                _StatsBar(tokens: tokens, stats: statsAsync),
                const SizedBox(height: 16),
                if (kits.isEmpty)
                  _EmptyState(tokens: tokens)
                else
                  for (var i = 0; i < kits.length; i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _KitCard(
                      tokens: tokens,
                      kit: kits[i],
                      onTap: () => GoRouter.of(context).push(
                        '${RouteNames.profileCompositionKitDetail}'
                        '?${RouteNames.paramKitId}=${kits[i].id}',
                      ),
                      onLongPress: () => _showActionSheet(context, ref, kits[i]),
                    ),
                  ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context, WidgetRef ref, CompositionKit kit) {
    final tokens = ref.read(themeTokensProvider);
    showLumiraBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LumiraListTile(
            leading: Icon(Icons.camera_alt_outlined, color: tokens.brand),
            title: const Text('套用拍照'),
            onTap: () {
              Navigator.pop(ctx);
              GoRouter.of(context).push(RouteNames.build(RouteNames.capture, {
                RouteNames.paramScene: kit.sceneId,
                RouteNames.paramTemplateId: kit.templateId ?? '',
                RouteNames.paramKitId: kit.id,
              }));
            },
          ),
          LumiraListTile(
            leading: Icon(Icons.delete_outline, color: tokens.danger),
            title: Text('删除', style: TextStyle(color: tokens.danger)),
            onTap: () async {
              Navigator.pop(ctx);
              final dao = await ref.read(compositionKitsDaoProvider.future);
              await dao.delete(kit.id);
              ref.invalidate(compositionKitsProvider);
              // ignore: use_build_context_synchronously
              if (!context.mounted) return;
              LumiraToast.show(context, '已删除');
            },
          ),
          LumiraListTile(
            title: Center(
              child: Text('取消',
                  style: TextStyle(color: tokens.textSecondary)),
            ),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  /// 弹出"新建组合"底部表单：选择场景（必选）+ 模板（可选）+ 名称
  void _showCreateKitSheet(BuildContext context, WidgetRef ref) {
    final tokens = ref.read(themeTokensProvider);
    showLumiraBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateKitSheet(tokens: tokens),
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
          Navigator.pop(context);
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

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.tokens, required this.stats});
  final ThemeTokens tokens;
  final AsyncValue<CompositionKitsStats> stats;

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: stats.when(
        loading: () => Center(child: LumiraProgress.circular()),
        error: (_, __) => const SizedBox.shrink(),
        data: (s) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _StatItem(
                tokens: tokens, value: '${s.totalCount}', label: '套件总数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: formatThousands(s.totalUsage),
                label: '总使用次数'),
            _Divider(tokens: tokens),
            _StatItem(
                tokens: tokens,
                value: s.lastUsedAt == null
                    ? '—'
                    : _formatDate(s.lastUsedAt!),
                label: '最近使用'),
          ],
        ),
      ),
    );
  }

  String _formatDate(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${dt.month}-${dt.day}';
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.tokens, required this.value, required this.label});
  final ThemeTokens tokens;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Noto Serif SC',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
            height: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: tokens.textTertiary),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(width: 0.5, height: 28, color: tokens.divider);
  }
}

class _KitCard extends ConsumerWidget {
  const _KitCard({
    required this.tokens,
    required this.kit,
    required this.onTap,
    required this.onLongPress,
  });

  final ThemeTokens tokens;
  final CompositionKit kit;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sceneAsync = ref.watch(compositionKitSceneProvider(kit.sceneId));
    final templateAsync = kit.templateId == null
        ? null
        : ref.watch(compositionKitTemplateProvider(kit.templateId!));

    final scene = sceneAsync.valueOrNull;
    final template = templateAsync?.valueOrNull;
    final cover = resolveKitCover(kit, scene: scene, template: template);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: NeuCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 80,
                height: 80,
                child: cover.hasImage
                    ? TemplateCoverImage(
                        cover: cover.cover,
                        coverData: cover.coverData,
                        fit: BoxFit.cover,
                        fallback: _CoverPlaceholder(tokens: tokens),
                        errorFallback: _CoverPlaceholder(tokens: tokens),
                      )
                    : _CoverPlaceholder(tokens: tokens),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    kit.name,
                    style: TextStyle(
                      fontFamily: 'Noto Serif SC',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _Tag(tokens: tokens, text: '场景: ${_nameOrShort(scene?.name, kit.sceneId)}'),
                      if (kit.templateId != null)
                        _Tag(
                          tokens: tokens,
                          text: '模板: ${_nameOrShort(template?.name, kit.templateId!)}',
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '使用 ${kit.usageCount} 次 · ${_formatLastUsed(kit.lastUsedAt)}',
                    style: TextStyle(fontSize: 11, color: tokens.textTertiary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
          ],
        ),
      ),
    );
  }

  /// 优先展示名称；场景/模板被删除（查询不到）时回退到短 ID。
  String _nameOrShort(String? name, String id) {
    if (name != null && name.isNotEmpty) return name;
    return _shortId(id);
  }

  String _shortId(String id) {
    // 取 id 中第一个 - 之前的部分作为简短标签
    final idx = id.indexOf('-');
    return idx == -1 ? id : id.substring(0, idx);
  }

  String _formatLastUsed(int? ms) {
    if (ms == null) return '未使用';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inHours < 1) return '刚刚';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 30) return '${diff.inDays}天前';
    return '${dt.month}-${dt.day}';
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: tokens.surface,
      child: Icon(Icons.layers_outlined, color: tokens.textTertiary, size: 28),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.brandSubtle,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, color: tokens.brandText),
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
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 40),
      child: Column(
        children: [
          Icon(Icons.layers_outlined, size: 60, color: tokens.textTertiary.withOpacity(0.35)),
          const SizedBox(height: 10),
          Text(
            '还没有组合套件',
            style: TextStyle(
              fontFamily: 'Noto Serif SC',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: tokens.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '在场景详情页点击"加入组合"即可创建',
            style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: () => GoRouter.of(context).push(RouteNames.scenes),
            child: const Text('去逛逛场景'),
          ),
        ],
      ),
    );
  }
}

/// "新建组合"底部表单
///
/// 字段：
/// - 名称（必填，≤30 字）
/// - 关联场景（必选，来源 scenesDaoProvider → ScenesDao.getAll）
/// - 关联模板（可选，来源 templatesDaoProvider → TemplatesDao.getAll）
///
/// 保存：构造 CompositionKit → compositionKitsDaoProvider.insert →
/// ref.invalidate(compositionKitsProvider) 刷新列表 → 关闭表单 + 成功 toast
class _CreateKitSheet extends ConsumerStatefulWidget {
  const _CreateKitSheet({required this.tokens});
  final ThemeTokens tokens;

  @override
  ConsumerState<_CreateKitSheet> createState() => _CreateKitSheetState();
}

class _CreateKitSheetState extends ConsumerState<_CreateKitSheet> {
  final _nameController = TextEditingController();
  String? _selectedSceneId;
  String? _selectedTemplateId;
  bool _saving = false;
  List<SceneRecord>? _scenes;
  List<TemplateRecord>? _templates;
  bool _loadError = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final scenesDao = await ref.read(scenesDaoProvider.future);
      final templatesDao = await ref.read(templatesDaoProvider.future);
      final scenes = await scenesDao.getAll();
      final templates = await templatesDao.getAll();
      if (!mounted) return;
      setState(() {
        _scenes = scenes;
        _templates = templates;
        // 默认选中第一个场景，避免用户必须手动选择
        _selectedSceneId = scenes.isEmpty ? null : scenes.first.id;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = true);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      LumiraToast.show(context, '请输入组合名称');
      return;
    }
    if (_selectedSceneId == null) {
      LumiraToast.show(context, '请选择关联场景');
      return;
    }
    setState(() => _saving = true);
    final toastContext = context;
    final navigator = Navigator.of(context);
    try {
      final dao = await ref.read(compositionKitsDaoProvider.future);
      final kit = CompositionKit(
        id: 'kit_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        sceneId: _selectedSceneId!,
        templateId: _selectedTemplateId,
        cameraOverrides: const {},
        note: '',
        coverUrl: null,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        lastUsedAt: null,
        usageCount: 0,
      );
      await dao.insert(kit);
      ref.invalidate(compositionKitsProvider);
      if (!mounted) return;
      navigator.pop();
      LumiraToast.show(toastContext, '已创建组合');
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '创建失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Padding(
      // 跟随键盘上推
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '新建组合',
              style: TextStyle(
                fontFamily: 'Noto Serif SC',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '将场景和模板组合成一套拍摄参数',
              style: TextStyle(fontSize: 12, color: tokens.textTertiary),
            ),
            const SizedBox(height: 18),
            _FieldLabel(text: '组合名称', required: true, tokens: tokens),
            const SizedBox(height: 6),
            LumiraTextField(
              controller: _nameController,
              hintText: '如：咖啡馆+柔光人像',
              maxLength: 30,
            ),
            const SizedBox(height: 14),
            _FieldLabel(text: '关联场景', required: true, tokens: tokens),
            const SizedBox(height: 6),
            _buildSceneField(tokens),
            const SizedBox(height: 14),
            _FieldLabel(text: '关联模板', required: false, tokens: tokens),
            const SizedBox(height: 6),
            _buildTemplateField(tokens),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _PillButton(
                    tokens: tokens,
                    label: '取消',
                    onTap: _saving ? null : () => Navigator.of(context).pop(),
                    primary: false,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PillButton(
                    tokens: tokens,
                    label: '保存',
                    onTap: _saving ? null : _save,
                    primary: true,
                    loading: _saving,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneField(ThemeTokens tokens) {
    if (_loadError) {
      return _HintBox(tokens: tokens, text: '加载场景失败');
    }
    if (_scenes == null) {
      return _LoadingBox(tokens: tokens);
    }
    if (_scenes!.isEmpty) {
      return _HintBox(tokens: tokens, text: '暂无可用场景，请先创建场景');
    }
    return LumiraDropdownFormField<String>(
      initialValue: _selectedSceneId,
      hintText: '选择场景',
      items: _scenes!
          .map((s) => DropdownMenuItem<String>(
                value: s.id,
                child: Text(
                  s.name.isEmpty ? s.id : s.name,
                  style: TextStyle(color: tokens.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedSceneId = v),
    );
  }

  Widget _buildTemplateField(ThemeTokens tokens) {
    if (_loadError) {
      return _HintBox(tokens: tokens, text: '加载模板失败');
    }
    if (_templates == null) {
      return _LoadingBox(tokens: tokens);
    }
    return LumiraDropdownFormField<String?>(
      initialValue: _selectedTemplateId,
      hintText: '选择模板',
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text(
            '不绑定模板',
            style: TextStyle(color: tokens.textTertiary),
          ),
        ),
        ..._templates!.map((t) => DropdownMenuItem<String?>(
              value: t.id,
              child: Text(
                t.name,
                style: TextStyle(color: tokens.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            )),
      ],
      onChanged: (v) => setState(() => _selectedTemplateId = v),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.text,
    required this.required,
    required this.tokens,
  });
  final String text;
  final bool required;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: tokens.textSecondary,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: tokens.danger),
            ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      alignment: Alignment.center,
      child: SizedBox(
        width: 18,
        height: 18,
        child: LumiraProgress.circular(strokeWidth: 2, size: 18),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox({required this.tokens, required this.text});
  final ThemeTokens tokens;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: tokens.textTertiary),
      ),
    );
  }
}

/// 胶囊状按钮（取消 / 保存）
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.tokens,
    required this.label,
    required this.onTap,
    required this.primary,
    this.loading = false,
  });
  final ThemeTokens tokens;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final bg = primary ? tokens.brand : tokens.surfaceAlt;
    final fg = primary
        ? tokens.canvas
        : (disabled ? tokens.textTertiary : tokens.textPrimary);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: disabled ? tokens.surfaceAlt : bg,
          borderRadius: BorderRadius.circular(9999),
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: LumiraProgress.circular(strokeWidth: 2, size: 18),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
      ),
    );
  }
}
