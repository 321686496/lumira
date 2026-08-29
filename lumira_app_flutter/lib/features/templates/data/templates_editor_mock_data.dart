/// 编辑器表单数据模型（对应 uni-app PhotoTemplate，简化版）
///
/// 视觉规格来源：lumira-app/src/types/template.ts 的 PhotoTemplate
/// 简化说明：仅保留 editor.vue 中实际编辑的字段，省略 classification / tagIds / version /
/// photographicStyle / hdr / aperture / nightMode / livePhoto / gridEnabled / aeAfLock / lensCorrection /
/// filterPreset / lightDirectionAngle 等未在 editor 中编辑的字段。
///
/// 与 capture 页 domain (photo_template.dart) 对齐：
/// - PostProcessColor 使用 double（与 domain 一致），新增 highlights/shadows/blackPoint/
///   clarity/vibrance/brilliance 可空字段
/// - Composition 新增 gridType / subjectFrame
/// - Camera 新增 lensType
/// - PostProcess 新增 systemFilter
/// - 新增 EditorFormFillLight（补光灯状态）
import '../../capture/domain/photo_template.dart' show SubjectFrame;
import 'remote_template_dto.dart';

class EditorForm {
  EditorForm({
    required this.meta,
    required this.composition,
    List<EditorFormPose>? poses,
    EditorFormPose? pose,
    required this.camera,
    required this.sceneGuide,
    required this.postProcess,
    this.fillLight,
  }) : poses = pose != null
            ? <EditorFormPose>[pose]
            : (poses ?? const <EditorFormPose>[]);

  EditorFormMeta meta;
  EditorFormComposition composition;
  /// 姿势列表（多姿势）。兼容 getter [pose] 读首张，供编辑器内既有控件操作 poses[0]。
  List<EditorFormPose> poses;
  EditorFormCamera camera;
  EditorFormSceneGuide sceneGuide;
  EditorFormPostProcess postProcess;
  /// 补光灯状态（与 capture 页补光灯功能对齐）。null 表示未启用。
  EditorFormFillLight? fillLight;

  /// 兼容旧调用：读首张姿势；空列表时返回占位空姿势。
  EditorFormPose get pose => poses.isNotEmpty ? poses.first : EditorFormPose();

  /// 深拷贝
  EditorForm copy() => EditorForm(
        meta: meta.copy(),
        composition: composition.copy(),
        poses: poses.map((p) => p.copy()).toList(),
        camera: camera.copy(),
        sceneGuide: sceneGuide.copy(),
        postProcess: postProcess.copy(),
        fillLight: fillLight?.copy(),
      );
}

/// 效果图（编辑器内统一以 base64 data URL 存储）。images[0] 即封面。
class EditorFormMetaImage {
  EditorFormMetaImage({required this.data});
  String data; // data URL

  EditorFormMetaImage copy() => EditorFormMetaImage(data: data);
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
    this.subStyle,
    this.method,
    List<EditorFormMetaImage>? images,
    String? coverImage,
    this.shortDesc = '',
    this.ambience,
  }) : images = images ??
            (coverImage != null && coverImage!.isNotEmpty
                ? <EditorFormMetaImage>[EditorFormMetaImage(data: coverImage!)]
                : const <EditorFormMetaImage>[]);

  String id;
  String name;
  String category; // 'portrait' / 'landscape' / 'food' / 'street' / 'night' / 'macro' / 'still-life'
  List<String> tags;
  String description;
  String referenceSource;
  // 四级分类（对齐后端 {type, majorStyle, subStyle, method}）
  String? style; // 二级 majorStyle
  String? subStyle; // 三级 subStyle（原 method 改名）
  String? method; // 四级 method（新增）
  /// 效果图列表，[0] 即封面。兼容 getter [coverImage] 读首张。
  List<EditorFormMetaImage> images;
  String shortDesc; // 短简介
  RemoteTemplateAmbienceDto? ambience; // 季节/天气/时段

  /// 封面 = images[0].data（兼容旧 `coverImage` 读取）。
  String? get coverImage => images.isNotEmpty ? images.first.data : null;

  /// 设置封面（兼容旧的 `coverImage = data` 赋值写法，替换首张）。
  void setCoverImage(String? url) {
    if (url == null || url.isEmpty) {
      images = <EditorFormMetaImage>[]; // 清空铺底，仍由 UI 保留占位
    } else if (images.isEmpty) {
      images = <EditorFormMetaImage>[EditorFormMetaImage(data: url)];
    } else {
      images = <EditorFormMetaImage>[
        EditorFormMetaImage(data: url),
        ...images.skip(1),
      ];
    }
  }

  /// 追加一张效果图（末尾）。
  void addImage(String dataUrl) {
    images = <EditorFormMetaImage>[
      ...images,
      EditorFormMetaImage(data: dataUrl),
    ];
  }

  EditorFormMeta copy() => EditorFormMeta(
        id: id,
        name: name,
        category: category,
        tags: List<String>.from(tags),
        description: description,
        referenceSource: referenceSource,
        style: style,
        subStyle: subStyle,
        method: method,
        images: images.map((e) => e.copy()).toList(),
        shortDesc: shortDesc,
        ambience: ambience,
      );
}

class EditorFormComposition {
  EditorFormComposition({
    this.overlayType = 'rule_of_thirds',
    this.gridType,
    this.subjectFrame,
    this.opacity = 0.5,
    this.aspectRatio = '3:4',
    this.description = '',
  });

  String overlayType; // 'rule_of_thirds' / 'golden_ratio' / 'diagonal' / 'grid' / 'leading_lines' / 'center' / 'none'
  /// 网格类型（与 domain Composition.gridType 对齐）：null 表示不使用网格。
  String? gridType;
  /// 主体框（与 domain Composition.subjectFrame 对齐）：null 表示不使用主体框。
  SubjectFrame? subjectFrame;
  String aspectRatio; // 'fullscreen' / '3:4' / '4:3' / '16:9' / '1:1' 等
  double opacity; // 0.0 ~ 1.0
  String description;

  EditorFormComposition copy() => EditorFormComposition(
        overlayType: overlayType,
        gridType: gridType,
        subjectFrame: subjectFrame,
        opacity: opacity,
        aspectRatio: aspectRatio,
        description: description,
      );
}

class EditorFormPose {
  EditorFormPose({
    this.name = '',
    SilhouetteResource? silhouette,
    Position? position,
    this.scale = 1.0,
    this.rotation = 0,
    this.description = '',
    this.cameraDirection,
  })  : silhouette = silhouette ?? SilhouetteResource(type: 'builtin', data: 'none'),
        position = position ?? Position(x: 0.5, y: 0.5);

  /// 姿势名称（仅编辑/展示用，落库时写入 pose[name]）。
  String name;
  SilhouetteResource silhouette;
  Position position;
  double scale; // 0.3 ~ 2.5（与 capture 页姿势剪影缩放范围对齐）
  double rotation; // -45 ~ 45

  String description;

  /// 相机方向：'front'（前置）| 'back'（后置）| null（跟随用户）。
  /// 与 domain Pose.cameraDirection 对齐；套用模板时据此自动切换前后摄像头。
  String? cameraDirection;

  EditorFormPose copy() => EditorFormPose(
        name: name,
        silhouette: silhouette.copy(),
        position: position.copy(),
        scale: scale,
        rotation: rotation,
        description: description,
        cameraDirection: cameraDirection,
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
    this.lensType,
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
  /// 镜头类型（与 domain CameraParams.lensType 对齐）：null 表示不指定。
  String? lensType;

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
        lensType: lensType,
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
    this.systemFilter,
  }) : color = color ?? PostProcessColor();

  String cropRatio;
  PostProcessColor color;
  int smoothStrength; // 0 ~ 100
  int sharpen; // 0 ~ 100
  int vignette; // 0 ~ 100
  int grain; // 0 ~ 100
  String lut; // 'none' / 'cinematic' / 'vintage' / 'bw' / 'warm_film' / 'cool_film' / 'pastel' / 'fuji'
  /// 系统滤镜预设（与 domain PostProcess.systemFilter 对齐）：null 表示不使用系统滤镜。
  String? systemFilter;

  EditorFormPostProcess copy() => EditorFormPostProcess(
        cropRatio: cropRatio,
        color: color.copy(),
        smoothStrength: smoothStrength,
        sharpen: sharpen,
        vignette: vignette,
        grain: grain,
        lut: lut,
        systemFilter: systemFilter,
      );
}

/// 后期色彩参数（与 domain PostProcessColor 对齐）。
/// 所有数值使用 double（与 domain 一致），新增的 6 个字段为可空（null 表示未调整）。
class PostProcessColor {
  PostProcessColor({
    this.brightness = 0.0,
    this.contrast = 0.0,
    this.saturation = 0.0,
    this.temperature = 0.0,
    this.tint = 0.0,
    this.highlights,
    this.shadows,
    this.blackPoint,
    this.clarity,
    this.vibrance,
    this.brilliance,
  });

  double brightness; // -100 ~ 100
  double contrast;
  double saturation;
  double temperature;
  double tint;
  /// 高光（-100 ~ 100）：null 表示未调整
  double? highlights;
  /// 阴影（-100 ~ 100）：null 表示未调整
  double? shadows;
  /// 黑点（-100 ~ 100）：null 表示未调整
  double? blackPoint;
  /// 清晰度（-100 ~ 100）：null 表示未调整
  double? clarity;
  /// 自然饱和度（-100 ~ 100）：null 表示未调整
  double? vibrance;
  /// 鲜明度（-100 ~ 100）：null 表示未调整
  double? brilliance;

  PostProcessColor copy() => PostProcessColor(
        brightness: brightness,
        contrast: contrast,
        saturation: saturation,
        temperature: temperature,
        tint: tint,
        highlights: highlights,
        shadows: shadows,
        blackPoint: blackPoint,
        clarity: clarity,
        vibrance: vibrance,
        brilliance: brilliance,
      );
}

/// 补光灯状态（与 capture 页补光灯功能对齐）。
/// 序列化到 postProcess JSON 的 fillLight 子对象。
class EditorFormFillLight {
  EditorFormFillLight({
    this.enabled = false,
    this.color = 0xFFFFE5B4,
    this.intensity = 0.8,
  });

  bool enabled;
  /// 补光颜色（ARGB int 值，与 Flutter Color.value 一致）
  int color;
  /// 补光强度（0.1 ~ 1.5）
  double intensity;

  EditorFormFillLight copy() => EditorFormFillLight(
        enabled: enabled,
        color: color,
        intensity: intensity,
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
    fillLight: EditorFormFillLight(),
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
      color: PostProcessColor(brightness: 5.0, contrast: 10.0, saturation: -5.0),
      smoothStrength: 30,
      sharpen: 15,
      vignette: 20,
      grain: 10,
      lut: 'warm_film',
    ),
    fillLight: EditorFormFillLight(enabled: false),
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
      color: PostProcessColor(
        brightness: 5.0,
        contrast: 10.0,
        saturation: -5.0,
        temperature: 8.0,
        tint: 0.0,
      ),
      smoothStrength: 30,
      sharpen: 15,
      vignette: 20,
      grain: 10,
      lut: 'warm_film',
    ),
    fillLight: EditorFormFillLight(enabled: false),
  );

  /// 通过 templateId 加载模板（mock：返回 existingTemplateForm 或 null）
  /// 来源：editor.vue 的 useTemplate().loadTemplate(id)
  ///
  /// 注意：编辑器实际加载优先走 DAO（_loadInitialFormAsync），
  /// 此 mock 仅在 DAO 加载失败或测试场景下作为兜底。
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

/// 格式化带符号数值（用于后期参数显示）。
/// 接受 double（与 PostProcessColor 字段类型一致），四舍五入为整数显示。
/// 来源：editor.vue 的 formatSigned
String formatSigned(num v) {
  final i = v.round();
  return i > 0 ? '+$i' : '$i';
}

/// 解析 aspectRatio 字符串 '3:4' → 3/4
///
/// - fullscreen 返回 -1（调用方需用屏幕比例处理）
/// - 4:3 根据 isPortrait 做方向自适应（竖屏→3/4，横屏→4/3），
///   与 capture 页 CaptureState.computeTargetRatio 保持一致
/// - 其他 "W:H" 格式直接返回 W/H
/// - 解析失败回退 4/3
double parseAspectRatio(String ratio, {bool? isPortrait}) {
  if (ratio == 'fullscreen') return -1;
  if (ratio == '4:3' && isPortrait != null) {
    return isPortrait ? 3.0 / 4.0 : 4.0 / 3.0;
  }
  final parts = (ratio.isNotEmpty ? ratio : '4:3').split(':');
  final w = double.tryParse(parts[0]) ?? 4;
  final h = parts.length > 1 ? (double.tryParse(parts[1]) ?? 3) : 3;
  if (w <= 0 || h <= 0) return 4 / 3;
  return w / h;
}
