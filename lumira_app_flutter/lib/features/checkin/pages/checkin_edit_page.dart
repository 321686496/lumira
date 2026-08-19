import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/common/fade_up.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/checkin_categories.dart';
import '../data/checkin_models.dart';
import '../data/checkin_providers.dart';
import '../widgets/checkin_common.dart';

/// 探店足迹新增/编辑页
///
/// - [checkinId] 非空：编辑模式（预填记录 + 关联照片）
/// - [photoId] 非空：相册入口（预填该照片）
class CheckinEditPage extends ConsumerStatefulWidget {
  const CheckinEditPage({super.key, this.checkinId, this.photoId});

  final String? checkinId;
  final String? photoId;

  @override
  ConsumerState<CheckinEditPage> createState() => _CheckinEditPageState();
}

class _CheckinEditPageState extends ConsumerState<CheckinEditPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _placeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  int _visitedAt = 0;
  int _rating = 0;
  String _category = 'coffee';
  final List<String> _photoIds = <String>[];
  final Map<String, GalleryItemRecord> _photoCache = <String, GalleryItemRecord>{};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  CheckinRecord? _existing;

  @override
  void initState() {
    super.initState();
    _visitedAt = DateTime.now().millisecondsSinceEpoch;
    // Forced fix: postFrameCallback 后加载，避免 build 期间同步 setState（同 collection edit）
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _placeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    try {
      final dao = await ref.read(checkinDaoProvider.future);
      if (widget.checkinId != null) {
        final record = await dao.getById(widget.checkinId!);
        if (record == null) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _loadError = '足迹不存在';
            });
          }
          return;
        }
        _existing = record;
        _nameController.text = record.name;
        _placeController.text = record.place;
        _noteController.text = record.note;
        _rating = record.rating;
        _category = record.category;
        _visitedAt = record.visitedAt;
        final ids = await dao.getPhotoIds(record.id);
        _photoIds.addAll(ids);
        final galleryDao = await ref.read(galleryDaoProvider.future);
        for (final pid in ids) {
          final p = await galleryDao.getById(pid);
          if (p != null) _photoCache[pid] = p;
        }
      } else if (widget.photoId != null && widget.photoId!.isNotEmpty) {
        final pid = widget.photoId!;
        final galleryDao = await ref.read(galleryDaoProvider.future);
        final p = await galleryDao.getById(pid);
        if (p != null) {
          _photoIds.add(pid);
          _photoCache[pid] = p;
        }
      }
      if (mounted) setState(() => _isLoading = false);
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
    if (_photoIds.length >= 9) {
      LumiraToast.show(context, '最多选择 9 张照片',
          duration: const Duration(milliseconds: 1500));
      return;
    }
    final tokens = ref.read(themeTokensProvider);
    final picked = await showLumiraBottomSheet<List<GalleryItemRecord>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CheckinPhotoPickerSheet(
        tokens: tokens,
        excludeIds: _photoIds.toSet(),
        maxCount: 9 - _photoIds.length,
      ),
    );
    if (picked == null || picked.isEmpty || !mounted) return;
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

  Future<void> _pickDate() async {
    final tokens = ref.read(themeTokensProvider);
    final now = DateTime.now();
    final initial = DateTime.fromMillisecondsSinceEpoch(_visitedAt);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.light(
            primary: tokens.brand,
            surface: tokens.surface,
            onSurface: tokens.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _visitedAt = DateTime(picked.year, picked.month, picked.day)
            .millisecondsSinceEpoch;
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      LumiraToast.show(context, '请输入店名');
      return;
    }
    setState(() => _isSaving = true);
    final toastContext = context;
    try {
      final dao = await ref.read(checkinDaoProvider.future);
      final now = DateTime.now().millisecondsSinceEpoch;
      final place = _placeController.text.trim();
      final note = _noteController.text.trim();
      if (_existing == null) {
        final id = 'checkin_$now';
        await dao.insert(CheckinRecord(
          id: id,
          name: name,
          place: place,
          category: _category,
          rating: _rating,
          note: note,
          visitedAt: _visitedAt,
          createdAt: now,
          updatedAt: now,
        ));
        await dao.replacePhotos(id, _photoIds);
      } else {
        await dao.update(CheckinRecord(
          id: _existing!.id,
          name: name,
          place: place,
          category: _category,
          rating: _rating,
          note: note,
          visitedAt: _visitedAt,
          createdAt: _existing!.createdAt,
          updatedAt: now,
        ));
        await dao.replacePhotos(_existing!.id, _photoIds);
      }
      ref.invalidate(checkinsProvider);
      ref.invalidate(checkinTotalCountProvider);
      if (_existing != null) {
        ref.invalidate(checkinDetailProvider(_existing!.id));
      }
      if (!mounted) return;
      LumiraToast.show(
        toastContext,
        _existing == null ? '已保存' : '已保存修改',
        duration: const Duration(milliseconds: 1500),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(toastContext, '保存失败：$e',
          duration: const Duration(milliseconds: 1500));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(appThemeProvider).tokens;
    final isEdit = _existing != null;
    return Scaffold(
      backgroundColor: tokens.canvas,
      extendBodyBehindAppBar: true,
      appBar: LumiraNav(
        title: isEdit ? '编辑足迹' : '记录探店',
        transparent: true,
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(child: LumiraProgress.circular())
          : _loadError != null
              ? _ErrorState(
                  tokens: tokens,
                  message: _loadError!,
                  onRetry: _loadInitial,
                )
              : _buildForm(tokens),
      bottomNavigationBar: _isLoading || _loadError != null
          ? null
          : SafeArea(
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
    );
  }

  Widget _buildForm(ThemeTokens tokens) {
    // Forced fix: extendBodyBehindAppBar=true 时 body 从 y=0 开始（同 collection edit）
    final topPadding = MediaQuery.of(context).viewPadding.top + 48;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeUp(
            child: _LabelField(
              tokens: tokens,
              label: '店名',
              required_: true,
              child: LumiraTextField(
                controller: _nameController,
                hintText: '店铺名称',
                maxLength: 30,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeUp(
            delay: const Duration(milliseconds: 60),
            child: _LabelField(
              tokens: tokens,
              label: '地点',
              child: LumiraTextField(
                controller: _placeController,
                hintText: '地址或区域（可选）',
                maxLength: 50,
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeUp(
            delay: const Duration(milliseconds: 120),
            child: _LabelField(
              tokens: tokens,
              label: '打卡日期',
              child: GestureDetector(
                onTap: _pickDate,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tokens.divider, width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined,
                          size: 16, color: tokens.textTertiary),
                      const SizedBox(width: 8),
                      Text(
                        formatCheckinDate(_visitedAt),
                        style: TextStyle(fontSize: 14, color: tokens.textPrimary),
                      ),
                      const Spacer(),
                      Icon(Icons.chevron_right, size: 18, color: tokens.textTertiary),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeUp(
            delay: const Duration(milliseconds: 180),
            child: _LabelField(
              tokens: tokens,
              label: '评分',
              child: _RatingSelector(
                tokens: tokens,
                rating: _rating,
                onChanged: (v) => setState(() => _rating = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeUp(
            delay: const Duration(milliseconds: 240),
            child: _LabelField(
              tokens: tokens,
              label: '分类',
              child: _CategorySelector(
                tokens: tokens,
                category: _category,
                onChanged: (v) => setState(() => _category = v),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FadeUp(
            delay: const Duration(milliseconds: 300),
            child: _LabelField(
              tokens: tokens,
              label: '心得',
              child: LumiraTextField(
                controller: _noteController,
                hintText: '写点什么…（可选）',
                maxLength: 200,
                maxLines: 4,
              ),
            ),
          ),
          const SizedBox(height: 20),
          FadeUp(
            delay: const Duration(milliseconds: 360),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CheckinPhotosSection(
              tokens: tokens,
              photoIds: _photoIds,
              photoCache: _photoCache,
              onAdd: _openPhotoPicker,
              onRemove: _removePhoto,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// === 私有 widget ===

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
                  TextSpan(text: ' *', style: TextStyle(color: tokens.danger)),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

/// 5 星点选（点当前星再点一次清零）
class _RatingSelector extends StatelessWidget {
  const _RatingSelector({
    required this.tokens,
    required this.rating,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final int rating;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        final filled = i < rating;
        return GestureDetector(
          onTap: () => onChanged(filled && rating == i + 1 ? 0 : i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              filled ? Icons.star : Icons.star_border,
              size: 28,
              color: filled ? tokens.brand : tokens.textTertiary,
            ),
          ),
        );
      }),
    );
  }
}

/// 7 分类单选
class _CategorySelector extends StatelessWidget {
  const _CategorySelector({
    required this.tokens,
    required this.category,
    required this.onChanged,
  });

  final ThemeTokens tokens;
  final String category;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final c in kCheckinCategories)
          GestureDetector(
            onTap: () => onChanged(c.key),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.key == category ? c.iconBgColor : tokens.surface,
                borderRadius: BorderRadius.circular(1000),
                border: Border.all(
                  color: c.key == category ? c.iconColor : tokens.divider,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c.icon,
                    size: 14,
                    color: c.key == category ? c.iconColor : tokens.textTertiary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 13,
                      color: c.key == category ? c.iconColor : tokens.textSecondary,
                      fontWeight: c.key == category ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 照片区：3 列网格，最多 9 张
class _CheckinPhotosSection extends StatelessWidget {
  const _CheckinPhotosSection({
    required this.tokens,
    required this.photoIds,
    required this.photoCache,
    required this.onAdd,
    required this.onRemove,
  });

  final ThemeTokens tokens;
  final List<String> photoIds;
  final Map<String, GalleryItemRecord> photoCache;
  final VoidCallback onAdd;
  final Future<void> Function(String id) onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with icon and count
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tokens.brand.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 16,
                  color: tokens.brand,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '照片',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${photoIds.length}/9',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (photoIds.isNotEmpty && photoIds.length < 9)
                GestureDetector(
                  onTap: onAdd,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: tokens.brand.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 14, color: tokens.brand),
                        const SizedBox(width: 2),
                        Text(
                          '添加',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Photo grid or empty state
        if (photoIds.isEmpty)
          _AddPhotoPrompt(tokens: tokens, onAdd: onAdd)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: photoIds.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) return _AddPhotoCell(tokens: tokens, onAdd: onAdd);
              final idx = i - 1;
              if (idx >= photoIds.length) return const SizedBox.shrink();
              final id = photoIds[idx];
              final photo = photoCache[id];
              final isCover = idx == 0;
              return _PhotoEditCell(
                tokens: tokens,
                photo: photo,
                isCover: isCover,
                onRemove: () => onRemove(id),
              );
            },
          ),
        // Footer hint
        if (photoIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12, left: 4),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 12,
                  color: tokens.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '第一张作为封面',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textTertiary,
                  ),
                ),
              ],
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
        height: 120,
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tokens.brand.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: tokens.brand.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 24,
                color: tokens.brand,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '添加照片',
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '从相册选择，最多 9 张',
              style: TextStyle(
                fontSize: 11,
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tokens.brand.withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: tokens.brand.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add,
                size: 18,
                color: tokens.brand,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '添加',
              style: TextStyle(
                fontSize: 11,
                color: tokens.brand,
                fontWeight: FontWeight.w500,
              ),
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
  });

  final ThemeTokens tokens;
  final GalleryItemRecord? photo;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final url = photo?.dataUrl ?? photo?.filePath;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: tokens.shadowConvexSubtle,
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: url == null || url.isEmpty
                ? Container(
                    color: tokens.surfaceAlt,
                    child: Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: tokens.textTertiary, size: 24),
                    ),
                  )
                : CheckinPhotoImage(url: url, tokens: tokens, fit: BoxFit.cover),
          ),
          // Gradient overlay for better contrast
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.2),
                  ],
                  stops: const [0.0, 0.3, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Cover badge
          if (isCover)
            Positioned(
              bottom: 6,
              left: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tokens.brand,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: tokens.brand.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    Icon(
                      Icons.star_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                    SizedBox(width: 2),
                    Text(
                      '封面',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // Remove button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
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

/// 选择照片的底部弹窗
class _CheckinPhotoPickerSheet extends ConsumerStatefulWidget {
  const _CheckinPhotoPickerSheet({
    required this.tokens,
    required this.excludeIds,
    required this.maxCount,
  });

  final ThemeTokens tokens;
  final Set<String> excludeIds;
  final int maxCount;

  @override
  ConsumerState<_CheckinPhotoPickerSheet> createState() =>
      _CheckinPhotoPickerSheetState();
}

class _CheckinPhotoPickerSheetState extends ConsumerState<_CheckinPhotoPickerSheet> {
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
      final galleryDao = await ref.read(galleryDaoProvider.future);
      final photos = await galleryDao.getAll(limit: 200);
      if (mounted) {
        setState(() {
          _photos = photos
              .where((p) => !widget.excludeIds.contains(p.id))
              .toList();
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

  void _toggle(String id) {
    if (_selected.contains(id)) {
      setState(() => _selected.remove(id));
    } else if (_selected.length < widget.maxCount) {
      setState(() => _selected.add(id));
    } else {
      LumiraToast.show(context, '最多选择 9 张照片',
          duration: const Duration(milliseconds: 1500));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: tokens.brand.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: tokens.brand,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择照片',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '已选 ${_selected.length} / ${widget.maxCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_selected.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tokens.brand, tokens.brand.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: tokens.brand.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => Navigator.of(context).pop(_selected
                            .map((id) => _photos.firstWhere((p) => p.id == id))
                            .toList()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          child: const Text(
                            '确定',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Divider
          Container(
            height: 1,
            color: tokens.divider.withOpacity(0.5),
          ),
          // Content
          Expanded(
            child: _isLoading
                ? Center(child: LumiraProgress.circular())
                : _photos.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_library_outlined,
                              size: 64,
                              color: tokens.textTertiary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '相册还没有照片',
                              style: TextStyle(
                                color: tokens.textTertiary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (_, i) {
                          final p = _photos[i];
                          final selected = _selected.contains(p.id);
                          return GestureDetector(
                            onTap: () => _toggle(p.id),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              child: Stack(
                                children: [
                                  // Photo
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: _buildThumb(p, tokens),
                                  ),
                                  // Selection overlay
                                  AnimatedOpacity(
                                    opacity: selected ? 1.0 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: tokens.brand.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: tokens.brand,
                                            width: 2.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Checkbox
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: selected
                                              ? tokens.brand
                                              : Colors.white.withOpacity(0.9),
                                          border: Border.all(
                                            color: selected
                                                ? tokens.brand
                                                : Colors.white.withOpacity(0.6),
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.15),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                size: 14,
                                                color: Colors.white,
                                              )
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
        child:
            Icon(Icons.broken_image_outlined, color: tokens.textTertiary, size: 24),
      );
    }
    return CheckinPhotoImage(url: url, tokens: tokens, fit: BoxFit.cover);
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
