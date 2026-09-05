// lib/features/capture/data/templates/geometric_facade.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 立面几何结构模板（街拍 / 几何 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate geometricFacadeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'geometric_facade',
    name: '立面几何结构',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'geometric', subStyle: 'geometric', method: 'wide'),
    tags: ['街拍', '立面', '几何', '建筑', '极简'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/geometric_facade.jpg'),
    ],
    description: '这是一套面向现代主义/极简建筑外立面的黑白摄影模板。画面以大面积留白的混凝土或涂料墙面为底，依靠强烈直射阳光在建筑体块转折处投下边缘锐利的硬阴影，形成强烈的明暗几何分割。横向贯通的黑色长条窗带与局部竖向凹凸肌理构成节奏感。适合拍摄美术馆、办公楼、极简住宅等具有干净体块与重复元素的建筑。无需人物，靠构图与光影本身说话；建议晴天正午前后拍摄以获得最硬的阴影边缘。',
    shortDesc: '纯白立面被烈日切出锐利对角阴影，竖向线条与黑色窗带交织成冷静秩序，高级灰调里藏着建筑的呼吸感🏛️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn', 'winter'],
      weathers: ['sunny'],
      timeTones: ['day'],
    ),
    referenceSource: '样片参考：建筑立面抽象摄影；参数参考秩序构图合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'grid_3x3',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.08, w: 1.0, h: 0.86),
    opacity: 0.25,
    aspectRatio: '1:1',
    description: '大远景/全景建筑立面，机位平视正拍，镜头与墙面平行避免透视变形。主体建筑几乎填满方形画幅(占比约92%)，顶部留窄条纯净天空、底部留窄条平整地面作呼吸。中央竖向肌理柱置于水平中线附近作主轴，三道横向黑窗带按三分法分布形成水平韵律，对角硬阴影作为动态引导线打破横竖的静态。环境交代极少，纯粹突出建筑体块与光影几何。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '单一强自然直射日光，从屏幕左上方约45°高位射入，硬光(光源面积极小、无柔化)，光比极高(约6:1以上)，阴影边缘极其锐利清晰，浓黑对角阴影投向屏幕右下方并落在白色墙面上；墙面呈现哑光磨砂混凝土/涂料质感，无反光无高光溢出，黑色窗格呈深邃哑光黑并隐约反射树影；无需任何补光，纯靠自然硬光塑造几何明暗。',
    shootingDistance: '8-15m',
    background: '纯净无云的浅灰天空 + 平整浅色水泥/石材地面',
    props: [],
    bestTime: '10:30-14:30',
    tips: [
      '务必选晴朗无云的正午前后时段拍摄，太阳越高越硬，阴影边缘才够锐利、明暗对比才够强烈；阴天柔光无法复现此效果。',
      '机位保持与墙面严格平行(正拍)，可用手机网格线对齐建筑横竖线条，避免透视倾斜破坏几何秩序感。',
      '曝光略微压暗(exposureCompensation -0.3)以保住白色墙面纹理、防止高光过曝发死白，同时让黑色窗带更沉。',
      '本模板核心是\'硬光对角阴影+横竖线条\'，若现场阴影方向不理想，可绕建筑走到阴影呈对角切割立面的那一面再拍。',
      '真机无法改变太阳硬度，若光线偏柔只能改期；后期靠 noir 滤镜+高对比+降饱和逼近硬朗黑白，无法替代真实硬光阴影。',
      '构图时让竖向肌理柱接近画面水平中线，三道黑窗带大致落在三分线上，对角阴影自然贯穿即成片。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: -2, contrast: 22, saturation: -100, highlights: -12, shadows: -8, clarity: 18),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 8,
    grain: 6,
    lut: 'noir',
  ),
);