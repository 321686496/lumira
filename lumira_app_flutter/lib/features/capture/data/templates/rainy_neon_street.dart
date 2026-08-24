// lib/features/capture/data/templates/rainy_neon_street.dart
import '../../domain/photo_template.dart';

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
    cover: 'assets/images/templates/rainy_neon_street.jpg',
    description: '雨后夜晚的城市街道，霓虹招牌与地面反光交织出浓郁的电影氛围',
    referenceSource: '样片参考：500px 街拍夜景精选；参数参考霓虹雨夜摄影教程',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.32, y: 0.35, w: 0.4, h: 0.45),
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '街道纵深延伸作为引导线，霓虹招牌点缀上部，地面倒影增强画面气氛',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'walking-street'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '可配合行人撑伞走过的动态剪影增强场景感',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'auto',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境霓虹光（无固定主光，靠霓虹招牌与店铺光）',
    shootingDistance: '中景（5-15m 街景纵深）',
    background: '霓虹招牌、湿滑路面、车辆光源、店铺橱窗',
    props: ['雨伞', '行人剪影', '车辆灯光制造光轨'],
    bestTime: '入夜后（霓虹灯亮、地面微湿的反光最佳）',
    tips: [
      '雨后地面反光是氛围的关键，优先寻找积水处',
      '使用较高 ISO 保证手持快门安全',
      '对焦在主体，利用霓虹光作为环境色',
      '可尝试放慢快门捕捉车辆光轨与行人动态',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 20, saturation: 10, temperature: -10, tint: 8),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 20,
    grain: 10,
    lut: 'cinematic',
  ),
);