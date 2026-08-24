// lib/features/capture/data/templates/starry_campsite.dart
import '../../domain/photo_template.dart';

/// 露营星空帐篷模板（夜景 / 星空 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryCampsiteTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_campsite',
    name: '露营星空帐篷',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry', method: 'wide'),
    tags: ['夜景', '星空', '露营', '帐篷'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/starry_desert.jpg',
    description: '露营帐篷在星空下的温暖光点，前景营地灯火与壮丽星空冷暖呼应',
    referenceSource: '样片参考：露营星空摄影作品；参数参考夜景低光地景合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.5, h: 0.4),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '发光的帐篷与篝火置于前景下偏，星空占据上部，冷暖对比营造氛围',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦营地与星空',
  ),
  camera: CameraParams(
    exposureCompensation: -1.0,
    isoMode: 'manual',
    iso: 1200,
    shutterSpeed: '18',
    whiteBalance: 'auto',
    whiteBalanceK: 4500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '帐篷灯火（前景暖光）+ 星光（背景冷）',
    shootingDistance: '中近景营地 + 无限远星空',
    background: '发光帐篷、篝火、草地、深邃星空',
    props: ['三脚架', '暖色营地灯', '广角镜头'],
    bestTime: '晴朗夜、营地灯火与星空亮度平衡时',
    tips: [
      '用营地暖光与星空冷色形成冷暖对比',
      '长曝光时保持营地灯不晃动避免拖影',
      '手动对焦兼顾客厅与无穷远',
      '适度曝光保留星空与营地细节',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -5, contrast: 26, saturation: 15, temperature: -10, tint: 8),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 20,
    grain: 16,
    lut: 'cinematic',
  ),
);