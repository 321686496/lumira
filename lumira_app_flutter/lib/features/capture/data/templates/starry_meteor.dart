// lib/features/capture/data/templates/starry_meteor.dart
import '../../domain/photo_template.dart';

/// 流星划过夜空模板（夜景 / 星空 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryMeteorTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_meteor',
    name: '流星划过夜空',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry', method: 'wide'),
    tags: ['夜景', '流星', '星空', '夜空'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/starry_desert.jpg',
    description: '捕抓到流星划破夜空的瞬间，星轨与流线在暗夜中留下轨迹',
    referenceSource: '样片参考：流星雨星空摄影；参数参考流星拍摄合集合集',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.3, w: 0.45, h: 0.4),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '流星轨迹沿对角方向延伸，地平线置于下三分之一，暗空留白突出流星',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦流星轨迹',
  ),
  camera: CameraParams(
    exposureCompensation: -1.0,
    isoMode: 'manual',
    iso: 2000,
    shutterSpeed: '15',
    whiteBalance: 'auto',
    whiteBalanceK: 4000,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '星光与月光（低光环境）',
    shootingDistance: '无限远（夜空+地景）',
    background: '深邃夜空、散落星光、流星轨迹、低矮地景',
    props: ['三脚架', '广角大光圈镜头', '定时连拍'],
    bestTime: '流星雨活跃期、晴朗无云深夜',
    tips: [
      '用连拍或多爆回收束流星出现几率',
      '手动对焦无穷远并保持稳定',
      '预测辐射点方向提高捕捉概率',
      '地面留适量暗景避免画面空洞',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -8, contrast: 28, saturation: 10, temperature: -18, tint: 8),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 22,
    grain: 20,
    lut: 'cinematic',
  ),
);