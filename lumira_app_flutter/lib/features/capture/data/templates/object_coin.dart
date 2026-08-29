// lib/features/capture/data/templates/object_coin.dart
import '../../domain/photo_template.dart';

/// 老硬币细节模板（微距 / 物品 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate objectCoinTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'object_coin',
    name: '老硬币细节',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'object', subStyle: 'object', method: 'macro'),
    tags: ['微距', '硬币', '老物件', '细节'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/object_coin.png'),
    ],
    description: '微距放大老硬币的币面纹样、刻字与岁月包浆，复古质感浓厚',
    referenceSource: '样片参考：硬币收藏微距作品；参数参考古物微距曝光合集',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.4, h: 0.3),
    opacity: 0.42,
    aspectRatio: '1:1',
    description: '硬币置于画面中心，币面纹样锐利为焦点，柔和背景突出主体',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 200,
    shutterSpeed: '1/150',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光或顶光（凸显币面浮雕）',
    shootingDistance: '5-12cm（微距）',
    background: '木质托盘、绒布垫、深色背景',
    props: ['微距镜头', '稳定支架', '素色垫布'],
    bestTime: '室内恒定光环境最佳',
    tips: [
      '用侧光让币面纹样产生浮雕立体感',
      '对焦锁定币面最复杂的刻纹处',
      '控制反光保留包浆质感',
      '倾斜硬币获得最佳明暗分布',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: 24, saturation: 5, temperature: 12, tint: 5),
    smoothStrength: 0,
    sharpen: 38,
    vignette: 12,
    grain: 10,
    lut: 'warm_film',
  ),
);
