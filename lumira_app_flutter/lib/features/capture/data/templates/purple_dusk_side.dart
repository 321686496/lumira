// lib/features/capture/data/templates/purple_dusk_side.dart
import '../../domain/photo_template.dart';

/// 紫色侧拍人像（purple_dusk 节点变体，method=side）
/// 复用 purple_dusk_portrait 封面/剪影
const PhotoTemplate purpleDuskSideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'purple_dusk_side',
    name: '紫色侧拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'purple_dusk', subStyle: 'purple_dusk', method: 'side'),
    tags: ['人像', '日暮', '紫色', '梦幻', '夕阳', '侧拍'],
    tagIds: [],
    price: 60,
    cover: 'assets/images/templates/purple_dusk_portrait.png',
    description: '紫色侧拍人像，侧脸迎暮光的唯美氛围。',
    referenceSource: '小红书克莱因蓝滤镜教程；夕阳紫色梦幻；日暮氛围人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.2, w: 0.35, h: 0.7),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '人物置于左侧三分位，侧脸望夕阳留白右侧',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.68,
    rotation: 0,
    description: '侧面站立，侧脸望夕阳，一手轻拂发丝，陶醉微笑',
  ),
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
      '侧拍突出面部线条',
      '侧逆光勾勒轮廓',
      'tint+15 是紫色关键',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -5,
      contrast: 9,
      saturation: 6,
      temperature: 5,
      tint: 16,
      highlights: -11,
      shadows: 5,
      clarity: 0,
      vibrance: 6,
    ),
    smoothStrength: 10,
    sharpen: 9,
    vignette: 11,
    grain: 6,
    lut: 'cinematic',
  ),
);