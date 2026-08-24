// lib/features/capture/data/templates/flat_tshirt.dart
import '../../domain/photo_template.dart';

/// 扁平衣物陈列模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatTshirtTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_tshirt',
    name: '扁平衣物陈列',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '衣物', '扁平', '陈列'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/magazine_flat.jpg',
    description: '90 度俯拍的衣物扁平陈列，材质纹理与配色在平面上呈现',
    referenceSource: '样片参考：扁平衣物陈列摄影；参数参考服装平铺摆拍合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.42,
    aspectRatio: '1:1',
    description: '衣物平铺于画面中央，配饰点缀角落，色彩均匀分布',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦平铺衣物',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正上方柔光（衣物色彩真实）',
    shootingDistance: '0.5-1m（正上方）',
    background: '素色地面 / 木地板 / 干净墙壁背景',
    props: ['平整衣物', '配饰点缀', '素色底垫'],
    bestTime: '白天自然光（均匀明亮）',
    tips: [
      '仔细抚平衣物褶皱摆正版型',
      '保持正上方垂直拍摄',
      '配色搭配和谐突出材质',
      '背景纯净衬托衣物主体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 10, contrast: 16, saturation: 10, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 0,
    grain: 0,
    lut: 'none',
  ),
);