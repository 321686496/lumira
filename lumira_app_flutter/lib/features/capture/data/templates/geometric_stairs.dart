// lib/features/capture/data/templates/geometric_stairs.dart
import '../../domain/photo_template.dart';

/// 旋转楼梯几何模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate geometricStairsTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'geometric_stairs',
    name: '旋转楼梯几何',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '旋转楼梯', '几何', '建筑', '极简'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/architectural_lines.jpg',
    description: '俯拍或仰拍的旋转楼梯，螺旋曲线与同心结构构成强烈的几何韵律',
    referenceSource: '样片参考：旋转楼梯几何摄影作品；参数参考建筑抽象构图合集',
  ),
  composition: Composition(
    overlayType: 'center',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.28, w: 0.5, h: 0.5),
    opacity: 0.55,
    aspectRatio: '4:5',
    description: '楼梯螺旋中心置于画面中央，扶手与台阶围合成重复的几何形状',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，突出楼梯结构本身',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顶光或窗户侧光（阶梯明暗交替）',
    shootingDistance: '5-20m（楼梯中轴仰/俯）',
    background: '旋转楼梯台阶、扶手、墙面结构',
    props: ['广角镜头增强透视'],
    bestTime: '白天光线充足时段（清晰几何）',
    tips: [
      '从楼梯中轴线上俯拍或仰拍最出效果',
      '利用重复的台阶与扶手形成节奏',
      '注意保持对称与线条垂直',
      '高光与阴影并存的时段更有立体感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 30, saturation: -30, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 40,
    vignette: 20,
    grain: 10,
    lut: 'bw',
  ),
);