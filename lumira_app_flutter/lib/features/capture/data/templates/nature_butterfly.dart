// lib/features/capture/data/templates/nature_butterfly.dart
import '../../domain/photo_template.dart';

/// 蝴蝶翅膀微距模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate natureButterflyTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'nature_butterfly',
    name: '蝴蝶翅膀微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '蝴蝶', '翅膀', '自然'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/macro_flower.jpg',
    description: '微距捕捉蝴蝶翅膀的鳞片纹理与色彩渐层，展现自然界的精致细节',
    referenceSource: '样片参考：蝴蝶微距摄影精选；参数参考微距细节曝光合集',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.4, h: 0.3),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '翅膀局部置于中心偏上，鳞片纹理为焦点，虚化背景衬托主体',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦蝴蝶翅膀细节',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 400,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光或柔光（突出鳞片反光）',
    shootingDistance: '3-10cm（微距）',
    background: '花瓣或叶片背景、空中虚化',
    props: ['微距镜头或近摄镜', '环形补光（可选）'],
    bestTime: '清晨或白天（蝴蝶活动、光线柔和）',
    tips: [
      '稳定机身减少微距抖动',
      '对焦锁定翅膀最清晰的鳞片区域',
      '用侧光让纹理产生质感',
      '背景尽量简洁突出主体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 22, saturation: 20, temperature: 5, tint: 5),
    smoothStrength: 0,
    sharpen: 36,
    vignette: 10,
    grain: 4,
    lut: 'nature',
  ),
);