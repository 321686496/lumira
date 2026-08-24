// lib/features/capture/data/templates/emotional_selfie.dart
import '../../domain/photo_template.dart';

/// 情绪氛围自拍模板（情绪胶片 · 自拍）
const PhotoTemplate emotionalSelfieTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'emotional_selfie',
    name: '情绪氛围自拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'emotional', subStyle: 'emotional', method: 'selfie'),
    tags: ['情绪', '自拍', '氛围', '逆光', '人像'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/sunset_silhouette.jpg',
    description: '日落氛围下的情绪自拍，利用逆光与眼神捕捉内心独白',
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.18, w: 0.4, h: 0.6),
    opacity: 0.45,
    aspectRatio: '3:4',
    description: '自拍取景，人物居中偏上，面部处于上三分线，四周留氛围',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'standing-profile'),
    position: Position(x: 0.5, y: 0.45),
    scale: 1.1,
    rotation: 0,
    description: '手持设备自拍，微微侧脸看镜头，眼神低垂或望向远方，情绪内敛',
  ),
  camera: CameraParams(
    exposureCompensation: -0.5,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光 180°（太阳位于身后上方）',
    shootingDistance: '0.3-0.6m',
    background: '开阔天空或逆光光斑，地平线下移留出天空',
    props: [],
    bestTime: '日落前 30 分钟（黄金时刻末段）',
    tips: [
      '对焦锁定面部，压低曝光保留氛围',
      '让发丝透光形成轮廓光',
      '可轻微后期加深暗角烘托情绪',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -5, contrast: 20, saturation: -8, temperature: 12, tint: 5),
    smoothStrength: 10,
    sharpen: 18,
    vignette: 30,
    grain: 12,
    lut: 'cinematic',
  ),
);