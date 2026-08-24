import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/db/dao/gallery_dao.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../core/utils/image_cache.dart';
import '../../../shared/widgets/lumira/lumira.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_preview_mock_data.dart';
import '../data/capture_state.dart';
import '../widgets/preview_edit_panel.dart';
import '../../gallery/widgets/photo_crop_layer.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import '../services/compare_image_generator.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/utils/safe_share.dart';
import '../../../shared/services/poster_generator.dart';
import '../services/exif_card_generator.dart';
import '../services/photo_exif_reader.dart';
import '../services/photo_post_processor.dart';

/// HarmonyOS 原生照片保存通道（PhotoSaverPlugin.ets）
const _photoSaverChannel = MethodChannel('lumira/photo_saver');

/// 抽屉栏 closed 档位高度（拖拽条 + 折叠操作按钮组）
const double _kClosedHeight = 120;

/// 抽屉栏模式：hidden=完全隐藏（只显示悬浮按钮组），expanded=展开（1/4 或 3/4）
enum _SheetMode { hidden, expanded }

/// 照片预览页（Task 2.9A）
///
/// 视觉规格来源：lumira-app/src/pages/capture/preview.vue (399 行)
/// - 深色背景 + LumiraNav transparent
/// - 照片预览（3:4）
/// - 底部白色 Sheet：心情标签 + 场景标签 + 操作按钮 + 保存按钮
///
/// 已知简化决策（brief §8）：
/// - photoUrl 路由参数：mock 阶段为 picsum URL，真实接入 Task 2.3 CaptureState
/// - 保存到相册：mock SnackBar + pop，不接入 saver_gallery
/// - 生成对比图 / EXIF 卡片：mock SnackBar，不接入图像生成
class CapturePreviewPage extends ConsumerStatefulWidget {
  const CapturePreviewPage({
    super.key,
    this.photoUrl,
    this.photoId,
    this.aspectRatio,
    this.challengeId,
  });

  /// 路由参数：photoUrl（拍摄后的照片 URL）
  final String? photoUrl;

  /// 路由参数：photoId（拍摄时自动保存到 DB 的记录 id）
  /// 用于在预览页修改场景时同步更新 DB 记录
  final String? photoId;

  /// 路由参数：aspectRatio（拍摄时使用的取景器比例 id，如 'fullscreen' / '3:4'）
  /// Task 10 起作为非破坏性重新处理时的裁剪比例传入 processFile。
  final String? aspectRatio;

  /// 路由参数：challengeId（来自挑战详情页 → 拍摄页 → 预览页透传）
  /// 保存照片后用于回写挑战状态 pending→done 并累加 XP，然后跳转 XP 奖励页
  final String? challengeId;

  @override
  ConsumerState<CapturePreviewPage> createState() =>
      _CapturePreviewPageState();
}

class _CapturePreviewPageState extends ConsumerState<CapturePreviewPage> {
  late String _photoUrl;
  late List<MoodOption> _moods;
  String? _selectedSceneId;

  /// 是否正在按住"对比"按钮显示原图
  bool _isComparing = false;

  /// 是否已生成对比图（用于"生成对比图"按钮的状态反馈）
  // TODO(t12-followup): wire to button UI (e.g. ✓ indicator) once a read site is added;
  // until then the field is write-only and suppresses `unused_field` lint.
  // ignore: unused_field
  bool _compareCardGenerated = false;

  /// 预览页本地后期参数（仅影响当前照片，不回写 CaptureState）。
  /// 修复参数泄漏：之前直接修改 CaptureState.editableTemplateProvider /
  /// freeModePostProcessProvider，导致返回拍摄页后拍摄页参数也被改变。
  /// 现在使用本地状态，保存时由 Task 10 从原图全量重新处理，拍摄页参数不受影响。
  late PostProcess _localPostProcess;

  /// 照片已烘焙的后期参数（拍照时烘焙进 JPEG 的参数）。
  ///
  /// 修复"2x 参数"bug：拍照时色彩矩阵已烘焙进 JPEG（_processCaptureInIsolate
  /// 调用 applyColorMatrixImg），预览页若再次应用完整参数会导致效果叠加
  /// （例如亮度 20 烘焙 + 亮度 20 ColorFiltered = 1.2×1.2=1.44 ≈ 亮度 44）。
  ///
  /// 现跟踪烘焙参数，预览页仅应用 delta（current - baked）：
  /// - 初始状态（未编辑）：_bakedPostProcess == _localPostProcess → delta=0 → 无 ColorFiltered
  /// - 用户调整后：delta≠0 → 在烘焙基础上叠加增量
  /// - 保存后：从原图重新处理全量参数 → 更新 _bakedPostProcess = _localPostProcess
  late PostProcess _bakedPostProcess;

  /// 预览页本地变换参数（旋转/翻转/拉直）。
  /// 仅影响当前照片预览，保存时由 Task 10 通过非破坏性编辑管线应用。
  TransformParams _localTransform = const TransformParams();

  /// 原图路径（从 GalleryItemRecord.originalPath 读取）。
  /// null 表示原图未保留 → 只读模式，不允许编辑/重新保存。
  String? _originalPath;

  /// 只读模式标志（originalPath == null 时为 true）。
  /// Task 11 会基于此标志在 UI 上显示横幅 + 禁用编辑控件。
  bool _isReadOnly = false;

  /// 保存进行中标志（避免重复点击保存按钮）
  bool _isSaving = false;

  /// 是否已修改照片（编辑态右上角保存按钮出现条件）
  bool _isEdited = false;

  /// 抽屉栏实时高度（拖拽时直接更新，实现跟手效果）
  late final ValueNotifier<double> _sheetHeightNotifier;

  /// 拖拽起始时的高度（用于 onDragUpdate 计算偏移）
  double _dragStartHeight = 0;

  /// 拖拽起始时手指全局 Y 坐标（用于 onDragUpdate 计算偏移）
  double _dragStartGlobalY = 0;

  /// UI 显隐状态：true=显示导航栏和操作栏，false=全屏纯净查看
  bool _uiVisible = true;

  /// 抽屉栏模式：hidden（默认，只显示悬浮按钮组）或 expanded（展开抽屉栏）
  _SheetMode _sheetMode = _SheetMode.hidden;

  /// 裁剪工具是否激活（在照片本身上叠加裁剪框）
  bool _isCropMode = false;

  /// 将裁剪比例字符串解析为数值宽高比（width/height），null 表示自由裁剪。
  static double? _parseCropAspectRatio(String ratio) {
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

  // ===== 历史照片左右滑动查看（问题7）=====

  /// 历史照片列表（从数据库加载，最新在前）。
  /// 空列表表示无 DB 记录（mock/网络图模式），退化为单张预览。
  List<GalleryItemRecord> _historyPhotos = [];

  /// 当前查看的照片在 _historyPhotos 中的索引
  int _currentIndex = 0;

  /// PageView 控制器
  late final PageController _pageController;

  /// 当前查看的照片 ID（随左右滑动更新，替代 widget.photoId 的只读限制）
  String? _currentPhotoId;

  /// quarter 档位高度（屏幕高度的 50%）
  ///
  /// 从 35% 提高到 50%：为 quarter 档底部「心情+场景露出区 + 上滑提示」让出空间，
  /// 避免压缩编辑面板导致图标条 RenderFlex overflow。
  static double _quarterHeight(BuildContext c) =>
      MediaQuery.of(c).size.height * 0.50;

  /// threeQuarter 档位高度（屏幕高度的 75%）
  static double _threeQuarterHeight(BuildContext c) =>
      MediaQuery.of(c).size.height * 0.75;

  @override
  void initState() {
    super.initState();
    _photoUrl =
        widget.photoUrl ?? CapturePreviewMockData.lastCapturedPhotoUrl;
    // 拍摄后默认不选择任何心情（全部非激活），用户可在编辑页选择或点击「跳过」
    _moods = CapturePreviewMockData.moods
        .map((m) => m.copyWith(active: false))
        .toList();
    // _localPostProcess 是用户在编辑页调整的【增量】参数（初始为默认值 0）。
    // 照片已烘焙 _bakedPostProcess 参数，预览页仅叠加增量 → 所见即所得。
    // 保存时：全量参数 = _bakedPostProcess.merge(_localPostProcess) 从原图重新处理。
    final initial = ref.read(CaptureState.effectivePostProcessProvider);
    _bakedPostProcess = initial;
    _localPostProcess = const PostProcess(color: PostProcessColor());
    _sheetHeightNotifier = ValueNotifier<double>(_kClosedHeight);
    _currentPhotoId = widget.photoId;
    _pageController = PageController(initialPage: 0);
    _loadHistoryPhotos(); // fire-and-forget; loads DB history + original path
  }

  @override
  void dispose() {
    _sheetHeightNotifier.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ===== 历史照片加载与滑动切换（问题7）=====

  /// 从数据库加载历史照片列表，定位当前照片索引。
  ///
  /// - 若 photoId 为 null 或数据库无记录：退化为单张预览（_historyPhotos 为空）。
  /// - 若找到当前照片：加载全部历史照片到 _historyPhotos，定位到当前索引，
  ///   并从 DB 记录恢复 originalPath / postProcess / transform / sceneId。
  Future<void> _loadHistoryPhotos() async {
    if (widget.photoId == null) {
      // 无 photoId（mock/网络图模式）：退化为单张预览
      _loadOriginalPath();
      return;
    }
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      final allPhotos = await dao.getAll();
      if (!mounted) return;

      if (allPhotos.isEmpty) {
        _loadOriginalPath();
        return;
      }

      // 定位当前照片在历史列表中的索引
      final idx = allPhotos.indexWhere((p) => p.id == widget.photoId);
      if (idx < 0) {
        // 当前照片不在 DB 中（可能尚未落库）：退化为单张预览
        _loadOriginalPath();
        return;
      }

      setState(() {
        _historyPhotos = allPhotos;
        _currentIndex = idx;
      });
      // 从 DB 记录恢复当前照片的状态
      _applyPhotoFromHistory(allPhotos[idx]);
      // PageView 首次构建后跳转到当前照片索引
      //（PageController 在 initState 中以 initialPage:0 创建，
      // 此处异步加载完历史后需手动跳转到正确页）
      if (idx != 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            _pageController.jumpToPage(idx);
          }
        });
      }
    } catch (e) {
      debugPrint('[preview] 加载历史照片失败: $e');
      _loadOriginalPath();
    }
  }

  /// 从历史照片记录恢复所有预览状态（滑动切换时调用）。
  ///
  /// 更新：photoUrl / originalPath / isReadOnly / localPostProcess /
  /// localTransform / selectedSceneId
  void _applyPhotoFromHistory(GalleryItemRecord record) {
    final initial = ref.read(CaptureState.effectivePostProcessProvider);
    setState(() {
      _currentPhotoId = record.id;
      _photoUrl = record.filePath ?? record.dataUrl ?? _photoUrl;
      _originalPath = record.originalPath;
      _isReadOnly = record.originalPath == null;
      // 照片 JPEG 已烘焙 record.postProcess 参数 → _bakedPostProcess = record.postProcess
      // _localPostProcess 重置为默认值（增量 0）→ 编辑面板滑块从 0 开始
      _bakedPostProcess = record.postProcess ?? initial;
      _localPostProcess = const PostProcess(color: PostProcessColor());
      _localTransform = record.transform ?? const TransformParams();
      _selectedSceneId = record.sceneId;
      _isEdited = false;
      // 恢复该照片的心情选中状态
      _moods = _moods
          .map((m) => m.copyWith(active: m.name == record.mood))
          .toList();
    });
  }

  /// PageView 页面切换回调：更新当前索引并恢复该照片的状态
  void _onPageChanged(int index) {
    if (index < 0 || index >= _historyPhotos.length) return;
    _currentIndex = index;
    _applyPhotoFromHistory(_historyPhotos[index]);
  }

  /// 从数据库加载原图路径，确定只读模式（fallback：无历史照片列表时使用）
  Future<void> _loadOriginalPath() async {
    final pid = _currentPhotoId ?? widget.photoId;
    if (pid == null) return;
    try {
      final dao = await ref.read(galleryDaoProvider.future);
      final record = await dao.getById(pid);
      if (!mounted) return;
      if (record != null) {
        setState(() {
          _originalPath = record.originalPath;
          _isReadOnly = record.originalPath == null;
        });
      }
    } catch (e) {
      debugPrint('[preview] 加载原图路径失败: $e');
    }
  }

  /// 只读模式下提示用户无法编辑
  void _showReadOnlyToast() {
    if (!mounted) return;
    LumiraToast.show(
      context,
      '原图未保留，无法再次编辑',
      duration: const Duration(seconds: 2),
    );
  }

  /// 本地后期参数更新（仅影响预览和保存，不回写 CaptureState）
  void _updateLocalPostProcess(PostProcess next) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localPostProcess = next;
      _isEdited = true;
    });
  }

  /// 本地变换参数更新（旋转/翻转/拉直）
  void _updateLocalTransform(TransformParams t) {
    if (!mounted) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localTransform = t;
      _isEdited = true;
    });
  }

  /// 计算预览页显示用的增量参数（current - baked）。
  ///
  /// 修复"2x 参数"bug：拍照时色彩矩阵已烘焙进 JPEG，预览页若再次应用完整
  /// 参数会导致效果叠加（亮度 20+20≈44）。本方法计算用户调整的增量部分，
  /// 预览页仅应用增量到已烘焙的照片上。
  ///
  /// 正确性说明：
  /// - delta=0（未编辑）：composePostProcessMatrix 返回单位矩阵 → 无效果 ✓
  /// - delta≠0（已调整）：simple subtraction 是近似值（矩阵乘法非线性），
  ///   但对小调整视觉差异不可感知；保存时从原图全量重新处理（准确）
  PostProcess _computeDeltaPostProcess() {
    final c = _localPostProcess.color;
    final b = _bakedPostProcess.color;
    return PostProcess(
      color: PostProcessColor(
        brightness: c.brightness - b.brightness,
        contrast: c.contrast - b.contrast,
        saturation: c.saturation - b.saturation,
        temperature: c.temperature - b.temperature,
        tint: c.tint - b.tint,
        highlights: (c.highlights ?? 0) - (b.highlights ?? 0),
        shadows: (c.shadows ?? 0) - (b.shadows ?? 0),
        blackPoint: (c.blackPoint ?? 0) - (b.blackPoint ?? 0),
        clarity: (c.clarity ?? 0) - (b.clarity ?? 0),
        vibrance: (c.vibrance ?? 0) - (b.vibrance ?? 0),
        brilliance: (c.brilliance ?? 0) - (b.brilliance ?? 0),
      ),
      // 非色彩矩阵参数不影响 ColorFiltered（sharpen/smoothStrength/vignette/grain
      // 仅在保存时从原图重新处理时应用）
      smoothStrength: 0,
      sharpen: 0,
      vignette: 0,
      grain: 0,
      // systemFilter / LUT：未更改时用 'none'/null（无附加滤镜）；
      // 已更改时无法通过 ColorFiltered 精确"撤销"烘焙的滤镜，但保存时会从原图重新处理
      systemFilter: (_localPostProcess.systemFilter != _bakedPostProcess.systemFilter)
          ? _localPostProcess.systemFilter
          : null,
      lut: (_localPostProcess.lut != _bakedPostProcess.lut)
          ? _localPostProcess.lut
          : 'none',
    );
  }

  // ===== 抽屉栏拖拽 =====

  /// 拖拽起始：记录当前高度和手指全局 Y 坐标
  void _onSheetDragStart(DragStartDetails details) {
    _dragStartHeight = _sheetHeightNotifier.value;
    _dragStartGlobalY = details.globalPosition.dy;
  }

  /// 拖拽更新：实时更新抽屉栏高度（跟手效果）
  /// 手指上滑 deltaY < 0 → 高度增加；手指下滑 deltaY > 0 → 高度减少
  void _onSheetDragUpdate(DragUpdateDetails details) {
    final deltaY = details.globalPosition.dy - _dragStartGlobalY;
    final newHeight = (_dragStartHeight - deltaY)
        .clamp(_kClosedHeight, _threeQuarterHeight(context));
    _sheetHeightNotifier.value = newHeight;
  }

  /// 拖拽结束：吸附到最近档位（280ms 动画）
  /// 接近 closed 高度时折叠为 hidden（显示悬浮按钮组）
  void _onSheetDragEnd(BuildContext context, DragEndDetails _) {
    _snapToNearest(context);
  }

  /// 吸附到最近档位
  /// - 接近 closed 高度 → 折叠为 hidden（_sheetMode = hidden）
  /// - 否则吸附到 quarter 或 threeQuarter
  void _snapToNearest(BuildContext context) {
    final current = _sheetHeightNotifier.value;
    final h1 = _kClosedHeight;
    final h2 = _quarterHeight(context);
    final h3 = _threeQuarterHeight(context);

    // 接近 closed 高度 → 折叠为 hidden
    if ((current - h1).abs() < 50) {
      setState(() {
        _sheetMode = _SheetMode.hidden;
        // 退出编辑时隐藏裁剪框（抽屉被整体销毁重建，tab 会重置，需同步收起裁剪框）
        _isCropMode = false;
      });
      _sheetHeightNotifier.value = h1;
      return;
    }

    // 否则吸附到 quarter 或 threeQuarter
    final distances = [
      (h2 - current).abs(),
      (h3 - current).abs(),
    ];
    final minIdx = distances.indexOf(distances.reduce((a, b) => a < b ? a : b));
    _sheetHeightNotifier.value = [h2, h3][minIdx];
  }

  // ===== 事件处理 =====

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  /// 「对比」按钮点击：在「显示原图」与「显示滤镜后」之间切换（点击一次显原图，再点恢复）
  void _onCompareToggle() {
    if (!mounted) return;
    setState(() => _isComparing = !_isComparing);
  }

  /// 照片单击（来自 PhotoView 的单击回调，双击已交给内置缩放，不会触发此处）
  /// - 编辑抽屉展开时：点击照片收起抽屉（不放大）
  /// - 否则：切换 UI 显隐（纯净模式查看全图）
  void _onPhotoTap(
    BuildContext context,
    TapUpDetails details,
    PhotoViewControllerValue _,
  ) {
    if (!mounted) return;
    setState(() {
      if (_sheetMode == _SheetMode.expanded) {
        _sheetMode = _SheetMode.hidden;
        _isCropMode = false;
        _sheetHeightNotifier.value = _kClosedHeight;
      } else {
        _uiVisible = !_uiVisible;
      }
    });
  }

  /// 双击缩放循环：fit(整图) ↔ originalSize(2 倍放大)。
  /// childSize = 2×视口，因此 initial/contained=0.5(整图)，originalSize(1.0)=2 倍放大。
  PhotoViewScaleState _previewScaleCycle(PhotoViewScaleState state) {
    switch (state) {
      case PhotoViewScaleState.initial:
      case PhotoViewScaleState.covering:
      case PhotoViewScaleState.zoomedOut:
        return PhotoViewScaleState.originalSize;
      case PhotoViewScaleState.originalSize:
      case PhotoViewScaleState.zoomedIn:
        return PhotoViewScaleState.initial;
    }
  }

  /// 构建单个照片的显示内容（含后期滤镜 + 旋转/翻转/拉直变换）。
  /// 作为 PhotoView.buildContent 供 PhotoView.customChild / GalleryPageOptions.customChild 使用。
  Widget _buildPhotoContent(
    String photoUrl,
    bool isComparing,
    PostProcess postProcess,
    TransformParams transform,
  ) {
    final bool isNetworkUrl = photoUrl.startsWith('http');

    Widget buildImage() => isNetworkUrl
        ? CachedNetworkImage(
            url: photoUrl,
            fit: BoxFit.contain,
            errorWidget: const Center(
              child:
                  Icon(Icons.broken_image, color: Colors.white38, size: 64),
            ),
          )
        : Image.file(
            File(photoUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Center(
              child:
                  Icon(Icons.broken_image, color: Colors.white38, size: 64),
            ),
          );

    if (photoUrl.isEmpty) {
      return const Center(
        child: Icon(Icons.photo, color: Colors.white38, size: 64),
      );
    }

    // 对比模式：显示原图色彩（透明滤镜 = 无后期），不应用变换
    if (isComparing) {
      return ColorFiltered(
        colorFilter: const ColorFilter.mode(
            Colors.transparent, BlendMode.dst),
        child: buildImage(),
      );
    }

    return RotatedBox(
      quarterTurns: transform.rotation ~/ 90,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..scale(
            transform.flipH ? -1.0 : 1.0,
            transform.flipV ? -1.0 : 1.0,
            1.0,
          ),
        child: Transform.rotate(
          angle: transform.straighten * math.pi / 180.0,
          child: ColorFiltered(
            colorFilter: fromPostProcess(postProcess),
            child: buildImage(),
          ),
        ),
      ),
    );
  }

  void _onSkip() {
    setState(() {
      // 跳过 = 不选择任何心情（全部取消激活）
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i].copyWith(active: false);
      }
    });
    LumiraToast.show(context, '已跳过');
  }

  Future<void> _onCompareCard() async {
    if (_photoUrl.isEmpty) return;
    LumiraToast.show(context, '生成对比图中', duration: const Duration(seconds: 1));

    try {
      // 原图 = 当前文件路径（已含滤镜，因为 capture 时已应用后期）
      // 为得到"原图"和"滤镜后"，需要原始 RAW 文件。这里简化为：
      // - filteredPath = 当前 _photoUrl
      // - originalPath = _photoUrl（无 raw 可用时同图）
      // 真实场景中应在 capture 时保留 raw 文件路径
      final outputPath =
          '${_photoUrl}_compare_${DateTime.now().millisecondsSinceEpoch}.png';
      await CompareImageGenerator.generate(
        originalPath: _photoUrl,
        filteredPath: _photoUrl,
        outputPath: outputPath,
      );
      if (!mounted) return;
      setState(() => _compareCardGenerated = true);
      LumiraToast.show(
        context,
        '对比图已生成',
        action: ToastAction(
          label: '查看',
          onTap: () {
            // 跳转到详情页查看对比图
            GoRouter.of(context).push(
              '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(outputPath)}',
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '生成失败：$e');
    }
  }

  Future<void> _onExifCard() async {
    if (_photoUrl.isEmpty || _photoUrl.startsWith('http')) {
      LumiraToast.show(context, '网络图片无法生成 EXIF 卡片');
      return;
    }
    LumiraToast.show(context, '生成 EXIF 卡片中...', duration: const Duration(seconds: 1));

    try {
      final templateId = ref.read(CaptureState.currentTemplateIdProvider);
      final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
      final exif = await PhotoExifReader.read(
        _photoUrl,
        sceneName: sceneId,
        template: templateId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final outputPath =
          '${_photoUrl}_exif_${DateTime.now().millisecondsSinceEpoch}.png';
      await ExifCardGenerator.generate(
        photoPath: _photoUrl,
        outputPath: outputPath,
        exif: exif,
      );
      if (!mounted) return;
      LumiraToast.show(
        context,
        'EXIF 卡片已生成',
        action: ToastAction(
          label: '查看',
          onTap: () {
            GoRouter.of(context).push(
              '${RouteNames.capturePreview}?photoUrl=${Uri.encodeComponent(outputPath)}',
            );
          },
        ),
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '生成失败：$e');
    }
  }

  /// 顶部 nav 分享按钮：弹出底部 Sheet
  Future<void> _onShare() async {
    final tokens = ref.read(themeTokensProvider);
    await showLumiraBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ShareOption(
            icon: Icons.save_alt_outlined,
            text: '保存到相册',
            tokens: tokens,
            onTap: () {
              Navigator.of(ctx).pop();
              _onSave();
            },
          ),
          _ShareOption(
            icon: Icons.ios_share_outlined,
            text: '分享到系统',
            tokens: tokens,
            onTap: () {
              Navigator.of(ctx).pop();
              _onShareSystem();
            },
          ),
          _ShareOption(
            icon: Icons.content_paste_outlined,
            text: '生成 EXIF 海报',
            tokens: tokens,
            onTap: () {
              Navigator.of(ctx).pop();
              _onExifPoster();
            },
          ),
          const SizedBox(height: 8),
          _ShareOption(
            icon: Icons.close,
            text: '取消',
            tokens: tokens,
            onTap: () => Navigator.of(ctx).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  /// 分享原始照片到系统
  Future<void> _onShareSystem() async {
    if (_photoUrl.isEmpty) return;
    try {
      if (_photoUrl.startsWith('http')) {
        await SafeShare.share(_photoUrl, subject: '如画 LUMIRA · 拍摄作品');
      } else {
        await SafeShare.shareXFiles(
          [XFile(_photoUrl)],
          subject: '如画 LUMIRA · 拍摄作品',
          text: '我用如画拍了一张照片，快来看看吧！',
        );
      }
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '分享失败：$e');
    }
  }

  /// 生成 EXIF 海报并弹出 PosterGenerator 预览
  Future<void> _onExifPoster() async {
    if (_photoUrl.isEmpty || _photoUrl.startsWith('http')) {
      LumiraToast.show(context, '网络图片无法生成 EXIF 海报');
      return;
    }

    try {
      final templateId = ref.read(CaptureState.currentTemplateIdProvider);
      final sceneId = ref.read(CaptureState.activeScenePresetIdProvider);
      final exif = await PhotoExifReader.read(
        _photoUrl,
        sceneName: sceneId,
        template: templateId,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      final outputPath =
          '${_photoUrl}_exif_${DateTime.now().millisecondsSinceEpoch}.png';
      await ExifCardGenerator.generate(
        photoPath: _photoUrl,
        outputPath: outputPath,
        exif: exif,
      );
      if (!mounted) return;

      final tokens = ref.watch(themeTokensProvider);
      // posterKey 仅传给 PosterGenerator 内部的 RepaintBoundary；
      // 不要同时挂到外层 Container，否则「Multiple widgets used the same GlobalKey」
      final posterKey = GlobalKey();
      await PosterGenerator.showPoster(
        context: context,
        tokens: tokens,
        title: 'EXIF 海报预览',
        content: Container(
          color: const Color(0xFF1C1A17),
          child: Image.file(
            File(outputPath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              height: 200,
              color: tokens.surfaceAlt,
              child: Icon(Icons.image_outlined, color: tokens.textTertiary),
            ),
          ),
        ),
        posterKey: posterKey,
        shareSubject: '如画 LUMIRA · EXIF 海报',
        shareText: '我用如画拍了这张照片，附带了完整的 EXIF 信息！',
        fileNamePrefix: 'lumira_exif',
      );
    } catch (e) {
      if (!mounted) return;
      LumiraToast.show(context, '生成失败：$e');
    }
  }

  void _selectMood(MoodOption selected) {
    setState(() {
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i].copyWith(active: _moods[i].name == selected.name);
      }
    });
    // 同步更新数据库中的心情标记（与 _selectScene 一致，让相册详情页能读到）
    final photoId = _currentPhotoId ?? widget.photoId;
    if (photoId != null) {
      ref.read(galleryDaoProvider.future).then((dao) async {
        try {
          await dao.updateMood(photoId, _activeMoodName());
          ref.invalidate(galleryDaoProvider);
        } catch (e) {
          debugPrint('[preview] 更新心情失败: $e');
        }
      });
    }
  }

  /// 当前激活的心情名称；未选择时返回 null
  String? _activeMoodName() {
    for (final m in _moods) {
      if (m.active) return m.name;
    }
    return null;
  }

  void _selectScene(String? id) {
    setState(() {
      _selectedSceneId = id;
    });
    // 同步更新数据库中的场景标记（拍摄时已落库，此处更新 scene_id 字段）
    final photoId = _currentPhotoId ?? widget.photoId;
    if (photoId != null) {
      ref.read(galleryDaoProvider.future).then((dao) async {
        try {
          await dao.updateScene(photoId, id);
          ref.invalidate(galleryDaoProvider);
        } catch (e) {
          debugPrint('[preview] 更新场景失败: $e');
        }
      });
    }
  }

  /// 另存为时生成一个不冲突的新文件路径。
  String _makeDuplicatePath(String sourcePath) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final dot = sourcePath.lastIndexOf('.');
    if (dot <= 0) return '${sourcePath}_$now.jpg';
    return '${sourcePath.substring(0, dot)}_$now${sourcePath.substring(dot)}';
  }

  /// 保存到系统相册（非破坏性编辑：从原图重新应用完整参数）
  ///
  /// 流程：
  /// 1. 检查只读模式（originalPath == null）→ 提示并返回
  /// 2. 弹出保存方式选择（替换原图 / 另存为新照片），用户取消则返回
  /// 3. 从 originalPath 重新处理（应用 _localPostProcess + _localTransform 全量参数）
  /// 4. 替换原图时覆盖当前文件，另存为时写入新文件路径
  /// 5. evict FileImage 缓存（避免显示旧版本）
  /// 6. 替换原图时更新 GalleryItemRecord，另存为时创建新记录
  /// 7. 调用原生通道保存到系统相册
  /// 8. 延迟返回相册页
  Future<void> _onSave() async {
    if (_isSaving) return;

    // 只读模式：原图未保留，无法重新处理
    if (_isReadOnly || _originalPath == null) {
      LumiraToast.show(context, '原图未保留，无法再次编辑');
      return;
    }

    // 网络图片不支持保存（使用 _photoUrl 以支持滑动切换后的当前照片）
    final photoPath = _photoUrl;
    if (photoPath.isEmpty || photoPath.startsWith('http')) {
      LumiraToast.show(context, '网络图片不支持保存到系统相册');
      return;
    }

    // 弹出保存方式选择：替换原图 / 另存为新照片
    final saveMode = await showLumiraSaveModeSheet(context: context);
    if (saveMode == null) return; // 用户取消
    final isDuplicate = saveMode == SaveMode.duplicate;

    setState(() => _isSaving = true);

    try {
      final originalPath = _originalPath!;
      final captureAspectRatio = widget.aspectRatio ?? 'fullscreen';

      // 检查原图是否存在
      if (!await File(originalPath).exists()) {
        if (!mounted) return;
        LumiraToast.show(context, '原图文件不存在，无法重新处理');
        return;
      }

      // 从原图重新处理（全量参数 = baked + local增量）
      // - 替换原图：outputPath=photoPath，覆盖当前显示的照片文件
      // - 另存为：写入不冲突的新文件路径，不影响原图
      final fullParams = _bakedPostProcess.merge(_localPostProcess);
      final outputPath =
          isDuplicate ? _makeDuplicatePath(photoPath) : photoPath;
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: originalPath,
        params: fullParams,
        transform: _localTransform,
        aspectRatio: captureAspectRatio,
        outputPath: outputPath,
        // 传入裁剪框（未拖拽过则为 null，此时 processFile 沿用比例裁剪）
        customCropRect: _localPostProcess.customCropRect,
      );

      // Evict FileImage 缓存（避免显示旧版本）
      try {
        PaintingBinding.instance.imageCache.evict(FileImage(File(processedPath)));
        PaintingBinding.instance.imageCache.evict(FileImage(File(originalPath)));
      } catch (_) {}

      // 操作数据库记录（使用 _currentPhotoId 以支持滑动切换后的当前照片）
      final currentPhotoId = _currentPhotoId ?? widget.photoId;
      if (isDuplicate) {
        // 另存为：创建新记录，原图记录保持不变
        final newPhotoId = 'photo_${DateTime.now().millisecondsSinceEpoch}';
        final old = (_currentIndex >= 0 &&
                _currentIndex < _historyPhotos.length)
            ? _historyPhotos[_currentIndex]
            : null;
        final dao = await ref.read(galleryDaoProvider.future);
        final newRecord = GalleryItemRecord(
          id: newPhotoId,
          dataUrl: null,
          filePath: processedPath,
          originalPath: originalPath,
          transform: _localTransform,
          postProcess: fullParams,
          sceneId: _selectedSceneId,
          templateId: old?.templateId,
          kitId: old?.kitId,
          mood: _activeMoodName() ?? old?.mood,
          lut: old?.lut,
          isFavorite: false,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await dao.insert(newRecord);
        ref.invalidate(galleryDaoProvider);
      } else if (currentPhotoId != null) {
        try {
          final dao = await ref.read(galleryDaoProvider.future);
          // 替换原图：保留原图（可再次编辑），更新当前记录
          await dao.updateEdit(
            id: currentPhotoId,
            filePath: processedPath,
            originalPath: originalPath,
            transform: _localTransform,
            postProcess: _localPostProcess,
          );
          ref.invalidate(galleryDaoProvider);
          if (mounted) {
            setState(() {
              _originalPath = originalPath;
              _isReadOnly = false;
              // 保存后照片已用 fullParams（baked+local）重新处理（烘焙），
              // 更新 _bakedPostProcess 为全量参数，_localPostProcess 重置为增量 0。
              _bakedPostProcess = fullParams;
              _localPostProcess = const PostProcess(color: PostProcessColor());
              _isEdited = false;
              // 同步更新历史列表中的记录
              if (_currentIndex < _historyPhotos.length) {
                final old = _historyPhotos[_currentIndex];
                _historyPhotos[_currentIndex] = GalleryItemRecord(
                  id: currentPhotoId,
                  dataUrl: old.dataUrl,
                  filePath: processedPath,
                  originalPath: originalPath,
                  transform: _localTransform,
                  postProcess: fullParams,
                  sceneId: _selectedSceneId,
                  templateId: old.templateId,
                  kitId: old.kitId,
                  mood: old.mood,
                  lut: old.lut,
                  isFavorite: old.isFavorite,
                  createdAt: old.createdAt,
                );
              }
            });
          }
        } catch (e) {
          debugPrint('[save] 更新数据库记录失败: $e');
        }
      }

      // 编辑态「保存」：仅保存到 app 相册（与后期修图页一致：重处理、更新 DB、toast、随后返回），
      // 不写系统相册；系统相册由底部悬浮「保存到系统相册」按钮负责。
      if (mounted) {
        LumiraToast.show(
          context,
          isDuplicate ? '已另存为新照片' : '已保存',
          duration: const Duration(seconds: 1),
        );
      }
    } catch (e) {
      debugPrint('[save] 保存流程异常: $e');
      if (!mounted) return;
      LumiraToast.show(context, '保存失败：$e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    // 保存完成后的跳转：
    // - 携带 challengeId：跳挑战确认页（用户决定是否作为挑战作品提交，再回写状态）
    // - 否则：延迟返回上一页或回到画廊
    if (mounted) {
      final cid = widget.challengeId;
      final pid = widget.photoId;
      if (cid != null && cid.isNotEmpty && pid != null && pid.isNotEmpty) {
        // 清栈跳转到挑战确认页（避免返回时再次进入预览页）
        GoRouter.of(context).go(
          '${RouteNames.challengeConfirm}'
          '?${RouteNames.paramChallengeId}=${Uri.encodeComponent(cid)}'
          '&${RouteNames.paramPhotoId}=${Uri.encodeComponent(pid)}',
        );
        return;
      }
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (!mounted) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          GoRouter.of(context).go(RouteNames.gallery);
        }
      });
    }
  }

  /// 悬浮"保存"按钮：仅保存当前照片（含编辑结果）到系统相册。
  /// 不弹出替换/另存选择、不改数据库、不跳转。
  Future<void> _onSaveToAlbum() async {
    if (_isSaving) return;
    final photoPath = _photoUrl;
    if (photoPath.isEmpty || photoPath.startsWith('http')) {
      LumiraToast.show(context, '网络图片不支持保存到系统相册');
      return;
    }
    if (_isReadOnly || _originalPath == null) {
      LumiraToast.show(context, '原图未保留，无法重新处理');
      return;
    }
    setState(() => _isSaving = true);
    String? tmpPath;
    try {
      // 从原图重新处理（应用当前编辑参数），写出到临时文件
      final fullParams = _bakedPostProcess.merge(_localPostProcess);
      tmpPath = _makeDuplicatePath(photoPath);
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: _originalPath!,
        params: fullParams,
        transform: _localTransform,
        aspectRatio: widget.aspectRatio ?? 'fullscreen',
        outputPath: tmpPath,
        // 传入裁剪框，确保保存到系统相册的结果与编辑页框选一致
        customCropRect: _localPostProcess.customCropRect,
      );
      final result = await _photoSaverChannel.invokeMethod('saveToAlbum', {
        'path': processedPath,
      });
      final success = result != null && result['success'] == true;
      if (!mounted) return;
      LumiraToast.show(
        context,
        success ? '已保存到系统相册' : '保存失败：${result?['error'] ?? "未知错误"}',
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      debugPrint('[save] 系统相册异常: $e');
      if (!mounted) return;
      LumiraToast.show(context, '保存失败：$e');
    } finally {
      // 清理临时导出文件
      if (tmpPath != null) {
        try {
          final f = File(tmpPath);
          if (await f.exists()) await f.delete();
        } catch (_) {}
      }
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// 删除当前照片：确认后删除数据库记录与本地文件，并返回上一页。
  Future<void> _onDelete() async {
    if (_isSaving) return;
    final tokens = ref.read(appThemeProvider).tokens;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '删除照片',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        content: Text(
          '确定删除这张照片吗？此操作不可撤销。',
          style: TextStyle(fontSize: 14, color: tokens.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('取消', style: TextStyle(color: tokens.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              '删除',
              style: TextStyle(color: tokens.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      // 删除数据库记录（有记录时）
      final pid = _currentPhotoId ?? widget.photoId;
      if (pid != null) {
        final dao = await ref.read(galleryDaoProvider.future);
        await dao.delete(pid);
        ref.invalidate(galleryDaoProvider);
      }
      // 删除本地结果/原图文件（忽略失败，避免阻塞删除流程）
      for (final p in [_photoUrl, _originalPath]) {
        if (p != null && p.isNotEmpty && !p.startsWith('http')) {
          try {
            final f = File(p);
            if (await f.exists()) await f.delete();
          } catch (_) {}
        }
      }
      if (!mounted) return;
      LumiraToast.show(
        context,
        '已删除',
        duration: const Duration(milliseconds: 1000),
      );
      _back();
    } catch (e) {
      debugPrint('[delete] 删除照片失败: $e');
      if (!mounted) return;
      LumiraToast.show(context, '删除失败：$e', duration: const Duration(seconds: 2));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = ref.watch(appThemeProvider);
    final tokens = appTheme.tokens;

    // 预选当前场景（修复 Issue 8：拍摄后自动选择该场景）
    // 仅在首次构建且用户未手动改过时设置；通过 postFrameCallback 避免在 build 中调用 setState
    final activeSceneId = ref.watch(CaptureState.activeScenePresetIdProvider);
    if (_selectedSceneId == null && activeSceneId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedSceneId == null) {
          setState(() => _selectedSceneId = activeSceneId);
        }
      });
    }

    return Scaffold(
      // 照片全屏显示，背景纯黑
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 照片区域（底部留出抽屉栏空间，避免被遮挡）
          // - _uiVisible=false 时照片铺满全屏（纯净模式）
          // - _sheetMode == expanded 时底部留出抽屉栏高度
          // - _sheetMode == hidden 时照片铺满全屏（仅悬浮按钮组浮在上方）
          // - 问题7：有历史照片时使用 PageView 左右滑动查看，无历史时退化为单张预览
          ValueListenableBuilder<double>(
            valueListenable: _sheetHeightNotifier,
            builder: (context, sheetHeight, _) {
              return Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom:
                    _uiVisible && _sheetMode == _SheetMode.expanded
                        ? sheetHeight
                        : 0,
                child: _isCropMode
                    // 裁剪模式：把裁剪框直接叠加在照片本体上（iPhone 风格）
                    ? PhotoCropLayer(
                        photoUrl: _photoUrl,
                        initialCrop: _localPostProcess.customCropRect != null
                            ? Rect.fromLTWH(
                                _localPostProcess.customCropRect!.x,
                                _localPostProcess.customCropRect!.y,
                                _localPostProcess.customCropRect!.w,
                                _localPostProcess.customCropRect!.h,
                              )
                            : null,
                        aspectRatio: _parseCropAspectRatio(
                            _localPostProcess.cropRatio),
                        transform: _localTransform,
                        onChanged: (rect) => setState(() {
                          _localPostProcess = _localPostProcess.copyWith(
                            customCropRect: CropRect(
                              x: rect.left,
                              y: rect.top,
                              w: rect.width,
                              h: rect.height,
                            ),
                          );
                          _isEdited = true;
                        }),
                        tokens: tokens,
                      )
                    : LayoutBuilder(
                  builder: (context, constraints) {
                    final outer = constraints.biggest;
                    // childSize = 2×视口：fit(contained=0.5) 显示整图，双击到 originalSize(1.0) = 2 倍放大。
                    final childSize =
                        Size(outer.width * 2, outer.height * 2);

                    // 无历史照片：单张预览
                    if (_historyPhotos.isEmpty) {
                      return PhotoView.customChild(
                        child: _buildPhotoContent(
                          _photoUrl,
                          _isComparing,
                          // 照片已烘焙 _bakedPostProcess，预览页仅应用增量 _localPostProcess。
                          _localPostProcess,
                          _localTransform,
                        ),
                        childSize: childSize,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: 6.0,
                        scaleStateCycle: _previewScaleCycle,
                        onTapUp: _onPhotoTap,
                        backgroundDecoration:
                            const BoxDecoration(color: Colors.black),
                      );
                    }

                    // 有历史照片：PhotoViewGallery 提供边界感知的横向切换：
                    // - 未放大(整图)时横滑切换照片；
                    // - 放大后横滑优先移动可视区域，触达左右边界才切换照片（与 PhotoView 内部
                    //   HitCornersDetector + PhotoViewGestureRecognizer 的 shouldMove 逻辑一致）。
                    return PhotoViewGallery.builder(
                      itemCount: _historyPhotos.length,
                      pageController: _pageController,
                      onPageChanged: _onPageChanged,
                      // 允许首尾弹性回弹（与原生相机一致）
                      scrollPhysics: const BouncingScrollPhysics(),
                      backgroundDecoration:
                          const BoxDecoration(color: Colors.black),
                      builder: (context, index) {
                        final record = _historyPhotos[index];
                        final url =
                            record.filePath ?? record.dataUrl ?? '';
                        final bool isCurrent = index == _currentIndex;
                        // 当前页使用增量参数（delta = local - baked），
                        // 其他页照片已烘焙各自的 record.postProcess，直接显示无需叠加滤镜。
                        return PhotoViewGalleryPageOptions.customChild(
                          child: isCurrent
                              ? _buildPhotoContent(
                                  _photoUrl,
                                  _isComparing,
                                  _localPostProcess,
                                  _localTransform,
                                )
                              : _buildPhotoContent(
                                  url,
                                  false,
                                  const PostProcess(
                                      color: PostProcessColor()),
                                  record.transform ??
                                      const TransformParams(),
                                ),
                          childSize: childSize,
                          minScale: PhotoViewComputedScale.contained,
                          maxScale: 6.0,
                          scaleStateCycle: _previewScaleCycle,
                          onTapUp: _onPhotoTap,
                        );
                      },
                    );
                  },
                ),
              );
            },
          ),
          // 2. 顶部导航 + 只读横幅（仅 _uiVisible 时显示）
          if (_uiVisible)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _PreviewNav(
                      tokens: tokens,
                      onBack: _back,
                      onShare: _onShare,
                      onSave: _onSave,
                      showSave: _sheetMode == _SheetMode.expanded && _isEdited,
                    ),
                    // 只读模式横幅：原图未保留时显示（位于导航栏下方）
                    if (_isReadOnly)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        color: tokens.dangerSubtle,
                        child: Row(
                          children: [
                            Icon(Icons.lock_outline,
                                size: 16, color: tokens.danger),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '此照片未保留原图，仅可查看，无法编辑',
                                style: TextStyle(
                                    fontSize: 12, color: tokens.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          // 3. 底部抽屉栏（仅 _uiVisible && _sheetMode == expanded 时显示）
          // 通过 ValueNotifier 驱动实时高度，AnimatedContainer 在松手后吸附
          // 抽屉栏展开后用两段式拖拽（1/4 ↔ 3/4），拖拽到 closed 高度时折叠为 hidden
          if (_uiVisible && _sheetMode == _SheetMode.expanded)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ValueListenableBuilder<double>(
                valueListenable: _sheetHeightNotifier,
                builder: (context, height, _) {
                  final quarter = _quarterHeight(context);
                  final threeQuarter = _threeQuarterHeight(context);
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: height,
                    child: SafeArea(
                      top: false,
                      child: _BottomSheet(
                        tokens: tokens,
                        moods: _moods,
                        selectedSceneId: _selectedSceneId,
                        onSelectMood: _selectMood,
                        onSelectScene: _selectScene,
                        onSkip: _onSkip,
                        onCompareCard: _onCompareCard,
                        onExifCard: _onExifCard,
                        localPostProcess: _localPostProcess,
                        bakedPostProcess: _bakedPostProcess,
                        onUpdateLocalPostProcess: _updateLocalPostProcess,
                        localTransform: _localTransform,
                        onUpdateLocalTransform: _updateLocalTransform,
                        // 折叠操作栏相关
                        onCompareToggle: _onCompareToggle,
                        isComparing: _isComparing,
                        onExpandToQuarter: () {
                          _sheetHeightNotifier.value = _quarterHeight(context);
                        },
                        onExpandToFull: () {
                          _sheetHeightNotifier.value =
                              _threeQuarterHeight(context);
                        },
                        // 抽屉栏拖拽相关
                        currentHeight: height,
                        closedHeight: _kClosedHeight,
                        quarterHeight: quarter,
                        threeQuarterHeight: threeQuarter,
                        isExpanded: height > _kClosedHeight + 20,
                        isFullExpanded: height > quarter + 20,
                        onDragStart: _onSheetDragStart,
                        onDragUpdate: _onSheetDragUpdate,
                        onDragEnd: (details) =>
                            _onSheetDragEnd(context, details),
                        onCropModeChanged: (isCrop) =>
                            setState(() => _isCropMode = isCrop),
                      ),
                    ),
                  );
                },
              ),
            ),
          // 4. 悬浮圆角按钮组（仅 _uiVisible && _sheetMode == hidden 时显示）
          // 包含：对比 / 保存到相册 / 编辑
          // 点击"编辑"展开抽屉栏到 1/4
          if (_uiVisible && _sheetMode == _SheetMode.hidden)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        // 半透明深色背景（80% 不透明），使用主题色
                        color: tokens.canvasDeep.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FloatingActionButton(
                            icon: Icons.compare,
                            label: '对比',
                            tokens: tokens,
                            active: _isComparing,
                            onTap: _onCompareToggle,
                          ),
                          const SizedBox(width: 16),
                          _FloatingActionButton(
                            icon: Icons.save_outlined,
                            label: '保存到系统相册',
                            tokens: tokens,
                            onTap: _onSaveToAlbum,
                          ),
                          const SizedBox(width: 16),
                          _FloatingActionButton(
                            icon: Icons.tune,
                            label: '编辑',
                            tokens: tokens,
                            onTap: () {
                              setState(() => _sheetMode = _SheetMode.expanded);
                              _sheetHeightNotifier.value =
                                  _quarterHeight(context);
                            },
                          ),
                          const SizedBox(width: 16),
                          _FloatingActionButton(
                            icon: Icons.delete_outline,
                            label: '删除',
                            tokens: tokens,
                            onTap: _onDelete,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 背景径向渐变装饰（glass 风格 backdrop-filter 可见性）
/// 与 templates_unlock_page._BackgroundDecoration 一致
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
                // 硬编码颜色，与 uni-app 一致 (preview-container bg #1C1A17)
                const Color(0xFF1C1A17).withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 顶部导航（LumiraNav transparent: true + 自定义返回按钮 + 分享按钮）
/// 对比按钮已移至底部折叠操作栏
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onShare,
    this.onSave,
    this.showSave = false,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onShare;

  /// 编辑态右上角保存按钮：仅当 showSave 为 true 时显示
  final VoidCallback? onSave;
  final bool showSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 透明背景：浮在照片上方
      color: Colors.transparent,
      child: LumiraNav(
        title: '照片预览',
        transparent: true,
        leading: _NavBackButton(
          onTap: onBack,
          color: tokens.textInverse,
        ),
        actions: [
          if (showSave && onSave != null)
            GestureDetector(
              onTap: onSave,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [tokens.brand, tokens.brandDeep],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_outlined,
                        size: 14, color: tokens.textInverse),
                    const SizedBox(width: 4),
                    Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: tokens.textInverse,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          GestureDetector(
            onTap: onShare,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.ios_share_outlined,
                size: 22,
                color: tokens.textInverse,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  const _NavBackButton({required this.onTap, required this.color});
  final VoidCallback onTap;
  final Color color;

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
          color: color,
        ),
      ),
    );
  }
}

/// 照片预览框
/// 修复：
/// 1. 原代码使用固定 3:4 AspectRatio + BoxFit.cover，改为自适应高度 + contain
/// 2. 添加 ColorFiltered 实时应用后期参数，所见即所得
/// 3. 参数隔离：postProcess 由父组件传入（本地状态），不直接 watch CaptureState，
///    避免预览页调整影响拍摄页参数
/// 4. 修复 WYSIWYG：使用传入的 targetRatio（与拍摄页取景器一致）作为 AspectRatio，
///    替代之前的 maxHeight: screenWidth * 1.33（3:4）约束。
///    旧约束会将 9:19.5 全屏照片强制压缩到 3:4 容器内，导致用户看到 4:3 比例。
///    新方案：AspectRatio(targetRatio) + BoxFit.contain，
///    - 若裁剪成功（照片已是 targetRatio）：填满容器，无信箱
///    - 若裁剪失败（照片仍为 4:3）：在 targetRatio 容器内信箱显示，便于诊断
class _PhotoFrame extends StatelessWidget {
  const _PhotoFrame({
    required this.tokens,
    required this.photoUrl,
    required this.isComparing,
    required this.postProcess,
    required this.transform,
    required this.targetRatio,
  });

  final ThemeTokens tokens;
  final String photoUrl;
  final bool isComparing;
  final PostProcess postProcess;
  final TransformParams transform;

  /// 照片目标比例（width/height），与拍摄页取景器使用同一逻辑计算
  final double targetRatio;

  @override
  Widget build(BuildContext context) {
    final bool isNetworkUrl = photoUrl.startsWith('http');

    Widget buildImage() => isNetworkUrl
        ? CachedNetworkImage(
            url: photoUrl,
            fit: BoxFit.contain,
            errorWidget: _PhotoEmptyState(tokens: tokens),
          )
        : Image.file(
            File(photoUrl),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _PhotoEmptyState(tokens: tokens),
          );

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: targetRatio,
          child: Container(
            color: const Color(0xFF1C1A17),
            child: photoUrl.isNotEmpty
                ? (isComparing
                    // 对比模式：显示原图，不应用任何变换或滤镜
                    ? buildImage()
                    : RotatedBox(
                        quarterTurns: transform.rotation ~/ 90,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..scale(
                              transform.flipH ? -1.0 : 1.0,
                              transform.flipV ? -1.0 : 1.0,
                              1.0,
                            ),
                          child: Transform.rotate(
                            angle: transform.straighten * math.pi / 180.0,
                            child: ColorFiltered(
                              colorFilter: fromPostProcess(postProcess),
                              child: buildImage(),
                            ),
                          ),
                        ),
                      ))
                : _PhotoEmptyState(tokens: tokens),
          ),
        ),
      ),
    );
  }
}

class _PhotoEmptyState extends StatelessWidget {
  const _PhotoEmptyState({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (photo-empty bg rgba(255,255,255,0.04))
      color: const Color.fromRGBO(255, 255, 255, 0.04),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.image_outlined,
            size: 40,
            // 硬编码颜色，与 uni-app 一致 (photo-empty-icon color rgba(255,255,255,0.3))
            color: Color.fromRGBO(255, 255, 255, 0.3),
          ),
          SizedBox(height: 8),
          Text(
            '无照片数据',
            style: TextStyle(
              fontSize: 13,
              // 硬编码颜色，与 uni-app 一致 (photo-empty-text color rgba(255,255,255,0.4))
              color: Color.fromRGBO(255, 255, 255, 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 底部抽屉栏（跟手拖动 + 三档吸附）
///
/// 通过 [currentHeight] / [isExpanded] / [isFullExpanded] 控制内容可见性：
/// - closed（!isExpanded）：拖拽条 + 折叠操作按钮组（对比/保存到相册/编辑/保存*）
/// - quarter（isExpanded && !isFullExpanded）：拖拽条 + PreviewEditPanel + 保存按钮
/// - threeQuarter（isFullExpanded）：拖拽条 + PreviewEditPanel + 心情 + 场景 + 操作行 + 保存按钮
///
/// 顶部拖拽手势区由父级通过 [onDragStart] / [onDragUpdate] / [onDragEnd] 处理，
/// 实时更新 [_sheetHeightNotifier] 实现跟手效果，松手后吸附到最近档位。
class _BottomSheet extends StatelessWidget {
  const _BottomSheet({
    required this.tokens,
    required this.moods,
    required this.selectedSceneId,
    required this.onSelectMood,
    required this.onSelectScene,
    required this.onSkip,
    required this.onCompareCard,
    required this.onExifCard,
    required this.localPostProcess,
    required this.bakedPostProcess,
    required this.onUpdateLocalPostProcess,
    required this.localTransform,
    required this.onUpdateLocalTransform,
    // 折叠操作栏相关
    required this.onCompareToggle,
    required this.isComparing,
    required this.onExpandToQuarter,
    // 点击「上滑查看更多」露出区：展开到 threeQuarter 查看完整心情/场景
    required this.onExpandToFull,
    // 抽屉栏拖拽相关
    required this.currentHeight,
    required this.closedHeight,
    required this.quarterHeight,
    required this.threeQuarterHeight,
    required this.isExpanded,
    required this.isFullExpanded,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onCropModeChanged,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final VoidCallback onSkip;
  final VoidCallback onCompareCard;
  final VoidCallback onExifCard;

  /// 预览页本地后期参数（仅影响当前照片，不回写 CaptureState）
  final PostProcess localPostProcess;

  /// 拍摄时已烘焙的后期参数基线（滑块显示全量 = 基线 + 本地增量）
  final PostProcess bakedPostProcess;

  /// 本地后期参数更新回调（仅更新本地状态，不污染拍摄页）
  final ValueChanged<PostProcess> onUpdateLocalPostProcess;

  /// 预览页本地变换参数（旋转/翻转/拉直，仅影响当前照片预览）
  final TransformParams localTransform;

  /// 本地变换参数更新回调
  final ValueChanged<TransformParams> onUpdateLocalTransform;

  /// 对比按钮点击：在「显示原图」与「显示滤镜后」之间切换
  final VoidCallback onCompareToggle;

  /// 当前是否处于对比（显示原图）状态
  final bool isComparing;

  /// 点击"编辑"按钮：展开抽屉栏到 quarter
  final VoidCallback onExpandToQuarter;

  /// 点击「上滑查看更多」露出区：展开抽屉栏到 threeQuarter
  final VoidCallback onExpandToFull;

  // ===== 抽屉栏拖拽相关 =====

  /// 当前抽屉栏高度（由父级 ValueNotifier 驱动）
  final double currentHeight;

  /// closed 档位高度
  final double closedHeight;

  /// quarter 档位高度
  final double quarterHeight;

  /// threeQuarter 档位高度
  final double threeQuarterHeight;

  /// 是否展开到 quarter 或更高（currentHeight > closedHeight + 20）
  final bool isExpanded;

  /// 是否展开到 threeQuarter（currentHeight > quarterHeight + 20）
  final bool isFullExpanded;

  /// 拖拽起始回调
  final void Function(DragStartDetails) onDragStart;

  /// 拖拽更新回调（实时更新高度）
  final void Function(DragUpdateDetails) onDragUpdate;

  /// 拖拽结束回调（吸附到最近档位）
  final void Function(DragEndDetails) onDragEnd;

  /// 裁剪工具激活状态回调（切到「裁剪旋转」Tab 时在照片上叠加裁剪框）
  final ValueChanged<bool> onCropModeChanged;

  @override
  Widget build(BuildContext context) {
    // 半透明深色背景（抽屉栏风格，浮在照片上方）
    // 使用主题 canvasDeep 色，确保深色/浅色主题下与照片对比度足够
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tokens.canvasDeep.withOpacity(0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 拖拽手势区 + 拖拽条（绑定 onVerticalDrag 系列回调，跟手拖动）
          GestureDetector(
            onVerticalDragStart: onDragStart,
            onVerticalDragUpdate: onDragUpdate,
            onVerticalDragEnd: onDragEnd,
            behavior: HitTestBehavior.opaque,
            child: Container(
              // 增大点击区域，便于拖拽
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: _SheetHandle(
                tokens: tokens,
                handleKey: const ValueKey('sheet_handle'),
              ),
            ),
          ),
          // 内容区（根据 isExpanded / isFullExpanded 条件渲染）
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  /// 根据 isExpanded / isFullExpanded 构建内容区。
  ///
  /// 使用 LayoutBuilder 检测可用高度：
  /// - AnimatedContainer 在吸附动画过程中高度会从旧值渐变到新值，
  ///   此时 isExpanded/isFullExpanded 已基于最终高度判定，但物理高度尚未到位，
  ///   PreviewEditPanel 在过小空间中渲染会触发 RenderFlex overflow。
  /// - 当可用高度 < 200px 时（动画过程中或 closed 状态），降级为折叠操作栏。
  Widget _buildContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        // 动画过程中或 closed 状态下高度不足时，显示折叠操作栏避免溢出
        if (availableHeight < 200) {
          return _buildCollapsedActions();
        }
        if (!isExpanded) {
          // closed：折叠操作按钮组
          return _buildCollapsedActions();
        }
        if (!isFullExpanded) {
          // quarter：PreviewEditPanel + 保存按钮 + 底部「心情/场景露出区」
          return Column(
            children: [
              Expanded(
                child: PreviewEditPanel(
                  postProcess: localPostProcess,
                  bakedPostProcess: bakedPostProcess,
                  transform: localTransform,
                  onPostProcessChanged: onUpdateLocalPostProcess,
                  onTransformChanged: onUpdateLocalTransform,
                  onCropModeChanged: onCropModeChanged,
                ),
              ),
              const SizedBox(height: 8),
              // 露出区：展示心情/场景 pill 一角 + 上滑提示，点击展开到 threeQuarter
              _QuarterPeek(
                tokens: tokens,
                moods: moods,
                selectedSceneId: selectedSceneId,
                onSelectMood: onSelectMood,
                onSelectScene: onSelectScene,
                onExpand: onExpandToFull,
              ),
            ],
          );
        }
        // threeQuarter：PreviewEditPanel + 心情 + 场景 + 操作行 + 保存按钮
        // 全部内容用 SingleChildScrollView 包裹避免溢出
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                // 收紧高度：让色彩/细节 Tab 内容（图标条+单滑块）贴合面板，
                // 避免在滑块下方与「今天的心情」之间留出大片空白。
                height: 176,
                child: PreviewEditPanel(
                  postProcess: localPostProcess,
                  bakedPostProcess: bakedPostProcess,
                  transform: localTransform,
                  onPostProcessChanged: onUpdateLocalPostProcess,
                  onTransformChanged: onUpdateLocalTransform,
                  onCropModeChanged: onCropModeChanged,
                ),
              ),
              const SizedBox(height: 8),
              _MoodSection(
                tokens: tokens,
                moods: moods,
                onSelectMood: onSelectMood,
                onSkip: onSkip,
              ),
              const SizedBox(height: 10),
              _SceneSection(
                tokens: tokens,
                selectedSceneId: selectedSceneId,
                onSelectScene: onSelectScene,
              ),
              const SizedBox(height: 10),
              _ActionRow(
                tokens: tokens,
                onCompareCard: onCompareCard,
                onExifCard: onExifCard,
              ),
            ],
          ),
        );
      },
    );
  }

  /// 折叠操作按钮组（closed 状态下显示）
  /// [对比] [编辑]
  Widget _buildCollapsedActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 对比按钮（点击切换显示原图/滤镜后）
          _CollapsedActionButton(
            icon: Icons.compare,
            label: '对比',
            tokens: tokens,
            onTap: onCompareToggle,
            active: isComparing,
          ),
          const SizedBox(width: 48),
          // 编辑（展开抽屉栏到 quarter）
          _CollapsedActionButton(
            icon: Icons.tune,
            label: '编辑',
            tokens: tokens,
            onTap: onExpandToQuarter,
          ),
        ],
      ),
    );
  }
}

/// 后期参数调整区已迁移至 `PreviewEditPanel`（4 标签编辑面板），
/// 见 `../widgets/preview_edit_panel.dart`。原 `_AdjustSection` / `_SliderRow` 已删除。
class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.tokens, this.handleKey});
  final ThemeTokens tokens;
  final Key? handleKey;

  @override
  Widget build(BuildContext context) {
    return Center(
      key: handleKey,
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          // 拖拽指示器：浅色（适配深色背景）
          color: tokens.textTertiary.withOpacity(0.5),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _MoodSection extends StatelessWidget {
  const _MoodSection({
    required this.tokens,
    required this.moods,
    required this.onSelectMood,
    required this.onSkip,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final ValueChanged<MoodOption> onSelectMood;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitleRow(
          title: '今天的心情是？',
          linkText: '跳过',
          onLinkTap: onSkip,
          tokens: tokens,
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < moods.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Pill(
                  icon: moods[i].icon,
                  text: moods[i].name,
                  active: moods[i].active,
                  onTap: () => onSelectMood(moods[i]),
                  tokens: tokens,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// quarter 档底部的「露出区」：同时预览心情 + 拍摄场景 pill 一角 + 上滑提示。
///
/// 解决心情/场景功能被"藏"在需上滑到 70% 档才可见的问题——
/// 在 quarter 档就同时露出心情与场景选项，并明确提示可上滑查看更多（操作行）。
/// 点击露出区空白处展开到 threeQuarter；点击 pill 直接选择，选择后停留在当前档。
class _QuarterPeek extends StatelessWidget {
  const _QuarterPeek({
    required this.tokens,
    required this.moods,
    required this.selectedSceneId,
    required this.onSelectMood,
    required this.onSelectScene,
    required this.onExpand,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    const scenes = CapturePreviewMockData.sceneOptions;
    return GestureDetector(
      onTap: onExpand,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 112,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              tokens.surfaceAlt.withOpacity(0.08),
              tokens.surfaceAlt.withOpacity(0.55),
            ],
          ),
          border: Border.all(color: tokens.divider, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 提示行：露出标题 + 上滑查看更多
            Row(
              children: [
                Icon(Icons.auto_awesome,
                    size: 14, color: tokens.brand),
                const SizedBox(width: 6),
                Text(
                  '心情 / 拍摄场景',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                Icon(Icons.expand_less,
                    size: 16, color: tokens.textSecondary),
                const SizedBox(width: 2),
                Text(
                  '上滑查看更多',
                  style: TextStyle(
                    fontSize: 11,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 露出心情 pill（可点击，选择后停留在当前档）
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < moods.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _Pill(
                      icon: moods[i].icon,
                      text: moods[i].name,
                      active: moods[i].active,
                      onTap: () => onSelectMood(moods[i]),
                      tokens: tokens,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 露出场景 pill（可点击，选择后停留在当前档）
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < scenes.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    _Pill(
                      icon: scenes[i].icon,
                      text: scenes[i].name,
                      active: selectedSceneId == scenes[i].id,
                      onTap: () => onSelectScene(scenes[i].id),
                      tokens: tokens,
                    ),
                  ],
                  const SizedBox(width: 8),
                  _Pill(
                    text: '不标记',
                    active: selectedSceneId == null,
                    onTap: () => onSelectScene(null),
                    tokens: tokens,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SceneSection extends StatelessWidget {
  const _SceneSection({
    required this.tokens,
    required this.selectedSceneId,
    required this.onSelectScene,
  });

  final ThemeTokens tokens;
  final String? selectedSceneId;
  final ValueChanged<String?> onSelectScene;

  @override
  Widget build(BuildContext context) {
    const scenes = CapturePreviewMockData.sceneOptions;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(title: '拍摄场景', tokens: tokens),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < scenes.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                _Pill(
                  icon: scenes[i].icon,
                  text: scenes[i].name,
                  active: selectedSceneId == scenes[i].id,
                  onTap: () => onSelectScene(scenes[i].id),
                  tokens: tokens,
                ),
              ],
              const SizedBox(width: 8),
              _Pill(
                text: '不标记',
                active: selectedSceneId == null,
                onTap: () => onSelectScene(null),
                tokens: tokens,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    required this.linkText,
    required this.onLinkTap,
    required this.tokens,
  });

  final String title;
  final String linkText;
  final VoidCallback onLinkTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _SectionTitle(title: title, tokens: tokens),
        ),
        GestureDetector(
          onTap: onLinkTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              linkText,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textTertiary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.tokens});
  final String title;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: 'Noto Serif SC',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: tokens.textPrimary,
      ),
    );
  }
}

/// 心情/场景 pill
class _Pill extends StatelessWidget {
  const _Pill({
    this.icon,
    required this.text,
    required this.active,
    required this.onTap,
    required this.tokens,
  });

  final IconData? icon;
  final String text;
  final bool active;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          gradient: active
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [tokens.brand, tokens.brandDeep],
                )
              : null,
          border: active
              ? Border.all(color: Colors.transparent, width: 1.5)
              : Border.all(color: tokens.divider, width: 1.5),
          color: active ? null : tokens.surface,
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: active ? tokens.textInverse : tokens.textSecondary,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: active ? tokens.textInverse : tokens.textSecondary,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 操作按钮行（生成对比图 / 生成 EXIF 卡片）
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.tokens,
    required this.onCompareCard,
    required this.onExifCard,
  });

  final ThemeTokens tokens;
  final VoidCallback onCompareCard;
  final VoidCallback onExifCard;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.bar_chart_outlined,
            text: '生成对比图',
            onTap: onCompareCard,
            tokens: tokens,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.content_paste_outlined,
            text: '生成 EXIF 卡片',
            onTap: onExifCard,
            tokens: tokens,
          ),
        ),
      ],
    );
  }
}

/// 折叠操作栏的紧凑按钮（圆形图标 + 文字）
/// 用于 closed 状态下底部操作栏：对比 / 保存到相册 / 编辑 / 保存*
class _CollapsedActionButton extends StatelessWidget {
  const _CollapsedActionButton({
    required this.icon,
    required this.label,
    required this.tokens,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final ThemeTokens tokens;
  final VoidCallback? onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  /// 是否为激活状态（如"对比"开启时高亮）
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: onPressStart == null ? null : (_) => onPressStart!(),
      onTapUp: onPressEnd == null ? null : (_) => onPressEnd!(),
      onTapCancel: onPressEnd,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 22,
                color: active ? tokens.brand : tokens.textPrimary),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: tokens.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// 悬浮圆角按钮组中的按钮（图标 + 文字垂直排列）
/// 用于 _sheetMode == hidden 时底部悬浮按钮组：对比 / 保存到相册 / 编辑
/// 按压时轻微缩放 + 品牌色淡底，提供柔和触感反馈。
class _FloatingActionButton extends StatefulWidget {
  const _FloatingActionButton({
    required this.icon,
    required this.label,
    required this.tokens,
    this.onTap,
    this.onPressStart,
    this.onPressEnd,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final ThemeTokens tokens;
  final VoidCallback? onTap;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;

  /// 是否为激活状态（如"对比"开启时高亮，提供视觉反馈）
  final bool active;

  @override
  State<_FloatingActionButton> createState() => _FloatingActionButtonState();
}

class _FloatingActionButtonState extends State<_FloatingActionButton> {
  bool _pressed = false;

  void _pressStart() {
    setState(() => _pressed = true);
    widget.onPressStart?.call();
  }

  void _pressEnd() {
    setState(() => _pressed = false);
    widget.onPressEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _pressStart(),
      onTapUp: (_) => _pressEnd(),
      onTapCancel: _pressEnd,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          // 适当扩大触控区，提升点击手感
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: (_pressed || widget.active)
              ? BoxDecoration(
                  color: tokens.brand.withOpacity(
                      _pressed ? 0.16 : 0.12),
                  borderRadius: BorderRadius.circular(18),
                )
              : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon,
                  size: 24,
                  color: widget.active
                      ? tokens.brand
                      : tokens.textPrimary),
              const SizedBox(height: 4),
              Text(
                widget.label,
                style: TextStyle(fontSize: 11, color: tokens.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: tokens.divider, width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: tokens.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    required this.icon,
    required this.text,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return LumiraListTile(
      leading: Icon(icon, size: 22, color: tokens.textPrimary),
      title: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: tokens.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
