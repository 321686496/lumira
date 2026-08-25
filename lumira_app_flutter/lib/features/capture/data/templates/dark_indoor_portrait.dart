// lib/features/capture/data/templates/dark_indoor_portrait.dart
import '../../domain/photo_template.dart';

/// 室内暗调氛围模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 8
const PhotoTemplate darkIndoorPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'dark_indoor_portrait',
    name: '暗调室内半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'urban_trend', style: 'dark_indoor', subStyle: 'dark_indoor', method: 'half_body'),
    tags: ['人像', '暗调', '咖啡馆', '锐化', '质感'],
    tagIds: [],
    price: 40,
    images: [

      TemplateImage(url: 'assets/images/templates/dark_indoor_portrait.png'),

    ],
    description: '咖啡馆暗调精致高级，锐化质感黑森林氛围，探店氛围感首选。',
    referenceSource: '小红书黑森林滤镜教程；咖啡馆暗调人像；探店拍照教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.18, w: 0.44, h: 0.65),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '三分线左侧半身取景，倚桌托腮构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/dark_indoor_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.78,
          rotation: 0,
          description: '侧身倚桌坐姿，单手托腮撑桌，微低头看侧方，沉思',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/dark_indoor_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.8,
          rotation: 0,
          description: '侧身站立面向窗光，一手搭椅背，轮廓光勾勒身形，静默沉思',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/dark_indoor_portrait.png'),
          position: Position(x: 0.45, y: 0.5),
          scale: 0.78,
          rotation: 0,
          description: '侧面坐姿，脸部朝向窗光，侧脸半明半暗，视线向下，安静含蓄',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/dark_indoor_portrait.png'),
          position: Position(x: 0.5, y: 0.4),
          scale: 0.7,
          rotation: 0,
          description: '站立微微低头看向下方镜头，气场增强，面部在暗调中突出',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    iso: 400,
    shutterSpeed: '1/80',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光（室内灯/窗光）',
    lightDirectionAngle: 90,
    shootingDistance: '1-1.5m',
    background: '咖啡馆/暗调室内/木质桌面',
    props: ['咖啡杯', '书', '餐具'],
    bestTime: '全天（室内）',
    tips: [
      '选择暗调咖啡馆靠窗位',
      '侧光营造明暗对比',
      '锐化突出质感细节',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -10,
      contrast: 10,
      saturation: -5,
      temperature: 5,
      tint: 0,
      highlights: -10,
      shadows: -5,
      clarity: 0,
      vibrance: 0,
    ),
    smoothStrength: 12,
    sharpen: 20,
    vignette: 15,
    grain: 8,
    lut: 'cinematic',
  ),
);
