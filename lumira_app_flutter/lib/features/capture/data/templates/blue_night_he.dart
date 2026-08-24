// lib/features/capture/data/templates/blue_night_he.dart
import '../../domain/photo_template.dart';

/// 蓝色夜光他拍人像（blue_night 节点变体，method=normal）
/// 复用 blue_night_portrait 封面/剪影
const PhotoTemplate blueNightHeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'blue_night_he',
    name: '蓝色夜光他拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'dreamy_night', style: 'blue_night', subStyle: 'blue_night', method: 'normal'),
    tags: ['人像', '暗夜', '逆光', '剪影', '冷调', '他拍'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/blue_night_portrait.png',
    description: '蓝色夜光他拍人像，夜风中的侧身回望剪影。',
    referenceSource: '小红书爱乐之城深色滤镜；逆光剪影人像；黄昏海边摄影',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.15, w: 0.4, h: 0.72),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '中心略偏右他拍取景，主体居中留出夜空',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/blue_night_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.5,
    rotation: 0,
    description: '他拍侧身回望镜头，一只手自然下垂，融入夜色',
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
    shootingDistance: '2-3m',
    background: '天空/大海/夕阳余晖/山顶',
    props: [],
    bestTime: '黄昏 17:00-19:00',
    bestTimeFrom: '17:00',
    bestTimeTo: '19:00',
    tips: [
      '他拍保持在人物正面略侧',
      '天空大海占画面一半',
      '人物深色突出轮廓',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -8,
      contrast: 12,
      saturation: -5,
      temperature: -12,
      tint: 0,
      highlights: -15,
      shadows: -5,
      clarity: 0,
      vibrance: 0,
    ),
    smoothStrength: 8,
    sharpen: 10,
    vignette: 15,
    grain: 8,
    lut: 'cool_film',
  ),
);