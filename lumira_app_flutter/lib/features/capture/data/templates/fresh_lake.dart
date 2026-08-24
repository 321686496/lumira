// lib/features/capture/data/templates/fresh_lake.dart
import '../../domain/photo_template.dart';

/// 湖畔清新平拍模板（风光 / 清新 / 平拍）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate freshLakeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'fresh_lake',
    name: '湖畔清新平拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'flat'),
    tags: ['风光', '湖畔', '清新', '平拍', '治愈'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/seaside_dusk.jpg',
    description: '平视角的湖畔风光，水面镜面倒影配上清澈天空，营造清新宁静的氛围',
    referenceSource: '样片参考：Pexels 湖畔清新风光精选；参数参考风光摄影清新色调合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.45, h: 0.45),
    opacity: 0.4,
    aspectRatio: '16:9',
    description: '湖岸线置于画面中下方，水面倒影占据下部，远处树木或山丘形成水平层次',
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
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5700,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺侧光（清晨柔光，湖面反光稳定）',
    shootingDistance: '远景（湖面全貌 100m+）',
    background: '平静湖面、远处山丘与小树林、清澈天空',
    props: ['三脚架（可选）', '偏光镜（增强水面通透）'],
    bestTime: '清晨 6:00-8:00（风小、湖面平静、光线柔和）',
    tips: [
      '压低机位贴近水面，让倒影更完整',
      '选择无风的清晨保证水镜效果',
      '以清新干净的蓝绿色调为主，避免过曝天空',
      '适当留白让画面透气',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 8, contrast: 10, saturation: 15, temperature: 0, tint: 5),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 10,
    grain: 5,
    lut: 'fresh',
  ),
);