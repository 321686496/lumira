// lib/features/capture/data/templates/fresh_green_portrait.dart
import '../../domain/photo_template.dart';

/// 清新淡雅绿模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 10
const PhotoTemplate freshGreenPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'fresh_green_portrait',
    name: '清新淡雅绿',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'fresh_green', method: 'full_body'),
    tags: ['人像', '森系', '露营', '净白', '户外'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/fresh_green_portrait.png',
    description: '户外森系净白空气感，清新淡雅绿调，草地森林的自然治愈。',
    referenceSource: '小红书净白滤镜教程；户外森系露营；清新淡雅绿调人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.1, w: 0.5, h: 0.8),
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '三分线左侧全身取景，留白充足，人景比例 4:6',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/fresh_green_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.7,
    rotation: 0,
    description: '侧身草地坐姿，回眸看镜头，双手撑地后撑，屈膝坐地，自然微笑',
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
    lightDirection: '漫射光（阴天/树荫）',
    lightDirectionAngle: 0,
    shootingDistance: '2-3m',
    background: '草地/森林/露营地/野餐垫',
    props: ['草帽', '野餐垫', '帐篷'],
    bestTime: '上午 8:00-10:00 或阴天',
    bestTimeFrom: '08:00',
    bestTimeTo: '10:00',
    tips: [
      '选择阴天或树荫漫射光',
      '服装浅色棉麻与自然融合',
      '留白要足，人景比例 4:6',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 12,
      contrast: -8,
      saturation: -8,
      temperature: -8,
      tint: 0,
      highlights: 5,
      shadows: 12,
      clarity: -5,
      vibrance: 0,
    ),
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel',
  ),
);
