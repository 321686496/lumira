// lib/features/capture/data/templates/japanese_fresh_portrait.dart
import '../../domain/photo_template.dart';

/// 日系小清新模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 3
const PhotoTemplate japaneseFreshPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'japanese_fresh_portrait',
    name: '日系小清新',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'japanese_fresh', method: 'seven_body'),
    tags: ['人像', '日系', '小清新', '空气感', '低对比'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/japanese_fresh_portrait.png',
    description: '干净清透的日系空气感，低对比微冷调，樱花校园的青春记忆。',
    referenceSource: '小红书日系小清新教程；日系写真风格；轻颜/醒图清新滤镜',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.1, w: 0.5, h: 0.8),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧七分身取景，留白充足，人物占比不超过 60%',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/japanese_fresh_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.7,
    rotation: 0,
    description: '侧身自然行走，侧脸看向远方，双手自然摆动，迈步动态，微笑',
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
    lightDirection: '顺光/漫射光',
    lightDirectionAngle: 30,
    shootingDistance: '2-3m',
    background: '樱花树/校园/蓝天白云/草地',
    props: [],
    bestTime: '上午 7:00-10:00',
    bestTimeFrom: '07:00',
    bestTimeTo: '10:00',
    tips: [
      '选择阴天或晨光获得柔和光线',
      '留白要足，人物占比不超过 60%',
      '服装选择浅色系',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 12,
      contrast: -10,
      saturation: -5,
      temperature: -5,
      tint: 0,
      highlights: 5,
      shadows: 15,
      clarity: -8,
      vibrance: 5,
    ),
    smoothStrength: 10,
    sharpen: 5,
    vignette: 0,
    grain: 0,
    lut: 'pastel',
  ),
);
