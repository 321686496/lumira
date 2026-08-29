// lib/features/capture/data/templates/overhead_brunch.dart
import '../../domain/photo_template.dart';

/// 早午餐俯拍模板（美食 / 俯拍 / 俯视）
/// 内置模板补充：美食大类非人像模板
const PhotoTemplate overheadBrunchTemplate = PhotoTemplate(
  meta: TemplateMeta(
    id: 'overhead_brunch',
    name: '早午餐俯拍',
    author: '如画 Lumira',
    version: '1.0.0',
    category: 'food',
    classification: TemplateClassification(type: 'food', style: 'overhead', subStyle: 'overhead', method: 'overhead'),
    tags: ['美食', '早午餐', '俯拍', 'brunch'],
    tagIds: [],
    price: 0,
    images: [
      TemplateImage(url: 'assets/images/templates/overhead_brunch.png'),
    ],
    description: '90 度俯拍的丰盛早午餐，突出咖啡、面包与水果的摆盘构成',
    referenceSource: '样片参考：The Bite Shot 早午餐俯拍；参数参考美食俯拍教程合集',
  ),
  composition: Composition(
    overlayType: 'grid',
    gridType: 'thirds',
    subjectFrame: SubjectFrame(x: 0.25, y: 0.25, w: 0.5, h: 0.5),
    opacity: 0.4,
    aspectRatio: '1:1',
    description: '主餐置于画面中心，咖啡杯与配菜沿对角线摆放，餐具点缀留白区',
  ),
  camera: CameraParams(
    exposureCompensation: 0,
    isoMode: 'auto',
    iso: 400,
    shutterSpeed: '1/80',
    whiteBalance: 'daylight',
    whiteBalanceK: 5200,
    flashMode: 'off',
    focusMode: 'manual',
    lensSuggestion: 'main',
    lensType: 'main',
  ),
  sceneGuide: SceneGuide(
    lightDirection: '正上方柔光（窗边自然光最佳）',
    shootingDistance: '0.5-0.8m（正上方）',
    background: '木质桌面 / 大理石 / 浅色桌布',
    props: ['白陶盘', '咖啡杯', '法棍面包', '新鲜水果', '餐巾'],
    bestTime: '上午（自然光充足的窗边）',
    tips: [
      '手机与桌面保持平行，避免透视畸变',
      '餐点摆盘留出呼吸感，色彩搭配丰富',
      '用一个小道具（花或杂志）点缀角落',
      '侧光与顶光结合表现食物质感',
    ],
  ),
  postProcess: PostProcess(
    cropRatio: '1:1',
    color: PostProcessColor(brightness: 10, contrast: 15, saturation: 18, temperature: 10, tint: 0),
    smoothStrength: 0,
    sharpen: 30,
    vignette: 0,
    grain: 0,
    lut: 'none',
  ),
);
