// lib/features/capture/data/templates/closeup_sushi.dart
import '../../domain/photo_template.dart';

/// 寿司鱼生特写模板（美食 / 特写 / 细节）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupSushiTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_sushi',
    name: '寿司鱼生特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'detail'),
    tags: ['美食', '寿司', '鱼生', '特写', '日料'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/dessert_closeup.jpg',
    description: '近距离拍摄的寿司鱼生，展现食材纹理、光泽与摆盘的精致细节',
    referenceSource: '样片参考：日料寿司特写摄影；参数参考食物微距曝光教程合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.4, h: 0.3),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '寿司置于黄金分割交点，鱼生纹理为焦点，强调食材光泽与颜色对比',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，聚焦食物本身',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 500,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5100,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光 45°（突出鱼生表面光泽）',
    shootingDistance: '10-20cm（特写）',
    background: '深色漆盘 / 浅色木质底座 / 竹帘',
    props: ['寿司盘', '芥末与姜片', '筷子', '小酱碟'],
    bestTime: '日料上桌后尽快拍摄（保持食材鲜亮）',
    tips: [
      '低角度侧光让鱼生表面泛出油润光泽',
      '对焦锁定鱼肉纹路最清晰处',
      '用深色背景衬托食材色彩',
      '保持摆盘干净突出主体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 6, contrast: 20, saturation: 18, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 34,
    vignette: 8,
    grain: 3,
    lut: 'clean_food',
  ),
);