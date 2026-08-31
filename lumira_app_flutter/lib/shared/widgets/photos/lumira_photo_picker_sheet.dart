import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/services/file_picker_service.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/safe_temp_dir.dart';
import '../../../core/utils/image_cache.dart';
import '../../widgets/images/fullscreen_image_gallery.dart';
import '../../widgets/images/lumira_image.dart';
import '../../widgets/lumira/lumira.dart';
import '../../../features/gallery/widgets/sweep_select_grid.dart';

/// 选择照片底部弹窗（与「探店日记」保持一致的样式与交互）。
///
/// - 顶部：图标 + 标题 + 已选计数 + 「系统相册」导入 + 渐变「确定」按钮
/// - 中间：`SweepSelectGrid` 三列网格，点照片全屏查看、长按滑动多选、
///   右上角独立勾选按钮、选中高亮描边
/// - [maxCount] 为 null 时不限制选择张数；否则最多选择该数量
class LumiraPhotoPickerSheet extends ConsumerStatefulWidget {
  const LumiraPhotoPickerSheet({
    super.key,
    required this.tokens,
    required this.excludeIds,
    this.maxCount,
  });

  final ThemeTokens tokens;
  final Set<String> excludeIds;
  final int? maxCount;

  @override
  ConsumerState<LumiraPhotoPickerSheet> createState() =>
      _LumiraPhotoPickerSheetState();
}

class _LumiraPhotoPickerSheetState
    extends ConsumerState<LumiraPhotoPickerSheet> {
  List<GalleryItemRecord> _photos = const [];
  final Set<String> _selected = <String>{};
  bool _isLoading = true;
  bool _importing = false;

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

  bool get _unlimited => widget.maxCount == null;

  int get _remaining {
    if (_unlimited) return 1 << 30;
    return widget.maxCount! - _selected.length;
  }

  void _toggle(String id) {
    if (_selected.contains(id)) {
      setState(() => _selected.remove(id));
    } else if (_unlimited || _selected.length < widget.maxCount!) {
      setState(() => _selected.add(id));
    } else {
      LumiraToast.show(context, '最多选择 $widget.maxCount 张照片',
          duration: const Duration(milliseconds: 1500));
    }
  }

  /// 点击照片放大查看（全屏多图左右滑动 + 双指缩放）。
  void _openViewer(int index) {
    final p = _photos[index];
    final target = p.dataUrl ?? p.filePath ?? '';
    if (target.isEmpty) return;
    final urls = _photos
        .map((x) => x.dataUrl ?? x.filePath ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
    final initial = urls.indexOf(target);
    Navigator.of(context).push(MaterialPageRoute<dynamic>(
      builder: (_) => FullscreenImageGallery(
        urls: urls,
        initialIndex: initial < 0 ? 0 : initial,
      ),
    ));
  }

  /// 从系统相册选择照片，写入 App 本地目录并导入相册（gallery_items）。
  ///
  /// 选中的照片与本弹窗 App 相册已选合并，由「确定」统一返回。
  Future<void> _importFromSystemGallery() async {
    if (_importing) return;
    if (!_unlimited && _remaining <= 0) {
      LumiraToast.show(context, '最多选择 ${widget.maxCount} 张照片',
          duration: const Duration(milliseconds: 1500));
      return;
    }
    setState(() => _importing = true);
    try {
      final galleryDao = await ref.read(galleryDaoProvider.future);
      final files = await FilePickerService.pickImages(allowMultiple: true);
      final picked = files ?? const <PickedFile>[];
      final slots = picked.take(_remaining).toList();

      // 批量导入前先确定目标目录（path_provider 在鸿蒙未注册时自动降级）
      final dir = await getSafeDocumentsDirectory();
      final folder = Directory('${dir.path}/lumira_import');
      if (!await folder.exists()) {
        await folder.create(recursive: true);
      }

      final now = DateTime.now().millisecondsSinceEpoch;
      final newRecords = <GalleryItemRecord>[];
      for (var i = 0; i < slots.length; i++) {
        final full = await FilePickerService.ensureFullBytes(slots[i]);
        final bytes = full.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        final ext = _imageExtFrom(full);
        final path = '${folder.path}/import_${now}_$i.$ext';
        await File(path).writeAsBytes(bytes);
        final rec = GalleryItemRecord(
          id: 'photo_${now}_$i',
          filePath: path,
          createdAt: now,
          // 从系统相册引入的照片仅服务当前记录，不在内部相册展示
          isHidden: true,
        );
        await galleryDao.insert(rec);
        newRecords.add(rec);
      }
      ref.invalidate(galleryDaoProvider);

      if (newRecords.isNotEmpty && mounted) {
        setState(() {
          for (final r in newRecords) {
            _photos = [r, ..._photos.where((p) => p.id != r.id)];
            if (_unlimited || _selected.length < widget.maxCount!) {
              _selected.add(r.id);
            }
          }
        });
      }

      if (!mounted) return;
      if (picked.isEmpty) {
        // 用户取消系统相册，静默
      } else if (newRecords.isEmpty) {
        LumiraToast.show(context, '读取照片失败，请重试',
            duration: const Duration(seconds: 2));
      } else if (!_unlimited && slots.length < picked.length) {
        LumiraToast.show(
            context, '最多只能再选 $_remaining 张，其余未选择',
            duration: const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        LumiraToast.show(context, '读取照片失败：$e',
            duration: const Duration(seconds: 2));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// 从 [PickedFile] 推断图片扩展名；无法推断时回退 jpg（保证可解码）。
  String _imageExtFrom(PickedFile f) {
    final r = RegExp(r'^(jpg|jpeg|png|gif|bmp|webp|heic|heif)$');
    final extRaw = f.extension;
    final ext = (extRaw == null ? '' : extRaw.trim()).toLowerCase();
    if (ext.isNotEmpty && r.hasMatch(ext)) return ext == 'jpeg' ? 'jpg' : ext;
    final name = f.name;
    final idx = name.lastIndexOf('.');
    if (idx >= 0 && idx < name.length - 1) {
      final ext2 = name.substring(idx + 1).toLowerCase();
      if (r.hasMatch(ext2)) return ext2 == 'jpeg' ? 'jpg' : ext2;
    }
    return 'jpg';
  }

  void _confirm() {
    Navigator.of(context).pop(_selected
        .map((id) => _photos.firstWhere((p) => p.id == id))
        .toList());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final selectedLabel = _unlimited
        ? '已选 ${_selected.length} 张'
        : '已选 ${_selected.length} / ${widget.maxCount}';
    final canImport = _importing || _unlimited || _remaining > 0;

    return Container(
      decoration: BoxDecoration(
        color: tokens.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 说明：顶部拖柄由 LumiraBottomSheetContainer 统一提供，这里不再重复绘制
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
                        selectedLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canImport)
                  GestureDetector(
                    onTap: _importing ? null : _importFromSystemGallery,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.brand.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_importing)
                            SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: tokens.brand,
                              ),
                            )
                          else
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 15,
                              color: tokens.brand,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            _importing ? '选择中' : '系统相册',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: tokens.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
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
                        onTap: _confirm,
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
                    : SweepSelectGrid(
                        itemCount: _photos.length,
                        idOf: (i) => _photos[i].id,
                        selectedIds: _selected,
                        onSelectionChanged: (next) => setState(() {
                          _selected
                            ..clear()
                            ..addAll(next);
                        }),
                        maxSelectable: _unlimited ? null : widget.maxCount,
                        onMaxReached: () => LumiraToast.show(
                          context,
                          '最多选择 ${widget.maxCount} 张照片',
                          duration: const Duration(milliseconds: 1500),
                        ),
                        padding: const EdgeInsets.all(16),
                        crossAxisCount: 3,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        aspectRatio: 1,
                        itemBuilder: (_, i, selected, startSweep) {
                          final p = _photos[i];
                          return GestureDetector(
                            onTap: () => _openViewer(i),
                            onLongPress: () => startSweep(),
                            behavior: HitTestBehavior.opaque,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 照片主体：铺满整个格子
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: _buildThumb(p, tokens),
                                ),
                                // 选中高亮描边
                                AnimatedOpacity(
                                  opacity: selected ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 200),
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
                                // 勾选按钮（独立可点，点击才勾选，不触发放大）
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _toggle(p.id),
                                    behavior: HitTestBehavior.opaque,
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 24,
                                      height: 24,
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
                                            color:
                                                Colors.black.withOpacity(0.15),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: selected
                                          ? const Icon(
                                              Icons.check_rounded,
                                              size: 15,
                                              color: Colors.white,
                                            )
                                          : null,
                                    ),
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
            color: tokens.textTertiary, size: 24),
      );
    }
    return url.startsWith('http')
        ? CachedNetworkImage(
            url: url,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: tokens.surfaceAlt,
              child: Icon(Icons.broken_image_outlined,
                  color: tokens.textTertiary, size: 24),
            ),
          )
        : LumiraImage(
            url,
            fit: BoxFit.cover,
            errorWidget: Container(
              color: tokens.surfaceAlt,
              child: Icon(Icons.broken_image_outlined,
                  color: tokens.textTertiary, size: 24),
            ),
          );
  }
}