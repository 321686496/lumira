// lib/features/capture/data/templates/morandi_minimal_portrait.dart
import '../../domain/photo_template.dart';

/// 莫兰迪高级冷淡模板（morandi_minimal 子风格）
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 7
const PhotoTemplate morandiMinimalPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'morandi_minimal_portrait',
    name: '莫兰迪极简半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'fresh_healing', style: 'morandi_minimal', subStyle: 'morandi_minimal', method: 'half_body'),
    tags: ['人像', '莫兰迪', '冷淡', '低饱和', '知性'],
    tagIds: [],
    price: 60,
    cover: 'assets/images/templates/morandi_minimal_portrait.png',
    description: '莫兰迪低饱和高级冷淡，纯色极简知性风，轻熟女的品质感。',
    referenceSource: '莫兰迪色系人像；轻熟女知性风；小红书极简人像教程',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.15, w: 0.4, h: 0.7),
    opacity: 0.2,
    aspectRatio: '4:5',
    description: '居中半身取景，纯色背景极简构图',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/morandi_minimal_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.8,
    rotation: 0,
    description: '正面端坐，双手交叠放膝上，并拢侧坐，正视镜头，知性无表情',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光/柔光',
    lightDirectionAngle: 30,
    shootingDistance: '1.5-2m',
    background: '纯色灰墙/莫兰迪色背景纸',
    props: [],
    bestTime: '全天（室内可控光）',
    tips: [
      '纯色背景保持极简',
      '服装选莫兰迪灰粉/灰绿/灰蓝',
      '光线柔和不产生硬阴影',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(
      brightness: 0,
      contrast: 5,
      saturation: -20,
      temperature: -5,
      tint: 0,
      highlights: 0,
      shadows: 0,
      clarity: 5,
      vibrance: -10,
    ),
    smoothStrength: 12,
    sharpen: 10,
    vignette: 5,
    grain: 5,
    lut: 'none',
  ),
);
