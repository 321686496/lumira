// lib/features/capture/data/templates/jewelry_closeup.dart
import '../../domain/photo_template.dart';

/// 首饰特写模板（微距 / 物体 / 无方法）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate jewelryCloseupTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'jewelry_closeup',
    name: '珠宝首饰微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'object', subStyle: 'object'),
    tags: ['微距', '首饰', '宝石', '质感', '精致'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/jewelry_closeup.jpg',
    description: '戒指/项链等首饰的超近特写，突出金属光泽、宝石切面与精致工艺',
    referenceSource: '样片参考：Pexels 产品微距精选；参数参考珠宝摄影教程',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.4, h: 0.4),
    opacity: 0.45,
    aspectRatio: '4:5',
    description: '首饰主体置于黄金分割交点，宝石反光作为亮点，留白营造高级感',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'macro-flower'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，静物首饰单独呈现',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顶光或侧逆光（用柔光板打散，避免金属反光过硬）',
    shootingDistance: '超近距离（微距特写）',
    background: '纯色亚克力、天鹅绒衬布、大理石台面',
    props: ['柔光箱/反光板', '首饰托/支架', '除尘气吹'],
    bestTime: '室内恒定光环境（随时可拍）',
    tips: [
      '金属表面易反光，用柔光罩打散主光',
      '对焦锁定在宝石切面的最亮点',
      '避免手部影子落入画面',
      '深色绒布衬底更能衬托金属光泽',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 20, saturation: 5, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 40,
    vignette: 8,
    grain: 0,
    lut: 'none',
  ),
);