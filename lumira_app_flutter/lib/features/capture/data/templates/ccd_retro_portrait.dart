// lib/features/capture/data/templates/ccd_retro_portrait.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// CCD 胶片复古模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 1
const PhotoTemplate ccdRetroPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'ccd_retro_portrait',
    name: 'CCD复古半身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'ccd_retro', subStyle: 'ccd_retro', method: 'half_body'),
    tags: ['人像', 'CCD', '复古', '胶片', '暖黄'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/ccd_retro_portrait.png'),
    ],
    description: '城市街头金时刻纪实人像模板，捕捉女生行走瞬间，侧逆光暖调光影，简约休闲日常穿搭，利用环境虚化前景烘托主体，适合日常出行街拍，记录松弛自然的行走动态。',
    shortDesc: '落日金辉漫洒老街，步履从容，慵懒松弛的城市氛围感✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['goldenHour'],
    ),
    referenceSource: '小红书 CCD 复古拍照教程；vivo X200 Ultra CCD 模式；ProCCD App 滤镜',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.26, y: 0.08, w: 0.6, h: 0.91),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '全身景别，平视机位，人物落在画面垂直左三分线附近；头顶保留约1/6留白，脚底贴近画面底边；前景虚化人物占画面左右，主体人物占画幅约60%，城市街道环境占40%。',
  ),
  poses: [
    Pose(
      name: '行走动态主姿势',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/ccd_retro_portrait_pose1.png'),
      position: Position(x: 0.44, y: 0.52),
      scale: 0.92,
      rotation: 0,
      description: '人物向前行走，身体朝向屏幕左约45°，面部转向屏幕左约90°，低头；屏幕右侧手插裤袋，屏幕左侧手握冰咖啡；重心落在屏幕右侧腿，屏幕左侧腿向前迈出；视线看向屏幕左下方，神情松弛淡然，帆布包搭在屏幕右肩膀。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 6200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕右上方45°高位侧逆光，属于黄金时刻硬质太阳光；无额外辅光；光比约3.5:1；影子投向屏幕左下方，阴影边缘锐利，地面长投影；阳光勾勒头发、肩膀轮廓，皮肤保留自然哑光纹理，墙面形成条状投影；环境背景店铺内有微弱暖黄环境光；整体主体暖金色。',
    lightDirectionAngle: 45,
    shootingDistance: '2.0-2.5m',
    background: '石质复古建筑外墙，临街咖啡馆玻璃橱窗，石板步行街路面；画面左右保留路人作为虚化前景',
    props: ['冰美式咖啡杯', '米白色帆布托特包'],
    bestTime: '16:00-17:30',
    bestTimeFrom: '15:00',
    bestTimeTo: '17:00',
    tips: [
      '抓拍行走动态，不要摆拍僵硬站姿；人物自然迈步，手部动作放松',
      '左右两侧安排人物做前景，靠近前景物体、拉大主体与背景距离，模拟样片虚化效果；手机无法实现光学大光圈虚化，依靠构图实现近似氛围',
      '利用建筑墙体条状光影，尽量让阳光打在人物身体一侧；避开正午顶光',
      '压低曝光补偿保留高光发丝轮廓，后期适当提亮暗部细节，加深暗角集中视线到人物身上',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -2,
      contrast: 10,
      saturation: 8,
      temperature: 7,
      tint: 1,
      highlights: -14,
      shadows: 11,
      clarity: 6,
    ),
    smoothStrength: 28,
    sharpen: 24,
    vignette: 28,
    grain: 24,
    lut: 'warm_film',
  ),
);