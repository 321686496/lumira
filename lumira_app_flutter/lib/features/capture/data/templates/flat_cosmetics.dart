// lib/features/capture/data/templates/flat_cosmetics.dart
import '../../domain/photo_template.dart';

/// 化妆品扁平展架模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatCosmeticsTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_cosmetics',
    name: '化妆品扁平展架',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '化妆品', '扁平', '展架'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/magazine_flat.jpg',
    description: '90 度俯拍的化妆品扁平陈列，瓶罐轮廓与品牌色调在平面上排列',
    referenceSource: '样片参考：化妆品扁平陈列摄影；参数参考美妆产品摆拍合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.42,
    aspectRatio: '1:1',
    description: '化妆品按大小与色系排列成网格，产品标签正面朝上呈现品牌感',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦展架上的产品排列',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/130',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正上方柔光（瓶罐无反光）',
    shootingDistance: '0.5-0.8m（正上方）',
    background: '素色桌面 / 大理石 / 镜面垫',
    props: ['化妆品瓶罐', '化妆刷', '素色展垫'],
    bestTime: '白天自然光（均匀明亮）',
    tips: [
      '让产品标签正面朝上清晰可读',
      '按色系或大小规则排列',
      '用大理石或素色垫营造高级感',
      '保持垂直拍摄避免透视变形',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 10, contrast: 18, saturation: 12, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 4,
    grain: 0,
    lut: 'clean_food',
  ),
);