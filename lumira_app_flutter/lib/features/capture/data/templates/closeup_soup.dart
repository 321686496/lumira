// lib/features/capture/data/templates/closeup_soup.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 汤面热气特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate closeupSoupTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'closeup_soup',
    name: '汤面热气特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '汤面', '热气', '特写', '蒸汽'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/closeup_soup.jpg'),
    ],
    description: '美食静物拍摄模板，适用于面馆居酒屋桌面实拍，柔和暖环境光捕捉面食热气，突出面条汤面质感，背景虚化交代餐厅环境，适合拍摄热汤面、日式简餐类食物。',
    referenceSource: '样片参考：美食特写蒸汽摄影精选；参数参考热气特写曝光合集',
    shortDesc: '热气氤氲的暖汤乌冬，居酒屋烟火感，温柔治愈🍜',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['winter', 'autumn'],
      weathers: [],
      timeTones: ['warm'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'ninth',
    subjectFrame: SubjectFrame(x: 0.16, y: 0.38, w: 0.68, h: 0.58),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '静物近景，略微俯拍45°机位；面碗主体位于画面中下，主体占画幅62%；上部留出蒸汽与背景空间，环境背景占画幅38%；四周保留部分桌面。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.15,
    isoMode: 'auto',
    iso: 600,
    shutterSpeed: '1/125',
    whiteBalance: 'incandescent',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方45°照射主体，属于柔和漫射室内环境光；无强烈硬阴影，光比约2.5:1；阴影柔和弥散，落在碗的屏幕右下方；背景多处暖黄色环境灯光提供环境氛围光；整体主体暖调。',
    shootingDistance: '0.7-1.1m',
    background: '日式面馆居酒屋虚化背景，木质餐桌，远处模糊的吧台、暖黄色吊灯，不要杂乱杂物入镜。',
    props: ['粗陶深色面碗', '乌冬热汤面', '葱花、白芝麻', '木质餐桌'],
    bestTime: '室内晚间18:00-21:00',
    tips: [
      '拍摄刚出锅热食，利用真实蒸汽营造氛围感；蒸汽效果为物理实拍，相机无法生成蒸汽。',
      '靠近食物主体，尽量拉远背景距离，模拟浅景深虚化；手机无法实现光学大光圈虚化，依靠构图+后期暗角辅助突出主体。',
      '关闭闪光灯，避免汤面反光过曝。',
      '碗不要完全居中，略微下沉，上方留出蒸汽升腾的画面空间。',
      '环境尽量使用室内暖黄光，避开冷白光灯管。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 4, contrast: -4, saturation: 10, temperature: 6, tint: 1, highlights: -12, shadows: 8, clarity: 10),
    smoothStrength: 0,
    sharpen: 24,
    vignette: 28,
    grain: 22,
    lut: 'warm_film',
  ),
);
