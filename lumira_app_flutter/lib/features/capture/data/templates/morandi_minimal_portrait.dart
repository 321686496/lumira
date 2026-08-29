// lib/features/capture/data/templates/morandi_minimal_portrait.dart
import '../../domain/photo_template.dart';

/// 莫兰迪高级冷淡模板（morandi_minimal 子风格）
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 7
const PhotoTemplate morandiMinimalPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'morandi_minimal_portrait',
    name: '莫兰迪极简半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'fresh_healing', style: 'morandi_minimal', subStyle: 'morandi_minimal', method: 'half_body'),
    tags: ['人像', '莫兰迪', '冷淡', '低饱和', '知性'],
    tagIds: [],
    price: 60,
    images: [
      TemplateImage(url: 'assets/images/templates/morandi_minimal_portrait.png'),
    ],
    description: '莫兰迪低饱和高级冷淡，纯色极简知性风，轻熟女的品质感。',
    referenceSource: '莫兰迪色系人像；轻熟女知性风；小红书极简人像教程',
  ),
  composition: Composition(
    overlayType: 'center',
    gridType: 'none',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.08, w: 0.5, h: 0.85),
    opacity: 0.2,
    aspectRatio: '4:5',
    description: '半身近景，裁剪至大腿中部。机位平视，镜头高度与人物眼睛齐平。主体严格居中，占据画面宽度的约50%，高度的约85%。头顶留白约占画面高度的15%，底部裁切在大腿处。背景为纯净无杂物的灰绿色墙面，环境占比约40%，主要作为负空间衬托主体。',
  ),
  poses: [
    Pose(
      name: '封面·静谧端坐',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/morandi_minimal_portrait_pose1.png'),
      position: Position(x: 0.5, y: 0.45),
      scale: 0.85,
      rotation: 0,
      description: '人物位于画面正中央，身体完全正对镜头（0°），面部正对镜头（0°）。采取坐姿，躯干挺直但放松，肩线水平。双臂自然下垂并在身前交汇，双手轻轻交叠放置于大腿上方（画面下方中央），手指自然舒展放松，无紧张感。头部端正，无侧倾（headRoll 0°），下巴微收（headPitch -5°），视线平视直视镜头，表情平静淡然，嘴角闭合无笑意，眼神清澈聚焦。整体传达出一种沉稳、内敛且疏离的高级情绪。',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为大面积柔光，从屏幕左前方约45°高位射入，光线极软，无明显硬边阴影。辅光来自屏幕右侧反光板或环境漫反射，填充阴影。光比约1:2，反差极低。鼻下阴影极淡且边缘模糊，投向屏幕右下方。无需额外补光灯，依靠窗边自然光或大型柔光箱即可。',
    shootingDistance: '1.5-2.0m',
    background: '纯色哑光灰绿色背景墙或挂布，无任何纹理和装饰',
    props: ['无'],
    bestTime: '10:00-16:00 (室内窗边) 或 全天候 (影棚)',
    tips: [
      '寻找朝北窗户或在窗户加一层白纱帘，以获得这种无方向的极致柔光。',
      '背景必须干净，若墙面有纹理，请后期使用smoothStrength轻微磨皮或拉远背景距离。',
      '真机无法实现大光圈物理虚化，请让人物距离背景至少1.5米以上，利用透视关系弱化背景细节。',
      '姿态要点：肩膀下沉放松，不要耸肩；手指不要用力扣紧，保持自然弯曲的松弛感。',
      '眼神要定，想象在看穿镜头后的某一点，保持面部肌肉完全放松。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(
      brightness: 2,
      contrast: -8,
      saturation: -25,
      temperature: -2,
      tint: 3,
      highlights: -10,
      shadows: 8,
    ),
    smoothStrength: 25,
    sharpen: 15,
    vignette: 15,
    grain: 12,
    lut: 'morandi',
  ),
);