// lib/features/capture/data/templates/flat_sonboc.dart
import '../../domain/photo_template.dart';

/// 扁平桌面摆件模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatSonbocTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_sonboc',
    name: '扁平桌面摆件',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '摆件', '扁平', '桌面'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/flat_sonboc_1.png'),
      TemplateImage(url: 'assets/images/templates/flat_sonboc_2.png'),
      TemplateImage(url: 'assets/images/templates/flat_sonboc_3.png'),
      TemplateImage(url: 'assets/images/templates/flat_sonboc_4.png'),
    ],
    description: '90 度俯拍的桌面摆件扁平陈列，几何与色彩在平面上形成秩序',
    referenceSource: '样片参考：扁平桌面静物作品；参数参考平面排版静物合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'square',
    subjectFrame: SubjectFrame(x: 0.04, y: 0.04, w: 0.92, h: 0.92),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '高机位完全俯拍（俯拍平面），1:1正方形画幅；静物平铺，物件分散排布，底色大量留白，静物主体合计占画面60‑70%，背景底色占30‑40%。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/120',
    whiteBalance: 'cloudy',
    whiteBalanceK: 6200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光来自屏幕斜上方45°，柔和漫射自然光；光比低约2:1；阴影柔和、浅淡，影子投向屏幕斜下方，阴影边缘模糊；保留陶瓷、玻璃、金属、纸张不同材质的哑光与微弱反光质感；不需要正面补光。',
    shootingDistance: '0.7‑1.1m',
    background: '纯色哑光平整台面；米白/浅奶油/灰蓝色哑光织物衬底，避免反光强亮面。',
    props: ['陶瓷盘杯', '石膏/水泥方块几何体', '玻璃器皿', '卡纸色卡', '金属细棒/金属环', '小型绿植/空气凤梨', '贝壳', '折纸方块'],
    bestTime: '10:00‑16:00',
    tips: [
      '尽量选择阴天窗边柔和散射光，避开直射硬阳光；直射阳光会造成锐利重阴影破坏氛围',
      '物件摆放互相不要重叠，物件之间预留空隙，控制画面平衡，不要一侧物件过多',
      '真机无法实现光学浅景深，尽量相机垂直向下正对桌面拍摄，手机镜头距离台面0.7‑1.1米，保持镜头与台面平行，防止透视变形',
      '台面必须哑光，不要使用亮反光桌面，避免杂乱倒影干扰画面',
      '不同道具混合多种材质：陶瓷、纸张、石材、金属、植物，丰富画面层次。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 5, contrast: -7, saturation: -18, temperature: 2, highlights: -12, shadows: 8, clarity: 6),
    smoothStrength: 10,
    sharpen: 18,
    vignette: 12,
    grain: 14,
    lut: 'morandi',
  ),
);