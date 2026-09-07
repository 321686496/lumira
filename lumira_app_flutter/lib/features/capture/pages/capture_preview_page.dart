import 'dart:async';
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
import '../../../shared/widgets/common/lumira_surface.dart';
import '../data/capture_preview_mock_data.dart';
import '../data/capture_state.dart';
import '../data/capture_thumbnail_state.dart';
import '../widgets/compare_photo_button.dart';
import '../widgets/detail_effects_layer.dart';
import '../widgets/preview_edit_toolbar.dart';
import '../widgets/preview_tag_pill_row.dart';
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

/// 照片预览页（Task 2.9A）
///
/// 视觉规格来源：lumira-app/src/pages/capture/preview.vue (399 行)
/// - 深色背景 + LumiraNav transparent
/// - 照片预览（全屏，可双击缩放）
/// - 底部编辑 dock：心情/场景 pill 行 + 工具条（色彩/细节/滤镜/裁剪/重置）+ 滑出面板
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
    this.pendingFinal = false,
  });

  /// 路由参数：photoUrl（拍摄后的照片 URL）
  final String? photoUrl;

  /// 先快后真：本次以 early 早帧（低质量）打开、full-res 后台完成后需原位升级。
  /// true 时预览页监听 [captureThumbnailProvider] 从 interim→final，替换 _photoUrl。
  final bool pendingFinal;

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

  /// 先快后真：以 early 早帧打开、等 full-res 原位升级的挂起标记。
  /// 为 true 时禁止编辑/保存（避免用低清早帧落库），升级完成后置 false。
  bool _isPendingFinal = false;

  /// 打开时的 early 早帧路径（升级后 evict 其 FileImage 缓存）。
  String? _interimUrl;

  /// 监听 captureThumbnailProvider 从 interim→final 的升级订阅。
  ProviderSubscription<CaptureThumbnailState>? _upgradeSub;

  /// UI 显隐状态：true=显示导航栏和操作栏，false=全屏纯净查看
  bool _uiVisible = true;

  /// 裁剪工具是否激活（在照片本身上叠加裁剪框）
  bool _isCropMode = false;

  /// 当前激活编辑工具；null = 面板收起（裁剪模式 = activeTool == crop）
  PreviewEditTool? _activeTool;

  /// 对比按钮开启后的短暂状态徽标
  bool _showCompareBadge = false;
  Timer? _compareBadgeTimer;

  /// 将裁剪比例字符串解析为数值宽高比（width/height），null 表示自由裁剪。
  /// [screenRatio] 用于 'fullscreen'（= 取景器/屏幕比例，与拍摄语义一致）。
  static double? _parseCropAspectRatio(String ratio, double screenRatio) {
    if (ratio == 'free' || ratio == 'none' || ratio.isEmpty) {
      return null;
    }
    if (ratio == 'fullscreen') return screenRatio;
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
    // 裁剪比例初值：拍摄比例已知时同步取之（默认选框 = 满幅，无操作 = 无裁剪）；
    // 未知时置 'free'（同样满幅），并在首帧后按照片实际比例校正。
    final captureRatio =
        (widget.aspectRatio != null && widget.aspectRatio!.isNotEmpty)
            ? widget.aspectRatio!
            : 'free';
    _localPostProcess =
        PostProcess(color: const PostProcessColor(), cropRatio: captureRatio);
    _currentPhotoId = widget.photoId;
    _pageController = PageController(initialPage: 0);
    _loadHistoryPhotos(); // fire-and-forget; loads DB history + original path
    // 先快后真：以 early 早帧打开时，监听 full-res 完成 → 原位升级 _photoUrl。
    _isPendingFinal = widget.pendingFinal;
    if (_isPendingFinal) {
      _interimUrl = _photoUrl.isNotEmpty ? _photoUrl : null;
      _upgradeSub = ref.listenManual<CaptureThumbnailState>(
        captureThumbnailProvider,
        (prev, next) {
          if (!_isPendingFinal) return;
          if (next.status == CaptureThumbnailStatus.final_ &&
              next.finalPath != null &&
              !_isEdited) {
            _upgradeInterimToFinal(next.finalPath!);
          }
        },
      );
    }
    // 首帧后按照片实际宽高比校正裁剪比例（兜底：拍摄比例参数缺失/不符时）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initLocalCropRatio();
    });
  }

  /// 按照片实际宽高比初始化本地裁剪比例（[PhotoPostProcessor.uiRatioIdForAspect]）。
  ///
  /// 不初始化时本地 cropRatio 为构造默认 '3:4'，进入裁剪模式即按 3:4 锁框
  /// 并回传默认选区 → 用户未做任何操作保存也会把 fullscreen 等比例照片裁成 3:4。
  /// 初始化为与照片一致的比例后，默认选框 = 满幅（无操作 = 无裁剪，WYSIWYG）。
  /// [path] 为保存后的新照片路径（保存后重置场景传入；缺省取当前照片）。
  Future<void> _initLocalCropRatio({String? path}) async {
    try {
      final photoPath = path ?? _photoUrl;
      final displayPath =
          (photoPath.isNotEmpty && !photoPath.startsWith('http'))
              ? photoPath
              : null;
      if (displayPath == null) return;
      // await 前先取屏幕比例（避免跨 await 使用 context）
      final screenRatio = MediaQuery.of(context).size.aspectRatio;
      final size = await PhotoPostProcessor.resolveImageSize(displayPath);
      if (size == null || size.width <= 0 || size.height <= 0) return;
      final ratioId = PhotoPostProcessor.uiRatioIdForAspect(
          size.width / size.height, screenRatio);
      if (!mounted) return;
      setState(() {
        // 仅覆盖比例，不动 customCropRect（null = 默认选区，首帧后回传）
        _localPostProcess = _localPostProcess.copyWith(cropRatio: ratioId);
      });
    } catch (e) {
      debugPrint('[preview] 初始化裁剪比例失败（忽略）: $e');
    }
  }

  @override
  void dispose() {
    _upgradeSub?.close();
    _upgradeSub = null;
    _compareBadgeTimer?.cancel();
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
    // 按该照片实际宽高比初始化裁剪比例（默认选框 = 满幅，无操作 = 无裁剪）
    _initLocalCropRatio();
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
    if (_guardPendingFinal()) return;
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
    if (_guardPendingFinal()) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localTransform = t;
      _isEdited = true;
    });
  }

  /// 编辑工具切换（null = 收起面板）；进入裁剪工具受先快后真门控。
  void _onToolChanged(PreviewEditTool? next) {
    if (next == PreviewEditTool.crop && _guardPendingFinal()) return;
    setState(() {
      _activeTool = next;
      _isCropMode = next == PreviewEditTool.crop;
    });
  }

  /// 一键重置全部本地编辑：增量归零 + 变换归零 + 裁剪选区清空
  /// （cropRatio 保留照片实际比例基线 = 满幅选框，无操作 = 无裁剪）。
  void _resetAllLocal() {
    if (!mounted) return;
    if (_guardPendingFinal()) return;
    if (_isReadOnly) {
      _showReadOnlyToast();
      return;
    }
    setState(() {
      _localPostProcess = PostProcess(
        color: const PostProcessColor(),
        cropRatio: _localPostProcess.cropRatio,
      );
      _localTransform = const TransformParams();
      _isEdited = false;
    });
  }

  /// 先快后真门控：full-res 尚未生成完（_isPendingFinal 仍为 true）时，禁止用低清
  /// 早帧做编辑/保存/裁剪，避免"编辑了却以低清落库"。返回 true 表示已被拦截。
  bool _guardPendingFinal() {
    if (!_isPendingFinal || !mounted) return false;
    LumiraToast.show(
      context,
      '高清照片生成中，稍后再编辑',
      duration: const Duration(milliseconds: 1500),
    );
    return true;
  }

  /// 先快后真：full-res 后台处理完成，把预览页从 early 早帧原位升级为高清成片。
  void _upgradeInterimToFinal(String finalPath) {
    if (!mounted || finalPath.isEmpty || finalPath == _photoUrl) return;
    final prevUrl = _photoUrl;
    final interimUrl = _interimUrl;
    setState(() {
      _photoUrl = finalPath;
      _isPendingFinal = false;
      _interimUrl = null;
    });
    // evict 旧图缓存（早帧 + 旧路径），避免旧低清帧残留
    if (interimUrl != null && interimUrl.isNotEmpty) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(interimUrl)));
    }
    if (prevUrl != null && prevUrl.isNotEmpty && prevUrl != finalPath) {
      PaintingBinding.instance.imageCache.evict(FileImage(File(prevUrl)));
    }
    // full-res 已落库：重载历史，恢复 originalPath / bakedPostProcess / 只读位
    _loadHistoryPhotos();
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

  // ===== 事件处理 =====

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  /// 右上角对比按钮：在「修改后」与「修改前（烘焙基线）」之间切换；
  /// 开启时短暂显示状态徽标（1s 后淡出），帮助用户理解当前看到的版本。
  void _onCompareToggle() {
    if (!mounted) return;
    setState(() {
      _isComparing = !_isComparing;
      _showCompareBadge = true;
    });
    _compareBadgeTimer?.cancel();
    _compareBadgeTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) setState(() => _showCompareBadge = false);
    });
  }

  /// 照片单击（来自 PhotoView 的单击回调，双击已交给内置缩放，不会触发此处）
  /// - 面板展开时：点击照片先收面板（不进纯净模式）
  /// - 否则：切换 UI 显隐（纯净模式查看全图）
  void _onPhotoTap(
    BuildContext context,
    TapUpDetails details,
    PhotoViewControllerValue _,
  ) {
    if (!mounted) return;
    setState(() {
      if (_activeTool != null) {
        // 面板展开时：点照片先收面板（不进纯净模式）
        _activeTool = null;
        _isCropMode = false;
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

    // 细节效果实时预览（锐化/磨皮/暗角/颗粒/拉腿的增量）：非对比、任一增量非零、
    // 且本地文件（非 http）→ 底层图片切为 GPU shader 细节效果层（磨皮也统一由该层
    // 处理，不再单独走 SmoothImageLayer）。解码未就绪/失败时自动回退到 buildImage()。
    final detailEffects = DetailEffectsParams.fromPostProcess(postProcess);
    final useDetailFx =
        !isComparing && detailEffects.hasAnyEffect && !isNetworkUrl;
    final Widget baseImage = useDetailFx
        ? DetailEffectsLayer(
            url: photoUrl,
            effects: detailEffects,
            fallback: buildImage,
          )
        : buildImage();

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
            child: baseImage,
          ),
        ),
      ),
    );
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
            icon: Icons.compare_outlined,
            text: '生成对比图',
            tokens: tokens,
            onTap: () {
              Navigator.of(ctx).pop();
              _onCompareCard();
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
    // 再点选中项 = 取消全部（等同旧「跳过」）
    final bool deselect = selected.active;
    setState(() {
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i].copyWith(
            active: deselect ? false : _moods[i].name == selected.name);
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
    if (_guardPendingFinal()) return;

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

      // 检查原图是否存在
      if (!await File(originalPath).exists()) {
        if (!mounted) return;
        LumiraToast.show(context, '原图文件不存在，无法重新处理');
        return;
      }

      // 屏幕比例 / 方向与拍摄烘焙时一致（应用锁竖屏，MediaQuery 即拍摄时比例）
      final screenSize = MediaQuery.of(context).size;
      final screenRatio = screenSize.width / screenSize.height;
      final screenIsPortrait = screenSize.height >= screenSize.width;

      // 解析裁剪上下文（多轮编辑 WYSIWYG 的关键，与后期修图页一致）：
      // - baseRatio / isPortrait 按烘焙照片实际尺寸推断（滑动切换到历史照片、
      //   横屏拍摄等场景不会被当前屏幕方向误判）；
      // - innerCropRect = 本轮 UI 框选（相对当前展示照片）；
      // - baseCropRect = DB 记录的上一轮裁剪（相对比例基准区域）；
      // - composedCropRect = 两者嵌套组合，保存后写回 DB 供下一轮编辑。
      final plan = await PhotoPostProcessor.resolveCropSavePlan(
        baked: _bakedPostProcess,
        local: _localPostProcess,
        displayedPhotoPath: photoPath,
        originalPath: originalPath,
        screenRatio: screenRatio,
        fallbackIsPortrait: screenIsPortrait,
        fallbackRatio: widget.aspectRatio,
      );

      // 从原图重新处理（全量参数 = baked + local增量；裁剪字段显式覆盖为
      // 组合结果——merge 对 cropRatio 恒取 baked、customCropRect 仅在 local
      // 非空时覆盖，均不符合嵌套组合语义）
      // - 替换原图：outputPath=photoPath，覆盖当前显示的照片文件
      // - 另存为：写入不冲突的新文件路径，不影响原图
      final fullParams = _bakedPostProcess.merge(_localPostProcess).copyWith(
        cropRatio: plan.baseRatio,
        customCropRect: plan.composedCropRect,
      );
      final outputPath =
          isDuplicate ? _makeDuplicatePath(photoPath) : photoPath;
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: originalPath,
        params: fullParams,
        transform: _localTransform,
        aspectRatio: plan.baseRatio,
        screenRatio: screenRatio,
        isPortrait: plan.isPortrait,
        outputPath: outputPath,
        // 本轮框选（相对展示照片），与 baseCropRect 在 processFile 内嵌套
        // 组合后映射到原图，保证「框选内容 == 导出内容」
        customCropRect: plan.innerCropRect,
        baseCropRect: plan.baseCropRect,
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
          // 替换原图：保留原图（可再次编辑），更新当前记录。
          // 注意 postProcess 必须存【全量参数】（与 JPEG 烘焙内容一致），
          // 之前误存 _localPostProcess（增量）会导致下一轮编辑的烘焙基线错乱。
          await dao.updateEdit(
            id: currentPhotoId,
            filePath: processedPath,
            originalPath: originalPath,
            transform: _localTransform,
            postProcess: fullParams,
          );
          ref.invalidate(galleryDaoProvider);
          if (mounted) {
            setState(() {
              _originalPath = originalPath;
              _isReadOnly = false;
              // 保存后照片已用 fullParams（baked+local）重新处理（烘焙），
              // 更新 _bakedPostProcess 为全量参数，_localPostProcess 重置为增量 0。
              _bakedPostProcess = fullParams;
              _localPostProcess = PostProcess(
                color: const PostProcessColor(),
                cropRatio: _localPostProcess.cropRatio,
              );
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
            // 按新照片实际比例校正裁剪比例（自由裁剪出非标比例时归 'free'）
            _initLocalCropRatio(path: processedPath);
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
    if (_guardPendingFinal()) return;
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
      // 屏幕比例 / 方向与拍摄烘焙时一致（与 _save 的保存路径保持一致）
      final screenSize = MediaQuery.of(context).size;
      final screenRatio = screenSize.width / screenSize.height;
      final screenIsPortrait = screenSize.height >= screenSize.width;
      // 解析裁剪上下文（与 _onSave 同一套组合规则，
      // 保证保存到系统相册的结果与编辑页框选一致）
      final plan = await PhotoPostProcessor.resolveCropSavePlan(
        baked: _bakedPostProcess,
        local: _localPostProcess,
        displayedPhotoPath: photoPath,
        originalPath: _originalPath!,
        screenRatio: screenRatio,
        fallbackIsPortrait: screenIsPortrait,
        fallbackRatio: widget.aspectRatio,
      );
      // 从原图重新处理（应用当前编辑参数），写出到临时文件
      final fullParams = _bakedPostProcess.merge(_localPostProcess).copyWith(
        cropRatio: plan.baseRatio,
        customCropRect: plan.composedCropRect,
      );
      tmpPath = _makeDuplicatePath(photoPath);
      final processedPath = await PhotoPostProcessor.processFile(
        inputPath: _originalPath!,
        params: fullParams,
        transform: _localTransform,
        aspectRatio: plan.baseRatio,
        screenRatio: screenRatio,
        isPortrait: plan.isPortrait,
        outputPath: tmpPath,
        // 本轮框选 + 上一轮裁剪嵌套组合，与编辑页框选所见即所得
        customCropRect: plan.innerCropRect,
        baseCropRect: plan.baseCropRect,
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
      body: Column(
        children: [
          // 1. 照片区：占满剩余空间（面板展开时由 Column 自动收缩）
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 照片本体（裁剪模式 → PhotoCropLayer；否则 PhotoView/历史滑动）
                _buildPhotoStage(tokens),
                // 顶部导航 + 只读横幅 + 右上角对比按钮/徽标（仅 _uiVisible 时显示）。
                // 对比按钮与顶栏共用同一 SafeArea 布局流、位于顶栏下方：
                // 真机状态栏 inset 下不与顶栏右侧动作图标重叠（不再引入
                // 独立于顶栏高度的 top 魔法值）。
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
                            showSave: _isEdited,
                            onDelete: _onDelete,
                            onSaveToAlbum: _onSaveToAlbum,
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
                          // 右上角对比按钮（顶栏下方，叠照片浮层取向：半透明+细边无阴影）
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16, right: 12),
                                child: ComparePhotoButton(
                                  comparing: _isComparing,
                                  tokens: tokens,
                                  onTap: _onCompareToggle,
                                  overlayOnImage: true,
                                ),
                              ),
                            ],
                          ),
                          // 对比状态徽标（开启后 1s 内显示，说明当前看到的版本）
                          if (_showCompareBadge)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(top: 8, right: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(1000),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.25)),
                                    ),
                                    child: Text(
                                      _isComparing ? '查看修改前' : '已回到修改后',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // 2. 底部编辑 dock：心情/场景 pill 行 + 工具条 + 滑出面板
          if (_uiVisible) _buildEditDock(tokens),
        ],
      ),
    );
  }

  /// 照片区：裁剪模式 → PhotoCropLayer；否则单张 PhotoView / 历史滑动 Gallery。
  /// （内容与旧版一致，仅去掉底部 sheet inset 包装）
  Widget _buildPhotoStage(ThemeTokens tokens) {
    return _isCropMode
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
                _localPostProcess.cropRatio,
                MediaQuery.of(context).size.aspectRatio),
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
              final childSize = Size(outer.width * 2, outer.height * 2);

              // 无历史照片：单张预览
              if (_historyPhotos.isEmpty) {
                return PhotoView.customChild(
                  childSize: childSize,
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: 6.0,
                  scaleStateCycle: _previewScaleCycle,
                  onTapUp: _onPhotoTap,
                  backgroundDecoration:
                      const BoxDecoration(color: Colors.black),
                  child: _buildPhotoContent(
                    _photoUrl,
                    _isComparing,
                    _localPostProcess,
                    _localTransform,
                  ),
                );
              }

              // 有历史照片：PhotoViewGallery 边界感知横向切换
              return PhotoViewGallery.builder(
                itemCount: _historyPhotos.length,
                pageController: _pageController,
                onPageChanged: _onPageChanged,
                scrollPhysics: const BouncingScrollPhysics(),
                backgroundDecoration:
                    const BoxDecoration(color: Colors.black),
                builder: (context, index) {
                  final record = _historyPhotos[index];
                  final url = record.filePath ?? record.dataUrl ?? '';
                  final bool isCurrent = index == _currentIndex;
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
                            const PostProcess(color: PostProcessColor()),
                            record.transform ?? const TransformParams(),
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
          );
  }

  /// 底部编辑 dock：单卡片承载 pill 行 + 工具条 + 滑出面板
  Widget _buildEditDock(ThemeTokens tokens) {
    // 滤镜缩略图：仅本地文件路径可用（网络图/空路径 → null 降级文字 Chip）
    final bool isNetwork = _photoUrl.startsWith('http');
    final String? previewImagePath =
        (_photoUrl.isNotEmpty && !isNetwork) ? _photoUrl : null;
    // SafeArea(top: false)：手势导航设备上避开底部 home 指示条
    // （viewPadding.bottom 24-48dp），pill 行/工具条不被系统手势条遮挡
    // （与顶栏的 SafeArea(bottom: false) 对称）。
    return SafeArea(
      top: false,
      child: LumiraSurface(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        radius: 20,
        clip: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PreviewTagPillRow(
              moods: _moods,
              selectedSceneId: _selectedSceneId,
              onSelectMood: _selectMood,
              onSelectScene: _selectScene,
              tokens: tokens,
            ),
            Container(
                width: double.infinity, height: 1, color: tokens.divider),
            PreviewEditToolbar(
              activeTool: _activeTool,
              postProcess: _localPostProcess,
              bakedPostProcess: _bakedPostProcess,
              transform: _localTransform,
              onToolChanged: _onToolChanged,
              onPostProcessChanged: _updateLocalPostProcess,
              onTransformChanged: _updateLocalTransform,
              onReset: _resetAllLocal,
              previewImagePath: previewImagePath,
              isReadOnly: _isReadOnly,
              onReadOnlyTap: _showReadOnlyToast,
              tokens: tokens,
            ),
          ],
        ),
      ),
    );
  }
}

/// 顶部导航（LumiraNav transparent: true + 自定义返回按钮 + 顶栏动作图标）
/// 保存 pill（编辑态）/ 删除 / 保存到系统相册 / 分享
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onShare,
    this.onSave,
    this.showSave = false,
    this.onDelete,
    this.onSaveToAlbum,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onShare;

  /// 编辑态右上角保存按钮：仅当 showSave 为 true 时显示
  final VoidCallback? onSave;
  final bool showSave;

  /// 删除当前照片（原底部悬浮组操作，收进顶栏）
  final VoidCallback? onDelete;

  /// 保存到系统相册（原底部悬浮组操作，收进顶栏）
  final VoidCallback? onSaveToAlbum;

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
          if (onDelete != null)
            _NavIcon(
                icon: Icons.delete_outline, onTap: onDelete!, tokens: tokens),
          if (onSaveToAlbum != null)
            _NavIcon(
                icon: Icons.save_alt, onTap: onSaveToAlbum!, tokens: tokens),
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

/// 顶栏动作图标（叠照片浮层）
class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    required this.onTap,
    required this.tokens,
  });

  final IconData icon;
  final VoidCallback onTap;
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22, color: tokens.textInverse),
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
