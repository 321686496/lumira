// lib/features/capture/data/templates/seaside_dusk.dart
import '../../domain/photo_template.dart';

/// 海边黄昏模板（风光 / 清新治愈 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate seasideDuskTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'seaside_dusk',
    name: '海边黄昏风光',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'fresh', subStyle: 'fresh', method: 'wide'),
    tags: ['风光', '海边', '黄昏', '治愈', '粉色调'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/seaside_dusk.jpg',
    description: '黄昏时分的海岸线，暖粉与蓝色交织，浪花与云层营造温柔治愈的氛围',
    referenceSource: '样片参考：Pexels 沿海风光精选；参数参考风光摄影黄昏合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.35, w: 0.45, h: 0.45),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '海平线置于画面下三分之一，晚霞占据上部，前景礁石或沙滩形成引导线',
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
    shutterSpeed: '1/180',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正逆光（落日方向，海面呈现金色反光）',
    shootingDistance: '远景（海岸全貌 100m+）',
    background: '开阔海面、晚霞云层、沙滩或礁石',
    props: ['三脚架（可选）', '渐变灰滤镜（压暗天空）'],
    bestTime: '日落前 30 分钟（晚霞色彩最浓、天空与海面光比适中）',
    tips: [
      '选择有前景（礁石、船只、人物剪影）的机位增加层次',
      '黄昏光比大，优先保证天空曝光，暗部靠后期拉回',
      '偏粉的晚霞可适度让白平衡偏暖',
      '浪花拍岸瞬间可用连拍捕捉动态',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 8, contrast: 10, saturation: 15, temperature: 15, tint: 10),
    smoothStrength: 0,
    sharpen: 20,
    vignette: 12,
    grain: 5,
    lut: 'warm_film',
  ),
);