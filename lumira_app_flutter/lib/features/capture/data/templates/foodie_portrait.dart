// lib/features/capture/data/templates/foodie_portrait.dart
import '../../domain/photo_template.dart';

/// 探店美食人像模板
/// 来源：docs/superpowers/specs/2026-08-04-portrait-template-redesign-design.md 模板 15
const PhotoTemplate foodiePortraitTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'foodie_portrait',
    name: '美食人像半身',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'portrait',
    classification: TemplateClassification(type: 'portrait', majorStyle: 'scene_portrait', style: 'foodie_portrait', subStyle: 'foodie_portrait', method: 'half_body'),
    tags: ['人像', '探店', '美食', '对角线', '下午茶'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/foodie_portrait_1.jpg'),
      TemplateImage(url: 'assets/images/templates/foodie_portrait_2.jpg'),
      TemplateImage(url: 'assets/images/templates/foodie_portrait_3.jpg'),
      TemplateImage(url: 'assets/images/templates/foodie_portrait_4.jpg'),
    ],
    description: '暖调咖啡馆下午茶人像，甜系松弛，捕捉惬意悠闲的探店时光。',
    referenceSource: '小红书探店下午茶拍照；Foodie 滤镜风格；咖啡馆人像教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'third',
    subjectFrame: SubjectFrame(x: 0.42, y: 0.08, w: 0.55, h: 0.88),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '1:1正方形画幅；封面图为半身景别，腰部以上入镜，人物放置画面右三分线，画面下半部分留给桌面甜品美食，头顶预留约1/6留白，背景虚化光斑，环境占画面40%，主体人像占60%；俯拍效果图人物上半部分在上半区，下半区铺满美食；侧颜图人物放在画面左侧三分线，右侧留出桌面空间。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/100',
    whiteBalance: 'custom',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光屏幕斜上方45°柔光；部分样片存在窗边侧逆光，背景大量散景暖黄色串灯光斑；室内环境漫反射柔光，光比约2.5:1，阴影柔和不生硬；逆光画面人物面部依靠环境漫反射提亮，不需要强制外置补光灯；发丝边缘有淡淡的轮廓高光。',
    lightDirectionAngle: 45,
    shootingDistance: '1.6‑2.2m',
    background: '复古木质咖啡馆，木质置物架，玻璃窗，虚化暖黄色串灯散景光斑，深色木质餐桌。',
    props: ['白瓷咖啡杯', '拿铁杯', '各式切块蛋糕、水果挞', '马卡龙', '可颂面包', '金属小叉子', '玻璃杯饮品'],
    bestTime: '14:00‑17:00，午后窗边自然光 / 晚间室内暖灯环境',
    tips: [
      '尽量拉开人物与背景距离，利用环境制造散景光斑，手机无法实现物理大光圈虚化，依靠构图+后期暗角模拟氛围感。',
      '道具摆放：桌面丰富摆放蛋糕、挞类、咖啡，错落分布，不要整齐排成一条直线。',
      '窗边逆光版本：优先利用环境漫反射照亮人脸，人脸不要完全压黑；人脸偏暗可开启软件内部fillLight模拟补光。',
      '穿搭优先选择米白、燕麦、浅卡其等低饱和浅色系针织毛衣，适配暖黄环境色调。',
      '拍摄坐姿，身体坐直略微放松，肩膀不要耸起，手指抓握杯子保持松弛状态，避免僵硬用力。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(
      brightness: 4,
      contrast: -4,
      saturation: 8,
      temperature: 6,
      tint: 1,
      highlights: -12,
      shadows: 8,
    ),
    smoothStrength: 32,
    sharpen: 20,
    vignette: 26,
    grain: 24,
    lut: 'warm_film',
  ),
);
