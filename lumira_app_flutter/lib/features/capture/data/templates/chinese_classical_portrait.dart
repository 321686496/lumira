// lib/features/capture/data/templates/chinese_classical_portrait.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 新中式古风模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 5
const PhotoTemplate chineseClassicalPortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'chinese_classical_portrait',
    name: '中式古典全身人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'retro_nostalgia', style: 'chinese_classical', subStyle: 'chinese_classical', method: 'full_body'),
    tags: ['人像', '古风', '新中式', '莫兰迪', '园林'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/chinese_classical_portrait.png'),
    ],
    description: '人物全身古风汉服人像，江南古典园林亭台场景，利用午后侧方柔和自然光，浅青竹纹宋制汉服搭配团扇道具，回眸回望镜头，营造含蓄清冷的东方古典氛围感，适合汉服爱好者拍摄。',
    referenceSource: '小红书古风人像教程；莫兰迪冷色调风格；汉服摄影套图',
    shortDesc: '亭下回眸执扇轻掩，清冷温婉，浸染江南园林的诗意古风🍃',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['day'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.34, y: 0.08, w: 0.54, h: 0.91),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '全身景别，平视机位斜侧45°拍摄；人物处于画面偏右位置，主体占画幅约65%；头顶保留约1/5留白，脚底贴近画面下边缘；背景完整保留亭柱、白墙假山池水园林环境，环境占画幅35%，左侧亭柱做框架式前景。',
  ),
  poses: [
    Pose(
      name: '封面·回眸执扇站姿',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/chinese_classical_portrait_pose1.png'),
      position: Position(x: 0.54, y: 0.46),
      scale: 0.92,
      rotation: 0,
      description: '人物身体背对镜头偏向屏幕左约135°，面部回转朝向镜头，头颈微微收下巴；重心落在屏幕右侧腿，屏幕左侧腿微微向后；屏幕右侧手臂抬起，手持竹纹团扇，扇子轻挡口鼻位置，手指放松握住扇柄；屏幕左侧手臂被宽大衣袖遮挡；身体站姿挺拔，肩线松弛，眼神望向镜头，神情温婉含蓄。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: 0.15,
    isoMode: 'auto',
    iso: 100,
    shutterSpeed: '1/160',
    whiteBalance: 'daylight',
    whiteBalanceK: 5100,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方45°入射，属于午后漫射太阳光；具备柔和轮廓光，在人物肩袖、发丝边缘勾勒亮边；光型柔和，光比约2.5:1；阴影投向屏幕右下方，阴影边缘柔和过渡；皮肤呈现哑光温润质感，发丝边缘有高光，树叶产生细碎光斑；环境整体冷调。',
    lightDirectionAngle: 135,
    shootingDistance: '2.0-2.4m',
    background: '江南古典园林，木质亭廊立柱，白墙黛瓦花格窗，太湖石假山、池塘水景，竹子、开花灌木植物',
    props: ['竹纹手绘团扇', '古风发簪步摇头饰'],
    bestTime: '15:00-16:30',
    bestTimeFrom: '08:00',
    bestTimeTo: '10:00',
    tips: [
      '尽量选择园林有遮挡的漫射日光，避开正午硬直射阳光',
      '靠近被摄者，与背景假山池水拉开距离，配合暗角参数模拟浅景深效果；手机硬件无法实现光学虚化',
      '左侧亭柱利用作为前景，增加画面层次，不要完全遮挡人物',
      '握扇手部姿态放松，不要用力攥紧扇柄，扇面轻挡下半张脸',
      '人物身体转过去之后再回头看向镜头，脖颈自然扭转，不要耸肩',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: 2,
      contrast: -8,
      saturation: -4,
      temperature: -6,
      tint: 3,
      highlights: 18,
      shadows: 12,
      clarity: -5,
    ),
    smoothStrength: 32,
    sharpen: 20,
    vignette: 26,
    grain: 16,
    lut: 'muted_gray',
  ),
);