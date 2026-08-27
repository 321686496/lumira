import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumira_app_flutter/core/utils/image_cache.dart';

import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/images/lumira_image.dart';
import '../../../shared/widgets/common/glass_background.dart';
import '../../../shared/widgets/common/lumira_surface.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../../capture/domain/filter_recipe.dart';
import '../../capture/domain/photo_template.dart';
import '../../capture/domain/post_process_delta.dart';
import '../../capture/services/photo_post_processor.dart';
import '../../capture/widgets/post_process_color_tab.dart';
import '../../capture/widgets/post_process_detail_tab.dart';
import '../../capture/widgets/preview_edit_panel.dart';
import '../../profile/providers/collection_providers.dart';
import '../widgets/photo_crop_layer.dart';

/// 相册照片修图页（独立编辑页）
///
/// UI 设计（参考 iPhone「照片」编辑交互）：
/// - 浅色暖白配色，贴合项目 Neumorphic 美学
/// - 照片居中放大，双指缩放查看细节
/// - 顶部导航：取消（左）/ 收藏 + 保存（右），画布右上角悬浮「对比」
/// - 底部横向工具条（色彩 / 细节 / 滤镜 / 裁剪旋转 / 重置），
///   点选工具后从底部滑出对应参数面板，再次点击收起
/// - 色彩/细节采用「横向调节条 + 单滑块」两级交互，避免清一色滑动条堆叠
///
/// 保存成功后自动 pop 返回详情页。
class GalleryEditPage extends ConsumerStatefulWidget {
  const GalleryEditPage({super.key, this.photoId});

  final String? photoId;

  @override
  ConsumerState<GalleryEditPage> createState() => _GalleryEditPageState();
}

/// 底部工具条工具类型
enum _EditTool { color, detail, filter, crop }

class _GalleryEditPageState extends ConsumerState<GalleryEditPage> {
  /// 照片已烘焙的后期参数（拍照/上次保存时烘焙进 JPEG 的色彩矩阵参数）。
  late PostProcess _bakedPostProcess;

  /// 本地编辑增量参数（仅影响当前预览，初始为默认值 0）。
  PostProcess _localPostProcess = const PostProcess(color: PostProcessColor());
  TransformParams _localTransform = const TransformParams();
  bool _isExporting = false;

  GalleryItemRecord? _photo;
  bool _isLoading = true;
  bool _isInitialLoaded = false;

  /// 只读模式标志（originalPath == null 时为 true）
  bool _isReadOnly = false;

  /// 当前展开的工具（null = 收起参数面板）
  _EditTool? _activeTool;

  /// 对比模式：切换后显示原图（不应用滤镜）
  bool _isComparing = false;

  Future<void> _loadPhoto(GalleryDao dao) async {
    try {
      if (widget.photoId == null) {
        if (mounted) {
          setState(() {
            _photo = null;
            _isLoading = false;
          });
        }
        return;
      }
      final photo = await dao.getById(widget.photoId!);
      if (mounted) {
        setState(() {
          _photo = photo;
          _bakedPostProcess =
              photo?.postProcess ?? const PostProcess(color: PostProcessColor());
          _localPostProcess = const PostProcess(color: PostProcessColor());
          _localTransform = photo?.transform ?? const TransformParams();
          _isReadOnly = photo?.originalPath == null;
          _isLoading = false;
        });
      }
    } catch (e, st) {
      debugPrint('[gallery-edit] _loadPhoto 异常: $e\n$st');
      if (mounted) {
        setState(() {
          _photo = null;
          _isLoading = false;
        });
      }
    }
  }

  void _showReadOnlyToast() {
    if (!mounted) return;
    LumiraToast.show(
      context,
      '原图未保留，无法编辑',
      duration: const Duration(seconds: 2),
    );
  }

  void _onPostProcessChanged(PostProcess next) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() => _localPostProcess = next);
  }

  void _onTransformChanged(TransformParams t) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() => _localTransform = t);
  }

  /// 烘焙基线（未提供时为全零基线）。
  PostProcess get _baked => _bakedPostProcess;

  /// 用户在色彩/细节/滤镜面板看到并操作的全量参数（baked + 增量）。
  PostProcess get _fullForEdit => fullOf(_baked, _localPostProcess);

  /// 由新的全量值反推增量并更新本地增量参数。
  void _updatePostFromFull(PostProcess newFull) =>
      _onPostProcessChanged(deltaOf(_baked, newFull));

  void _toggleTool(_EditTool tool) {
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _activeTool = _activeTool == tool ? null : tool;
    });
    HapticFeedback.lightImpact();
  }

  void _reset() {
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localPostProcess = const PostProcess(color: PostProcessColor());
      _localTransform = const TransformParams();
    });
    HapticFeedback.lightImpact();
  }

  /// 将裁剪比例字符串解析为数值宽高比（width/height），null 表示自由裁剪。
  double? _parseCropAspectRatio(String ratio) {
    if (ratio == 'free' || ratio == 'none' || ratio == 'fullscreen') {
      return null;
    }
    if (ratio == '1:1') return 1.0;
    final parts = ratio.split(':');
    if (parts.length == 2) {
      final w = double.tryParse(parts[0]);
      final h = double.tryParse(parts[1]);
      if (w != null && h != null && w > 0 && h > 0) return w / h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);
    final daoAsync = ref.watch(galleryDaoProvider);
    return Scaffold(
      backgroundColor: tokens.canvas,
      appBar: LumiraNav(
        title: '后期修图',
        transparent: true,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '取消',
              style: TextStyle(
                fontSize: 15,
                color: tokens.brandText,
              ),
            ),
          ),
        ),
        actions: [
          if (_photo != null)
            _FavoriteButton(
              photo: _photo!,
              onToggled: (next) {
                setState(() {
                  _photo = GalleryItemRecord(
                    id: _photo!.id,
                    dataUrl: _photo!.dataUrl,
                    filePath: _photo!.filePath,
                    originalPath: _photo!.originalPath,
                    transform: _photo!.transform,
                    postProcess: _photo!.postProcess,
                    sceneId: _photo!.sceneId,
                    templateId: _photo!.templateId,
                    kitId: _photo!.kitId,
                    mood: _photo!.mood,
                    lut: _photo!.lut,
                    isFavorite: next,
                    createdAt: _photo!.createdAt,
                  );
                });
                ref.invalidate(collectionsListProvider);
              },
            ),
          const SizedBox(width: 4),
          _SaveAction(
            isExporting: _isExporting,
            isReadOnly: _isReadOnly,
            onPressed: _isExporting ? () {} : () => _export(),
          ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: GlassBackground()),
          daoAsync.when(
            loading: () => Center(
              child: LumiraProgress.circular(),
            ),
            error: (e, _) => Center(
              child: Text(
                '加载失败：$e',
                style: TextStyle(color: tokens.textSecondary),
              ),
            ),
            data: (dao) {
              if (!_isInitialLoaded) {
                _isInitialLoaded = true;
                _loadPhoto(dao);
              }
              if (_isLoading) {
                return Center(child: LumiraProgress.circular());
              }
              return _photo == null
                  ? _EmptyCanvas(tokens: tokens)
                  : _buildContent(_photo!);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildContent(GalleryItemRecord photo) {
    final tokens = ref.watch(themeTokensProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 只读横幅（originalPath == null 时显示）
        if (_isReadOnly)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: tokens.dangerSubtle,
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: tokens.danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '此照片未保留原图，仅可查看，无法编辑',
                    style: TextStyle(fontSize: 12, color: tokens.danger),
                  ),
                ),
              ],
            ),
          ),
        // 画布区：照片居中放大 + 悬浮「对比」按钮
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: _CanvasArea(
                  photo: photo,
                  postProcess: _localPostProcess,
                  transform: _localTransform,
                  isComparing: _isComparing,
                  tokens: tokens,
                  isCropMode: _activeTool == _EditTool.crop,
                  cropRect: _localPostProcess.customCropRect != null
                      ? Rect.fromLTWH(
                          _localPostProcess.customCropRect!.x,
                          _localPostProcess.customCropRect!.y,
                          _localPostProcess.customCropRect!.w,
                          _localPostProcess.customCropRect!.h,
                        )
                      : null,
                  cropAspectRatio: _parseCropAspectRatio(
                      _localPostProcess.cropRatio),
                  onCropChanged: (rect) => _onPostProcessChanged(
                    _localPostProcess.copyWith(
                      customCropRect: CropRect(
                        x: rect.left,
                        y: rect.top,
                        w: rect.width,
                        h: rect.height,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _CompareButton(
                  comparing: _isComparing,
                  tokens: tokens,
                  onTap: () => setState(() => _isComparing = !_isComparing),
                ),
              ),
            ],
          ),
        ),
        // 底部工具条
        _EditToolBar(
          activeTool: _activeTool,
          isReadOnly: _isReadOnly,
          tokens: tokens,
          onSelect: _toggleTool,
          onReset: _reset,
        ),
        // 参数面板：点选工具后滑出，再次点击收起
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _activeTool == null
              ? const SizedBox.shrink()
              : _buildPanel(tokens),
        ),
      ],
    );
  }

  /// 根据当前工具构建参数面板（AnimatedSize 驱动高度变化）。
  Widget _buildPanel(ThemeTokens tokens) {
    final Widget panel;
    final double height;
    switch (_activeTool!) {
      case _EditTool.color:
        panel = PostProcessColorTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case _EditTool.detail:
        panel = PostProcessDetailTab(
          full: _fullForEdit,
          onChanged: _updatePostFromFull,
          tokens: tokens,
        );
        height = 160;
        break;
      case _EditTool.filter:
        panel = FilterTab(
          postProcess: _fullForEdit,
          onChanged: _updatePostFromFull,
          previewImagePath: _photo?.dataUrl ?? _photo?.filePath,
          tokens: tokens,
        );
        height = 264;
        break;
      case _EditTool.crop:
        panel = CropTab(
          transform: _localTransform,
          onChanged: _onTransformChanged,
          postProcess: _localPostProcess,
          onPostProcessChanged: _onPostProcessChanged,
          tokens: tokens,
          previewImagePath: _photo?.dataUrl ?? _photo?.filePath,
        );
        height = 328;
        break;
    }

    return LumiraSurface(
      radius: 20,
      clip: true,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: SizedBox(
        height: height,
        child: panel,
      ),
    );
  }

  Future<void> _export() async {
    if (_photo == null) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }

    final originalPath = _photo!.originalPath ?? _photo!.filePath;
    final photoPath = _photo!.filePath;

    if (originalPath == null || originalPath.isEmpty) {
      LumiraToast.show(context, '原图未保留，无法重新编辑');
      return;
    }
    if (photoPath == null || photoPath.isEmpty) {
      LumiraToast.show(context, '照片路径无效');
      return;
    }
    if (originalPath.startsWith('http') || photoPath.startsWith('http')) {
      LumiraToast.show(context, '网络图片不支持编辑');
      return;
    }

    // 弹出保存方式选择：替换原图 / 另存为新照片
    final saveMode = await showLumiraSaveModeSheet(context: context);
    if (saveMode == null || !mounted) return; // 用户取消
    final isDuplicate = saveMode == SaveMode.duplicate;

    final screenSize = MediaQuery.of(context).size;
    final screenRatio = screenSize.width / screenSize.height;
    final isPortrait = screenSize.height >= screenSize.width;
    // 全量参数 = baked + local增量（从原图重新处理时使用）
    final fullParams = _bakedPostProcess.merge(_localPostProcess);
    final aspectRatio = fullParams.cropRatio.isNotEmpty
        ? fullParams.cropRatio
        : 'fullscreen';

    if (!await File(originalPath).exists()) {
      if (!mounted) return;
      LumiraToast.show(context, '原图文件不存在，无法重新处理');
      return;
    }

    setState(() => _isExporting = true);

    try {
      // 另存为时写入新文件路径，替换原图时覆盖当前照片文件
      final outputPath = isDuplicate
          ? _makeDuplicatePath(photoPath)
          : photoPath;

      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: originalPath,
        params: fullParams,
        transform: _localTransform,
        aspectRatio: aspectRatio,
        screenRatio: screenRatio,
        isPortrait: isPortrait,
        outputPath: outputPath,
        // 如果用户调整了裁剪框，传入自定义裁剪 Rect；
        // 如果未调整（customCropRect 为 null），保持原有按比例裁剪逻辑
        customCropRect: fullParams.customCropRect,
      );

      try {
        PaintingBinding.instance.imageCache.evict(FileImage(File(processedPath)));
        PaintingBinding.instance.imageCache.evict(FileImage(File(originalPath)));
      } catch (_) {}

      final dao = await ref.read(galleryDaoProvider.future);

      if (isDuplicate) {
        // 另存为：创建新记录，原图记录保持不变
        final newPhotoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
        final newRecord = GalleryItemRecord(
          id: newPhotoId,
          dataUrl: _photo!.dataUrl,
          filePath: processedPath,
          originalPath: originalPath,
          transform: _localTransform,
          postProcess: fullParams,
          sceneId: _photo!.sceneId,
          templateId: _photo!.templateId,
          kitId: _photo!.kitId,
          mood: _photo!.mood,
          lut: _photo!.lut,
          isFavorite: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await dao.insert(newRecord);
        ref.invalidate(galleryDaoProvider);
        ref.invalidate(collectionsListProvider);

        if (mounted) {
          LumiraToast.show(
            context,
            '已另存为新照片',
            duration: const Duration(seconds: 1),
          );
        }
        // 另存为不修改当前编辑页的 _photo，直接返回详情页
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) Navigator.of(context).maybePop();
        });
        return;
      }

      // 替换原图：更新现有记录
      await dao.updateEdit(
        id: _photo!.id,
        filePath: processedPath,
        originalPath: originalPath,
        transform: _localTransform,
        postProcess: fullParams,
      );
      ref.invalidate(galleryDaoProvider);
      ref.invalidate(collectionsListProvider);

      setState(() {
        _photo = GalleryItemRecord(
          id: _photo!.id,
          dataUrl: _photo!.dataUrl,
          filePath: processedPath,
          originalPath: originalPath,
          transform: _localTransform,
          postProcess: fullParams,
          sceneId: _photo!.sceneId,
          templateId: _photo!.templateId,
          kitId: _photo!.kitId,
          mood: _photo!.mood,
          lut: _photo!.lut,
          isFavorite: _photo!.isFavorite,
          createdAt: _photo!.createdAt,
        );
        // 保存后 JPEG 已用 fullParams 重新处理（烘焙），
        // 更新 _bakedPostProcess 为全量参数，_localPostProcess 重置为增量 0。
        _bakedPostProcess = fullParams;
        _localPostProcess = const PostProcess(color: PostProcessColor());
      });

      if (mounted) {
        LumiraToast.show(context, '已保存', duration: const Duration(seconds: 1));
      }

      // 保存成功后延迟 1s 让 toast 显示，再 pop 返回详情页
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) Navigator.of(context).maybePop();
      });
    } catch (e, st) {
      debugPrint('[gallery-edit] 导出失败: $e\n$st');
      if (mounted) {
        LumiraToast.show(context, '保存失败：$e', duration: const Duration(seconds: 2));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// 另存为时生成一个不冲突的新文件路径。
  String _makeDuplicatePath(String sourcePath) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dot = sourcePath.lastIndexOf('.');
    if (dot <= 0) return '${sourcePath}_$now.jpg';
    return '${sourcePath.substring(0, dot)}_$now${sourcePath.substring(dot)}';
  }
}

// === 私有 widget ===

/// 画布右上角悬浮「对比」按钮
class _CompareButton extends StatelessWidget {
  const _CompareButton({
    required this.comparing,
    required this.tokens,
    required this.onTap,
  });

  final bool comparing;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: tokens.surface,
          shape: BoxShape.circle,
          boxShadow: tokens.shadowConvexSubtle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.chrome_reader_mode_outlined,
              size: 20,
              color: comparing ? tokens.brand : tokens.textSecondary,
            ),
            if (comparing)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: tokens.brand,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 保存 / 完成按钮（金色渐变 pill）
class _SaveAction extends ConsumerWidget {
  const _SaveAction({
    required this.isExporting,
    required this.isReadOnly,
    required this.onPressed,
  });
  final bool isExporting;
  final bool isReadOnly;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    final disabled = isReadOnly;
    return GestureDetector(
      onTap: disabled ? null : onPressed,
      behavior: HitTestBehavior.opaque,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            gradient: disabled
                ? null
                : LinearGradient(
                    colors: [tokens.brand, tokens.brandDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: disabled ? tokens.surfaceAlt : null,
            borderRadius: BorderRadius.circular(1000),
          ),
          child: isExporting
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: tokens.textInverse,
                  ),
                )
              : Text(
                  '保存',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: disabled ? tokens.textTertiary : tokens.textInverse,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 收藏按钮：点击切换 is_favorite
class _FavoriteButton extends ConsumerWidget {
  const _FavoriteButton({required this.photo, required this.onToggled});
  final GalleryItemRecord photo;
  final void Function(bool next) onToggled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(themeTokensProvider);
    return GestureDetector(
      onTap: () async {
        try {
          final dao = await ref.read(galleryDaoProvider.future);
          await dao.toggleFavorite(photo.id);
          // 个性化反馈：收藏照片（且照片带模板）→ 回写模板画像（失败静默）
          if (!photo.isFavorite && photo.templateId != null) {
            try {
              final interest =
                  await ref.read(interestServiceProvider.future);
              await interest.recordSignal(photo.templateId!, 1.5);
            } catch (_) {}
          }
          onToggled(!photo.isFavorite);
          if (context.mounted) {
            HapticFeedback.lightImpact();
            LumiraToast.show(
              context,
              photo.isFavorite ? '已取消收藏' : '已收藏',
              duration: const Duration(milliseconds: 1000),
            );
          }
        } catch (e) {
          if (context.mounted) {
            LumiraToast.show(
              context,
              '操作失败：$e',
              duration: const Duration(milliseconds: 1500),
            );
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(
          photo.isFavorite ? Icons.favorite : Icons.favorite_border,
          size: 20,
          color: photo.isFavorite ? tokens.danger : tokens.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyCanvas extends StatelessWidget {
  const _EmptyCanvas({required this.tokens});

  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 48, color: tokens.textTertiary),
          const SizedBox(height: 12),
          Text(
            '照片不存在或已被删除',
            style: TextStyle(fontSize: 13, color: tokens.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// 底部横向工具条：色彩 / 细节 / 滤镜 / 裁剪旋转 / 重置
class _EditToolBar extends StatelessWidget {
  const _EditToolBar({
    required this.activeTool,
    required this.isReadOnly,
    required this.tokens,
    required this.onSelect,
    required this.onReset,
  });

  final _EditTool? activeTool;
  final bool isReadOnly;
  final ThemeTokens tokens;
  final ValueChanged<_EditTool> onSelect;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    const specs = <_EditTool, IconData>{
      _EditTool.color: Icons.tune,
      _EditTool.detail: Icons.auto_fix_high_outlined,
      _EditTool.filter: Icons.filter_vintage_outlined,
      _EditTool.crop: Icons.crop_rotate,
    };
    const labels = <_EditTool, String>{
      _EditTool.color: '色彩',
      _EditTool.detail: '细节',
      _EditTool.filter: '滤镜',
      _EditTool.crop: '裁剪',
    };
    const order = <_EditTool>[
      _EditTool.color,
      _EditTool.detail,
      _EditTool.filter,
      _EditTool.crop,
    ];

    return LumiraSurface(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 8),
      radius: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final tool in order)
            _ToolItem(
              icon: specs[tool]!,
              label: labels[tool]!,
              selected: activeTool == tool,
              tokens: tokens,
              onTap: () => onSelect(tool),
            ),
          // 重置
          _ToolItem(
            icon: Icons.refresh,
            label: '重置',
            selected: false,
            tokens: tokens,
            onTap: isReadOnly ? () {} : onReset,
          ),
        ],
      ),
    );
  }
}

/// 单个工具项：图标 + 文字，选中时品牌色高亮 + 圆角底
class _ToolItem extends StatelessWidget {
  const _ToolItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.tokens,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final ThemeTokens tokens;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? tokens.brand : tokens.textSecondary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? tokens.brandSubtle : Colors.transparent,
          borderRadius: BorderRadius.circular(1000),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 画布区：实时应用 PostProcess（ColorFiltered）+ TransformParams（旋转/翻转/拉直）
/// 支持 InteractiveViewer 双指缩放查看细节（不影响参数编辑）。
/// 裁剪模式下切换到 [PhotoCropLayer]，把裁剪框直接叠加在照片本体上。
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({
    required this.photo,
    required this.postProcess,
    required this.transform,
    required this.isComparing,
    required this.tokens,
    required this.isCropMode,
    this.cropRect,
    this.cropAspectRatio,
    this.onCropChanged,
  });
  final GalleryItemRecord photo;
  final PostProcess postProcess;
  final TransformParams transform;
  final bool isComparing;
  final ThemeTokens tokens;
  final bool isCropMode;
  final Rect? cropRect;
  final double? cropAspectRatio;
  final ValueChanged<Rect>? onCropChanged;

  @override
  Widget build(BuildContext context) {
    final url = photo.dataUrl ?? photo.filePath;

    return Container(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: url == null || url.isEmpty
            ? Container(
                color: tokens.surfaceAlt,
                child: Center(
                  child: Icon(Icons.image_outlined,
                      size: 32, color: tokens.textTertiary),
                ),
              )
            : isCropMode
                ? PhotoCropLayer(
                    photoUrl: url,
                    initialCrop: cropRect,
                    aspectRatio: cropAspectRatio,
                    transform:
                        isComparing ? const TransformParams() : transform,
                    onChanged: onCropChanged ?? (_) {},
                    tokens: tokens,
                  )
                : InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 4.0,
                    panEnabled: true,
                    scaleEnabled: true,
                    boundaryMargin: EdgeInsets.zero,
                    child: _buildImage(url, isComparing),
                  ),
      ),
    );
  }

  Widget _buildImage(String url, bool isComparing) {
    // 对比模式：显示原图（不应用变换或滤镜）
    final appliedTransform =
        isComparing ? const TransformParams() : transform;
    final appliedPost = isComparing
        ? const PostProcess(color: PostProcessColor())
        : postProcess;

    // 强制图片填满取景框，让 BoxFit.contain 居中，避免 InteractiveViewer 左上对齐产生右侧空白
    Widget imageWidget = LumiraImage(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.contain,
      errorWidget: Container(
        color: tokens.surfaceAlt,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.broken_image_outlined,
                  size: 32, color: tokens.textTertiary),
              const SizedBox(height: 8),
              Text('图片加载失败',
                  style: TextStyle(
                      fontSize: 12, color: tokens.textTertiary)),
            ],
          ),
        ),
      ),
    );

    if (!appliedTransform.isIdentity) {
      imageWidget = RotatedBox(
        quarterTurns: appliedTransform.rotation ~/ 90,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..scale(
              appliedTransform.flipH ? -1.0 : 1.0,
              appliedTransform.flipV ? -1.0 : 1.0,
              1.0,
            ),
          child: Transform.rotate(
            angle: appliedTransform.straighten * math.pi / 180.0,
            child: ColorFiltered(
              colorFilter: fromPostProcess(appliedPost),
              child: imageWidget,
            ),
          ),
        ),
      );
    } else {
      imageWidget = ColorFiltered(
        colorFilter: fromPostProcess(appliedPost),
        child: imageWidget,
      );
    }

    // 晕影预览：通过 Stack + RadialGradient 叠加在图片上方
    // （smoothStrength/sharpen 为逐像素效果，仅导出时生效，无法用 ColorFilter 模拟）
    if (appliedPost.vignette > 0) {
      imageWidget = Stack(
        fit: StackFit.passthrough,
        children: [
          imageWidget,
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(
                          appliedPost.vignette / 100 * 0.5),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return imageWidget;
  }
}