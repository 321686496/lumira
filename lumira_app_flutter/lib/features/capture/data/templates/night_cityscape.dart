// lib/features/capture/data/templates/night_cityscape.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 夜景城市模板
/// 来源：lumira-app/src/data/templates/night-cityscape.ts
const PhotoTemplate nightCityscapeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'night_cityscape',
    name: '城市霓虹夜景',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'night',
    classification: TemplateClassification(type: 'night', style: 'neon', subStyle: 'neon', method: 'wide'),
    tags: ['夜景', '城市', '长曝光', '风光'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/night_cityscape.png'),
    ],
    description: "这是一套专为城市夜景设计的长曝光风格模板。捕捉日落后30分钟的'蓝调时刻'，利用高机位俯瞰跨江大桥与CBD天际线。画面强调冷暖对比：深邃的蓝紫色天空与暖橙色的车流光轨、璀璨的建筑灯光形成强烈视觉冲击。适合拥有广角镜头的用户，在立交桥、高楼观景台或无人机视角下拍摄，展现城市的宏大叙事与流动美感。",
    referenceSource: '样片 EXIF: 城市夜景摄影集；参数参考 500px 城市夜景精选作品',
    shortDesc: '暮色四合，蓝调天空与霓虹灯火交织，车流光轨如丝带般穿梭于江畔，定格这座不夜城的赛博浪漫与流动诗意🌃✨',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn', 'winter'],
      weathers: ['sunny', 'cloudy'],
      timeTones: ['cool', 'night'],
    ),
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'diagonal_guides',
    subjectFrame: SubjectFrame(x: 0.1, y: 0.3, w: 0.8, h: 0.5),
    opacity: 0.3,
    aspectRatio: '16:9',
    description: '大远景，高机位俯拍（模拟无人机或高楼视角）。横构图16:9。主体为跨江大桥与对岸天际线，占据画面中部核心区域。前景利用弯曲的高架桥光轨作为引导线，增强纵深感。天空保留大面积蓝调与晚霞细节，水面提供倒影平衡。整体追求宏大、开阔的视觉张力。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.3,
    isoMode: 'auto',
    iso: 800,
    shutterSpeed: '1/15',
    whiteBalance: 'shade',
    whiteBalanceK: 7200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'wide_angle_0.6x',
    lensType: '广角镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '环境光为主。自然光来自屏幕后方地平线处的落日余晖（逆光/侧逆光），呈现暖橙色；人造光来自城市建筑（屏幕中上部）与车流（屏幕左下部），呈现冷暖交织。光比极大（约1:8以上），天空与暗部建筑反差强，高光点（车灯、楼体灯光）明亮。无需正面补光，依赖环境光与长曝光积累光线。',
    shootingDistance: '远距离俯瞰（500m-2km+）',
    background: '城市CBD天际线、宽阔江面、多云的蓝调天空',
    props: ['三脚架（必备）', '快门线或手机定时拍摄'],
    bestTime: '日落后20-40分钟（蓝调时刻）',
    tips: [
      '【关键】必须使用三脚架固定机位，任何抖动都会导致画面模糊。',
      '【长曝光模拟】真机若无专业长曝光模式，请使用App内的\'流光快门\'或\'光绘\'模式；若只有普通拍照，需后期叠加或多张合成。本模板通过LUT和参数模拟长曝光的色彩氛围，但无法物理生成光轨，请务必在支持长曝光的设备上拍摄原片。',
      '【曝光控制】点击屏幕最亮处（如车灯或高楼灯光）锁定对焦并适当降低曝光补偿（-0.3至-0.7EV），防止高光过曝死白，保留天空蓝色层次。',
      '【白平衡】手动设置K值在7000-7500之间，强化天空的冷蓝色调，与暖色灯光形成冷暖对比。',
      '【构图】寻找高处机位（天桥、高楼、无人机），确保能拍到桥梁全貌及前景的道路曲线。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '16:9',
    color: PostProcessColor(brightness: -2, contrast: 18, saturation: 25, temperature: -8, tint: 5, highlights: -15, shadows: 12, clarity: 15, vibrance: 20),
    smoothStrength: 0,
    sharpen: 35,
    vignette: 25,
    grain: 12,
    lut: 'twilight',
  ),
);
