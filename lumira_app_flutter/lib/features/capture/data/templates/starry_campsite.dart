// lib/features/capture/data/templates/starry_campsite.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 露营星空帐篷模板（夜景 / 星空 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate starryCampsiteTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'starry_campsite',
    name: '露营星空帐篷',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'starry', subStyle: 'starry', method: 'wide'),
    tags: ['夜景', '星空', '露营', '帐篷'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/starry_campsite.png'),
    ],
    description: "这是一套专为夜景星空露营设计的风景模板。画面以壮丽的银河为顶幕，连绵雪山为远景，前景布置精致的Bell Tent（钟形帐篷）与篝火营地。核心视觉在于极致的冷暖对比：深邃蓝紫的夜空与地面金黄温暖的灯火形成强烈反差。适用于户外爱好者、旅行摄影师，在晴朗无月的夜晚，于高海拔或光污染极少的山区复刻此景。造型重点在于营造'精致野奢'感，通过多点暖光源（马灯、篝火、帐篷内透光）点亮暗部细节。",
    shortDesc: '星河垂落山巅，帐篷暖光如豆，篝火跃动间治愈所有孤独，是逃离城市的极致浪漫🏕️✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['night', 'cool'],
    ),
    referenceSource: '样片参考：露营星空摄影作品；参数参考夜景低光地景合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal_galaxy',
    subjectFrame: SubjectFrame(x: 0.1, y: 0.65, w: 0.8, h: 0.3),
    opacity: 0.25,
    aspectRatio: '1:1',
    description: '正方形构图(1:1)。大远景景别。机位平视略低，强调天空的广阔。上部65%为星空，下部35%为地面。银河作为强引导线从左上指向中心。帐篷与篝火作为视觉锚点分布在下方左右两侧，形成稳定的三角构图基底。环境占比极大，突出人与自然的渺小与和谐。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 4200,
    flashMode: 'off',
    focusMode: 'manual_infinity',
    lensSuggestion: 'wide_angle_16mm',
    lensType: '广角镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '多源混合光。主环境光为天空漫射冷光(来自上方/后方)；局部主光为地面篝火与马灯(来自屏幕左下及右下，暖色硬光/柔光混合)；帐篷内部透光(来自屏幕右侧中下部，大面积暖柔光)。光比极大(约1:8)，阴影浓重投向屏幕外侧及上方。无需正面补光，依靠场景自身光源照明。',
    shootingDistance: '5-10m (需容纳帐篷全景与部分前景)',
    background: '清晰可见的银河星空 + 连绵雪山剪影 + 远处微弱的地平线辉光',
    props: ['米白色钟形帐篷(Bell Tent)', '燃烧旺盛的篝火堆', '复古马灯/煤油灯(至少3-4盏)', '折叠露营椅', '木质小桌', '悬挂式灯架'],
    bestTime: '22:00-02:00 (银河升起且无月光干扰时)',
    tips: [
      '必须使用三脚架固定机位，真机无法手持长曝光，需依赖App夜景模式或后期合成模拟星轨/银河清晰度。',
      '白平衡设为自定义4200K左右，以平衡天空的冷蓝与灯光的暖黄，避免天空过紫或灯光过白。',
      '若真机无法拍出如此清晰的银河，建议后期叠加星空素材，或选择光污染极少的地点拍摄。',
      'vignette:25 压暗四角，聚焦中心营地与银河核心。',
      'grain:15 增加轻微颗粒感，模拟高感光度下的胶片质感，掩盖夜景噪点。',
      '确保帐篷内放置强暖光源(如LED灯串)，使其呈现通透发光效果，这是画面的视觉重心之一。',
      '篝火需保持燃烧状态，火焰动态能增加画面生气，注意防火安全。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: -2, contrast: 18, saturation: 12, temperature: -8, tint: 5, highlights: -15, shadows: 12, clarity: 15),
    smoothStrength: 10,
    sharpen: 35,
    vignette: 25,
    grain: 15,
    lut: 'twilight',
  ),
);
