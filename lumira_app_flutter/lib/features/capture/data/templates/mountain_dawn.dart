// lib/features/capture/data/templates/mountain_dawn.dart
import '../../domain/photo_template.dart';

/// 山岳晨光模板（风光 / 大气应急 / 远景）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate mountainDawnTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'mountain_dawn',
    name: '群山破晓',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'wide'),
    tags: ['风光', '山岳', '云海', '晨雾', '大气'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/mountain_dawn.jpg',
    description: '高山云海与日出的壮阔画面，强调层层叠嶂与光线的纵深',
    referenceSource: '样片参考：500px 高山日出云海精选；参数参考风光摄影黄金时刻合集',
  ),
  composition: Composition(
    overlayType: 'golden_ratio',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.32, w: 0.45, h: 0.5),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '最高峰置于黄金分割交点，远近山峦形成层叠引导线，天空留白展示晨光',
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
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（日出方向，山体轮廓受光）',
    shootingDistance: '远景（山岳全貌 500m+）',
    background: '层叠山峦、翻涌云海、辽阔天空',
    props: ['三脚架（长焦或全景接片）', '渐变灰滤镜（压暗天空）', '遮光罩'],
    bestTime: '日出后 20 分钟（山顶晨光斜射，云海未散）',
    tips: [
      '寻找层叠山脊形成纵深引导线',
      '云海出现时降低机位增加层次',
      '使用渐变滤镜平衡天空与地面光比',
      '多张全景接片可展现更广阔的山势',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 5, contrast: 20, saturation: 10, temperature: 15, tint: 5),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 15,
    grain: 5,
    lut: 'cinematic',
  ),
);