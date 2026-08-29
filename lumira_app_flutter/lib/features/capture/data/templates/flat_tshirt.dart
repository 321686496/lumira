// lib/features/capture/data/templates/flat_tshirt.dart
import '../../domain/photo_template.dart';

/// 扁平衣物陈列模板（静物 / 扁平 / 平拍）
/// 内置模板补充：静物大类非人像模板
const PhotoTemplate flatTshirtTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'flat_tshirt',
    name: '扁平衣物陈列',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'still-life',
    classification: TemplateClassification(type: 'still-life', style: 'flat', subStyle: 'flat', method: 'flat'),
    tags: ['静物', '衣物', '扁平', '陈列'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/flat_tshirt_1.png'),
      TemplateImage(url: 'assets/images/templates/flat_tshirt_2.png'),
      TemplateImage(url: 'assets/images/templates/flat_tshirt_3.png'),
      TemplateImage(url: 'assets/images/templates/flat_tshirt_4.png'),
    ],
    description: '90 度俯拍的衣物扁平陈列，材质纹理与配色在平面上呈现',
    referenceSource: '样片参考：扁平衣物陈列摄影；参数参考服装平铺摆拍合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    gridType: 'grid',
    subjectFrame: SubjectFrame(x: 0.04, y: 0.05, w: 0.92, h: 0.91),
    opacity: 0.3,
    aspectRatio: '1:1',
    description: '俯拍平面，1:1正方形画幅；服装主体居中，主体占画幅85‑92%；少量配饰道具放在画面角落九宫格点位；背景材质露出四周，无前后景纵深，二维平面静物构图。',
  ),
  camera: CameraParams(
    exposureCompensation: 0.3,
    isoMode: 'auto',
    iso: 200,
    shutterSpeed: '1/125',
    whiteBalance: 'daylight',
    whiteBalanceK: 5400,
    flashMode: 'off',
    focusMode: 'auto',
    lensSuggestion: 'main',
    lensType: '主摄镜头',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '主光从屏幕斜上方45°，漫射柔光，无强烈直射硬阴影；光比约2:1；阴影浅淡柔和，阴影投向屏幕斜下方；保留织物面料细微肌理质感；无逆光，不需要正面补光。',
    shootingDistance: '1.2‑1.6m',
    background: '可选用实木地板、白色平面、浅米色卡纸、浅灰色毛毡垫，哑光低反射材质。',
    props: ['帆布小包、皮带、墨镜、书本、陶瓷杯碟、戒指、帆布鞋', '道具少量摆放画面对角角落，不要遮挡服装主体'],
    bestTime: '10:00‑15:00，阴天靠窗柔和自然光，避免阳光直射',
    tips: [
      '相机垂直向下俯拍，保持镜头与平面完全平行，避免透视变形',
      '衣物不要完全拉平，保留自然轻微褶皱，还原面料真实质感',
      '道具放在画面四角九宫格位置，不可遮挡服装主体区域',
      '使用窗边漫射自然光，避开直射阳光，防止生硬深色阴影',
      '想要模拟虚化：尽量相机靠近衣物、背景远离，配合轻暗角vignette压四角；手机无法实现光学浅景深',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 4, contrast: -7, saturation: -8, temperature: 2, highlights: -12, shadows: 8, clarity: 6),
    smoothStrength: 0,
    sharpen: 24,
    vignette: 16,
    grain: 12,
    lut: 'cream',
  ),
);