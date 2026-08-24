// lib/features/capture/data/templates/starry_desert.dart
import '../../domain/photo_template.dart';

/// 璀璨星空模板（夜景 / 星空 / 无方法）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryDesertTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_desert',
    name: '沙漠银河星空',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry'),
    tags: ['夜景', '星空', '银河', '沙漠', '旷野'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/starry_desert.jpg',
    description: '远离光污染的荒野夜空，银河与繁星清晰可见，前景剪影增强空间纵深',
    referenceSource: '样片参考：500px 银河星野摄影精选；参数参考星野摄影教程',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.28, y: 0.3, w: 0.45, h: 0.5),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '银河斜贯画面对角，前景沙丘或枯木剪影置于下沿提供尺度参照',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯星野场景，可配合人物或地景剪影',
  ),
  camera: CameraParams(
    exposureCompensation: -1,
    isoMode: 'manual',
    iso: 3200,
    shutterSpeed: '20s',
    whiteBalance: 'auto',
    whiteBalanceK: 4000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境光仅来自星空（弱，需长曝光）',
    shootingDistance: '广角全景（星野占满画面）',
    background: '无光污染的夜空、远山或沙丘轮廓',
    props: ['三脚架（必须）', '广角大光圈镜头', '红光头灯（保护夜视）'],
    bestTime: '无月晴朗夜晚（新月前后，银河最清晰）',
    tips: [
      '选择偏远无光污染地区，银河核心在夏夜东南方',
      '对焦切换到手动并调到无穷远附近拍出锐利星点',
      '遵循 500 法则控制快门避免星轨拖影',
      '星空对焦困难，先用亮星对焦再锁定',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 10, contrast: 25, saturation: 10, temperature: -10, tint: 5),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 15,
    grain: 10,
    lut: 'cinematic',
  ),
);