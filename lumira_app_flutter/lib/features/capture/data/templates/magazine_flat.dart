// lib/features/capture/data/templates/magazine_flat.dart
import '../../domain/photo_template.dart';

/// 杂志静物平面模板（静物 / 平面 / 无方法）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate magazineFlatTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'magazine_flat',
    name: '杂志版面扁平静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat'),
    tags: ['静物', '杂志', '平铺', '构图', '设计感'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/magazine_flat.jpg',
    description: '杂志风平铺静物，将书本、卡片与物件整齐排列，体现设计感与秩序美',
    referenceSource: '样片参考：Pinterest 平铺静物精选；参数参考杂志风布景教程',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '物件在桌面呈整齐网格或对角线排列，图文肌理作为画面纹理',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'food-overhead'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯俯拍平铺场景',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 250,
    shutterSpeed: '1/60',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顶光或窗边漫射光（保证平铺面无硬影）',
    shootingDistance: '0.5-1m（正上方垂直对桌）',
    background: '纯色桌面、光面纸、灰/白卡纸',
    props: ['杂志/书本', '名片/卡片', '文具', '小花、眼镜等小道具'],
    bestTime: '白天（自然光充足、光线均匀）',
    tips: [
      '物件按网格或对角线整齐摆放，制造秩序感',
      '深浅色物件间隔排列增强节奏',
      '机位严格垂直桌面保证边线横平竖直',
      '留白处放小道具让画面透气',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 8, contrast: 15, saturation: 10, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 5,
    grain: 3,
    lut: 'none',
  ),
);