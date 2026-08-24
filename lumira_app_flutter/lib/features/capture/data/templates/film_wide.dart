// lib/features/capture/data/templates/film_wide.dart
import '../../domain/photo_template.dart';

/// 胶片街角远景人像模板（情绪胶片 · 远景）
const PhotoTemplate filmWideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'film_wide',
    name: '胶片街角远景人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'film', subStyle: 'film', method: 'wide'),
    tags: ['胶片', '街角', '远景', '怀旧', '人像'],
    tagIds: [],
    price: 20,
    cover: 'assets/images/templates/film_vintage.jpg',
    description: '街角远景的胶片人像，人物融入街道纵深，旧时光氛围扑面而来',
    referenceSource: '样片 EXIF: 500px 胶片人像作品；参数参考胶片摄影作品',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.4, w: 0.26, h: 0.42),
    opacity: 0.42,
    aspectRatio: '3:4',
    description: '人物作为环境点置入街道景深，展现街角纵深与怀旧氛围',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'vintage-portrait'),
    position: Position(x: 0.4, y: 0.62),
    scale: 0.85,
    rotation: 0,
    description: '站立于街角，身体朝向街道延伸方向，剪影融入旧街氛围',
  ),
  camera: CameraParams(
    exposureCompensation: 0.2,
    isoMode: 'manual',
    iso: 320,
    shutterSpeed: '1/160',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光/漫射光',
    shootingDistance: '5-8m',
    background: '老街区、骑楼、斑驳墙面与延伸街道',
    props: [],
    bestTime: '黄金时刻 16:00-18:00',
    tips: [
      '用街道纵深引导线增强画面层次',
      '保持人物占画面比例小凸显环境氛围',
      '后期叠加颗粒与褪色强化胶片感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 8, contrast: -6, saturation: -12, temperature: 20, tint: 6),
    smoothStrength: 18,
    sharpen: 12,
    vignette: 26,
    grain: 45,
    lut: 'vintage',
  ),
);