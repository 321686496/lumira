// lib/features/capture/data/templates/nature_bees.dart
import '../../domain/photo_template.dart';

/// 蜜蜂采蜜微距模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate natureBeesTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'nature_bees',
    name: '蜜蜂采蜜微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '蜜蜂', '采蜜', '自然'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/macro_flower.jpg',
    description: '微距定格蜜蜂停驻花蕊采蜜的瞬间，绒毛与花粉细节清晰可见',
    referenceSource: '样片参考：蜜蜂采蜜微距作品；参数参考虫类微距高速拍摄合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.3, w: 0.35, h: 0.35),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '蜜蜂置于黄金分割交点，花蕊围绕，虚化背景突出主体动态',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦蜜蜂采蜜',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 500,
    shutterSpeed: '1/400',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光或侧光（蜜蜂绒毛清晰）',
    shootingDistance: '5-15cm（微距）',
    background: '花朵花瓣、绿叶、虚化背景',
    props: ['微距镜头', '高速连拍', '稳定支架'],
    bestTime: '花田日照充足时（蜜蜂活跃）',
    tips: [
      '使用高速快门凝固蜜蜂动态',
      '连拍捕捉最佳姿态',
      '顺光让绒毛细节更清楚',
      '穿深色衣物减少干扰蜜蜂',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 24, saturation: 18, temperature: 8, tint: 5),
    smoothStrength: 0,
    sharpen: 38,
    vignette: 10,
    grain: 4,
    lut: 'nature',
  ),
);