// lib/features/capture/data/templates/casual_market.dart
import '../../domain/photo_template.dart';

/// 市集日常抓拍模板（街拍 / 随性 / 常规）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate casualMarketTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'casual_market',
    name: '市集日常抓拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'normal'),
    tags: ['街拍', '市集', '日常', '生活'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/street_bw.jpg',
    description: '市集里摊贩与人流交错的生活化抓拍，充满烟火气与真实感',
    referenceSource: '样片参考：人文市集抓拍作品；参数参考街头生活叙事合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.5, h: 0.5),
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '摊贩或顾客置于三分线交点，前景货物与背景人流形成层次',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.4, y: 0.5),
    scale: 0.9,
    rotation: 0,
    description: '抓拍摊主整理、顾客挑选交流的自然姿态',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境光（室内外混合光，保留氛围）',
    shootingDistance: '3-8m（单人或局部）',
    background: '市集货摊、蔬果货物、来往人流与遮阳棚',
    props: ['小光圈保留环境细节'],
    bestTime: '早市或傍晚人流高峰（生活气息浓）',
    tips: [
      '多捕捉摊贩与顾客的互动瞬间',
      '利用货物色彩装点画面活力',
      '避免打扰拍摄对象保持自然',
      '适当提高快门凝固动态',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 20, saturation: 10, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 32,
    vignette: 16,
    grain: 12,
    lut: 'clean_food',
  ),
);