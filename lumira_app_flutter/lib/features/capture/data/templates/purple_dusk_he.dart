// lib/features/capture/data/templates/purple_dusk_he.dart
import '../../domain/photo_template.dart';

/// 紫色暮色他拍人像（purple_dusk 节点变体，method=normal）
/// 复用 purple_dusk_portrait 封面/剪影
const PhotoTemplate purpleDuskHeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'purple_dusk_he',
    name: '紫色暮色他拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'purple_dusk', subStyle: 'purple_dusk', method: 'normal'),
    tags: ['人像', '日暮', '紫色', '梦幻', '夕阳', '他拍'],
    tagIds: [],
    price: 60,
    cover: 'assets/images/templates/purple_dusk_portrait.png',
    description: '紫色暮色他拍人像，晚霞环绕的温柔氛围。',
    referenceSource: '小红书克莱因蓝滤镜教程；夕阳紫色梦幻；日暮氛围人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.18, w: 0.4, h: 0.7),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '中心略偏右他拍取景，晚霞留白背景',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/purple_dusk_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.6,
    rotation: 0,
    description: '正对镜头他拍，双手自然摆放，微微一笑，融入暮色',
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
    shootingDistance: '1.5-2.5m',
    background: '夕阳天空/紫色晚霞/海边',
    props: [],
    bestTime: '黄昏 17:30-19:00',
    bestTimeFrom: '17:30',
    bestTimeTo: '19:00',
    tips: [
      '捕捉紫色晚霞最浓时刻',
      '他拍保持正对或略侧',
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