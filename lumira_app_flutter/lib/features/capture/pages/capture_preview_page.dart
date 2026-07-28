import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/router/route_names.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../shared/widgets/feedback/lumira_toast.dart';
import '../../../shared/widgets/nav/lumira_nav.dart';
import '../data/capture_preview_mock_data.dart';
import '../data/capture_state.dart';
import '../domain/filter_recipe.dart';
import '../domain/photo_template.dart';
import '../services/compare_image_generator.dart';
import 'package:share_plus/share_plus.dart';
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
/// - 照片预览（3:4）
/// - 底部白色 Sheet：心情标签 + 场景标签 + 操作按钮 + 保存按钮
///
/// 已知简化决策（brief §8）：
/// - photoUrl 路由参数：mock 阶段为 picsum URL，真实接入 Task 2.3 CaptureState
/// - 保存到相册：mock SnackBar + pop，不接入 saver_gallery
/// - 生成对比图 / EXIF 卡片：mock SnackBar，不接入图像生成
class CapturePreviewPage extends ConsumerStatefulWidget {
  const CapturePreviewPage({super.key, this.photoUrl, this.photoId});

  /// 路由参数：photoUrl（拍摄后的照片 URL）
  final String? photoUrl;

  /// 路由参数：photoId（拍摄时自动保存到 DB 的记录 id）
  /// 用于在预览页修改场景时同步更新 DB 记录
  final String? photoId;

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

  /// 拍摄时的后期参数快照（用于计算 delta，避免重复处理）。
  /// 在 initState 中从 CaptureState.effectivePostProcessProvider 读取一次，
  /// 之后不再变化。保存时用 (_localPostProcess - _initialPostProcess) 作为 delta
  /// 应用到已处理的照片上，避免参数被重复叠加。
  late final PostProcess _initialPostProcess;

  /// 预览页本地后期参数（仅影响当前照片，不回写 CaptureState）。
  /// 修复参数泄漏：之前直接修改 CaptureState.editableTemplateProvider /
  /// freeModePostProcessProvider，导致返回拍摄页后拍摄页参数也被改变。
  /// 现在使用本地状态，保存时按 delta 应用到照片文件，拍摄页参数不受影响。
  late PostProcess _localPostProcess;

  @override
  void initState() {
    super.initState();
    _photoUrl =
        widget.photoUrl ?? CapturePreviewMockData.lastCapturedPhotoUrl;
    _moods = CapturePreviewMockData.moods
        .map((m) => m.copyWith(active: m.active))
        .toList();
    // 快照拍摄时参数，作为本地调整的初始值和 delta 基准。
    // ConsumerState.initState 中 ref.read 是安全的（provider 已初始化）。
    final initial = ref.read(CaptureState.effectivePostProcessProvider);
    _initialPostProcess = initial;
    _localPostProcess = initial;
  }

  /// 本地后期参数更新（仅影响预览和保存，不回写 CaptureState）
  void _updateLocalPostProcess(PostProcess next) {
    if (!mounted) return;
    setState(() => _localPostProcess = next);
  }

  // ===== 事件处理 =====

  void _back() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      GoRouter.of(context).go(RouteNames.capture);
    }
  }

  void _onCompareStart() {
    setState(() => _isComparing = true);
  }

  void _onCompareEnd() {
    if (!mounted) return;
    setState(() => _isComparing = false);
  }

  void _onSkip() {
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
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5E0D8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _ShareOption(
              icon: Icons.save_alt_outlined,
              text: '保存到相册',
              onTap: () {
                Navigator.of(ctx).pop();
                _onSave();
              },
            ),
            _ShareOption(
              icon: Icons.ios_share_outlined,
              text: '分享到系统',
              onTap: () {
                Navigator.of(ctx).pop();
                _onShareSystem();
              },
            ),
            _ShareOption(
              icon: Icons.content_paste_outlined,
              text: '生成 EXIF 海报',
              onTap: () {
                Navigator.of(ctx).pop();
                _onExifPoster();
              },
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.close,
              text: '取消',
              onTap: () => Navigator.of(ctx).pop(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 分享原始照片到系统
  Future<void> _onShareSystem() async {
    if (_photoUrl.isEmpty) return;
    try {
      if (_photoUrl.startsWith('http')) {
        await Share.share(_photoUrl, subject: '如画 LUMIRA · 拍摄作品');
      } else {
        await Share.shareXFiles(
          [XFile(_photoUrl)],
          subject: '如画 LUMIRA · 拍摄作品',
          text: '我用如画拍了一张照片，快来看看吧！',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('分享失败：$e')),
      );
    }
  }

  /// 生成 EXIF 海报并弹出 PosterGenerator 预览
  Future<void> _onExifPoster() async {
    if (_photoUrl.isEmpty || _photoUrl.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('网络图片无法生成 EXIF 海报')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('生成失败：$e')),
      );
    }
  }

  void _selectMood(MoodOption selected) {
    setState(() {
      for (var i = 0; i < _moods.length; i++) {
        _moods[i] = _moods[i].copyWith(active: _moods[i].name == selected.name);
      }
    });
  }

  void _selectScene(String? id) {
    setState(() {
      _selectedSceneId = id;
    });
    // 同步更新数据库中的场景标记（拍摄时已落库，此处更新 scene_id 字段）
    final photoId = widget.photoId;
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

  /// 保存到系统相册（应用相册已在拍摄时自动保存）
  /// 修复：
  /// 1. saver_gallery 不支持 HarmonyOS，改用 MethodChannel 调用原生 photoAccessHelper
  /// 2. 添加详细诊断日志，LumiraToast 显示具体成功/失败信息
  /// 3. 参数隔离：仅应用预览页本地调整的 delta（_localPostProcess - _initialPostProcess）
  ///    到已处理的照片上，避免参数被重复叠加，也不回写 CaptureState（不影响拍摄页）。
  ///    delta 仅包含亮度/对比度/饱和度三个预览页可调字段，其他效果（锐化/暗角/颗粒/LUT）
  ///    保留拍摄时的处理结果，不重复应用。
  Future<void> _onSave() async {
    if (_photoUrl.isEmpty) {
      LumiraToast.show(context, '无照片数据');
      return;
    }

    final bool isLocalFile = !_photoUrl.startsWith('http');

    // 保存前应用预览页本地调整的 delta（亮度/对比度/饱和度）
    // delta = _localPostProcess - _initialPostProcess，仅对预览页可调字段计算差值
    String savePath = _photoUrl;
    if (isLocalFile) {
      final deltaColor = PostProcessColor(
        brightness:
            _localPostProcess.color.brightness - _initialPostProcess.color.brightness,
        contrast:
            _localPostProcess.color.contrast - _initialPostProcess.color.contrast,
        saturation:
            _localPostProcess.color.saturation - _initialPostProcess.color.saturation,
        // 其他字段（temperature/tint）预览页未暴露滑块，delta = 0
        temperature: 0,
        tint: 0,
      );
      final deltaParams = PostProcess(color: deltaColor);
      debugPrint('[save] 应用预览页本地调整 delta: '
          'b=${deltaColor.brightness}, c=${deltaColor.contrast}, s=${deltaColor.saturation}');
      // aspectRatio='free' 跳过裁剪（照片在拍摄时已按选定比例裁剪）
      // rawMode=false 让 delta color matrix 生效
      savePath = await PhotoPostProcessor.processFile(
        inputPath: _photoUrl,
        params: deltaParams,
        rawMode: false,
        aspectRatio: 'free',
      );

      // 修复：二次处理覆盖文件后 evict FileImage 缓存，避免预览页和
      // 后续相册页显示旧版本解码图（与 capture_page.dart 的修复同理）。
      try {
        PaintingBinding.instance.imageCache.evict(FileImage(File(savePath)));
      } catch (_) {}
    }

    File? imageFile;
    if (isLocalFile) {
      imageFile = File(savePath);
      if (!await imageFile.exists()) {
        if (!mounted) return;
        LumiraToast.show(context, '照片文件不存在');
        return;
      }
    }

    // 调用原生保存到系统相册（应用相册已在拍摄时自动保存，此处不重复写 DB）
    if (isLocalFile && imageFile != null) {
      try {
        debugPrint('[save] 调用原生保存到系统相册: ${imageFile.path}');
        final result = await _photoSaverChannel.invokeMethod('saveToAlbum', {
          'path': imageFile.path,
        });
        debugPrint('[save] 原生保存结果: $result');
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
      }
    } else {
      if (!mounted) return;
      LumiraToast.show(context, '网络图片不支持保存到系统相册');
    }

    // 保存完成后延迟返回
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      } else {
        GoRouter.of(context).go(RouteNames.gallery);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ref.watch(themeTokensProvider);

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

    // 计算照片的目标比例（与拍摄页 _ViewfinderArea 使用同一逻辑），
    // 用于 _PhotoFrame 的 AspectRatio，确保预览页显示比例 = 拍摄页取景器比例 = 照片实际比例。
    // 修复 Bug：原代码使用 maxHeight: screenWidth * 1.33（3:4）强制容器比例，
    // 导致全屏 9:19.5 照片被信箱模式压缩为 3:4 显示。
    final ratioId = ref.watch(CaptureState.aspectRatioProvider);
    final screenSize = MediaQuery.of(context).size;
    final isPortrait = screenSize.height >= screenSize.width;
    final screenRatio = screenSize.width / screenSize.height;
    final photoTargetRatio =
        CaptureState.computeTargetRatio(ratioId, isPortrait) ?? screenRatio;

    return Scaffold(
      // 硬编码颜色，与 uni-app 一致 (preview-container bg #1C1A17)
      backgroundColor: const Color(0xFF1C1A17),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _BackgroundDecoration(tokens: tokens),
          SafeArea(
            top: false,
            bottom: false,
            child: Column(
              children: [
                _PreviewNav(
                  tokens: tokens,
                  onBack: _back,
                  onPressStart: _onCompareStart,
                  onPressEnd: _onCompareEnd,
                  onShare: _onShare,
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _PhotoFrame(
                          tokens: tokens,
                          photoUrl: _photoUrl,
                          isComparing: _isComparing,
                          // 照片目标比例：与拍摄页取景器一致，确保 WYSIWYG
                          targetRatio: photoTargetRatio,
                          // 使用本地后期参数，避免回写 CaptureState 导致参数泄漏
                          postProcess: _localPostProcess,
                        ),
                        _BottomSheet(
                          tokens: tokens,
                          moods: _moods,
                          selectedSceneId: _selectedSceneId,
                          onSelectMood: _selectMood,
                          onSelectScene: _selectScene,
                          onSkip: _onSkip,
                          onCompareCard: _onCompareCard,
                          onExifCard: _onExifCard,
                          onSave: _onSave,
                          // 本地后期参数及更新回调，供 _AdjustSection 使用
                          localPostProcess: _localPostProcess,
                          onUpdateLocalPostProcess: _updateLocalPostProcess,
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

/// 顶部导航（LumiraNav transparent: true + 自定义返回按钮 + 对比链接）
class _PreviewNav extends StatelessWidget {
  const _PreviewNav({
    required this.tokens,
    required this.onBack,
    required this.onPressStart,
    required this.onPressEnd,
    required this.onShare,
  });

  final ThemeTokens tokens;
  final VoidCallback onBack;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return Container(
      // 硬编码颜色，与 uni-app 一致 (preview-nav bg rgba(28,26,23,0.9))
      color: const Color.fromRGBO(28, 26, 23, 0.9),
      child: LumiraNav(
        title: '照片预览',
        transparent: true,
        leading: _NavBackButton(onTap: onBack),
        actions: [
          _CompareLink(
            onTap: () {},
            onPressStart: onPressStart,
            onPressEnd: onPressEnd,
          ),
          GestureDetector(
            onTap: onShare,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(
                Icons.ios_share_outlined,
                size: 22,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavBackButton extends StatelessWidget {
  const _NavBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new,
          size: 20,
          // 硬编码颜色，与 uni-app 一致 (nav-back-icon color #ffffff)
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CompareLink extends StatelessWidget {
  const _CompareLink({
    required this.onTap,
    required this.onPressStart,
    required this.onPressEnd,
  });
  final VoidCallback onTap;
  final VoidCallback onPressStart;
  final VoidCallback onPressEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onPressStart(),
      onTapUp: (_) => onPressEnd(),
      onTapCancel: onPressEnd,
      behavior: HitTestBehavior.opaque,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Text(
          '对比 ›',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            // 硬编码颜色，与 uni-app 一致 (nav-compare color #C9A96E)
            color: Color(0xFFC9A96E),
          ),
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
    required this.targetRatio,
  });

  final ThemeTokens tokens;
  final String photoUrl;
  final bool isComparing;
  final PostProcess postProcess;

  /// 照片目标比例（width/height），与拍摄页取景器使用同一逻辑计算
  final double targetRatio;

  @override
  Widget build(BuildContext context) {
    final bool isNetworkUrl = photoUrl.startsWith('http');
    // 对比模式下不应用滤镜，显示原图
    final colorFilter =
        isComparing ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
            : fromPostProcess(postProcess);

    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: targetRatio,
          child: Container(
            color: const Color(0xFF1C1A17),
            child: photoUrl.isNotEmpty
                ? ColorFiltered(
                    colorFilter: colorFilter,
                    child: isNetworkUrl
                        ? Image.network(
                            photoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _PhotoEmptyState(tokens: tokens),
                          )
                        : Image.file(
                            File(photoUrl),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _PhotoEmptyState(tokens: tokens),
                          ),
                  )
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

/// 底部白色 Sheet
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
    required this.onSave,
    required this.localPostProcess,
    required this.onUpdateLocalPostProcess,
  });

  final ThemeTokens tokens;
  final List<MoodOption> moods;
  final String? selectedSceneId;
  final ValueChanged<MoodOption> onSelectMood;
  final ValueChanged<String?> onSelectScene;
  final VoidCallback onSkip;
  final VoidCallback onCompareCard;
  final VoidCallback onExifCard;
  final VoidCallback onSave;

  /// 预览页本地后期参数（仅影响当前照片，不回写 CaptureState）
  final PostProcess localPostProcess;

  /// 本地后期参数更新回调（仅更新本地状态，不污染拍摄页）
  final ValueChanged<PostProcess> onUpdateLocalPostProcess;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHandle(tokens: tokens),
          const SizedBox(height: 16),
          // 后期参数调整区（亮度/对比度/饱和度滑块）
          // 使用本地状态：仅影响当前照片预览和保存，不回写 CaptureState（避免参数泄漏到拍摄页）
          _AdjustSection(
            tokens: tokens,
            postProcess: localPostProcess,
            onUpdate: onUpdateLocalPostProcess,
          ),
          const SizedBox(height: 16),
          _MoodSection(
            tokens: tokens,
            moods: moods,
            onSelectMood: onSelectMood,
            onSkip: onSkip,
          ),
          const SizedBox(height: 24),
          _SceneSection(
            tokens: tokens,
            selectedSceneId: selectedSceneId,
            onSelectScene: onSelectScene,
          ),
          const SizedBox(height: 24),
          _ActionRow(
            tokens: tokens,
            onCompareCard: onCompareCard,
            onExifCard: onExifCard,
          ),
          const SizedBox(height: 16),
          _SaveButton(onTap: onSave),
        ],
      ),
    );
  }
}

/// 后期参数调整区：亮度/对比度/饱和度滑块
///
/// 修复参数泄漏：
/// 原代码 watch CaptureState.effectivePostProcessProvider 并直接修改
/// editableTemplateProvider / freeModePostProcessProvider，导致返回拍摄页后
/// 拍摄页参数也被改变。
/// 现在使用父组件传入的本地 postProcess 和 onUpdate 回调，仅影响当前照片
/// 预览和保存（保存时按 delta 应用到照片文件），不污染拍摄页状态。
class _AdjustSection extends StatelessWidget {
  const _AdjustSection({
    required this.tokens,
    required this.postProcess,
    required this.onUpdate,
  });

  final ThemeTokens tokens;
  final PostProcess postProcess;
  final ValueChanged<PostProcess> onUpdate;

  @override
  Widget build(BuildContext context) {
    final post = postProcess;

    void update(double brightness, double contrast, double saturation) {
      final newColor = post.color.copyWith(
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
      );
      onUpdate(post.copyWith(color: newColor));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('后期调整', style: TextStyle(
          fontSize: 14, fontWeight: FontWeight.w600, color: tokens.textPrimary,
        )),
        const SizedBox(height: 8),
        _SliderRow(
          label: '亮度',
          value: post.color.brightness.toDouble(),
          min: -100, max: 100,
          onChanged: (v) => update(v, post.color.contrast.toDouble(), post.color.saturation.toDouble()),
        ),
        _SliderRow(
          label: '对比度',
          value: post.color.contrast.toDouble(),
          min: -100, max: 100,
          onChanged: (v) => update(post.color.brightness.toDouble(), v, post.color.saturation.toDouble()),
        ),
        _SliderRow(
          label: '饱和度',
          value: post.color.saturation.toDouble(),
          min: -100, max: 100,
          onChanged: (v) => update(post.color.brightness.toDouble(), post.color.contrast.toDouble(), v),
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              activeColor: const Color(0xFFC9A96E),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              value.toInt().toString(),
              style: const TextStyle(fontSize: 11, color: Colors.black45),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle({required this.tokens});
  final ThemeTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (sheet-handle bg #E5E0D8)
          color: const Color(0xFFE5E0D8),
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
                ),
              ],
            ],
          ),
        ),
      ],
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
        const _SectionTitle(title: '拍摄场景'),
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
                ),
              ],
              const SizedBox(width: 8),
              _Pill(
                text: '不标记',
                active: selectedSceneId == null,
                onTap: () => onSelectScene(null),
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
  });

  final String title;
  final String linkText;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: _SectionTitle(title: title),
        ),
        GestureDetector(
          onTap: onLinkTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              linkText,
              style: const TextStyle(
                fontSize: 13,
                // 硬编码颜色，与 uni-app 一致 (section-link color $color-text-tertiary — 白色 sheet 上用深灰)
                color: Color(0xFF999999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontFamily: 'Noto Serif SC',
        fontSize: 15,
        fontWeight: FontWeight.w600,
        // 硬编码颜色，与 uni-app 一致 (section-title color $color-text-primary — 白色 sheet 上用深色)
        color: Color(0xFF1A1A1A),
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
  });

  final IconData? icon;
  final String text;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (pill.active linear-gradient(135deg, #C9A96E 0%, #A88550 100%))
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFC9A96E), Color(0xFFA88550)],
                )
              : null,
          // 硬编码颜色，与 uni-app 一致 (pill border $color-border — 白色 sheet 上用浅灰)
          border: active
              ? Border.all(color: Colors.transparent, width: 1.5)
              : Border.all(color: const Color(0xFFE5E0D8), width: 1.5),
          // 硬编码颜色，与 uni-app 一致 (pill bg $color-bg-card — 白色 sheet 上用浅米色)
          color: active ? null : const Color(0xFFFAF7F2),
          borderRadius: BorderRadius.circular(9999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                // 硬编码颜色，与 uni-app 一致 (pill active icon #ffffff / inactive $color-text-secondary)
                color: active ? Colors.white : const Color(0xFF666666),
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
                // 硬编码颜色，与 uni-app 一致 (pill.active color #ffffff / inactive $color-text-secondary)
                color: active ? Colors.white : const Color(0xFF666666),
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
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            icon: Icons.content_paste_outlined,
            text: '生成 EXIF 卡片',
            onTap: onExifCard,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (action-btn border $color-border)
          border: Border.all(color: const Color(0xFFE5E0D8), width: 1.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              // 硬编码颜色，与 uni-app 一致 (action-icon color $color-text-secondary)
              color: const Color(0xFF666666),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  // 硬编码颜色，与 uni-app 一致 (action-text color $color-text-primary)
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 保存到相册主按钮
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        decoration: BoxDecoration(
          // 硬编码颜色，与 uni-app 一致 (save-btn bg #1A1A1A)
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.save_outlined,
              size: 16,
              // 硬编码颜色，与 uni-app 一致 (save-icon color #FAF7F2)
              color: Color(0xFFFAF7F2),
            ),
            SizedBox(width: 8),
            Text(
              '保存到系统相册',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                // 硬编码颜色，与 uni-app 一致 (save-text color #FAF7F2)
                color: Color(0xFFFAF7F2),
                height: 1,
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
  });

  final IconData icon;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22, color: const Color(0xFF1A1A1A)),
      title: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A1A),
        ),
      ),
      onTap: onTap,
    );
  }
}
