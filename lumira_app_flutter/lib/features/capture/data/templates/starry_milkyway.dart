// lib/features/capture/data/templates/starry_milkyway.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 银河拱门夜景模板（夜景 / 星空 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryMilkywayTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_milkyway',
    name: '银河拱门夜景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry', method: 'wide'),
    tags: ['夜景', '银河', '星空', '拱门'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/starry_milkyway.jpg'),
    ],
    description: '这是一套专为高海拔/低光害地区设计的银河全景拍摄模板。画面以壮丽的雪山主峰为视觉锚点，上方覆盖完整的银河拱桥，下方保留暗调前景与湖面反光。采用超广角横构图，强调天地辽阔感。光线依赖自然星光与地平线微弱的暖色气辉，整体色调冷峻深邃，点缀星云紫红与地平线橙黄。适合天文摄影爱好者、户外探险者及追求极致风光大片的人群。需配合三脚架与长曝光技术（或App夜景模式）实现。',
    shortDesc: '亿万星辰垂落雪峰之巅，银河如瀑横跨天际，静谧浩瀚，一眼万年🌌',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['night', 'cool'],
    ),
    referenceSource: '样片参考：银河拱门星空摄影；参数参考银河拍摄参数合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'horizontal_thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.1, w: 1.0, h: 0.8),
    opacity: 0.3,
    aspectRatio: '16:9',
    description: '大远景横构图。机位平视略低，强调天空的广阔。主体（雪山+银河）占画幅90%以上。天空留白极少，被繁星填满；地景紧凑，突出主峰轮廓。宽高比严格锁定16:9以展现全景气势。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 4200,
    flashMode: 'off',
    focusMode: 'manual_infinity',
    lensSuggestion: 'ultra_wide',
    lensType: '超广角镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '无单一主光源。环境光来自满天星斗（漫射冷光，屏幕全方向）及地平线远处城镇/气辉（屏幕下方边缘，暖橙色微光）。光比极大（天空亮部与地面暗部约5:1）。阴影极软，几乎不可见，仅在山体背光面形成深黑剪影。无需补光，纯自然弱光环境。',
    shootingDistance: '无限远（对焦无穷远）',
    background: '高海拔雪山山脉 + 平静湖面 + 裸露岩石荒原',
    props: ['三脚架（必需）', '快门线/定时拍摄'],
    bestTime: '22:00-02:00（银河中心可见时段）',
    tips: [
      '必须使用三脚架固定机位，开启App‘夜景/星空模式’或手动长曝光（建议15-25秒）。',
      '对焦务必切换至手动并拧到无穷远（∞），或通过放大屏幕确认星星为锐利点状。',
      '该效果真机无法单张手持实现，若App无长曝光功能，请选择‘夜景增强’算法模式近似模拟。',
      'vignette:15 轻微压暗四角，聚焦中央银河与山峰；grain:25 增加胶片颗粒感，掩盖高ISO噪点并提升星空质感。',
      '白平衡设为自定义4200K，保留星空的冷蓝基调，同时让地平线暖光自然呈现。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -2, contrast: 18, saturation: 12, temperature: -6, tint: 4, highlights: -10, shadows: 8, clarity: 15),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 25,
    lut: 'twilight',
  ),
);
