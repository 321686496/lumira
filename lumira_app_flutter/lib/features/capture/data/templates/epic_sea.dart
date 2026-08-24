// lib/features/capture/data/templates/epic_sea.dart
import '../../domain/photo_template.dart';

/// 海天一色远景模板（风光 / 大气 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate epicSeaTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'epic_sea',
    name: '海天一色远景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'wide'),
    tags: ['风光', '大海', '海天', '远景', '大气'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/mountain_dawn.jpg',
    description: '海天相接的壮阔远景，广阔海面与天空融为一体，气势磅礴',
    referenceSource: '样片参考：500px 海天一色大气风光精选；参数参考海洋风光黄金时刻合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.5, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '海平线置于画面下三分之一，天空占上部，前景浪花或礁石增加纵深感',
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
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顺侧光（日间稳定光，海面色彩顺滑）',
    shootingDistance: '远景（海面全貌 1km+）',
    background: '开阔海面、天际云层、光影折射的浪花',
    props: ['偏光镜（消除水面反光）', '三脚架（可选）'],
    bestTime: '上午或午后（天色通透、海面平静）',
    tips: [
      '把海平线放在画面三分之一处营造开阔感',
      '用偏光镜压暗水面反光增强层次',
      '收纳前景浪花或礁石增强空间纵深感',
      '保留天空细节避免过曝',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 6, contrast: 18, saturation: 15, temperature: 8, tint: 5),
    smoothStrength: 0,
    sharpen: 24,
    vignette: 14,
    grain: 5,
    lut: 'cinematic',
  ),
);