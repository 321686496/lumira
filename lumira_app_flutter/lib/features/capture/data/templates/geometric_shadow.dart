// lib/features/capture/data/templates/geometric_shadow.dart
import '../../domain/photo_template.dart';

/// 光影几何过道模板（街拍 / 几何 / 俯角）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate geometricShadowTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'geometric_shadow',
    name: '光影几何过道',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'overhead'),
    tags: ['街拍', '光影', '几何', '过道', '极简'],
    tagIds: [],
    price: 0,
    cover: 'assets/images/templates/architectural_lines.jpg',
    description: '俯角捕捉过道里的光影分割，几何形状与明暗交织的极简画面',
    referenceSource: '样片参考：极简光影几何摄影；参数参考明暗对比构图合集',
  ),
  composition: Composition(
    overlayType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.5),
    opacity: 0.55,
    aspectRatio: '4:5',
    description: '过道透视线沿对角线延伸，地面的光影色块分割形成节奏',
  ),
  pose: Pose(
    silhouette: SilhouetteResource(type: 'builtin', data: 'landscape-wide'),
    position: Position(x: 0.5, y: 0.5),
    scale: 1.0,
    rotation: 0,
    description: '无人物姿态，聚焦过道的纯几何与光影',
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
    lensSuggestion: 'wide',
    lensType: 'wide',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '顶光或强侧光（形成清晰投影）',
    shootingDistance: '5-15m（过道中段）',
    background: '建筑过道、窗户投下的光影、墙面线条',
    props: ['遮光罩减少炫光'],
    bestTime: '正午或午后（光影对比最强烈）',
    tips: [
      '选择光比大的时段让阴影更利落',
      '用建筑结构形成强引导线',
      '等待行人适时进入光影区域',
      '高光不过曝保持画面干净',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 5, contrast: 35, saturation: -40, temperature: 0, tint: 0),
    smoothStrength: 0,
    sharpen: 40,
    vignette: 22,
    grain: 10,
    lut: 'bw',
  ),
);