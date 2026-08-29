// lib/features/capture/data/templates/neon_river.dart
import '../../domain/photo_template.dart';

/// 河岸霓虹倒影模板（夜景 / 霓虹 / 远景）
/// 内置模板补充：夜景大类非人像模板
const PhotoTemplate neonRiverTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'neon_river',
    name: '河岸霓虹倒影',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'neon', subStyle: 'neon', method: 'wide'),
    tags: ['夜景', '霓虹', '河岸', '倒影'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/neon_river.jpg'),
    ],
    description: '河岸两岸霓虹在城市水面的斑斓倒影，横向开阔的夜间景观',
    referenceSource: '样片参考：城市河道霓虹夜景；参数参考夜景长曝光倒影合集',
  ),
  composition: Composition(
    overlayType: 'symmetry_horizontal',
    gridType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.05, y: 0.2, w: 0.9, h: 0.6),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '大远景景别，平视机位。严格遵循上下对称原则，地平线位于画面正中。主体建筑群宽度占画幅 90%，高度占上半部分的 60%。天空与水面各占约 25%-30% 的留白空间，确保倒影完整性。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 800,
    shutterSpeed: '1/40',
    whiteBalance: 'custom',
    whiteBalanceK: 4800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境光为主。自然天光从屏幕后方（日落方向）提供背景照明，形成剪影与渐变；城市人造光（点光源）从建筑群内部及表面发出，照亮主体细节。无明显单一方向硬光，整体为柔和漫射光与点状高光结合。无需正面补光。',
    shootingDistance: '50-200m (隔江/隔湖拍摄)',
    background: '开阔水域（黄浦江/湖泊/雨后大面积积水），对岸城市天际线',
    props: ['三脚架（强烈建议）', '减光镜ND（可选，用于白天长曝光）'],
    bestTime: '18:30-19:15 (日落后20-40分钟，天空尚有余晖且城市灯光已全开)',
    tips: [
      '【核心要领】必须寻找完全平静的水面，若有波纹可尝试低机位贴近水面拍摄，或等待风停间隙。',
      '【构图铁律】开启相机网格线，确保地平线绝对水平，上下对称是本图灵魂，歪斜会破坏美感。',
      '【曝光控制】夜景容易过曝，建议降低曝光补偿(-0.3至-0.7)，保留天空紫色层次和建筑灯光细节，避免高光死白。',
      '【稳定性】真机无法实现光学长曝光，若光线较暗导致噪点多，请务必使用三脚架固定手机，依靠算法多帧合成降噪。',
      '【白平衡】手动锁定白平衡在4800K左右，防止自动白平衡将紫色天空校正为灰色或过度偏蓝。',
      '【无法复现说明】原图的极致平滑水面可能依赖长曝光或后期堆栈，普通拍摄若有微波纹，可通过后期\'模糊\'或\'镜面\'特效轻微修饰，但尽量前期找静水。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: -2, contrast: 12, saturation: 18, temperature: -3, tint: 8, highlights: -15, shadows: 10, vibrance: 12),
    smoothStrength: 15,
    sharpen: 25,
    vignette: 15,
    grain: 8,
    lut: 'twilight',
  ),
);
