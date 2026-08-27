// lib/features/capture/data/templates/city_lights_trail.dart
import '../../domain/photo_template.dart';

/// 城市光轨模板（夜景 / 霓虹 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate cityLightsTrailTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'city_lights_trail',
    name: '车流光轨夜景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'neon', subStyle: 'neon', method: 'wide'),
    tags: ['夜景', '城市', '光轨', '长曝光', '车流'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/city_lights_trail.jpg',
    description: '夜晚城市车流光轨与楼宇灯光交织，长曝光造就流动的光影线条',
    referenceSource: '样片参考：500px 长曝车流光轨精选；参数参考车流光轨摄影教程',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.45, h: 0.5),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '弯道车流形成贯穿画面对角线的光轨主线条，楼宇灯光作为背景层次',
  ),
  // pose: Pose(
  //   silhouette: SilhouetteResource(type: 'builtin', data: 'cityscape-tripod'),
  //   position: Position(x: 0.5, y: 0.5),
  //   scale: 1.0,
  //   rotation: 0,
  //   description: '无人物姿势，纯夜景长曝光场景',
  // ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '4s',
    whiteBalance: 'auto',
    whiteBalanceK: 4500,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境灯光（车灯光源形成光轨）',
    shootingDistance: '中远景（天桥、立交、高楼顶机位最佳）',
    background: '车流道路、城市灯光、高楼轮廓',
    props: ['三脚架（必须）', '快门线/延时自拍（防抖）'],
    bestTime: '入夜后 1-2 小时（车流密集、路灯全亮）',
    tips: [
      '三脚架固定机位，长曝光 2-8s 拉出光轨',
      '优先选弯道或立交，车辆转向光轨更丰富',
      '使用快门线或 3s 延时避免按快门抖动',
      '低 ISO 保证画质，配合长曝光延长操作时间',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 5, contrast: 20, saturation: 10, temperature: -5, tint: 5),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 15,
    grain: 5,
    lut: 'cinematic',
  ),
);