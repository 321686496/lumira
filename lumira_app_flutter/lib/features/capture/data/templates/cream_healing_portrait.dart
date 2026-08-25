// lib/features/capture/data/templates/cream_healing_portrait.dart
import '../../domain/photo_template.dart';

/// 奶油治愈风模板（cream_healing 子风格）
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 4
const PhotoTemplate creamHealingPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'cream_healing_portrait',
    name: '奶油暖调半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'fresh_healing', style: 'cream_healing', subStyle: 'cream_healing', method: 'half_body'),
    tags: ['人像', '奶油', '治愈', '暖调', '夕阳'],
    tagIds: [],
    price: 0,
    images: [

      TemplateImage(url: 'assets/images/templates/cream_healing_portrait.png'),

    ],
    description: '奶油橙暖调温柔治愈，夕阳海边氛围感，拯救废片的小镰仓风。',
    referenceSource: '小红书小镰仓滤镜教程；海边夕阳拍照；Foodie 暖调滤镜',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.2, w: 0.4, h: 0.65),
    opacity: 0.25,
    aspectRatio: '3:4',
    description: '居中偏右半身取景，三分线右侧构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/cream_healing_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '正面坐姿，单手托腮，头部微倾，盘腿或屈膝坐，温柔微笑看镜头',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/cream_healing_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '靠窗侧坐，微微弯腰靠近窗沿，手搭在窗台，暖光洒在脸上',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/cream_healing_portrait.png'),
          position: Position(x: 0.5, y: 0.55),
          scale: 0.7,
          rotation: 0,
          description: '仰面躺或坐地上抬头，双手轻托脸，眉眼弯弯温柔笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/cream_healing_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '侧身坐或站，侧脸朝向逆光方向，发丝随风透光',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0,
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '1x',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光/侧逆光（夕阳）',
    lightDirectionAngle: 150,
    shootingDistance: '1.5-2m',
    background: '海边/夕阳/沙滩/暖色墙面',
    props: [],
    bestTime: '下午 16:00-18:00',
    bestTimeFrom: '16:00',
    bestTimeTo: '18:00',
    tips: [
      '利用夕阳逆光营造暖调氛围',
      '让发丝透光产生金色轮廓光',
      '服装选择奶油色系',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 12,
      contrast: -8,
      saturation: 5,
      temperature: 12,
      tint: 0,
      highlights: -5,
      shadows: 12,
      clarity: -5,
      vibrance: 5,
    ),
    smoothStrength: 15,
    sharpen: 8,
    vignette: 5,
    grain: 5,
    lut: 'warm_film',
  ),
);
