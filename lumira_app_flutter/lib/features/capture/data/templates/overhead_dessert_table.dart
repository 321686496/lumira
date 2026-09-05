// lib/features/capture/data/templates/overhead_dessert_table.dart
import '../../domain/photo_template.dart';

/// 甜品桌俯拍模板（美食 / 俯拍 / 平拍）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate overheadDessertTableTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'overhead_dessert_table',
    name: '甜品桌俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'overhead', subStyle: 'overhead', method: 'flat'),
    tags: ['美食', '甜品', '俯拍', '蛋糕', '下午茶'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/overhead_dessert_table.jpg'),
    ],
    description: '90 度俯拍的甜品桌，蛋糕、马卡龙与茶具整齐铺陈的仪式感画面',
    referenceSource: '样片参考：美食俯拍甜品桌精选；参数参考甜品摄影布光合集',
  ),
  composition: Composition(
    overlayType: 'rule_of_thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.3, w: 0.5, h: 0.5),
    opacity: 0.42,
    aspectRatio: '1:1',
    description: '主蛋糕置于三分线交点，甜品与茶杯围绕错落摆放，形成对称或不规则节奏',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/70',
    whiteBalance: 'daylight',
    whiteBalanceK: 5300,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正上方柔光（窗边自然光最佳）',
    shootingDistance: '0.5-0.8m（正上方）',
    background: '大理石桌面 / 淡色桌布 / 木托盘',
    props: ['蛋糕', '马卡龙', '茶杯茶壶', '鲜花', '小餐盘'],
    bestTime: '下午茶时段（光线充足氛围好）',
    tips: [
      '按八角形成圆形排列甜品营造围合感',
      '用同系列餐具保持色彩统一',
      '在桌面留少量碎屑或花瓣增加生动感',
      '保持桌面整洁避免杂乱干扰主体',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 10, contrast: 14, saturation: 16, temperature: 12, tint: 4),
    smoothStrength: 0,
    sharpen: 28,
    vignette: 0,
    grain: 0,
    lut: 'warm_film',
  ),
);
