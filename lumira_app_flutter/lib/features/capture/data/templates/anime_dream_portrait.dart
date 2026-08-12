// lib/features/capture/data/templates/anime_dream_portrait.dart
import '../../domain/photo_template.dart';

/// 动漫温柔青模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 12
const PhotoTemplate animeDreamPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'anime_dream_portrait',
    name: '动漫温柔青',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'anime_dream', method: 'full_body'),
    tags: ['人像', '动漫', '宫崎骏', '梦境', '晴天'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/anime_dream_portrait.png',
    description: '宫崎骏感饱和提亮梦境青，晴天草地张开双臂的动漫浪漫。',
    referenceSource: '小红书梦境滤镜教程；宫崎骏动漫感；晴天户外人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.2, y: 0.1, w: 0.55, h: 0.8),
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线左侧偏中全身取景，天空留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/anime_dream_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.7,
    rotation: 0,
    description: '正面站立张开双臂，仰头看天，微张站立，开心大笑',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光/顶光',
    lightDirectionAngle: 30,
    shootingDistance: '2-3m',
    background: '蓝天白云/草地/花海',
    props: [],
    bestTime: '上午 9:00-11:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '晴天蓝天才有效果',
      '仰拍带天空',
      '服装浅色与天空呼应',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 12,
      contrast: -5,
      saturation: 10,
      temperature: 5,
      tint: 0,
      highlights: -5,
      shadows: 15,
      clarity: -5,
      vibrance: 8,
    ),
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel',
  ),
);
