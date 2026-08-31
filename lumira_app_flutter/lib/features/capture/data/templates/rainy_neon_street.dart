// lib/features/capture/data/templates/rainy_neon_street.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 雨夜街头模板（街拍 / 随性 / 常规）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate rainyNeonStreetTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'rainy_neon_street',
    name: '雨夜霓虹街拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'normal'),
    tags: ['街拍', '雨夜', '霓虹', '氛围', '倒影'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/rainy_neon_street.png'),
    ],
    description: '这是一套专为雨夜都市街头设计的赛博朋克风拍照模板。画面以背对镜头的撑伞人物为视觉锚点，利用湿滑路面的霓虹倒影形成强烈的纵向引导线。光线依赖环境中的红蓝霓虹灯牌与车灯，呈现高对比、高饱和的冷暖撞色质感。穿搭建议全黑极简风衣或大衣，搭配黑色雨伞，强化剪影效果。适合喜欢电影感、情绪片、都市夜景题材的用户，在雨后夜晚的商业街复刻此效果。',
    shortDesc: '雨夜霓虹倒映湿漉街道，黑伞孤影穿行光影之间，冷紫暖红交织，满是疏离又迷人的赛博都市氛围感🌧️🏙️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'autumn', 'winter'],
      weathers: ['rain'],
      timeTones: ['night'],
    ),
    referenceSource: '样片参考：500px 街拍夜景精选；参数参考霓虹雨夜摄影教程',
  ),
  composition: Composition(
    overlayType: 'center_symmetry',
    gridType: 'leading_lines',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.42, w: 0.3, h: 0.35),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '全身大远景，平视机位，正拍。主体位于画面中下部，约占画幅25%，头顶留白适中。环境占据75%，强调街道纵深感与地面霓虹倒影的延伸。利用斑马线与路面反光作为强引导线，将视线汇聚至人物背影。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '主摄镜头',
    lensSuggestion: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境光为主：屏幕右侧红色霓虹灯牌提供暖色侧逆光，屏幕左侧及远处蓝色/白色招牌提供冷色辅光，前方车灯提供正面弱补光。光比高（约5:1），阴影浓重投向屏幕下方及人物脚下，边缘因雨水漫反射而偏软。无需额外补光灯，依赖环境霓虹即可；若主体过暗可开启手机闪光灯常亮模式从屏幕正面远距离（2m+）微弱补光，但建议优先保留剪影感。',
    shootingDistance: '3-5m',
    background: '繁华商业步行街，两侧密集竖排中文霓虹灯牌（红/蓝/白），湿滑沥青路面带斑马线，远处有模糊车流与行人。',
    props: ['黑色长柄雨伞', '深色单肩包'],
    bestTime: '20:00-23:00（雨后即刻最佳）',
    tips: [
      '必须选择雨后或小雨中拍摄，干燥路面无法形成霓虹倒影，这是本模板核心效果。',
      '寻找两侧有密集发光招牌的街道，利用路面水洼作为天然反光板。',
      '人物务必穿全黑或深色衣物，形成剪影效果，避免浅色衣服破坏暗调氛围。',
      '机位保持平视或略微降低（蹲姿），以增强地面倒影的视觉占比。',
      '对焦锁定在人物背部，适当降低曝光补偿（-0.3至-0.7）以压暗天空并提升霓虹饱和度。',
      '真机无法实现大光圈浅景深虚化，依靠拉远拍摄距离（3m以上）让背景自然缩小，配合后期暗角聚焦主体。',
      '注意安全，避开真实车流，建议在步行街或封闭路段拍摄。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -5,
      contrast: 18,
      saturation: 35,
      temperature: -2,
      tint: 8,
      highlights: -10,
      shadows: 5,
      clarity: 12,
    ),
    smoothStrength: 10,
    sharpen: 25,
    vignette: 35,
    grain: 22,
    lut: 'cyberpunk',
  ),
);
