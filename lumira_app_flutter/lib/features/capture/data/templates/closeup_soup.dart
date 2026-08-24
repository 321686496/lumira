// lib/features/capture/data/templates/closeup_soup.dart
import '../../domain/photo_template.dart';

/// 汤面热气特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupSoupTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_soup',
    name: '汤面热气特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '汤面', '热气', '特写', '蒸汽'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/dessert_closeup.jpg',
    description: '近距离拍摄的汤面升腾热气，镜头捕捉高温蒸汽的朦胧与面条细节',
    referenceSource: '样片参考：美食特写蒸汽摄影精选；参数参考热气特写曝光合集',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.3, w: 0.35, h: 0.4),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '汤碗置于中心偏下，热气在光线中显现，撒料葱花提供细节焦点',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，聚焦食物本身',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（逆光下热气与蒸汽清晰可见）',
    shootingDistance: '10-20cm（特写）',
    background: '汤碗内壁、冒着热气的汤面、撒料',
    props: ['深色衬底突出热气', '注水喷壶（补足蒸汽）'],
    bestTime: '热汤刚出锅时（蒸汽最浓）',
    tips: [
      '逆光或侧逆光让热气边缘发亮',
      '快速对焦锁定面与配菜细节',
      '趁热拍摄把握蒸汽浓度',
      '用深色背景衬托氤氲热气',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 18, saturation: 15, temperature: 8, tint: 0),
    smoothStrength: 0,
    sharpen: 32,
    vignette: 6,
    grain: 4,
    lut: 'warm_film',
  ),
);