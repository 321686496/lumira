// lib/features/capture/data/templates/dessert_closeup.dart
import '../../domain/photo_template.dart';

/// 甜点特写模板（美食 / 特写 / 微距）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate dessertCloseupTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'dessert_closeup',
    name: '甜品奶泡特写',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'closeup', subStyle: 'closeup', method: 'macro'),
    tags: ['美食', '甜点', '特写', '诱人', '细节'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/dessert_closeup_1.png'),
      TemplateImage(url: 'assets/images/templates/dessert_closeup_2.png'),
      TemplateImage(url: 'assets/images/templates/dessert_closeup_3.png'),
      TemplateImage(url: 'assets/images/templates/dessert_closeup_4.png'),
    ],
    description: '窗边午后柔光下的甜点静物特写，通透柔和、暖调治愈，适合记录慵懒下午茶时光。',
    referenceSource: '样片参考：Pexels 甜品摄影精选；参数参考美食微距教程',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.24, y: 0.12, w: 0.64, h: 0.78),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '美食静物1:1正方形画幅；45°斜俯机位；甜点主体放置九宫格交叉点位；保留上方大量环境留白；道具边角平衡画面，主体占画幅55‑60%，背景环境占40‑45%。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/120',
    whiteBalance: 'daylight',
    whiteBalanceK: 5600,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光来自屏幕左上方45°窗边漫射日光，柔光；无硬直射阳光；光比约2.5:1；阴影投向屏幕右下方，阴影边缘柔和，浓度中等；物体表面有柔和高光反光，保留食物肌理质感；环境为明亮窗边，整体暖调。',
    shootingDistance: '0.8‑1.2m',
    background: '浅色白墙、窗户、原木桌面，背景尽量简洁，远离杂乱杂物。',
    props: ['浅米色陶瓷圆盘', '木质桌面', '新鲜薄荷叶', '糖粉', '水果小丁', '餐巾纸'],
    bestTime: '14:00‑16:00',
    tips: [
      '使用窗边散射柔光，避免直射硬太阳光，阳光过强可以拉一层薄纱窗帘柔化光线',
      '靠近甜点主体，同时把背景尽量拉远，配合vignette压暗四角模拟浅景深效果；手机无法实现光学大光圈虚化',
      '少量撒糖粉、摆放薄荷叶做边角平衡，道具不要抢夺甜点主体视觉重心',
      '对焦锁定甜点主体奶油、果肉纹理，保证食物细节锐利',
      '避免开启闪光灯，闪光灯会破坏柔和自然光质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 4, contrast: -4, saturation: 10, temperature: 5, tint: 1, highlights: -12, shadows: 8, clarity: 6),
    smoothStrength: 12,
    sharpen: 24,
    vignette: 26,
    grain: 16,
    lut: 'warm_film',
  ),
);
