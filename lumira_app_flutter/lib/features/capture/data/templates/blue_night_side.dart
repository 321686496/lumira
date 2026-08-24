// lib/features/capture/data/templates/blue_night_side.dart
import '../../domain/photo_template.dart';

/// 蓝色侧拍人像（blue_night 节点变体，method=side）
/// 复用 blue_night_portrait 封面/剪影
const PhotoTemplate blueNightSideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'blue_night_side',
    name: '蓝色侧拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'blue_night', subStyle: 'blue_night', method: 'side'),
    tags: ['人像', '暗夜', '逆光', '剪影', '冷调', '侧拍'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/blue_night_portrait.png',
    description: '蓝色侧拍人像，侧脸逆光勾勒纯粹的夜色轮廓。',
    referenceSource: '小红书爱乐之城深色滤镜；逆光剪影人像；黄昏海边摄影',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.4, y: 0.2, w: 0.3, h: 0.7),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '人物置于右侧三分位，侧脸望海留白左侧',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/blue_night_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.6,
    rotation: 0,
    description: '侧面站立，侧脸望海，双手自然下垂，线条流畅',
  ),
  camera: CameraParams(
    exposureCompensation: -0.5,
    iso: 200,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光',
    lightDirectionAngle: 180,
    shootingDistance: '1.5-2.5m',
    background: '天空/大海/夕阳余晖/山顶',
    props: [],
    bestTime: '黄昏 17:00-19:00',
    bestTimeFrom: '17:00',
    bestTimeTo: '19:00',
    tips: [
      '侧拍突出面部与身形轮廓',
      '避免正面光线',
      '冷调压暗留出剪影',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -9,
      contrast: 15,
      saturation: -6,
      temperature: -14,
      tint: 0,
      highlights: -16,
      shadows: -6,
      clarity: 0,
      vibrance: 0,
    ),
    smoothStrength: 6,
    sharpen: 12,
    vignette: 18,
    grain: 10,
    lut: 'cool_film',
  ),
);