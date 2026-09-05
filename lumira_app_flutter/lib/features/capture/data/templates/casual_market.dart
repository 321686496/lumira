// lib/features/capture/data/templates/casual_market.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 市集日常抓拍模板（街拍 / 随性 / 常规）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate casualMarketTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'casual_market',
    name: '市集日常抓拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'normal'),
    tags: ['街拍', '市集', '日常', '生活'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/casual_market.jpg'),
    ],
    description: '纪实感环境人像模板，以传统市集菜摊为场景，主角站在画面中部偏左整理新鲜蔬菜，采用平视近距离抓拍，利用棚顶缝隙透入的偏暖自然光和摊位灯形成柔中带硬的生活光影。人物适合穿深色碎花衬衫、围裙等朴素日常服装，前景用蔬菜形成自然层次，适合喜欢市井纪实、生活感街拍与自然抓拍氛围的用户。',
    shortDesc: '暖光落在热闹菜摊间，低头挑菜、轻声交谈，满满都是鲜活松弛的市井烟火气🥬✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['day', 'warm'],
    ),
    referenceSource: '样片参考：人文市集抓拍作品；参数参考街头生活叙事合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.16, y: 0.22, w: 0.43, h: 0.53),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '近景环境人像，平视机位、斜侧约45°抓拍。主角头部位于画面左上区域与上方三分线附近，身体占中部约45%，前景蔬菜从画面下方大面积铺入形成纵深；右侧顾客以虚化人物作为前景框架，背景人群与棚顶保留约35%环境信息。头顶上方保留约1/6画面空间，主体不完全居中，利用菜摊横向排列和前景蔬菜形成由下向中部延伸的自然引导线。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.15,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/250',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光来自屏幕左上方约45°，由市集棚顶开口和环境自然光共同形成偏暖的中等柔光；左侧灯具提供局部暖色补光。整体光比约3:1，面部向屏幕右下方逐渐变暗，阴影边缘较柔；背景存在零散亮点和棚外环境光，前景蔬菜高光清晰但不过曝，整体保留皮肤纹理、衣物纹理和食材湿润质感。',
    shootingDistance: '1.5-2.2m',
    background: '传统露天或半室内菜市场，顶部有遮阳棚、灯具和摊位结构；背景保持多人活动但不要刻意清空，利用不同距离的人群制造生活感层次。',
    props: ['新鲜绿叶菜', '茄子', '黄瓜', '番茄', '塑料购物袋', '帆布购物袋', '菜摊电子秤或金属秤盘'],
    bestTime: '08:00-10:30 或 15:30-17:30',
    tips: [
      '主角不要直视镜头，保持低头整理、捆扎或递出蔬菜的连续动作，让摄影师在动作中抓拍。',
      '拍摄者站在菜摊外侧，与主角保持约1.5-2.2米距离，镜头高度接近人物胸口到眼睛之间，避免明显俯拍。',
      '前景至少保留一层距离镜头较近的蔬菜，占画面下方约25%-35%，保留自然堆叠感。',
      '让一名顾客位于屏幕右侧靠近镜头的位置，形成半遮挡前景框架，但不要挡住主角的脸和双手。',
      '背景人物保持正常走动或购物状态，不要排成整齐队列，以真实市集活动感增加层次。',
      '背景虚化来自真实拍摄距离与前后景层次；真机无法通过本模板参数自动生成光学虚化，可通过靠近主角、让背景人物和棚架更远来获得近似效果。',
      '若棚顶高光过亮，保持EV略微负向并在后期压低highlights；主体阴影区域通过轻微提升shadows恢复细节。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 2, contrast: 14, saturation: 8, temperature: 7, tint: 1, highlights: 18, shadows: 10, blackPoint: 6, clarity: 8, vibrance: 10),
    smoothStrength: 8,
    sharpen: 24,
    vignette: 12,
    grain: 16,
    lut: 'warm_film',
  ),
);
