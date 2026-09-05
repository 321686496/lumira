// lib/features/capture/data/templates/object_watch.dart
import '../../domain/photo_template.dart';

/// 手表表盘微距模板（微距 / 物品 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate objectWatchTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'object_watch',
    name: '手表表盘微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'object', subStyle: 'object', method: 'macro'),
    tags: ['微距', '手表', '表盘', '物品'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/object_watch.jpg'),
    ],
    description: '微距拍摄手表表盘的精细做工，指针、刻度和金属反光的质感',
    referenceSource: '样片参考：手表表盘微距作品；参数参考产品微距布光合集',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.4, h: 0.3),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '表盘占据画面中心，指针与刻度清晰，浅景深虚化表壳',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '柔光箱侧柔光（金属反光均匀）',
    shootingDistance: '5-15cm（微距）',
    background: '表盘玻璃、表壳、简洁深色台面',
    props: ['柔光箱', '反光板', '手表支架'],
    bestTime: '室内恒定光环境最佳',
    tips: [
      '用柔光控制金属反光防止过曝',
      '对焦锁定指针或刻度细节',
      '调整角度避免眩光反射',
      '背景简洁突出表盘质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 22, saturation: 8, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 36,
    vignette: 8,
    grain: 3,
    lut: 'clean_food',
  ),
);
