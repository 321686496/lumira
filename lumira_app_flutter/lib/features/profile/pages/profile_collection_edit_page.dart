import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../shared/widgets/images/lumira_image.dart';
import '../../../core/db/dao/collections_dao.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../providers/collection_providers.dart';

/// 精选集编辑页（新建 / 编辑）
///
/// - [collectionId] 为 null：新建模式，初始空表单
/// - [collectionId] 非 null：编辑模式，加载现有精选集元信息 + 关联照片
///
/// 功能：
/// 1. 名称 TextField（必填）
/// 2. 描述 TextField（可空）
/// 3. 已添加照片列表（可删除、点击设为封面）
/// 4. "添加照片"按钮 → 弹出底部 Sheet 选择器（读 GalleryDao.getAll）
/// 5. 保存按钮 → 调 CollectionService.createManualCollection / updateManualCollection
class ProfileCollectionEditPage extends ConsumerStatefulWidget {
  const ProfileCollectionEditPage({super.key, this.collectionId});

  final String? collectionId;

  @override
  ConsumerState<ProfileCollectionEditPage> createState() =>
      _ProfileCollectionEditPageState();
}

class _ProfileCollectionEditPageState
    extends ConsumerState<ProfileCollectionEditPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _scrolled = false;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  /// 当前编辑的精选集记录（编辑模式加载后填充）
  CollectionRecord? _existing;

  /// 已选照片 ID 列表（顺序即展示顺序；首张为封面）
  final List<String> _photoIds = <String>[];

  /// 缓存照片详情，避免重复查询
  final Map<String, GalleryItemRecord> _photoCache = <String, GalleryItemRecord>{};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    // Forced fix: 在 initState 后帧加载，避免 build 期间同步触发 setState
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    const threshold = 12.0;
    final s = _scrollController.offset;
    final next = s > threshold;
    if (next != _scrolled) {
      setState(() => _scrolled = next);
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      if (widget.collectionId != null) {
        final service = await ref.read(collectionServiceProvider.future);
        final record = await service.getCollection(widget.collectionId!);
        if (record == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _loadError = '精选集不存在';
            });
          }
          return;
        }
        _existing = record;
        _nameController.text = record.name;
        _descController.text = record.description ?? '';
        // 加载 manual 关联照片
        final photos = await service.getCollectionPhotos(
          widget.collectionId!,
          limit: 100,
        );
        _photoIds
          ..clear()
          ..addAll(photos.map((p) => p.id));
        for (final p in photos) {
          _photoCache[p.id] = p;
        }
      }
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadError = '加载失败：$e';
        });
      }
    }
  }

  Future<void> _openPhotoPicker() async {
    final tokens = ref.read(themeTokensProvider);
    final picked = await showLumiraBottomSheet<List<GalleryItemRecord>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PhotoPickerSheet(
        tokens: tokens,
        excludeIds: _photoIds.toSet(),
      ),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() {
      for (final p in picked) {
        if (!_photoIds.contains(p.id)) {
          _photoIds.add(p.id);
          _photoCache[p.id] = p;
        }
      }
    });
  }

  Future<void> _removePhoto(String id) async {
    setState(() {
      _photoIds.remove(id);
      _photoCache.remove(id);
    });
  }

  Future<void> _setCover(String id) async {
    setState(() {
      _photoIds.remove(id);
      _photoIds.insert(0, id);
    });
    LumiraToast.show(context, '已设为封面', duration: const Duration(milliseconds: 1200));
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      LumiraToast.show(context, '请输入精选集名称');
      return;
    }
    setState(() => _isSaving = true);
    final toastContext = context;
    try {
      final service = await ref.read(collectionServiceProvider.future);
      final coverPhotoId =
          _photoIds.isNotEmpty ? _photoIds.first : null;
      if (_existing == null) {
        // 新建
        final id = await service.createManualCollection(
          name: name,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          coverPhotoId: coverPhotoId,
        );
        // 添加照片
        for (final pid in _photoIds) {
          await service.addPhotoToCollection(id, pid);
        }
      } else {
        // 编辑：更新元信息 + 同步照片关联
        final updated = CollectionRecord(
          id: _existing!.id,
          name: name,
          description: _descController.text.trim().isEmpty
              ? null
              : _descController.text.trim(),
          coverPhotoId: coverPhotoId ?? _existing!.coverPhotoId,
          type: CollectionType.manual,
          sourceMeta: _existing!.sourceMeta,
          photoCount: _photoIds.length,
          createdAt: _existing!.createdAt,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );
        await service.updateManualCollection(updated);
        // 同步关联：先读现有，再 diff
        final existingPhotos = await service.getCollectionPhotos(
          _existing!.id,
          limit: 100,
        );
        final existingIds = existingPhotos.map((p) => p.id).toSet();
        final newIds = _photoIds.toSet();
        // 删除被移除的
        for (final old in existingIds) {
          if (!newIds.contains(old)) {
            await service.removePhotoFromCollection(_existing!.id, old);
          }
        }
        // 添加新增的
        for (final pid in _photoIds) {
          if (!existingIds.contains(pid)) {
            await service.addPhotoToCollection(_existing!.id, pid);
          }
        }
        // 重排顺序
        if (_photoIds.isNotEmpty) {
          await service.reorderPhotosInCollection(_existing!.id, _photoIds);
        }
      }
      // 刷新列表
      ref.invalidate(collectionsListProvider);
      if (!mounted) return;
      LumiraToast.show(toastContext, _existing == null ? '已创建精选集' : '已保存修改', duration: const Duration(milliseconds: 1500));
      context.pop();
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '保存失败：$e', duration: const Duration(milliseconds: 1500));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final isEdit = _existing != null;

    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: isEdit ? '编辑精选集' : '新建精选集',
        transparent: true,
        showBackButton: true,
        scrolled: _scrolled,
      ),
      body: Stack(
        children: [
          // 整页统一覆盖 GlassBackground，避免保存按钮区露出 canvas（“只有一半 glass 背景”）
          const Positioned.fill(
            child: GlassBackground(variant: GlassBackgroundVariant.profile),
          ),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? Center(child: LumiraProgress.circular())
                      : _loadError != null
                          ? _ErrorState(
                              tokens: tokens,
                              message: _loadError!,
                              onRetry: _loadInitial,
                            )
                          : _buildForm(tokens),
                ),
                if (_isLoading || _loadError != null)
                  const SizedBox.shrink()
                else
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
                      child: LumiraButton(
                        variant: ButtonVariant.primary,
                        onPressed: _isSaving ? null : _save,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(_isSaving ? '保存中…' : '保存'),
                          ],
                        ),
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

  Widget _buildForm(ThemeTokens tokens) {
    // Forced fix: extendBodyBehindAppBar=true 时 body 从 y=0 开始，
    // 用 viewPadding.top（状态栏） + 48（nav 内容高度） 精确占位
    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 名称
          FadeUp(
            child: _LabelField(
              tokens: tokens,
              label: '精选集名称',
              required_: true,
              child: LumiraTextField(
                controller: _nameController,
                hintText: '给精选集起个名字',
                maxLength: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 描述
          FadeUp(
            delay: const Duration(milliseconds: 60),
            child: _LabelField(
              tokens: tokens,
              label: '描述',
              child: LumiraTextField(
                controller: _descController,
                hintText: '写点什么（可选）',
                maxLength: 100,
                maxLines: 3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 照片列表
          FadeUp(
            delay: const Duration(milliseconds: 120),
            child: _PhotosSection(
              tokens: tokens,
              photoIds: _photoIds,
              photoCache: _photoCache,
              onAdd: _openPhotoPicker,
              onRemove: _removePhoto,
              onSetCover: _setCover,
            ),
          ),
        ],
      ),
    );
  }
}

/// 标签 + 字段容器
class _LabelField extends StatelessWidget {
  const _LabelField({
    required this.tokens,
    required this.label,
    required this.child,
    this.required_ = false,
  });
  final ThemeTokens tokens;
  final String label;
  final Widget child;
  final bool required_;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: tokens.textSecondary,
              ),
              children: [
                TextSpan(text: label),
                if (required_)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: tokens.danger),
                  ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({
    required this.tokens,
    required this.photoIds,
    required this.photoCache,
    required this.onAdd,
    required this.onRemove,
    required this.onSetCover,
  });
  final ThemeTokens tokens;
  final List<String> photoIds;
  final Map<String, GalleryItemRecord> photoCache;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onRemove;
  final Future<void> Function(String id) onSetCover;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Text(
                '照片',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${photoIds.length} 张',
                style: TextStyle(
                  fontSize: 11,
                  color: tokens.textTertiary,
                ),
              ),
              const Spacer(),
              if (photoIds.isNotEmpty)
                GestureDetector(
                  onTap: onAdd,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 16, color: tokens.brand),
                        const SizedBox(width: 4),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.brand,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (photoIds.isEmpty)
          _AddPhotoPrompt(tokens: tokens, onAdd: onAdd)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.0,
            ),
            itemCount: photoIds.length + 1,
            itemBuilder: (context, i) {
              if (i == 0 && photoIds.isNotEmpty) {
                // 第 0 个槽位为"添加"按钮
                return _AddPhotoCell(tokens: tokens, onAdd: onAdd);
              }
              final idx = i - 1;
              if (idx >= photoIds.length) {
                return const SizedBox.shrink();
              }
              final id = photoIds[idx];
              final photo = photoCache[id];
              final isCover = idx == 0;
              return _PhotoEditCell(
                tokens: tokens,
                photo: photo,
                isCover: isCover,
                onRemove: () => onRemove(id),
                onSetCover: () => onSetCover(id),
              );
            },
          ),
        if (photoIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              '点击照片设为封面，点击右上角 × 删除',
              style: TextStyle(
                fontSize: 11,
                color: tokens.textTertiary,
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPhotoPrompt extends StatelessWidget {
  const _AddPhotoPrompt({required this.tokens, required this.onAdd});
  final ThemeTokens tokens;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 28, color: tokens.textTertiary),
            const SizedBox(height: 6),
            Text(
              '添加照片',
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

class _AddPhotoCell extends StatelessWidget {
  const _AddPhotoCell({required this.tokens, required this.onAdd});
  final ThemeTokens tokens;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, size: 22, color: tokens.textTertiary),
            const SizedBox(height: 2),
            Text(
              '添加',
              style: TextStyle(fontSize: 10, color: tokens.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoEditCell extends StatelessWidget {
  const _PhotoEditCell({
    required this.tokens,
    required this.photo,
    required this.isCover,
    required this.onRemove,
    required this.onSetCover,
  });
  final ThemeTokens tokens;
  final GalleryItemRecord? photo;
  final bool isCover;
  final VoidCallback onRemove;
  final VoidCallback onSetCover;

  @override
  Widget build(BuildContext context) {
    final url = photo?.dataUrl ?? photo?.filePath;
    return GestureDetector(
      onTap: onSetCover,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url == null || url.isEmpty
                ? Container(
                    color: tokens.surfaceAlt,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: tokens.textTertiary),
                    ),
                  )
                : url.startsWith('http')
                    ? CachedNetworkImage(
                        url: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: Container(
                          color: tokens.surfaceAlt,
                          child: Icon(Icons.broken_image_outlined,
                              color: tokens.textTertiary),
                        ),
                      )
                    : LumiraImage(
                        url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorWidget: Container(
                          color: tokens.surfaceAlt,
                          child: Icon(Icons.broken_image_outlined,
                              color: tokens.textTertiary),
                        ),
                      ),
          ),
          // 封面标识
          if (isCover)
            Positioned(
              top: 4,
              left: 4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.brand,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: const Text(
                  '封面',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          // 删除按钮
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.tokens,
    required this.message,
    required this.onRetry,
  });
  final ThemeTokens tokens;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: tokens.danger),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          LumiraButton(
            variant: ButtonVariant.secondary,
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}

/// 照片选择器底部 Sheet
class _PhotoPickerSheet extends ConsumerStatefulWidget {
  const _PhotoPickerSheet({
    required this.tokens,
    required this.excludeIds,
  });
  final ThemeTokens tokens;
  final Set<String> excludeIds;

  @override
  ConsumerState<_PhotoPickerSheet> createState() => _PhotoPickerSheetState();
}

class _PhotoPickerSheetState extends ConsumerState<_PhotoPickerSheet> {
  List<GalleryItemRecord> _photos = const [];
  final Set<String> _selected = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final db = await ref.read(databaseProvider.future);
      final photos = await GalleryDao(db).getAll(limit: 200);
      if (mounted) {
        setState(() {
          _photos = photos.where((p) => !widget.excludeIds.contains(p.id)).toList();
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _photos = const [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final height = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                Text(
                  '选择照片',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '已选 ${_selected.length} 张',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textTertiary,
                  ),
                ),
                const Spacer(),
                LumiraButton(
                  variant: ButtonVariant.ghost,
                  onPressed: _selected.isEmpty
                      ? null
                      : () => Navigator.of(context).pop(_selected
                          .map((id) => _photos.firstWhere((p) => p.id == id))
                          .toList()),
                  child: const Text('确定'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // 内容
          Expanded(
            child: _isLoading
                ? Center(child: LumiraProgress.circular())
                : _photos.isEmpty
                    ? Center(
                        child: Text(
                          '相册暂无可选照片',
                          style: TextStyle(
                              color: tokens.textTertiary, fontSize: 13),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          mainAxisSpacing: 6,
                          crossAxisSpacing: 6,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (_, i) {
                          final p = _photos[i];
                          final selected = _selected.contains(p.id);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (selected) {
                                  _selected.remove(p.id);
                                } else {
                                  _selected.add(p.id);
                                }
                              });
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: _buildThumb(p, tokens),
                                ),
                                if (selected)
                                  Positioned.fill(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: tokens.brand.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                            color: tokens.brand, width: 2),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: selected
                                          ? tokens.brand
                                          : Colors.black45,
                                    ),
                                    child: selected
                                        ? const Icon(Icons.check,
                                            size: 12, color: Colors.white)
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumb(GalleryItemRecord p, ThemeTokens tokens) {
    final url = p.dataUrl ?? p.filePath;
    if (url == null || url.isEmpty) {
      return Container(
        color: tokens.surfaceAlt,
        child: Icon(Icons.broken_image_outlined,
            color: tokens.textTertiary, size: 20),
      );
    }
    return url.startsWith('http')
        ? CachedNetworkImage(url: url, fit: BoxFit.cover,
            errorWidget: Container(
                  color: tokens.surfaceAlt,
                  child: Icon(Icons.broken_image_outlined,
                      color: tokens.textTertiary, size: 20),
                ))
        : LumiraImage(url, fit: BoxFit.cover,
            errorWidget: Container(
                  color: tokens.surfaceAlt,
                  child: Icon(Icons.broken_image_outlined,
                      color: tokens.textTertiary, size: 20),
                ));
  }
}
