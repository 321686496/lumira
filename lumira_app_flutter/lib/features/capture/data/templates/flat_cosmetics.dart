// lib/features/capture/data/templates/flat_cosmetics.dart
import '../../domain/photo_template.dart';

/// 化妆品扁平展架模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatCosmeticsTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_cosmetics',
    name: '化妆品扁平展架',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '化妆品', '扁平', '展架'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/flat_cosmetics_1.png'),
      TemplateImage(url: 'assets/images/templates/flat_cosmetics_2.png'),
    ],
    description: '90 度俯拍的化妆品扁平陈列，瓶罐轮廓与品牌色调在平面上排列',
    referenceSource: '样片参考：化妆品扁平陈列摄影；参数参考美妆产品摆拍合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'square',
    subjectFrame: SubjectFrame(x: 0.08, y: 0.08, w: 0.84, h: 0.84),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '静物俯拍，1:1正方形画幅，高机位垂直向下俯拍；彩妆产品铺满画面主要区域，四周保留10‑15%背景台面留白；主体产品占画幅85%，背景占15%。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/130',
    whiteBalance: 'custom',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方45°入射，柔和漫射柔光；无硬直射光；光比约2:1；阴影柔和浅淡，影子投向屏幕右下方，阴影边缘模糊；金属瓶盖有柔和高光反射；不需要正面补光，纯自然柔光。',
    shootingDistance: '0.7‑1.1m',
    background: '浅白色大理石 / 浅米哑光台面 / 多格透明玻璃托盘，纯色干净低纹理背景',
    props: ['粉底液瓶', '眼影盘', '唇釉', '粉膏散粉罐', '化妆刷套装'],
    bestTime: '10:00‑15:00',
    tips: [
      '使用窗边柔和漫射天光，避免阳光直射产生硬黑影；拉薄纱窗帘柔化光线',
      '产品摆放互相错开角度，不要全部横平竖直，大小高低穿插，不要堆叠遮挡',
      '真机无法实现光学大光圈虚化，依靠轻暗角+干净背景来聚焦主体；不要紧贴产品，镜头距离0.7米以上避免畸变',
      '金属、玻璃瓶盖注意反光角度，调整产品旋转角度避免刺眼高光溢出',
      '台面保持干净无灰尘，保证画面高级干净质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: -7, saturation: -6, temperature: 3, highlights: -12, shadows: 8, clarity: 4),
    smoothStrength: 20,
    sharpen: 24,
    vignette: 18,
    grain: 12,
    lut: 'cream',
  ),
);