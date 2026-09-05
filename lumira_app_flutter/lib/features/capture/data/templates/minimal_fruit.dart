// lib/features/capture/data/templates/minimal_fruit.dart
import '../../domain/photo_template.dart';

/// 极简果盘静物模板（静物 / 极简 / 单体）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate minimalFruitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'minimal_fruit',
    name: '极简果盘静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'minimal', subStyle: 'minimal', method: 'single'),
    tags: ['静物', '水果', '极简', '单体'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/minimal_fruit.jpg'),
    ],
    description: '少量水果以极简方式摆放的静物，干净背景与柔和色彩传递宁静',
    referenceSource: '样片参考：极简果盘静物摄影；参数参考食物色彩极简合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.35),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '少量水果点缀在画面三分区，留白充足，色彩统一简洁',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/140',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧柔光（水果光泽自然）',
    shootingDistance: '0.5-1m（单体静物）',
    background: '素色桌面 / 纯色背景布',
    props: ['少量当季水果', '素雅小盘'],
    bestTime: '白天窗边柔光（自然光）',
    tips: [
      '只放少量水果保持极简',
      '用统一色系点缀干净场景',
      '侧光表现水果水润质感',
      '留白让画面更透气',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 14, saturation: 12, temperature: 5, tint: 3),
    smoothStrength: 0,
    sharpen: 26,
    vignette: 6,
    grain: 3,
    lut: 'clean_food',
  ),
);
