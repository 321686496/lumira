/// 编辑器表单数据模型（对应 uni-app PhotoTemplate，简化版）
///
/// 视觉规格来源：lumira-app/src/types/template.ts 的 PhotoTemplate
/// 简化说明：仅保留 editor.vue 中实际编辑的字段，省略 classification / tagIds / version / cover /
/// photographicStyle / hdr / aperture / nightMode / livePhoto / gridEnabled / aeAfLock / lensCorrection /
/// lensType / filterPreset / systemFilter / subjectFrame / gridType / lightDirectionAngle 等未在 editor 中编辑的字段
class EditorForm {
  EditorForm({
    required this.meta,
    required this.composition,
    required this.pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
  });

  EditorFormMeta meta;
  EditorFormComposition composition;
  EditorFormPose pose;
  EditorFormCamera camera;
  EditorFormSceneGuide sceneGuide;
  EditorFormPostProcess postProcess;

  /// 深拷贝
  EditorForm copy() => EditorForm(
        meta: meta.copy(),
        composition: composition.copy(),
        pose: pose.copy(),
        camera: camera.copy(),
        sceneGuide: sceneGuide.copy(),
        postProcess: postProcess.copy(),
      );
}

class EditorFormMeta {
  EditorFormMeta({
    this.id = '',
    this.name = '',
    this.category = 'portrait',
    this.tags = const [],
    this.description = '',
    this.referenceSource = '',
    this.style,
    this.method,
  });

  String id;
  String name;
  String category; // 'portrait' / 'landscape' / 'food' / 'street' / 'night' / 'macro' / 'still-life'
  List<String> tags;
  String description;
  String referenceSource;
  // 三层分类的二、三层：风格 / 方式（可选，未选择时为 null）
  String? style;
  String? method;

  EditorFormMeta copy() => EditorFormMeta(
        id: id,
        name: name,
        category: category,
        tags: List<String>.from(tags),
        description: description,
        referenceSource: referenceSource,
        style: style,
        method: method,
      );
}

class EditorFormComposition {
  EditorFormComposition({
    this.overlayType = 'rule_of_thirds',
    this.aspectRatio = '3:4',
    this.opacity = 0.5,
    this.description = '',
  });

  String overlayType; // 'rule_of_thirds' / 'golden_ratio' / 'diagonal' / 'grid' / 'leading_lines' / 'center' / 'none'
  String aspectRatio; // '3:4' / '4:3' / '16:9' / '1:1' 等
  double opacity; // 0.0 ~ 1.0
  String description;

  EditorFormComposition copy() => EditorFormComposition(
        overlayType: overlayType,
        aspectRatio: aspectRatio,
        opacity: opacity,
        description: description,
      );
}

class EditorFormPose {
  EditorFormPose({
    SilhouetteResource? silhouette,
    Position? position,
    this.scale = 1.0,
    this.rotation = 0,
    this.description = '',
  })  : silhouette = silhouette ?? SilhouetteResource(type: 'builtin', data: 'none'),
        position = position ?? Position(x: 0.5, y: 0.5);

  SilhouetteResource silhouette;
  Position position;
  double scale; // 0.5 ~ 1.5
  double rotation; // -45 ~ 45

  String description;

  EditorFormPose copy() => EditorFormPose(
        silhouette: silhouette.copy(),
        position: position.copy(),
        scale: scale,
        rotation: rotation,
        description: description,
      );
}

class SilhouetteResource {
  SilhouetteResource({
    required this.type,
    required this.data,
    this.filename,
    this.sizeKB,
  });

  String type; // 'builtin' / 'image' / 'svg'
  String data; // builtin: silhouette key; image: base64 data URL; svg: inline SVG string
  String? filename;
  int? sizeKB;

  SilhouetteResource copy() => SilhouetteResource(
        type: type,
        data: data,
        filename: filename,
        sizeKB: sizeKB,
      );
}

class Position {
  Position({this.x = 0.5, this.y = 0.5});

  double x; // 0.0 ~ 1.0
  double y; // 0.0 ~ 1.0

  Position copy() => Position(x: x, y: y);
}

class EditorFormCamera {
  EditorFormCamera({
    this.exposureCompensation = 0.0,
    this.isoMode = 'auto',
    this.iso = 200,
    this.shutterSpeed = '1/200',
    this.whiteBalance = 'daylight',
    this.whiteBalanceK = 5500,
    this.flashMode = 'off',
    this.focusMode = 'auto',
    this.lensSuggestion = 'main',
  });

  double exposureCompensation; // -3.0 ~ 3.0
  String isoMode; // 'auto' / 'manual'
  int iso;
  String shutterSpeed;
  String whiteBalance; // 'daylight' / 'cloudy' / 'shade' / 'tungsten' / 'fluorescent' / 'custom'
  int whiteBalanceK;
  String flashMode; // 'off' / 'on' / 'auto' / 'torch'
  String focusMode; // 'auto' / 'manual' / 'continuous'
  String lensSuggestion; // 'wide' / 'main' / 'telephoto' / 'ultra_wide'

  EditorFormCamera copy() => EditorFormCamera(
        exposureCompensation: exposureCompensation,
        isoMode: isoMode,
        iso: iso,
        shutterSpeed: shutterSpeed,
        whiteBalance: whiteBalance,
        whiteBalanceK: whiteBalanceK,
        flashMode: flashMode,
        focusMode: focusMode,
        lensSuggestion: lensSuggestion,
      );
}

class EditorFormSceneGuide {
  EditorFormSceneGuide({
    this.lightDirection = '',
    this.shootingDistance = '',
    this.background = '',
    this.props = const [],
    this.bestTime = '',
    this.tips = const [],
  });

  String lightDirection;
  String shootingDistance;
  String background;
  List<String> props;
  String bestTime;
  List<String> tips;

  EditorFormSceneGuide copy() => EditorFormSceneGuide(
        lightDirection: lightDirection,
        shootingDistance: shootingDistance,
        background: background,
        props: List<String>.from(props),
        bestTime: bestTime,
        tips: List<String>.from(tips),
      );
}

class EditorFormPostProcess {
  EditorFormPostProcess({
    this.cropRatio = '3:4',
    PostProcessColor? color,
    this.smoothStrength = 0,
    this.sharpen = 0,
    this.vignette = 0,
    this.grain = 0,
    this.lut = 'none',
  }) : color = color ?? PostProcessColor();

  String cropRatio;
  PostProcessColor color;
  int smoothStrength; // 0 ~ 100
  int sharpen; // 0 ~ 100
  int vignette; // 0 ~ 100
  int grain; // 0 ~ 100
  String lut; // 'none' / 'cinematic' / 'vintage' / 'bw' / 'warm_film' / 'cool_film' / 'pastel' / 'fuji'

  EditorFormPostProcess copy() => EditorFormPostProcess(
        cropRatio: cropRatio,
        color: color.copy(),
        smoothStrength: smoothStrength,
        sharpen: sharpen,
        vignette: vignette,
        grain: grain,
        lut: lut,
      );
}

class PostProcessColor {
  PostProcessColor({
    this.brightness = 0,
    this.contrast = 0,
    this.saturation = 0,
    this.temperature = 0,
    this.tint = 0,
  });

  int brightness; // -100 ~ 100
  int contrast;
  int saturation;
  int temperature;
  int tint;

  PostProcessColor copy() => PostProcessColor(
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        temperature: temperature,
        tint: tint,
      );
}

/// 创建空白模板
/// 来源：editor.vue 的 createBlankTemplate()
EditorForm createBlankEditorForm() {
  return EditorForm(
    meta: EditorFormMeta(),
    composition: EditorFormComposition(),
    pose: EditorFormPose(),
    camera: EditorFormCamera(),
    sceneGuide: EditorFormSceneGuide(),
    postProcess: EditorFormPostProcess(),
  );
}

/// 编辑器 mock 数据
class TemplatesEditorMockData {
  TemplatesEditorMockData._();

  /// 空白模板（新建模板时使用）
  static EditorForm blankForm = createBlankEditorForm();

  /// 草稿模板（draftId 恢复时使用，模拟部分已填写状态）
  static final EditorForm draftForm = EditorForm(
    meta: EditorFormMeta(
      id: 'draft-editor-1',
      name: '咖啡馆人像草稿',
      category: 'portrait',
      tags: ['人像', '咖啡馆', '柔光'],
      description: '适合咖啡馆窗边自然光的半身人像',
      referenceSource: '样片 EXIF: Pexels #12345',
    ),
    composition: EditorFormComposition(
      overlayType: 'rule_of_thirds',
      aspectRatio: '3:4',
      opacity: 0.6,
      description: '主体位于右侧三分线交点',
    ),
    pose: EditorFormPose(
      silhouette: SilhouetteResource(type: 'builtin', data: 'sitting-cafe'),
      position: Position(x: 0.5, y: 0.55),
      scale: 1.0,
      rotation: 0,
      description: '坐姿托腮，长发披肩',
    ),
    camera: EditorFormCamera(
      exposureCompensation: 0.7,
      isoMode: 'manual',
      iso: 400,
      shutterSpeed: '1/125',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensSuggestion: 'main',
    ),
    sceneGuide: EditorFormSceneGuide(
      lightDirection: '侧面柔光 45°',
      shootingDistance: '1.5-2m',
      background: '咖啡馆窗边 / 绿植背景',
      props: ['咖啡杯', '书'],
      bestTime: '14:00-16:00',
      tips: ['让模特自然托腮', '利用窗光制造柔光效果'],
    ),
    postProcess: EditorFormPostProcess(
      cropRatio: '3:4',
      color: PostProcessColor(brightness: 5, contrast: 10, saturation: -5),
      smoothStrength: 30,
      sharpen: 15,
      vignette: 20,
      grain: 10,
      lut: 'warm_film',
    ),
  );

  /// 已存在模板（templateId 加载时使用，模拟完整模板）
  static final EditorForm existingTemplateForm = EditorForm(
    meta: EditorFormMeta(
      id: 'tpl-cafe-portrait',
      name: '咖啡馆人像',
      category: 'portrait',
      tags: ['人像', '咖啡馆', '日系'],
      description: '适合咖啡馆窗边自然光的半身人像模板',
      referenceSource: '样片 EXIF: Pexels #12345',
    ),
    composition: EditorFormComposition(
      overlayType: 'rule_of_thirds',
      aspectRatio: '3:4',
      opacity: 0.5,
      description: '主体位于右侧三分线交点',
    ),
    pose: EditorFormPose(
      silhouette: SilhouetteResource(type: 'builtin', data: 'sitting-cafe'),
      position: Position(x: 0.6, y: 0.5),
      scale: 1.0,
      rotation: 0,
      description: '坐姿托腮，长发披肩',
    ),
    camera: EditorFormCamera(
      exposureCompensation: 0.7,
      isoMode: 'manual',
      iso: 400,
      shutterSpeed: '1/125',
      whiteBalance: 'daylight',
      whiteBalanceK: 5500,
      flashMode: 'off',
      focusMode: 'auto',
      lensSuggestion: 'main',
    ),
    sceneGuide: EditorFormSceneGuide(
      lightDirection: '侧面柔光 45°',
      shootingDistance: '1.5-2m',
      background: '咖啡馆窗边 / 绿植背景',
      props: ['咖啡杯', '书'],
      bestTime: '14:00-16:00',
      tips: ['让模特自然托腮', '利用窗光制造柔光效果', '避免直射阳光'],
    ),
    postProcess: EditorFormPostProcess(
      cropRatio: '3:4',
      color: PostProcessColor(brightness: 5, contrast: 10, saturation: -5, temperature: 8, tint: 0),
      smoothStrength: 30,
      sharpen: 15,
      vignette: 20,
      grain: 10,
      lut: 'warm_film',
    ),
  );

  /// 内置剪影 key 列表（子集，5 个，用于剪影缩略图横向滚动）
  /// 来源：lumira-app/src/data/silhouettes/index.ts 的 BUILTIN_SILHOUETTE_KEYS
  /// 注意：完整库有更多 key（standing-profile / sitting-cafe / walking-street / soft-portrait / neon-pose / 等）
  /// 本任务只 mock 5 个用于编辑器缩略图展示，Task 2.9 接入真实数据时替换
  static const List<String> builtinSilhouetteKeys = [
    'none',
    'standing-profile',
    'sitting-cafe',
    'walking-street',
    'soft-portrait',
  ];

  /// 内置剪影 SVG 字符串（简化版 — 仅 mock 数据）
  /// 实际剪影 SVG 来自 lumira-app/src/data/silhouettes/index.ts，Task 2.9 接入时迁移完整 SVG 库
  /// 当前 mock：返回空 SVG 字符串（占位），PoseSilhouette 组件用 Icon 替代渲染
  static const Map<String, String> builtinSilhouettes = {
    'none': '',
    'standing-profile': '', // TODO: Task 2.9 迁移完整 SVG
    'sitting-cafe': '',
    'walking-street': '',
    'soft-portrait': '',
  };

  /// 通过 templateId 加载模板（mock：返回 existingTemplateForm 或 null）
  /// 来源：editor.vue 的 useTemplate().loadTemplate(id)
  static EditorForm? loadTemplateById(String? templateId) {
    if (templateId == null || templateId.isEmpty) return null;
    if (templateId == 'tpl-cafe-portrait') return existingTemplateForm.copy();
    return null;
  }

  /// 通过 draftId 加载草稿（mock：返回 draftForm 或 null）
  /// 来源：editor.vue 的 useTemplate().loadDraft(id)
  ///
  /// Forced fix: editor 的 _onPreview 会动态生成 draftId 'draft-editor-${timestamp}'。
  /// mock 阶段没有真实草稿存储，所有以 'draft-editor-' 开头的 id 都返回 draftForm 占位，
  /// 让模板预览页能正常加载（避免"模板加载失败"）。
  static EditorForm? loadDraftById(String? draftId) {
    if (draftId == null || draftId.isEmpty) return null;
    if (draftId.startsWith('draft-editor-')) return draftForm.copy();
    return null;
  }
}

/// 格式化 EV 值（与 templates_management_mock_data.dart 的 formatEv 一致）
/// 来源：editor.vue 的 formatEv
String formatEvSlider(double v) {
  return v > 0 ? '+${v.toStringAsFixed(1)}' : v.toStringAsFixed(1);
}

/// 格式化带符号整数（用于后期参数显示）
/// 来源：editor.vue 的 formatSigned
String formatSigned(int v) {
  return v > 0 ? '+$v' : '$v';
}

/// 解析 aspectRatio 字符串 '3:4' → 3/4
/// 来源：editor.vue 的 _compositionPreviewPadding 中的解析逻辑
/// 用于 Step 2 构图预览框和 Step 3 姿势预览框的 AspectRatio 计算
double parseAspectRatio(String ratio) {
  final parts = (ratio.isNotEmpty ? ratio : '4:3').split(':');
  final w = int.tryParse(parts[0]) ?? 4;
  final h = parts.length > 1 ? (int.tryParse(parts[1]) ?? 3) : 3;
  if (w <= 0 || h <= 0) return 4 / 3;
  return w / h;
}
