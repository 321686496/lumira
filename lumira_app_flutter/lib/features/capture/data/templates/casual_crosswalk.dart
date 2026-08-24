// lib/features/capture/data/templates/casual_crosswalk.dart
import '../../domain/photo_template.dart';

/// 斑马线随拍模板（街拍 / 随性 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate casualCrosswalkTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'casual_crosswalk',
    name: '斑马线随拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'wide'),
    tags: ['街拍', '斑马线', '随拍', '人文'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/street_bw.jpg',
    description: '远景抓拍行人穿过斑马线的随性瞬间，线条透视与真实生活气息',
    referenceSource: '样片参考：Magnum 街拍斑马线作品；参数参考人文街头抓拍合集',
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.45),
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '斑马线透视线引导视线，行人位于线条交汇与三分线交点',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.4, y: 0.5),
    scale: 0.9,
    rotation: 0,
    description: '抓拍行人自然行走、驻足或交谈的日常动态',
  ),
  camera: CameraParams(
    exposureCompensation: -0.2,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光或顶光（强化地面线条）',
    shootingDistance: '10-20m（路口远景）',
    background: '斑马线、路口信号灯、街道建筑与行人',
    props: ['长焦或变焦镜头'],
    bestTime: '上午 9:00-11:00 或傍晚（光线舒适、行人较多）',
    tips: [
      '在路口等待多个行人形成节奏',
      '用斑马线线条引导视线至主体',
      '保持耐心等待决定性瞬间',
      '注意过曝，优先保留高光细节',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 22, saturation: -30, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 18,
    grain: 15,
    lut: 'bw',
  ),
);