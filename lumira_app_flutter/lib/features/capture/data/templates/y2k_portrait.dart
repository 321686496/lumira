// lib/features/capture/data/templates/y2k_portrait.dart
import '../../domain/photo_template.dart';

/// Y2K 千禧风模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 11
const PhotoTemplate y2kPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'y2k_portrait',
    name: 'Y2K 千禧风',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'y2k', method: 'half_body'),
    tags: ['人像', 'Y2K', '千禧', '高饱和', '闪光'],
    tagIds: [],
    price: 40,
    cover: 'assets/images/templates/y2k_portrait.png',
    description: '千禧回潮高饱和闪光，飒爽酷 girl 攻击性，Y2K 非甜美路线。',
    referenceSource: '小红书 Y2K 千禧风教程；酷 girl 非甜美风格；千禧回潮摄影',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.15, w: 0.4, h: 0.7),
    opacity: 0.2,
    aspectRatio: '3:4',
    description: '居中半身取景，双手叉腰开立站姿',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/y2k_portrait.png'),
    position: Position(x: 0.5, y: 0.5),
    scale: 0.8,
    rotation: 0,
    description: '正面双手叉腰站立，开立站姿，头部微仰，酷无表情直视镜头',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'on',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正面闪光',
    lightDirectionAngle: 0,
    shootingDistance: '1-1.5m',
    background: '纯色墙/涂鸦墙/街头',
    props: ['墨镜', '链条', '发夹'],
    bestTime: '全天（闪光为主光）',
    tips: [
      '开启闪光灯直打',
      '服装亮色+金属配饰',
      '表情要酷不要甜',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 5,
      contrast: 12,
      saturation: 15,
      temperature: 5,
      tint: 0,
      highlights: -5,
      shadows: -5,
      clarity: 0,
      vibrance: 5,
    ),
    smoothStrength: 8,
    sharpen: 15,
    vignette: 5,
    grain: 5,
    lut: 'none',
  ),
);
