// lib/features/capture/data/templates/purple_dusk_portrait.dart
import '../../domain/photo_template.dart';

/// 紫色黄昏半身人像模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 14
const PhotoTemplate purpleDuskPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'purple_dusk_portrait',
    name: '紫色黄昏半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'purple_dusk', subStyle: 'purple_dusk', method: 'half_body'),
    tags: ['人像', '日暮', '紫色', '梦幻', '夕阳'],
    tagIds: [],
    price: 60,
    images: [

      TemplateImage(url: 'assets/images/templates/purple_dusk_portrait.png'),

    ],
    description: '夕阳克莱因蓝梦幻紫，HSL 蓝饱和提升的日暮浪漫。',
    referenceSource: '小红书克莱因蓝滤镜教程；夕阳紫色梦幻；日暮氛围人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.2, w: 0.4, h: 0.65),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线右侧半身取景，侧脸望夕阳构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '侧身站立，侧脸仰头望夕阳，一手轻拂发丝，并拢站立，陶醉微笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.6,
          rotation: 0,
          description: '正对镜头他拍，双手自然摆放，微微一笑，融入暮色',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
          position: Position(x: 0.5, y: 0.42),
          scale: 0.38,
          rotation: 0,
          description: '远景背影站立看晚霞，人物较小融入紫色天地',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.68,
          rotation: 0,
          description: '侧面站立，侧脸望夕阳，一手轻拂发丝，陶醉微笑',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    iso: 200,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（夕阳）',
    lightDirectionAngle: 150,
    shootingDistance: '1.5-2m',
    background: '夕阳天空/紫色晚霞/海边',
    props: [],
    bestTime: '黄昏 17:30-19:00',
    bestTimeFrom: '17:30',
    bestTimeTo: '19:00',
    tips: [
      '选择紫色晚霞的黄昏',
      '侧逆光勾勒轮廓',
      'tint+15 是紫色关键',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -5,
      contrast: 8,
      saturation: 5,
      temperature: 5,
      tint: 15,
      highlights: -10,
      shadows: 5,
      clarity: 0,
      vibrance: 5,
    ),
    smoothStrength: 10,
    sharpen: 8,
    vignette: 10,
    grain: 5,
    lut: 'cinematic',
  ),
);
