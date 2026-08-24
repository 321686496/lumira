// lib/features/capture/data/templates/film_selfie.dart
import '../../domain/photo_template.dart';

/// 胶片质感自拍模板（情绪胶片 · 自拍）
const PhotoTemplate filmSelfieTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'film_selfie',
    name: '胶片质感自拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'film', subStyle: 'film', method: 'selfie'),
    tags: ['胶片', '自拍', '复古', '氛围', '人像'],
    tagIds: [],
    price: 20,
    cover: 'assets/images/templates/film_vintage.jpg',
    description: '低头胶片质感自拍，旧时光滤镜下捕捉松弛而复古的自我',
    referenceSource: '样片 EXIF: 500px 胶片人像作品；参数参考胶片摄影作品',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.15, w: 0.4, h: 0.6),
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '自拍取景居中偏上，面部占画面中心，留白营造胶片氛围',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'vintage-portrait'),
    position: Position(x: 0.5, y: 0.4),
    scale: 1.15,
    rotation: 0,
    description: '手持设备自拍，微微侧脸，眼神从容放松，发丝自然垂落',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 400,
    shutterSpeed: '1/100',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '柔光黄金时刻（低角度暖光）',
    shootingDistance: '0.3-0.5m',
    background: '复古墙面、窗帘或柔光背景，避免现代元素',
    props: [],
    bestTime: '黄金时刻 16:00-18:00 或阴天柔光',
    tips: [
      '轻微过曝营造胶片的轻盈通透',
      '自拍时注意手部不影响面部',
      '后期叠加颗粒与褪色增强旧时光质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 10, contrast: -10, saturation: -10, temperature: 20, tint: 5),
    smoothStrength: 20,
    sharpen: 10,
    vignette: 22,
    grain: 40,
    lut: 'vintage',
  ),
);