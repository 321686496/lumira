// lib/features/capture/data/templates/minimal_book.dart
import '../../domain/photo_template.dart';

/// 单本书籍静物模板（静物 / 极简 / 单体）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate minimalBookTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'minimal_book',
    name: '单本书籍静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'minimal', subStyle: 'minimal', method: 'single'),
    tags: ['静物', '书籍', '极简', '单体'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/indoor_still_life.jpg',
    description: '单本极简风格书籍置于干净背景上的静物，突出留白与质感的宁静',
    referenceSource: '样片参考：极简书籍静物摄影；参数参考留白构图合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.4, h: 0.35),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '书籍置于三分线交点，大面积留白凸显极简氛围',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦单本静物',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/120',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧柔光（书本封面质感）',
    shootingDistance: '0.5-1m（单体静物）',
    background: '素色桌面 / 纯色背景 / 亚麻布',
    props: ['单片书', '极简摆件（可选小物件）'],
    bestTime: '白天窗边柔光（自然光）',
    tips: [
      '保持背景通勤纯色突出书籍',
      '侧光让封面材质有细节',
      '适当留白营造极简呼吸感',
      '避免多余道具保持简洁',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 16, saturation: 0, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 6,
    grain: 4,
    lut: 'clean_food',
  ),
);