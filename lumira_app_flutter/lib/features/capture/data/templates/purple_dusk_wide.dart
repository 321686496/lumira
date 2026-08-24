// lib/features/capture/data/templates/purple_dusk_wide.dart
import '../../domain/photo_template.dart';

/// 紫色黄昏远景人像（purple_dusk 节点变体，method=wide）
/// 复用 purple_dusk_portrait 封面/剪影
const PhotoTemplate purpleDuskWideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'purple_dusk_wide',
    name: '紫色黄昏远景人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'purple_dusk', subStyle: 'purple_dusk', method: 'wide'),
    tags: ['人像', '日暮', '紫色', '梦幻', '夕阳', '远景'],
    tagIds: [],
    price: 60,
    cover: 'assets/images/templates/purple_dusk_portrait.png',
    description: '紫色黄昏远景人像，漫山晚霞包裹的梦幻背影。',
    referenceSource: '小红书克莱因蓝滤镜教程；夕阳紫色梦幻；日暮氛围人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.2, y: 0.12, w: 0.6, h: 0.75),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '人物置于下方，紫色晚霞占大面积留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
    position: Position(x: 0.5, y: 0.42),
    scale: 0.38,
    rotation: 0,
    description: '远景背影站立看晚霞，人物较小融入紫色天地',
  ),
  camera: CameraParams(
    exposureCompensation: -0.4,
    iso: 100,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（夕阳）',
    lightDirectionAngle: 150,
    shootingDistance: '5-8m',
    background: '夕阳天空/紫色晚霞/海边/山丘',
    props: [],
    bestTime: '黄昏 17:30-19:00',
    bestTimeFrom: '17:30',
    bestTimeTo: '19:00',
    tips: [
      '远景人小景大',
      '紫色晚霞占画面 2/3',
      'tint+15 保留梦幻紫',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -6,
      contrast: 10,
      saturation: 6,
      temperature: 5,
      tint: 16,
      highlights: -12,
      shadows: 3,
      clarity: 0,
      vibrance: 6,
    ),
    smoothStrength: 8,
    sharpen: 10,
    vignette: 12,
    grain: 6,
    lut: 'cinematic',
  ),
);