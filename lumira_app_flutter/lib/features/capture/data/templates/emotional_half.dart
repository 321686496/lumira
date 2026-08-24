// lib/features/capture/data/templates/emotional_half.dart
import '../../domain/photo_template.dart';

/// 情绪特写半身人像模板（情绪胶片 · 半身）
const PhotoTemplate emotionalHalfTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'emotional_half',
    name: '情绪特写半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'emotional', subStyle: 'emotional', method: 'half_body'),
    tags: ['情绪', '特写', '半身', '逆光', '人像'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/sunset_silhouette.jpg',
    description: '剪影偏半身的情绪特写，突出面部与手部微表情',
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.22, w: 0.42, h: 0.55),
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '半身取景，面部位于上三分线，手部入画点缀情绪',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'standing-profile'),
    position: Position(x: 0.45, y: 0.4),
    scale: 1.2,
    rotation: 0,
    description: '半身侧对镜头，一手轻触脸颊或整理发丝，眼神低垂流露情绪',
  ),
  camera: CameraParams(
    exposureCompensation: -0.6,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'telephoto',
    lensType: 'telephoto',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光 180°（太阳位于模特正后方）',
    shootingDistance: '1.5-2.5m',
    background: '干净天空或虚化光斑背景，人物与背景分离',
    props: ['反光板（补面部光）'],
    bestTime: '日落前 30 分钟（黄金时刻末段）',
    tips: [
      '使用长焦压缩背景、突出面部',
      '对焦锁定眼睛，压低 EV 烘托氛围',
      '后期保留天空暖色增强情绪',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -4, contrast: 22, saturation: -9, temperature: 14, tint: 5),
    smoothStrength: 12,
    sharpen: 20,
    vignette: 28,
    grain: 10,
    lut: 'cinematic',
  ),
);