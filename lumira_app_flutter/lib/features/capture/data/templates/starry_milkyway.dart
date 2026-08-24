// lib/features/capture/data/templates/starry_milkyway.dart
import '../../domain/photo_template.dart';

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
    cover: 'assets/images/templates/starry_desert.jpg',
    description: '横跨夜空的银河拱门，璀璨星带配以辽阔地平线前景',
    referenceSource: '样片参考：银河拱门星空摄影；参数参考银河拍摄参数合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '银河拱门横贯画面上部，地平线置于下三分之一，前景山形或剪影衬托',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦银河星空',
  ),
  camera: CameraParams(
    exposureCompensation: -1.0,
    isoMode: 'manual',
    iso: 1600,
    shutterSpeed: '20',
    whiteBalance: 'auto',
    whiteBalanceK: 4000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '星光与月光（低光环境）',
    shootingDistance: '无限远（星空+远景地平线）',
    background: '银河星带、深邃夜空、山形或荒漠剪影',
    props: ['三脚架', '快门线或定时拍摄', '广角大光圈镜头'],
    bestTime: '无月光晴夜、银河中心升起的夜晚',
    tips: [
      '使用广角大光圈并手动对焦到无穷远',
      '长曝光或用多张堆栈提升星点细节',
      '避开城市光污染找暗空区域',
      '前景补充山形或地景增加纵深感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -8, contrast: 30, saturation: 15, temperature: -20, tint: 10),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 20,
    grain: 18,
    lut: 'cinematic',
  ),
);