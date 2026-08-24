// lib/features/capture/data/templates/blue_night_wide.dart
import '../../domain/photo_template.dart';

/// 蓝色之夜远景人像（blue_night 节点变体，method=wide）
/// 复用 blue_night_portrait 封面/剪影
const PhotoTemplate blueNightWideTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'blue_night_wide',
    name: '蓝色夜景远景人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'blue_night', subStyle: 'blue_night', method: 'wide'),
    tags: ['人像', '暗夜', '逆光', '剪影', '冷调', '远景'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/blue_night_portrait.png',
    description: '蓝色之夜远景人像，夜色天空大海的壮阔留白。',
    referenceSource: '小红书爱乐之城深色滤镜；逆光剪影人像；黄昏海边摄影',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.2, y: 0.1, w: 0.6, h: 0.8),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '人物置于下方三分位，天空大海占大面积留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/blue_night_portrait.png'),
    position: Position(x: 0.5, y: 0.45),
    scale: 0.4,
    rotation: 0,
    description: '远景背影站立望海，人物较小融入夜色',
  ),
  camera: CameraParams(
    exposureCompensation: -0.6,
    iso: 100,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光',
    lightDirectionAngle: 180,
    shootingDistance: '5-8m',
    background: '天空/大海/夕阳余晖/山顶',
    props: [],
    bestTime: '黄昏 17:00-19:00',
    bestTimeFrom: '17:00',
    bestTimeTo: '19:00',
    tips: [
      '远景人小景大',
      '天空大海占画面 2/3',
      '保持人物轮廓清晰',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -10,
      contrast: 14,
      saturation: -5,
      temperature: -12,
      tint: 0,
      highlights: -18,
      shadows: -8,
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