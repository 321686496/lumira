// lib/features/capture/data/templates/ccd_retro_portrait.dart
import '../../domain/photo_template.dart';

/// CCD 胶片复古模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 1
const PhotoTemplate ccdRetroPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'ccd_retro_portrait',
    name: 'CCD复古半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'ccd_retro', subStyle: 'ccd_retro', method: 'half_body'),
    tags: ['人像', 'CCD', '复古', '胶片', '暖黄'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/ccd_retro_portrait.png',
    description: '90 年代 CCD 复古质感，暖黄颗粒自带柔光，拍出老照片的温柔记忆。',
    referenceSource: '小红书 CCD 复古拍照教程；vivo X200 Ultra CCD 模式；ProCCD App 滤镜',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.15, w: 0.45, h: 0.7),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '三分线左侧半身取景，头部位于上三分线，右侧留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/ccd_retro_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.75,
    rotation: 0,
    description: '侧身站立回眸看镜头，一手轻触发梢，一前一后站姿，微笑',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6000,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧顺光',
    lightDirectionAngle: 45,
    shootingDistance: '1.5-2m',
    background: '老街/室内暖光/复古墙面',
    props: [],
    bestTime: '下午 15:00-17:00',
    bestTimeFrom: '15:00',
    bestTimeTo: '17:00',
    tips: [
      '利用午后暖光营造复古氛围',
      '可轻微晃动模拟 CCD 对焦不准',
      '服装选择纯色或格纹',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 8,
      contrast: -5,
      saturation: 5,
      temperature: 15,
      tint: 0,
      highlights: -10,
      shadows: 10,
      clarity: -5,
      vibrance: 5,
    ),
    smoothStrength: 15,
    sharpen: 8,
    vignette: 15,
    grain: 20,
    lut: 'vintage',
  ),
);
