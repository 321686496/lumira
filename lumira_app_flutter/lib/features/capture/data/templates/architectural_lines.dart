// lib/features/capture/data/templates/architectural_lines.dart
import '../../domain/photo_template.dart';

/// 几何建筑线构模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate architecturalLinesTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'architectural_lines',
    name: '建筑线条几何',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '建筑', '几何', '线条', '极简'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/architectural_lines.jpg',
    description: '城市建筑的重复线条与几何构成，强调秩序感、对称性与留白',
    referenceSource: '样片参考：500px 建筑摄影精选；参数参考极简建筑构图教程',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.45, h: 0.5),
    opacity: 0.45,
    aspectRatio: '4:5',
    description: '建筑的垂直线条平行延伸，汇聚焦点置于画面交点，使用广角强化透视',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'cityscape-tripod'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，重点表现建筑结构与光影',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧光或顺光（晴天线条投影更清晰）',
    shootingDistance: '中远距离（完整收纳建筑立面）',
    background: '玻璃幕墙、混凝土立面、天桥、楼梯等重复结构',
    props: ['三脚架（长焦压缩线条可手持）'],
    bestTime: '晴日午后（光线角度佳，立面受光均匀）',
    tips: [
      '寻找重复的窗格、立柱、楼梯形成秩序感',
      '善用透视——低机位仰拍让线条向上汇聚',
      '保持横平竖直，可利用水平校准辅助线',
      '画面精简，避免杂乱元素破坏几何感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 0, contrast: 20, saturation: -5, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 10,
    grain: 0,
    lut: 'none',
  ),
);