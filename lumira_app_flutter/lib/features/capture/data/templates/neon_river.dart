// lib/features/capture/data/templates/neon_river.dart
import '../../domain/photo_template.dart';

/// 河岸霓虹倒影模板（夜景 / 霓虹 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate neonRiverTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_river',
    name: '河岸霓虹倒影',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'neon', subStyle: 'neon', method: 'wide'),
    tags: ['夜景', '霓虹', '河岸', '倒影'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/night_cityscape.jpg',
    description: '河岸两岸霓虹在城市水面的斑斓倒影，横向开阔的夜间景观',
    referenceSource: '样片参考：城市河道霓虹夜景；参数参考夜景长曝光倒影合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.5, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '河面倒影与岸边霓虹建筑对称分布，水面反射的彩光丰富暗部',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦河岸夜景',
  ),
  camera: CameraParams(
    exposureCompensation: -0.4,
    isoMode: 'auto',
    iso: 800,
    shutterSpeed: '1/40',
    whiteBalance: 'fluorescent',
    whiteBalanceK: 4200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '岸边建筑与霓虹灯光（环境低光）',
    shootingDistance: '远景（河岸全貌 100m+）',
    background: '河面倒影、两岸霓虹楼宇、夜空、桥梁灯光',
    props: ['三脚架（长曝光）', '偏振镜（控制倒影）'],
    bestTime: '夜晚霓虹点亮后（倒影最清晰）',
    tips: [
      '用三脚架降低快门增强水面倒影',
      '保持河面平静以便倒影清晰',
      '天空留出空间避免画面过满',
      '控制曝光保留霓虹不过曝',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 0, contrast: 22, saturation: 22, temperature: -12, tint: 12),
    smoothStrength: 0,
    sharpen: 26,
    vignette: 16,
    grain: 12,
    lut: 'neon',
  ),
);