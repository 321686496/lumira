// lib/features/capture/data/templates/casual_crosswalk.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 斑马线随拍模板（街拍 / 随性 / 远景）
/// 内置模板补充：街拍大类非人像模板
const PhotoTemplate casualCrosswalkTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'casual_crosswalk',
    name: '斑马线随拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'street',
    classification: TemplateClassification(type: 'street', style: 'casual', subStyle: 'casual', method: 'wide'),
    tags: ['街拍', '斑马线', '随拍', '人文'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/casual_crosswalk_1.png'),
      TemplateImage(url: 'assets/images/templates/casual_crosswalk_2.png'),
      TemplateImage(url: 'assets/images/templates/casual_crosswalk_3.png'),
      TemplateImage(url: 'assets/images/templates/casual_crosswalk_4.png'),
    ],
    description: '街拍非人像模板，大远景抓拍行人穿行斑马线的生活决定性瞬间；利用斑马线透视引导线构建画面，侧光/顶光塑造路面线条质感，黑白高对比胶片质感，适合记录城市人文纪实场景。',
    referenceSource: '样片参考：Magnum 街拍斑马线作品；参数参考人文街头抓拍合集',
    shortDesc: '城市路口黑白纪实，斑马线延伸出充满烟火的街头故事📷',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn'],
      weathers: ['sunny'],
      timeTones: ['day'],
    ),
  ),
  composition: Composition(
    overlayType: 'leading_lines',
    gridType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.3, y: 0.3, w: 0.5, h: 0.45),
    opacity: 0.5,
    aspectRatio: '3:4',
    description: '大远景景别，机位平视略抬高；斑马线透视引导线作为画面骨架；等候街头决定性瞬间，行人趣味点落在三分线交点；路面斑马线占画幅下半约60%，街道建筑远景占上半约40%。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.2,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/300',
    whiteBalance: 'daylight',
    whiteBalanceK: 5500,
    flashMode: 'off',
    focusMode: 'continuous',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光屏幕上方偏侧，侧光或顶光；硬光光比约3:1；阴影投向屏幕下方，阴影边缘偏硬；保留路面与建筑纹理质感，高光落在斑马线白色条纹上，无明显光斑；环境光为日间街道自然光。',
    shootingDistance: '10-20m',
    background: '斑马线、路口信号灯、城市街道建筑、往来行人和车辆',
    props: ['变焦能力的手机镜头'],
    bestTime: '09:00-11:00 或者 17:00-19:00',
    tips: [
      '在路口保持耐心，等待决定性瞬间，等候多个行人形成画面节奏再按下快门',
      '充分利用斑马线的透视引导线，将行人趣味点放置在线条汇聚附近',
      '控制曝光，优先保留斑马线高光条纹细节，避免高光区域过曝发白',
      '本模板为纪实抓拍，手机无法实现专业相机高速快门定格，依靠连续对焦抓拍动态行人',
      '暗角参数用于压暗画面四角，视觉重心汇聚到画面中部斑马线区域，不产生背景虚化效果',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 5, contrast: 22, saturation: -30, temperature: 0, tint: 0, highlights: -12, shadows: 8),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 18,
    grain: 15,
    lut: 'noir',
  ),
);
