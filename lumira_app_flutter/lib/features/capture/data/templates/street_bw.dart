// lib/features/capture/data/templates/street_bw.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 黑白街拍模板
/// 来源：lumira-app/src/data/templates/street-bw.ts
const PhotoTemplate streetBwTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'street_bw',
    name: '随性街头黑白',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'normal'),
    tags: ['黑白', '街拍', '人文', '极简'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/street_bw.png'),
    ],
    description: "这是一套专为都市街头设计的黑白人像模板。场景设定在具有几何线条感的斑马线或建筑前，利用强烈的自然侧逆光制造高对比度阴影。穿搭建议以深色长款大衣、围巾为主，强调廓形与质感。适合喜欢清冷、疏离、电影感风格的用户，通过行走中的抓拍捕捉不经意的回眸或侧视，营造'城市独行'的情绪张力。",
    shortDesc: '城市斑马线上的黑白剪影，大衣随风微扬，眼神清冷疏离，满是电影感的故事氛围🎞️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['autumn', 'winter'],
      weathers: ['sunny'],
      timeTones: ['day', 'goldenHour'],
    ),
    referenceSource: '样片 EXIF: Magnum 街拍作品；参数参考 Magnum Photos 黑白街拍合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal_leading_lines',
    subjectFrame: SubjectFrame(x: 0.35, y: 0.15, w: 0.35, h: 0.8),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '全身景别，头顶留白约1/5，脚底接近画面下缘。机位平视略低（约腰部高度），正拍略带斜侧。主体占画幅垂直方向约70%，水平居中。利用斑马线的白色条纹作为前景引导线，从左下延伸至右上，增强纵深感。背景建筑线条垂直，与人物形成几何对比。',
  ),
  poses: [
    Pose(
      name: '封面·斑马线独行',
      silhouette: SilhouetteResource(type: 'image', data: 'assets/images/silhouettes/street_bw_pose1.webp'),
      position: Position(x: 0.48, y: 0.63),
      scale: 1.79,
      rotation: 0,
      description: '人物位于画面中央略偏右，全身入画。身体朝向屏幕左前方约+45°行进，但面部完全转向屏幕左侧约-90°，形成自然的\u2018行走中侧视\u2019。头颈微微上扬+5°，下巴微收，视线看向屏幕左方远处，表情清冷平静。双手插在大衣口袋中，肩线随步伐自然倾斜，重心落在右腿（画面右侧腿），左腿（画面左侧腿）向前迈出，脚尖朝屏幕左下方。大衣下摆随动作微微飘动，斜挎包带从右肩斜跨至左腰。',
      cameraDirection: 'back',
    ),
  ],
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '主摄镜头',
    lensSuggestion: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为强烈的自然日光，从屏幕右上方约45°射入（硬光）。光比极高（约5:1），人物面部受光均匀但背景处于阴影中。阴影投向屏幕左下方，边缘锐利清晰，浓度深黑。无需补光，依靠环境反光略微提亮暗部即可。',
    shootingDistance: '2.5-3.5m',
    background: '带有横向纹理的石材建筑外墙、大型竖幅广告牌（如CELINE）、交通信号灯杆、模糊的行人剪影。',
    props: ['无手持道具', '斜挎皮包'],
    bestTime: '14:00-16:00',
    tips: [
      '寻找有强烈阳光直射的斑马线或开阔街道，确保地面有清晰投影。',
      '让模特保持行走状态，摄影师使用连拍模式捕捉步伐迈开、大衣飘动的瞬间。',
      '指导模特不要看镜头，视线看向远方或侧面，保持面部肌肉放松，营造\u2018无视镜头\u2019的纪实感。',
      '构图时利用斑马线的斜线引导视觉指向人物，背景尽量简洁或有规律的建筑线条。',
      '后期重点：转为黑白后，大幅提高对比度（contrast +30以上），压低黑色色阶（blackPoint -15）使阴影更纯净，适当增加颗粒感（grain 25-35）模拟胶片质感。',
      '若手机无法直接拍出如此高的光比，可在后期单独压暗背景亮度，提亮人物面部高光。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(
      brightness: -5,
      contrast: 35,
      saturation: -100,
      temperature: 0,
      tint: 0,
      highlights: -10,
      shadows: -20,
      blackPoint: -15,
      clarity: 15,
    ),
    smoothStrength: 10,
    sharpen: 30,
    vignette: 25,
    grain: 30,
    lut: 'noir',
  ),
);
