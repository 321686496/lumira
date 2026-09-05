// lib/features/capture/data/templates/neon_portrait.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 霓虹人像模板
/// 来源：lumira-app/src/data/templates/neon-portrait.ts
const PhotoTemplate neonPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_portrait',
    name: '霓虹街角他拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'urban_trend', style: 'neon_city', subStyle: 'neon_city', method: 'normal'),
    tags: ['霓虹', '夜景人像', '赛博朋克', '城市'],
    tagIds: [],
    price: 20,
    images: [
      TemplateImage(url: 'assets/images/templates/neon_portrait_1.jpg'),
    ],
    description: '这是一套专为雨夜繁华街头设计的赛博港风人像模板。场景选取霓虹灯牌密集的湿润街道，利用地面反光增强氛围。光线以背景高饱和霓虹为主，主体需正面补光以从暗背景中剥离。穿搭建议黑色系露肤度适中的吊带或外套，营造冷艳疏离感。适合喜欢电影感、夜景街拍及情绪大片的用户。',
    referenceSource: '样片 EXIF: 赛博朋克人像作品集；参数参考 500px Neon Portrait 专题',
    shortDesc: '雨夜霓虹倒映湿漉街面，紫红光影交错，回眸一瞬清冷又迷离，满是赛博都市的孤独浪漫感🌃✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn'],
      weathers: ['rain'],
      timeTones: ['night'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.35, w: 0.5, h: 0.6),
    opacity: 0.3,
    aspectRatio: '9:16',
    description: '竖构图9:16。半身至七分身景别，裁剪至大腿中部。机位平视，略低于眼睛高度。主体位于画面水平居中，垂直方向占下半部分2/3。头顶留白约1/5，上方留给密集的霓虹灯牌背景。环境占比约40%，强调街道纵深与地面反光。',
  ),
  poses: [
    Pose(
      name: '封面·侧身回眸',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/neon_portrait_pose1.webp'),
      position: Position(x: 0.5, y: 0.5),
      scale: 2.5,
      rotation: 0,
      description: '人物位于画面中下部居中位置。身体背对镜头略向屏幕左侧转约135°（侧背），面部完全回转面向镜头（0°），形成经典的\'侧身回眸\'姿态。头颈微微向屏幕右侧倾斜约5°，下巴微收。视线直视镜头，眼神平静带有一丝疏离感。左肩（屏幕右侧）略微下沉，右肩（屏幕左侧）被头发遮挡。手臂自然下垂或被衣物遮挡，重心看似在双腿之间，姿态放松但挺拔。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'custom',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为屏幕正面补光（柔光），照亮面部与肩部；环境光来自屏幕后方及上方的霓虹灯牌（红/蓝/紫），形成逆光轮廓与背景氛围；地面反射光从屏幕下方漫射上来。光比约1:4（主体亮，背景暗但霓虹亮）。阴影柔和，主要落在背部。',
    shootingDistance: '1.5-2.0m',
    background: '繁华商业街区，密集的中英文霓虹灯牌（如\'重庆\'、\'JOLLY CLUB\'），湿润的柏油路面有积水反光，远处有模糊的行人与车辆尾灯。',
    props: ['无手持道具', '可选：透明雨伞（未撑开）'],
    bestTime: '20:00-23:00',
    tips: [
      '必须开启补光灯或使用手机闪光灯加柔光罩，从屏幕正前方距离1米左右补光，确保面部清晰且肤色自然，避免被背景霓虹吞没。',
      '寻找雨后或有积水的街道，利用地面反射霓虹灯光，增加画面层次感与赛博氛围。',
      '背景选择灯牌密集处，但要注意避开直射镜头的强光点，以免眩光。',
      '真机无法实现大光圈虚化，请尽量靠近主体（1.5米内），让背景自然远离，配合后期暗角压暗四周。',
      '白平衡设为自定义4800K左右，保留霓虹的冷暖对比，不要自动白平衡把颜色校正没了。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(
      brightness: -2,
      contrast: 18,
      saturation: 35,
      temperature: -5,
      tint: 8,
      highlights: -15,
      shadows: 10,
      clarity: 12,
    ),
    smoothStrength: 25,
    sharpen: 30,
    vignette: 35,
    grain: 22,
    lut: 'cyberpunk',
    fillLight: FillLightParams(enabled: true, color: 4294967295, intensity: 0.75),
  ),
);