// lib/features/capture/data/templates/elegant_lady_portrait.dart
import '../../domain/photo_template.dart';

/// 知性优雅轻熟女模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 17
const PhotoTemplate elegantLadyPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'elegant_lady_portrait',
    name: '优雅女士七分身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'scene_portrait', style: 'elegant_lady', subStyle: 'elegant_lady', method: 'seven_body'),
    tags: ['人像', '知性', '优雅', '轻熟女', '莫兰迪'],
    tagIds: [],
    price: 60,
    images: [

      TemplateImage(url: 'assets/images/templates/elegant_lady_portrait.png'),

    ],
    description: '莫兰迪淡雅三分法，知性优雅轻熟女，成熟大气的品质感。',
    referenceSource: '小红书轻熟女穿搭拍照；莫兰迪淡雅风格；城市街拍人像',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.1, w: 0.5, h: 0.8),
    opacity: 0.25,
    aspectRatio: '4:5',
    description: '三分线左侧七分身取景，行走抓拍构图',
  ),
    poses: [
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/elegant_lady_portrait.png'),
          position: Position(x: 0.5, y: 0.5),
          scale: 0.7,
          rotation: 0,
          description: '侧身优雅行走，侧脸看远方，一手持包，一手自然摆动，优雅迈步，自信微笑',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/elegant_lady_portrait.png'),
          position: Position(x: 0.6, y: 0.5),
          scale: 0.75,
          rotation: 0,
          description: '侧身驻足回望镜头，一手持包，一手自然下垂，神情从容自信',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/elegant_lady_portrait.png'),
          position: Position(x: 0.4, y: 0.5),
          scale: 0.7,
          rotation: 0,
          description: '侧立回眸望向远方，一手提包，一手轻披颈巾，身姿修长优雅',
    ),
    Pose(
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/elegant_lady_portrait.png'),
          position: Position(x: 0.45, y: 0.6),
          scale: 0.6,
          rotation: 0,
          description: '远眺站立于平台或街道尽头，望向城市远端，身姿挺拔从容',
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
    lightDirection: '侧光/漫射光',
    lightDirectionAngle: 60,
    shootingDistance: '2-3m',
    background: '城市街拍/办公室/简约室内',
    props: ['手提包'],
    bestTime: '上午 9:00-11:00 或下午 15:00-17:00',
    bestTimeFrom: '09:00',
    bestTimeTo: '11:00',
    tips: [
      '莫兰迪色系服装',
      '侧身行走抓拍动态',
      '三分法构图留白',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(
      brightness: 5,
      contrast: 5,
      saturation: -12,
      temperature: -5,
      tint: 0,
      highlights: 0,
      shadows: 5,
      clarity: 0,
      vibrance: -5,
    ),
    smoothStrength: 12,
    sharpen: 10,
    vignette: 8,
    grain: 5,
    lut: 'cinematic',
  ),
);
