// lib/features/capture/data/templates/foodie_portrait.dart
import '../../domain/photo_template.dart';

/// 探店美食人像模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 15
const PhotoTemplate foodiePortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'foodie_portrait',
    name: '美食人像半身',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'scene_portrait', style: 'foodie_portrait', subStyle: 'foodie_portrait', method: 'half_body'),
    tags: ['人像', '探店', '美食', '对角线', '下午茶'],
    tagIds: [],
    price: 0,
    images: [

      TemplateImage(url: 'assets/images/templates/foodie_portrait.png'),

    ],
    description: '美食+人物对角线暖调，下午茶探店的诱人时光。',
    referenceSource: '小红书探店下午茶拍照；Foodie 滤镜风格；咖啡馆人像教程',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.2, y: 0.2, w: 0.6, h: 0.6),
    opacity: 0.25,
    aspectRatio: '1:1',
    description: '对角线构图，人物与美食呈对角',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/foodie_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '侧身坐姿，一手举杯/餐具，一手托腮，低头看桌面食物，微笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/foodie_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.8,
          rotation: 0,
          description: '侧身坐姿，一手举杯伸向镜头方向，一手轻扶桌面，侧头看向镜头，微笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/foodie_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.9,
          rotation: 0,
          description: '俯视角拍摄，人物低头探向桌面美食，双手持杯或餐具，桌面铺满食物',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/foodie_portrait.png'),
          position: Position(x: 0.35, y: 0.5),
          scale: 0.8,
          rotation: 0,
          description: '侧坐面向桌面，一手持杯轻抿，一手托腮望向窗外，侧影温柔安静',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 200,
    shutterSpeed: '1/100',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光/侧光（室内灯）',
    lightDirectionAngle: 45,
    shootingDistance: '0.8-1.2m',
    background: '咖啡馆桌面/餐厅/美食',
    props: ['咖啡杯', '蛋糕', '餐具'],
    bestTime: '全天（室内）',
    tips: [
      '美食与人物呈对角线构图',
      '俯拍 45 度角',
      '暖调让食物更诱人',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(
      brightness: 10,
      contrast: -5,
      saturation: 10,
      temperature: 10,
      tint: 0,
      highlights: 0,
      shadows: 8,
      clarity: 0,
      vibrance: 5,
    ),
    smoothStrength: 12,
    sharpen: 10,
    vignette: 5,
    grain: 0,
    lut: 'warm_film',
  ),
);
