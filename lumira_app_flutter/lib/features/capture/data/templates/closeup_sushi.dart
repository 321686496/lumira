// lib/features/capture/data/templates/closeup_sushi.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 寿司鱼生特写模板（美食 / 特写 / 细节）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupSushiTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_sushi',
    name: '寿司鱼生特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'detail'),
    tags: ['美食', '寿司', '鱼生', '特写', '日料'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/closeup_sushi.jpg'),
    ],
    description: '美食静物拍摄模板，适用于日料握寿司菜品拍摄，侧方柔和暖光塑造鱼肉通透肌理，深色哑光餐盘搭配原木桌面，突出生鱼食材新鲜质感，适合探店、美食记录使用；画面无人物、无手部出镜。',
    shortDesc: '暖调居酒屋光影，鱼肉鲜润通透，高级日式料理静物氛围感🍣',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'autumn', 'winter'],
      weathers: [],
      timeTones: ['warm'],
    ),
    referenceSource: '样片参考：日料寿司特写摄影；参数参考食物微距曝光教程合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.11, y: 0.37, w: 0.78, h: 0.44),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '静物特写，45°斜侧机位，主体寿司占据画面中间约52%画幅，背景环境占48%，四周适度留白，后景道具做虚化处理；无手、无人物入镜。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.15,
    isoMode: 'auto',
    iso: 500,
    shutterSpeed: '1/160',
    whiteBalance: 'incandescent',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方45°照射，属于柔和漫射室内灯光；无强硬轮廓光；光比约2.5:1；阴影投向屏幕右下方，阴影边缘柔和，浓度中等；光线打出鱼肉水润反光、海苔油亮质感；背景为弱亮度暖调环境光；整体主体暖调，背景色调略暗。',
    shootingDistance: '0.6-0.9m',
    background: '浅原木色木质桌面，暗调模糊的室内餐厅背景',
    props: ['黑色哑光餐盘', '腌姜片', '山葵', '小号酱油陶瓷碗'],
    bestTime: '室内环境灯光，无室外时间限制，推荐晚间餐厅室内',
    tips: [
      '尽量关闭机顶闪光灯，使用环境室内暖光；避免直射硬光',
      '靠近主体，尽量拉大主体与背景距离，模拟浅景深效果，真机无法实现光学虚化，依靠构图+后期暗角辅助突出主体',
      '配菜姜片、山葵、酱油碗放在画面远端做虚化陪衬，不要抢寿司主体',
      '餐盘倾斜摆放，利用餐盘边缘制造画面斜向引导线',
      '避免鱼肉高光区域过曝，适当降低曝光补偿保护食材纹理细节',
      '拍摄时画面不要拍入人手，只拍摄餐盘与食物本身',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 2, contrast: 7, saturation: 9, temperature: 6, tint: 1, highlights: -14, shadows: 8, clarity: 11),
    smoothStrength: 0,
    sharpen: 26,
    vignette: 28,
    grain: 14,
    lut: 'none',
  ),
);
