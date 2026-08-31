// lib/features/capture/data/templates/urban_architecture.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 城市建筑模板
/// 来源：lumira-app/src/data/templates/urban-architecture.ts
const PhotoTemplate urbanArchitectureTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'urban_architecture',
    name: '城市建筑天际线',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'landscape',
    classification: TemplateClassification(type: 'landscape', style: 'epic', subStyle: 'epic', method: 'wide'),
    tags: ['建筑', '城市', '风光', '几何线条'],
    tagIds: [],
    price: 20,
    images: [
      TemplateImage(url: 'assets/images/templates/urban_architecture.png'),
    ],
    description: '这是一套专为现代超高层建筑群设计的风景/建筑摄影模板。采用极低机位广角仰拍，强化主塔楼的垂直延伸感与视觉压迫力。画面以冷调银蓝为主色，利用晴朗天气下的自然顺侧光展现玻璃幕墙的镜面反射质感与天空卷云的流动纹理。适合在晴朗白天拍摄城市地标、CBD建筑群，传达清冷、宏大、秩序井然的都市美学。',
    shortDesc: '湛蓝穹顶下银蓝玻璃幕墙直插云霄，流云如丝掠过塔尖，清冷通透的现代都市力量感扑面而来🏙️',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'autumn', 'winter'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['day'],
    ),
    referenceSource: '样片 EXIF: ArchDaily 建筑摄影作品；参数参考建筑摄影作品集',
  ),
  composition: Composition(
    overlayType: 'center_vertical',
    gridType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.15, y: 0.05, w: 0.7, h: 0.9),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '大远景景别，低机位仰拍（相机高度接近地面，仰角约 60-70 度）。正拍机位，确保主塔楼垂直居中不变形（或保留轻微广角透视）。主体建筑群占画幅约 70%，天空环境占 55%（含重叠），底部前景占 15%。头顶（塔尖）留白约 5-8%，避免切顶。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensType: '广角镜头',
    lensSuggestion: 'wide_angle_0.5x_or_main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光为自然日光，从屏幕左上方约 45°-60° 高位射入（顺侧光）。光线较硬但经大气散射略柔，光比中等（约 3:1）。建筑左侧面受光明亮呈银白色，右侧面及凹陷处形成冷蓝色阴影，阴影边缘清晰。玻璃幕墙产生强烈镜面高光反射天空。无需人工补光，纯自然光拍摄。',
    shootingDistance: '50-100m (需后退至广场开阔处以容纳全貌)',
    background: '晴朗深蓝色天空 + 高空卷云/丝状云',
    props: [],
    bestTime: '09:00-11:00 或 14:00-16:00 (太阳高度角较高，天空最蓝)',
    tips: [
      '务必使用广角镜头（0.5x 或更广），并尽量贴近地面仰拍，以最大化建筑的巍峨感。',
      '保持手机绝对水平且正对主楼，利用 App 内置水平仪确保垂直线条不歪斜（除非刻意追求夸张透视）。',
      '曝光补偿略微降低 (-0.3 至 -0.7)，防止天空过曝发白，同时压暗建筑阴影增加立体感。',
      '寻找有丝状卷云的天气拍摄，云层纹理能打破大面积蓝天的单调，增加画面动感。',
      '该效果依赖广角镜头的物理透视，真机无法通过后期完全模拟超广角的边缘拉伸感，请尽量用硬件广角拍摄。',
      '无需开启补光灯，自然光已足够明亮。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(
      brightness: 2,
      contrast: 12,
      saturation: 8,
      temperature: -6,
      tint: -3,
      highlights: -15,
      shadows: 5,
      clarity: 18,
    ),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 15,
    grain: 5,
    lut: 'cyan',
  ),
);
