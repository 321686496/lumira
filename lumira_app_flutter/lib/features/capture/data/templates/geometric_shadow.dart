// lib/features/capture/data/templates/geometric_shadow.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

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
    images: [
      TemplateImage(url: 'assets/images/templates/geometric_shadow.jpg'),
    ],
    description: '这是一张极具视觉冲击力的建筑摄影模板。利用强烈的侧逆硬光，在长廊中切割出明暗分明的几何色块。画面采用经典的单点透视，重复的圆柱与地面平行的阴影形成强烈的节奏感与纵深感。左侧大面积的深沉阴影与右侧的高光柱列形成极高反差的明暗对比（Chiaroscuro），营造出一种肃穆、冷静且充满秩序感的空间氛围。适合拍摄美术馆、博物馆、古典柱廊或具有重复结构的现代建筑通道。',
    referenceSource: '样片参考：极简光影几何摄影；参数参考明暗对比构图合集',
    shortDesc: '光与影的极致拉扯，柱列如琴键般延伸，静谧中透着秩序的冷峻美感，一眼万年🏛️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn', 'winter'],
      weathers: ['sunny'],
      timeTones: ['day'],
    ),
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    gridType: 'perspective_grid',
    subjectFrame: SubjectFrame(x: 0.45, y: 0.55, w: 0.1, h: 0.1),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '正方形画幅（1:1）。大远景/全景景别，平视机位。主体为整个建筑通道的透视结构。利用右侧柱列和地面阴影作为强力引导线，将视线引向画面中心的消失点。左侧保留约40%的暗部负空间，平衡右侧的高光细节。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.7,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为强烈的自然硬光，从屏幕右侧（柱列外侧）射入，角度较低（约30-45度），光线未被柔化。光比极大（约8:1以上）。阴影投向屏幕左侧及地面，边缘极其锐利清晰，浓度深黑。无需补光，刻意保留左侧死黑以增强戏剧性。',
    shootingDistance: '5-10m (需站在通道一端向另一端拍摄)',
    background: '具有重复圆柱结构的长廊、美术馆回廊、古典建筑柱廊',
    props: [],
    bestTime: '09:00-10:30 或 15:00-16:30 (太阳角度较低，能形成长投影时)',
    tips: [
      '寻找具有严格重复结构的建筑空间（如柱廊、长窗走廊）。',
      '必须在晴天且太阳角度较低时拍摄，确保光线能从侧面穿透柱子形成地面长影。',
      '机位务必保持绝对水平，使用手机自带的水平仪辅助，确保垂直的柱子不歪斜，水平的阴影平行。',
      '对焦在画面中后部的柱子上，曝光补偿降低（-0.5至-1.0 EV），压暗整体以保护高光不过曝，让阴影自然沉入纯黑。',
      '该效果依赖真实建筑的强光影，真机无法通过算法凭空生成如此锐利的硬光阴影，必须实地寻找合适光位。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: -8, contrast: 35, saturation: -85, highlights: -15, shadows: -20, clarity: 25),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 8,
    lut: 'fine_art_bw',
  ),
);