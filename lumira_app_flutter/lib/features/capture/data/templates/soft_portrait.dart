// lib/features/capture/data/templates/soft_portrait.dart
import '../../domain/photo_template.dart';

/// 柔光人像模板
/// 来源：lumira-app/src/data/templates/soft-portrait.ts
const PhotoTemplate softPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'soft_portrait',
    name: '柔光人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', style: 'japanese', method: 'normal'),
    tags: ['人像', '柔光', '自然光', '清新'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/soft_portrait.jpg',
    description: '柔光环境下的半身人像，肤色通透自然，适合清新风格肖像',
    referenceSource: '样片 EXIF: Unsplash 柔光人像合集；参数参考人像摄影工作室',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.2, w: 0.4, h: 0.6),
    opacity: 0.4,
    aspectRatio: '3:4',
    description: '人物居中构图，面部位于画面上 1/3 处，保留头顶适当留白',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'soft-portrait'),
    position: Position(x: 0.5, y: 0.45),
    scale: 1.0,
    rotation: 0,
    description: '模特半身姿态，身体微侧，面部朝向光源，表情自然放松',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'telephoto',
    lensType: 'telephoto',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '柔光窗边 45°（漫射自然光为主光源）',
    shootingDistance: '1.5-2m',
    background: '简洁纯色墙面或浅色窗帘，避免杂乱元素干扰',
    props: ['反光板', '浅色窗帘', '绿植点缀'],
    bestTime: '上午 09:00-11:00 或下午 15:00-17:00（窗光柔和）',
    tips: [
      '让模特面朝窗户，利用柔光均匀照亮面部',
      '使用长焦镜头压缩背景，虚化环境突出人物',
      '避免顶光直射造成眼窝阴影',
      '可使用反光板补面部暗部，降低反差',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 10, contrast: -5, saturation: 0, temperature: 5, tint: 5),
    smoothStrength: 40,
    sharpen: 10,
    vignette: 10,
    grain: 5,
    lut: 'pastel',
  ),
);
