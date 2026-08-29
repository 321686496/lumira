// lib/features/capture/data/templates/indoor_still_life.dart
import '../../domain/photo_template.dart';

/// 室内静物模板
/// 来源：lumira-app/src/data/templates/indoor-still-life.ts
const PhotoTemplate indoorStillLifeTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'indoor_still_life',
    name: '室内极简静物',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'minimal', subStyle: 'minimal', method: 'single'),
    tags: ['静物', '室内', '柔光', '生活美学'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/indoor_still_life_1.png'),
      TemplateImage(url: 'assets/images/templates/indoor_still_life_2.jpg'),
    ],
    description: '暖调大面积留白的极简静物，午后侧光勾勒器皿与亚麻布的纹理，宁静治愈。',
    referenceSource: '样片 EXIF: Pexels 静物摄影作品；参数参考静物摄影教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds_grid',
    subjectFrame: SubjectFrame(x: 0.15, y: 0.55, w: 0.7, h: 0.4),
    opacity: 0.3,
    aspectRatio: '3:4',
    description: '竖构图3:4。图一强调“点与面”的极致对比，主体极小且偏置，留白极大；图二强调“线与影”的交织，利用桌面水平线、干花引导线与墙面斜光影构建几何美感。主体均避开绝对中心，依托三分法布局。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/200',
    whiteBalance: 'custom',
    whiteBalanceK: 5800,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '图一：主光为大面积柔和漫射光（如北向窗光或柔光箱），从屏幕正前方偏上均匀照亮，光比极低(约1.5:1)，阴影极淡几乎不可见，无需补光。图二：主光为午后硬侧光，从屏幕左侧约30°-45°射入（模拟窗户光），光质偏硬，光比大(约4:1)，在物体右侧及桌面投下清晰长影，边缘锐利；左侧墙面有窗框斜影。无需正面补光，保留暗部质感。',
    shootingDistance: '0.8-1.5m',
    background: '图一：纯色暖杏色/浅驼色哑光乳胶漆墙面，无纹理。图二：浅灰白色哑光墙面，允许有自然光影投射。',
    props: ['浅色原木桌（图一）', '深色胡桃木桌（图二）', '极简白色细颈陶瓷小花瓶', '白色小雏菊/满天星3-5枝', '米白色粗陶马克杯', '原色亚麻餐巾', '球形干花/兔尾草3-4枝', '浅色粗陶小圆碟'],
    bestTime: '14:00-16:00（图二需此时段侧光）；全天散射光时段（图一）',
    tips: [
      '图一核心是“克制”：花瓶一定要小，位置一定要偏右下，墙面必须干净无插座/开关，留白不够可后期裁剪扩展。',
      '图二核心是“光影”：务必在晴日下午拍摄，让阳光从侧面打入。若光线太硬，可在窗外加一层薄纱帘柔化边缘；若阴影太黑死，可在屏幕右侧放一块白色泡沫板微弱反光，但切勿破坏整体明暗对比。',
      '干花摆放要随意自然，不要排列整齐，营造“不经意掉落”的松弛感。',
      '亚麻布不要熨烫得太平整，保留自然褶皱更有生活气息与肌理感。',
      '真机无法实现大光圈物理虚化，请尽量让背景墙面远离桌面（至少1米以上），并在后期适当提高smoothStrength模拟空气感。',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '3:4',
    color: PostProcessColor(brightness: 6, contrast: 4, saturation: -8, temperature: 8, tint: 3, highlights: -12, shadows: 15, clarity: 8),
    smoothStrength: 15,
    sharpen: 25,
    vignette: 12,
    grain: 12,
    lut: 'cream',
  ),
);
