// lib/features/capture/data/templates/golden_landscape.dart
import '../../domain/photo_template.dart';

/// 黄金时刻风光模板
/// 来源：lumira-app/src/data/templates/golden-landscape.ts
const PhotoTemplate goldenLandscapeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'golden_landscape',
    name: '金色麦田风光',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'wide'),
    tags: ['风光', '黄金时刻', '日出日落', '广角'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/golden_landscape.jpg'),
    ],
    description: '黄金时刻拍摄风光，色调温暖柔和，强调自然光影层次',
    referenceSource: '样片 EXIF: 500px 风光精选；参数参考 500px 风光摄影黄金时刻合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'horizontal_thirds',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '竖幅 3:4 构图。大远景景别。地平线置于画面中上部（约 0.55 高度），刻意压低天空比例以突出前景麦田的浩瀚。主体（麦田+雪山）占满画幅，无多余留白。利用麦浪的横向纹理作为隐性引导线，将视线引向远处的雪山主峰。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '自然顺光/侧顺光。主光从屏幕右上方来（依据右侧云层高光及彩虹位置判断），光线硬朗明亮，光比中等（约 3:1）。阴影落在麦穗背光侧及山体背阴面，边缘较硬。无需补光，纯自然光拍摄。',
    shootingDistance: '无限远（风景远景）',
    background: '连绵雪山、蓝天白云、右侧彩虹',
    props: [],
    bestTime: '10:00-15:00',
    tips: [
      '寻找高处或开阔地带，确保前景麦田无遮挡，能完整收纳远处雪山轮廓。',
      '测光点选在麦田亮部与雪山之间，避免天空过曝或麦田欠曝；若天空过亮，可略微降低曝光补偿（-0.3 至 -0.7）并在后期提亮阴影。',
      '彩虹通常出现在太阳对面，拍摄时注意站位，让太阳在身后或侧后方，才能拍到前方的彩虹。',
      '真机无法实现光学浅景深，本模板依靠大景深全景清晰呈现，后期通过 sharpen 增强麦穗细节，vignette 轻微压暗四角聚焦中心。',
      '若现场光线平淡，可提高 saturation 和 contrast 模拟样片的浓郁感。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 12, saturation: 18, temperature: 2, tint: 0, highlights: -10, shadows: 8, clarity: 15, vibrance: 10),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 5,
    lut: 'fuji',
  ),
);