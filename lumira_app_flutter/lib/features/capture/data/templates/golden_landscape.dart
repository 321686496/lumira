// lib/features/capture/data/templates/golden_landscape.dart
import '../../domain/photo_template.dart';

/// 黄金时刻风光模板
/// 来源：lumira-app/src/data/templates/golden-landscape.ts
const PhotoTemplate goldenLandscapeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'golden_landscape',
    name: '黄金时刻风光',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', method: 'wide'),
    tags: ['风光', '黄金时刻', '日出日落', '广角'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/golden_landscape.jpg',
    description: '黄金时刻拍摄风光，色调温暖柔和，强调自然光影层次',
    referenceSource: '样片 EXIF: 500px 风光精选；参数参考 500px 风光摄影黄金时刻合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.38, y: 0.35, w: 0.4, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '主体位于黄金螺旋交点，前景引导线指向主体，天空占画面三分之一',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'none'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯风光场景',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光或侧光 30°-60°（太阳低角度）',
    shootingDistance: '远景（风光全貌 100m+）',
    background: '开阔自然景观：山川、田野、海岸、草原',
    props: ['三脚架（可选）', '渐变灰滤镜（压暗天空）', '遮光罩（避免眩光）'],
    bestTime: '日出后 30 分钟 或 日落前 60 分钟（黄金时刻）',
    tips: [
      '使用小光圈（手机等效）保证远近景都清晰',
      '天空与地面光比大时使用渐变滤镜',
      '寻找前景元素（岩石、花朵）增加纵深感',
      '拍摄 RAW 保留更多动态范围便于后期',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 5, contrast: 15, saturation: 15, temperature: 20, tint: 5),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 10,
    grain: 5,
    lut: 'warm_film',
  ),
);
