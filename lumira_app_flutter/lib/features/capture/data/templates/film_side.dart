// lib/features/capture/data/templates/film_side.dart
import '../../domain/photo_template.dart';

/// 胶片旧时光侧拍模板（情绪胶片 · 侧拍）
const PhotoTemplate filmSideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'film_side',
    name: '胶片旧时光侧拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'film', subStyle: 'film', method: 'side'),
    tags: ['胶片', '侧拍', '旧时光', '怀旧', '人像'],
    tagIds: [],
    price: 20,
    cover: 'assets/images/templates/film_vintage.jpg',
    description: '侧拍视角定格旧时光，暖调褪色与肢体侧影交织怀旧情绪',
    referenceSource: '样片 EXIF: 500px 胶片人像作品；参数参考胶片摄影作品',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.32, y: 0.15, w: 0.34, h: 0.68),
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '人物侧身置于左侧三分线，顺人物视线方向留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'vintage-portrait'),
    position: Position(x: 0.4, y: 0.4),
    scale: 1.05,
    rotation: 0,
    description: '身体侧对镜头，目光望向来时方向，一手自然下垂，背影带旧时光况味',
  ),
  camera: CameraParams(
    exposureCompensation: 0.2,
    isoMode: 'manual',
    iso: 320,
    shutterSpeed: '1/125',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（低角度暖光）',
    shootingDistance: '2.5-3.5m',
    background: '复古建筑、巷口、老墙或晒衣绳等怀旧场景',
    props: ['纸质书刊', '老式道具', '干花束'],
    bestTime: '黄金时刻 16:00-18:00',
    tips: [
      '顺视线方向留白增加想象空间',
      '略过曝营造胶片轻盈通透感',
      '避免画面中出现现代元素',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 9, contrast: -8, saturation: -12, temperature: 18, tint: 5),
    smoothStrength: 22,
    sharpen: 10,
    vignette: 20,
    grain: 40,
    lut: 'vintage',
  ),
);