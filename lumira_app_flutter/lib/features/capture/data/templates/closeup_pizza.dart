// lib/features/capture/data/templates/closeup_pizza.dart
import '../../domain/photo_template.dart';

/// 披萨拉丝特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupPizzaTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_pizza',
    name: '披萨拉丝特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '披萨', '拉丝', '特写', 'cheese'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/dessert_closeup.jpg',
    description: '近距离捕捉披萨被拿起时的芝士拉丝瞬间，口感与细节的近距冲击',
    referenceSource: '样片参考：美食拉丝特写摄影；参数参考动态特写快门合集',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.4),
    opacity: 0.45,
    aspectRatio: '1:1',
    description: '披萨沿对角线构图，拉丝芝士作为视觉焦点，强调动态与质感',
  ),
  // pose: Pose(
  //   silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
  //   position: Position(x: 0.5, y: 0.5),
  //   scale: 1.0,
  //   rotation: 0,
  //   description: '无人物姿势，聚焦食物拉丝瞬间',
  // ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5000,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光（强化芝士拉丝的立体光泽）',
    shootingDistance: '15-25cm（特写）',
    background: '披萨表面、融化的芝士、温热蒸汽',
    props: ['披萨热盘', '切面刀', '深色桌垫'],
    bestTime: '披萨刚出炉趁热时（拉丝最佳）',
    tips: [
      '用连拍捕捉拉起时的动态拉丝',
      '高温时芝士拉丝最完整持久',
      '侧光突出芝士油润与焦化细节',
      '保留热气增加烟火气氛围',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 20, saturation: 20, temperature: 10, tint: 0),
    smoothStrength: 0,
    sharpen: 32,
    vignette: 6,
    grain: 4,
    lut: 'warm_film',
  ),
);