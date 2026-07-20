// lib/features/capture/data/templates/sunset_silhouette.dart
import '../../domain/photo_template.dart';

/// 日落逆光剪影模板
/// 来源：lumira-app/src/data/templates/sunset-silhouette.ts
const PhotoTemplate sunsetSilhouetteTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'sunset_silhouette',
    name: '日落逆光剪影',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'emotional', method: 'wide'),
    tags: ['逆光', '剪影', '黄昏', '人像'],
    tagIds: [],
    price: 0,
    cover: 'https://picsum.photos/seed/template-sunset-silhouette/400/600',
    description: '日落时分逆光拍摄人像剪影，突出轮廓与氛围',
    referenceSource: '样片 EXIF: Pexels #12345；参数参考摄影教学网站 Photzy 逆光人像指南',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.33, y: 0.4, w: 0.34, h: 0.5),
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '人物置于左侧三分线交点，剪影轮廓清晰，上方留白展示天空',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'standing-profile'),
    position: Position(x: 0.35, y: 0.55),
    scale: 1.0,
    rotation: 0,
    description: '模特侧身站立，背对镜头，面朝夕阳方向，手臂自然下垂',
  ),
  camera: CameraParams(
    exposureCompensation: -0.7,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'telephoto',
    lensType: 'telephoto',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '逆光 180°（太阳位于模特正后方）',
    shootingDistance: '3-5m',
    background: '开阔天空，地平线低于模特头部',
    props: ['三脚架（可选）', '反光板（补面部光）'],
    bestTime: '日落前 30 分钟（黄金时刻末段）',
    tips: [
      '对焦点选天空中等亮度区域锁定曝光',
      '确保模特轮廓无重叠，头部与天空分离',
      '可降低 EV 制造更深剪影',
      '拍摄 RAW 便于后期恢复天空色彩',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -5, contrast: 25, saturation: -10, temperature: 15, tint: 5),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 30,
    grain: 10,
    lut: 'cinematic',
  ),
);
