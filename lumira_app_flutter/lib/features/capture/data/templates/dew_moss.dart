// lib/features/capture/data/templates/dew_moss.dart
import '../../domain/photo_template.dart';

/// 露珠苔藓模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate dewMossTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'dew_moss',
    name: '苔藓晨露微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '苔藓', '露珠', '自然', '清新'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/dew_moss.jpg',
    description: '清晨苔藓上滚动的露珠特写，剔透的水珠折射光线，展现自然微观之美',
    referenceSource: '样片参考：Pexels 微距自然精选；参数参考自然微距教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.4),
    opacity: 0.4,
    aspectRatio: '4:5',
    description: '最大的露珠置于三分线交点，其余水珠沿苔藓纹理自然散落',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'macro-flower'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯自然微距主体',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'macro',
    lensType: 'macro',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '柔和的侧逆光（晨光透过露珠更通透）',
    shootingDistance: '超近距离（5-20cm 微距）',
    background: '茂密苔藓、湿润岩石、叶片表面',
    props: ['微距镜头/近摄镜', '三脚架（低机位）', '喷壶（如需补露珠）'],
    bestTime: '清晨露水未散（湿度大、光线柔和）',
    tips: [
      '清晨湿度大时露珠最多最饱满',
      '背光角度拍摄让露珠透亮带高光轮廓',
      '手持用极浅景深对焦水珠核心',
      '可用喷壶补挂水雾增加质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 15, saturation: 15, temperature: 10, tint: 0),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 10,
    grain: 0,
    lut: 'fresh',
  ),
);