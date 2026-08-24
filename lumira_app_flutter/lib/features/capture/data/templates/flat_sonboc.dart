// lib/features/capture/data/templates/flat_sonboc.dart
import '../../domain/photo_template.dart';

/// 扁平桌面摆件模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatSonbocTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_sonboc',
    name: '扁平桌面摆件',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '摆件', '扁平', '桌面'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/magazine_flat.jpg',
    description: '90 度俯拍的桌面摆件扁平陈列，几何与色彩在平面上形成秩序',
    referenceSource: '样片参考：扁平桌面静物作品；参数参考平面排版静物合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.4, h: 0.35),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '摆件按几何网格排列，色彩与形状在平面上形成严谨构图',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦平面摆件阵列',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/120',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正上方柔光（避免投影错位）',
    shootingDistance: '0.5-1m（正上方）',
    background: '素色桌面 / 几何桌布',
    props: ['小摆件', '几何道具', '素色底垫'],
    bestTime: '白天自然光（均匀明亮）',
    tips: [
      '保持正上方向下拍避免透视',
      '摆件按几何节奏排列',
      '色彩统一或形成对比节奏',
      '背景干净不干扰主体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 18, saturation: 10, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 0,
    grain: 0,
    lut: 'none',
  ),
);