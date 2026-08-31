// lib/features/capture/data/templates/food_flat_lay.dart
import '../../domain/photo_template.dart';
import '../../../templates/data/remote_template_dto.dart';

/// 美食俯拍模板
/// 来源：lumira-app/src/data/templates/food-flat-lay.ts
const PhotoTemplate foodFlatLayTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'food_flat_lay',
    name: '木质桌面俯拍料理',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'overhead', subStyle: 'overhead', method: 'flat'),
    tags: ['美食', '俯拍', 'flat-lay', '静物'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/food_flat_lay.jpg'),
    ],
    description: '美食静物拍摄模板，日式蒲烧鳗鱼盖饭，高机位垂直俯拍；采用柔和漫射顶光，保留食材油润光泽，蓝黑纹理深盘做背景，色彩浓郁对比强烈，适合拍摄精致日式简餐、摆盘料理。',
    shortDesc: '高级氛围感鳗鱼定食俯拍，色彩浓郁诱人，质感满满的美食大片🍱',
    ambience: RemoteTemplateAmbienceDto(
      seasons: ['spring', 'summer', 'autumn', 'winter'],
      weathers: [],
      timeTones: ['warm'],
    ),
    referenceSource: '样片 EXIF: 食物摄影教程；参数参考 YouTube 频道 The Bite Shot',
  ),
  composition: Composition(
    overlayType: 'center_composition',
    gridType: 'square',
    subjectFrame: SubjectFrame(x: 0.03, y: 0.06, w: 0.94, h: 0.88),
    opacity: 0.3,
    aspectRatio: '4:5',
    description: '高机位垂直俯拍（接近平面俯拍）；餐盘主体居于画面正中，主体占画幅88%，四周保留深色纹理背景做环境留白；无上下留白裁剪，完整收纳整只餐盘与少量外部背景。',
  ),
  camera: CameraParams(
    exposureCompensation: -0.15,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/60',
    whiteBalance: 'custom',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕斜上方45°，柔和漫射光；无硬直射光；光比约2.5:1；阴影柔和浅淡，阴影落向屏幕斜下方；不需要正面补光，依靠环境漫反射照亮暗部。',
    shootingDistance: '0.6‑0.9m',
    background: '深青绿色做旧哑光纹理台面，避免反光，颜色偏冷，和食物暖色调形成对比',
    props: ['纹理陶瓷深盘', '蒲烧鳗鱼', '溏心蛋', '玉米段', '毛豆、紫洋葱、小番茄、海苔丝、香丝配菜', '黄芥末类装饰酱汁'],
    bestTime: '11:00‑15:00室内窗边柔和漫射光，避开直射太阳',
    tips: [
      '手机镜头垂直向下俯拍，镜头尽量和餐盘平面保持平行，防止盘子透视变形',
      '不要使用机顶直闪，直闪会造成食物表面刺眼反光；优先窗边柔光，可使用柔光板弱化硬光斑',
      '摆盘时高低错落，利用酱汁流动线条丰富画面，配菜环形环绕主体鳗鱼',
      '开启vignette压暗画面四角，把视线集中到餐盘食物中心；真机无法实现大光圈虚化，依靠背景本身颜色与纹理拉开层次',
      '台面选择低反光哑光材质，避免镜面反光干扰画面',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '4:5',
    color: PostProcessColor(brightness: 2, contrast: 8, saturation: 14, temperature: 3, tint: 1, highlights: -12, shadows: 7, clarity: 10),
    smoothStrength: 0,
    sharpen: 24,
    vignette: 28,
    grain: 16,
    lut: 'warm_film',
  ),
);
