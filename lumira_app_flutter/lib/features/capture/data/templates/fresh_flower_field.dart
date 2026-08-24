// lib/features/capture/data/templates/fresh_flower_field.dart
import '../../domain/photo_template.dart';

/// 花田清新远景模板（风光 / 清新 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate freshFlowerFieldTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'fresh_flower_field',
    name: '花田清新远景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'wide'),
    tags: ['风光', '花田', '清新', '远景', '治愈'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/seaside_dusk.jpg',
    description: '延绵花田铺向天际的清新远景，色块柔美、光线通透，充满治愈气息',
    referenceSource: '样片参考：500px 花田清风景精选；参数参考风光摄影清新色彩合集',
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.45),
    opacity: 0.42,
    aspectRatio: '16:9',
    description: '花田色块沿地平线铺陈，前景花丛形成引导线指向天空，地平线置于下三分之一',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯风光场景',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺光（日间柔光，花田色彩通透）',
    shootingDistance: '远景（整片花田 500m+）',
    background: '大面积花田、远处草坡与天空、零星树木',
    props: ['三脚架（可选）', '偏光镜（增强花田色彩）'],
    bestTime: '上午 9:00-11:00（光线柔和，花田色彩最饱和）',
    tips: [
      '从高处或远距离取景展现花田层次',
      '用对比色或大片同色花田制造色块节奏',
      '控制曝光保留花瓣与天空细节',
      '收纳前景花丛增加纵深引导',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 8, contrast: 12, saturation: 20, temperature: 5, tint: 10),
    smoothStrength: 0,
    sharpen: 22,
    vignette: 8,
    grain: 5,
    lut: 'fresh',
  ),
);