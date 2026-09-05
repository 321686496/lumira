// lib/features/capture/data/templates/closeup_pizza.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 披萨拉丝特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupPizzaTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_pizza',
    name: '披萨拉丝特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '披萨', '拉丝', '特写', 'cheese'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/closeup_pizza.jpg'),
    ],
    description: '美食静物拍摄模板，拍摄被铲起一块的玛格丽特披萨，使用侧上方柔和暖光，突出芝士拉丝流动质感，适合室内餐桌美食拍摄，还原食物诱人的食欲氛围。',
    shortDesc: '暖光裹挟芝士拉丝，烟火美味瞬间，满满治愈食欲感🍕',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn', 'winter'],
      weathers: [],
      timeTones: ['warm'],
    ),
    referenceSource: '样片参考：美食拉丝特写摄影；参数参考动态特写快门合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'third',
    subjectFrame: SubjectFrame(x: 0.02, y: 0.08, w: 0.96, h: 0.91),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '近景美食静物，斜侧45°机位，主体披萨占画面75%，虚化暗调背景占25%，视觉焦点落在右上方被抬起的披萨切片。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.15,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/250',
    whiteBalance: 'incandescent',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方45°入射，柔和漫射光源；无强硬辅光；光比约3:1；阴影投向屏幕右下方，阴影边缘柔和；突出芝士油亮反光、饼皮焦斑纹理；背景环境光偏暗，形成明暗分离；整体主体暖，背景偏冷暗。',
    shootingDistance: '0.6-1.0m',
    background: '深色哑光桌面，后方模糊暗调室内环境，无杂乱物体。',
    props: ['陶瓷餐盘', '披萨铲', '新鲜罗勒叶点缀', '番茄片'],
    bestTime: '12:00-15:00，窗边柔和自然光环境，也可室内暖台灯模拟',
    tips: [
      '拍摄时刻快速抓拍芝士拉丝瞬间。',
      '靠近食物、尽量拉远背景，配合暗角模拟浅景深效果，手机无法实现光学虚化。',
      '避免闪光灯直打，防止芝士出现过曝刺眼反光。',
      '罗勒、番茄片作为点缀，少量摆放，不要铺满画面。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 2, contrast: 8, saturation: 14, temperature: 6, tint: 1, highlights: -12, shadows: 10, clarity: 12),
    smoothStrength: 8,
    sharpen: 26,
    vignette: 30,
    grain: 14,
    lut: 'warm_film',
  ),
);
