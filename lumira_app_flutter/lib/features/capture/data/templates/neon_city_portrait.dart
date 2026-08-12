// lib/features/capture/data/templates/neon_city_portrait.dart
import '../../domain/photo_template.dart';

/// 夜景霓虹人像模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 9
const PhotoTemplate neonCityPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_city_portrait',
    name: '夜景霓虹人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'neon_city', method: 'half_body'),
    tags: ['人像', '霓虹', '夜景', '青紫', '爱乐之城'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/neon_city_portrait.png',
    description: '城市霓虹青紫冷暖对比，爱乐之城夜景人像，夜晚街头的赛博浪漫。',
    referenceSource: '小红书爱乐之城滤镜教程；城市夜景人像；霓虹拍照教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.15, w: 0.4, h: 0.6),
    opacity: 0.25,
    aspectRatio: '9:16',
    description: '三分线左侧半身取景，竖构图霓虹背景',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/neon_city_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.75,
    rotation: 0,
    description: '正面站立单手叉腰，一腿前一腿后，酷无表情看镜头',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    iso: 800,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '多向光（霓虹光源）',
    lightDirectionAngle: 0,
    shootingDistance: '1.5-2m',
    background: '霓虹招牌/城市夜景/车流光斑',
    props: [],
    bestTime: '夜晚 20:00-23:00',
    bestTimeFrom: '20:00',
    bestTimeTo: '23:00',
    tips: [
      '选择多色霓虹招牌背景',
      '冷暖对比是核心（青天+品红霓虹）',
      '人物着深色突出霓虹色彩',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(
      brightness: -8,
      contrast: 12,
      saturation: 8,
      temperature: -12,
      tint: 10,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: 5,
    ),
    smoothStrength: 12,
    sharpen: 12,
    vignette: 18,
    grain: 12,
    lut: 'cool_film',
  ),
);
