// lib/features/capture/data/templates/epic_valley.dart
import '../../domain/photo_template.dart';

/// 峡谷晨雾俯拍模板（风光 / 大气 / 俯拍）
/// 内置模板补充：风光大类非人像模板
const PhotoTemplate epicValleyTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'epic_valley',
    name: '峡谷晨雾俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'overhead'),
    tags: ['风光', '峡谷', '晨雾', '俯拍', '大气'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/mountain_dawn.jpg',
    description: '高空俯视的峡谷与晨雾，层次分明的山脊与流动雾海展现壮阔地貌',
    referenceSource: '样片参考：500px 高山俯拍峡谷晨雾精选；参数参考风光摄影航拍视角合集',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.5),
    opacity: 0.45,
    aspectRatio: '16:9',
    description: '峡谷山脊沿对角线延伸，晨雾分布在中下部，天空与雾海形成明暗对比',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿势，纯风光场景',
  ),
  camera: CameraParams(
    exposureCompensation: 0.2,
    isoMode: 'manual',
    iso: 100,
    shutterSpeed: '1/320',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '侧逆光（晨光斜射，山谷明暗分明）',
    shootingDistance: '高空俯拍（峡谷全貌 1km+）',
    background: '层叠峡谷、流动晨雾、裸露山岩与植被',
    props: ['无人机或高处机位', '渐变灰滤镜（压暗天空）', '遮光罩'],
    bestTime: '日出后 20-40 分钟（晨雾浓度最佳、光线斜射）',
    tips: [
      '选择高处或低空俯拍拉开峡谷层次',
      '晨雾流动时用连拍或延时捕捉变化',
      '注意雾海高度，避免阻挡主体',
      '以山脊线条为主导强化构图纵深感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: 5, contrast: 22, saturation: 8, temperature: 10, tint: 5),
    smoothStrength: 0,
    sharpen: 25,
    vignette: 16,
    grain: 6,
    lut: 'cinematic',
  ),
);