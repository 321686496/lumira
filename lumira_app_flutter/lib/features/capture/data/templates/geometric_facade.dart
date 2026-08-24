// lib/features/capture/data/templates/geometric_facade.dart
import '../../domain/photo_template.dart';

/// 立面几何结构模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate geometricFacadeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'geometric_facade',
    name: '立面几何结构',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '立面', '几何', '建筑', '极简'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/architectural_lines.jpg',
    description: '规整的建筑立面几何，重复的窗户与线条构成抽象秩序',
    referenceSource: '样片参考：建筑立面抽象摄影；参数参考秩序构图合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.55,
    aspectRatio: '4:5',
    description: '立面均分画面，窗户与墙面形成规整网格，强调秩序与重复',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，突出立面结构',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'telephoto',
    lensType: 'telephoto',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正侧光（立面明暗均匀或形成阴影节奏）',
    shootingDistance: '20-50m（远距离正对立面）',
    background: '建筑立面、整齐窗户、细部构造',
    props: ['长焦镜头压缩立面透视'],
    bestTime: '侧光时段（立面立体感强）',
    tips: [
      '平视正对立面保持线条横平竖直',
      '用长焦压缩距离让立面更规整',
      '寻找重复元素建立视觉节奏',
      '注意水平与垂直线避免畸变',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 28, saturation: -20, temperature: 5, tint: 0),
    smoothStrength: 0,
    sharpen: 38,
    vignette: 18,
    grain: 8,
    lut: 'bw',
  ),
);