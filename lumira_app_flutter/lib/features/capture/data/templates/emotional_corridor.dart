// lib/features/capture/data/templates/emotional_corridor.dart
import '../../domain/photo_template.dart';

/// 室外情绪他拍人像模板（情绪胶片 · 他拍）
const PhotoTemplate emotionalCorridorTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'emotional_corridor',
    name: '室外情绪他拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'emotional', subStyle: 'emotional', method: 'normal'),
    tags: ['情绪', '他拍', '室外', '逆光', '人像'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/sunset_silhouette.jpg',
    description: '室外开阔场景的情绪他拍，运用逆光刻画行走中的剪影与神态',
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.33, y: 0.35, w: 0.34, h: 0.55),
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '人物置于右侧三分线，左侧留白延伸环境纵深',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'standing-profile'),
    position: Position(x: 0.6, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '背面或侧背影行走，面朝夕阳方向，手臂自然摆动，身姿具叙事感',
  ),
  camera: CameraParams(
    exposureCompensation: -0.7,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光 180°（太阳位于模特正后方）',
    shootingDistance: '3-6m',
    background: '室外开阔环境：天台、公园小道或长廊，地平线低于模特头部',
    props: ['三脚架（可选）'],
    bestTime: '日落前 30 分钟（黄金时刻末段）',
    tips: [
      '用长廊或小道引导线增强纵深感',
      '对焦天空中等亮度区域锁定曝光',
      '捕捉行走瞬间增强画面叙事',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -5, contrast: 24, saturation: -10, temperature: 16, tint: 6),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 32,
    grain: 12,
    lut: 'cinematic',
  ),
);