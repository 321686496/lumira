// lib/features/capture/data/templates/film_vintage.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 胶片复古人像模板
/// 来源：lumira-app/src/data/templates/film-vintage.ts
const PhotoTemplate filmVintageTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'film_vintage',
    name: '胶片复古他拍人像',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'emotional_film', style: 'film', subStyle: 'film', method: 'normal'),
    tags: ['胶片', '复古', '人像', '怀旧', '暖调'],
    tagIds: [],
    price: 20,
    images: [
      TemplateImage(url: 'assets/images/templates/film_vintage.png'),
    ],
    description: '这是一套主打黄昏暖调与复古质感的街头人像模板。利用下午4-5点的低角度硬侧光，在粗糙石墙上投下百叶窗般的条纹阴影，营造强烈的明暗对比与故事感。穿搭建议采用深蓝针织背心搭配米白高腰阔腿裤，简约法式风。适合喜欢胶片质感、追求自然松弛氛围的用户。',
    referenceSource: '样片 EXIF: 500px 胶片人像作品；参数参考胶片摄影作品',
    shortDesc: '金色夕阳洒在石墙，手捧冰咖漫步街头，光影斑驳间尽是慵懒松弛的复古电影感🎞️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['goldenHour', 'day'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.24, y: 0.08, w: 0.54, h: 0.92),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '全身景别，机位平视，人物放在画面偏左的九宫格交叉位置；头顶保留约1/5留白，脚底贴近画面底边；虚化前后景路人作为虚实层次，环境建筑背景占画面40%。',
  ),
  poses: [
    Pose(
      name: '行走抓拍主姿势',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/film_vintage_pose1.png'),
      position: Position(x: 0.44, y: 0.52),
      scale: 0.88,
      rotation: 0,
      description: '人物向前行走，身体侧向屏幕右约-45°，面部转向屏幕右-90°，头颈微微低头，视线看向屏幕地面方向；屏幕左侧手握住冰咖啡，屏幕右侧手插入裤袋，重心落在屏幕右腿，屏幕左腿向前迈出，脚步呈行走动态，整体状态松弛自然。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕右上方45°黄金侧顺光，属于黄昏硬质感暖光；无明显辅光；光比约3:1；阴影投向屏幕左下方，影子边缘偏硬；墙面投射百叶状条状光影；皮肤呈现哑光质感，保留皮肤纹理，发丝有暖金色高光；环境背景带有店铺橱窗暖调环境光，整体画面主体暖调。',
    lightDirectionAngle: 45,
    shootingDistance: '2.0-2.5m',
    background: '石质外墙复古临街商铺，玻璃窗、石板人行道，可利用路过行人做虚化前后景',
    props: ['冰咖啡饮品', '帆布托特包'],
    bestTime: '17:00-18:15',
    tips: [
      '抓拍行走瞬间，不要摆僵，脚步要有动态感；',
      '尽量选择建筑物侧面受光，获取条状墙面光影；',
      '靠近主体，利用远处行人充当虚化前景后景，模拟浅景深效果；手机无法物理大光圈虚化，靠构图与暗角辅助氛围；',
      '避开镜头直射强光，防止画面大面积高光过曝；',
      '可以让包自然垂挂肩头增加生活感。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -2,
      contrast: 8,
      saturation: 8,
      temperature: 6,
      tint: 1,
      highlights: -14,
      shadows: 10,
      clarity: 6,
    ),
    smoothStrength: 25,
    sharpen: 20,
    vignette: 28,
    grain: 24,
    lut: 'warm_film',
  ),
);