// lib/features/capture/data/templates/blue_night_portrait.dart
import '../../domain/photo_template.dart';

/// 复古暗夜蓝模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 13
const PhotoTemplate blueNightPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'blue_night_portrait',
    name: '复古暗夜蓝',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'blue_night', method: 'seven_body'),
    tags: ['人像', '暗夜', '逆光', '剪影', '冷调'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/blue_night_portrait.png',
    description: '黄昏逆光暗夜蓝冷峻浪漫，天空大海的背影剪影诗。',
    referenceSource: '小红书爱乐之城深色滤镜；逆光剪影人像；黄昏海边摄影',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.15, w: 0.5, h: 0.75),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧七分身取景，天空大海占主体留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/blue_night_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.65,
    rotation: 0,
    description: '背影站立望海，仰头，双手自然下垂，并拢站立',
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
      '黄昏逆光剪影感',
      '天空大海占画面 2/3',
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
