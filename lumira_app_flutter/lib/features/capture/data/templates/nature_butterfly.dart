// lib/features/capture/data/templates/nature_butterfly.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 蝴蝶翅膀微距模板（微距 / 自然 / 微距）
/// 内置模板补充：微距大类非人像模板
const PhotoTemplate natureButterflyTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'nature_butterfly',
    name: '蝴蝶翅膀微距',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'macro',
    classification: TemplateClassification(type: 'macro', style: 'nature', subStyle: 'nature', method: 'macro'),
    tags: ['微距', '蝴蝶', '翅膀', '自然'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/nature_butterfly_1.jpg'),
      TemplateImage(url: 'assets/images/templates/nature_butterfly_2.jpg'),
    ],
    description: '这是一组专注于蝴蝶翅膀微观纹理的静物微距模板。利用纯黑背景与高对比度侧光，凸显翅脉的几何线条与鳞粉的虹彩质感。第一张图呈现翠绿与朱红的荧光感，第二张图展现深红与乳白的丝绒光泽。适合自然爱好者、微距摄影玩家及追求极致细节质感的用户。拍摄时需保持绝对稳定，依靠光影而非色彩滤镜来塑造立体感。',
    referenceSource: '样片参考：蝴蝶微距摄影精选；参数参考微距细节曝光合集',
    shortDesc: '暗夜里的鳞粉星河，红绿交织的呼吸感，每一道翅脉都藏着宇宙的秘密，静谧又绚烂🦋✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer'],
      weathers: ['overcast'],
      timeTones: [],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal',
    subjectFrame: SubjectFrame(x: 0.0, y: 0.0, w: 1.0, h: 1.0),
    opacity: 0.2,
    aspectRatio: '9:16',
    description: '竖构图微距特写。图 1 主体偏左，右侧留黑，利用翅脉做对角引导；图 2 满幅填充，利用翅脉做几何分割。机位平视或微俯，紧贴主体，景深极浅（通过后期模拟或物理靠近实现），背景完全压暗。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.7,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/250',
    whiteBalance: 'custom',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual_macro',
    lensSuggestion: 'macro',
    lensType: '微距镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕左上方 45° 侧逆光射入，硬光质，勾勒翅脉边缘与鳞粉反光；光比约 8:1，阴影极深且投向屏幕右下方，边缘锐利；无需正面补光，依靠侧光塑造立体感与神秘氛围。',
    shootingDistance: '0.05-0.15m',
    background: '纯黑吸光布或深色天鹅绒，确保无反光',
    props: ['蝴蝶标本或活体（需固定）', '小型 LED 聚光灯', '三脚架', '快门线'],
    bestTime: '任意（需全遮光室内环境）',
    tips: [
      '必须使用三脚架固定手机，微距下任何抖动都会导致模糊。',
      '关闭所有环境光，仅保留一盏小型聚光灯从侧上方打光，以压暗背景并突出纹理。',
      '手动对焦锁定在翅脉最清晰处，曝光补偿降低 -0.7 至 -1.0 EV，确保黑色背景纯净不泛灰。',
      '若手机无原生微距，可外接微距镜头或后期裁剪放大（会损失画质，建议优先用硬件）。',
      '图 1 效果依赖鳞粉的结构色，光线角度微调几度颜色就会变化，需耐心寻找最佳反光角。',
      '后期增加 clarity（清晰度）和 sharpen（锐化）以强化鳞片颗粒感，增加 contrast（对比度）压暗暗部。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '9:16',
    color: PostProcessColor(brightness: -8, contrast: 25, saturation: 15, temperature: -2, tint: 3, highlights: -10, shadows: -15, clarity: 30, vibrance: 10),
    smoothStrength: 0,
    sharpen: 45,
    vignette: 35,
    grain: 12,
    lut: 'none',
  ),
);
