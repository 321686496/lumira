# 如画 Lumira Flutter 迁移设计文档

> **创建日期**：2026-07-18  
> **目标**：将 uni-app 项目 `lumira-app/` 的全部功能迁移到 Flutter 工程 `lumira_app_flutter/`，Flutter 作为后续主开发技术栈  
> **目标平台**：iOS / Android / **HarmonyOS**  
> **迁移策略**：方案 A（核心基建优先 + 页面并行迁移）  
> **状态管理**：Riverpod  
> **本地存储**：sqflite

---

## 目录

1. [整体架构与技术栈](#1-整体架构与技术栈)
2. [主题系统迁移](#2-主题系统迁移)
3. [路由与页面结构](#3-路由与页面结构)
4. [拍摄页与相机系统](#4-拍摄页与相机系统)
5. [模板系统与数据持久化](#5-模板系统与数据持久化)
6. [资源迁移与测试策略](#6-资源迁移与测试策略)

---

## 1. 整体架构与技术栈

### 1.1 工程目录结构

```
lumira_app_flutter/
├── lib/
│   ├── main.dart                          # 入口：初始化数据库、主题、路由
│   ├── app/
│   │   ├── app.dart                       # MaterialApp 根 + 主题包装
│   │   ├── router.dart                    # 命名路由表（与 pages.json 1:1 对应）
│   │   └── app_startup.dart               # 启动流程：DB 初始化 → 主题加载 → 路由决策
│   ├── core/
│   │   ├── theme/                         # 主题系统（9 主题 + 4 风格）
│   │   │   ├── app_theme.dart             # ThemeData 生成器
│   │   │   ├── theme_tokens.dart          # 设计 Token（颜色/阴影/圆角）
│   │   │   ├── theme_controller.dart      # Riverpod 主题状态
│   │   │   └── ui_style_controller.dart   # 新拟态/扁平/玻璃/女性美学切换
│   │   ├── router/
│   │   │   ├── route_names.dart           # 路由名常量（与 pages.json 路径对齐）
│   │   │   └── route_observers.dart       # 路由观察者（页面切换埋点/状态清理）
│   │   ├── db/
│   │   │   ├── database_provider.dart     # sqflite 数据库初始化与迁移
│   │   │   └── dao/                       # 数据访问对象（templates_dao/scenes_dao/...）
│   │   └── constants/                     # 全局常量
│   ├── features/                          # 按业务特性分包
│   │   ├── splash/
│   │   ├── home/
│   │   ├── templates/                     # 含 index/detail/editor/drafts/recommend/all/unlock
│   │   ├── capture/                       # 含 index/preview/preview-template/scene-guide/scene-manage/scene-detail
│   │   ├── challenge/                     # 含 index/detail
│   │   ├── gallery/                       # 含 index/detail/diary/monthly-digest
│   │   ├── inspiration/
│   │   ├── profile/                       # 含 index/settings/settings-theme/growth/invite/academy/...
│   │   ├── scenes/
│   │   └── shootkit/
│   ├── shared/                            # 跨特性共享
│   │   ├── widgets/                       # 通用组件（LumiraNav/LumiraButton/NeuCard/FloatingTabBar/...）
│   │   │   ├── nav/lumira_nav.dart
│   │   │   ├── buttons/lumira_buttons.dart
│   │   │   ├── cards/neu_card.dart        # 新拟态卡片（含 4 风格分支渲染）
│   │   │   ├── tabbar/floating_tabbar.dart
│   │   │   └── silhouette/pose_silhouette.dart  # CustomPainter 剪影渲染
│   │   ├── models/                        # PhotoTemplate / SilhouetteResource / Scene / ...
│   │   ├── services/                      # TemplateEngine / CameraService / ImageProcessor
│   │   ├── providers/                     # 跨特性共享 Riverpod Provider
│   │   └── utils/                         # 工具函数
│   └── data/
│       ├── templates/                     # 12 个内置模板的 Dart 数据
│       ├── silhouettes/                   # 内置 SVG 路径数据
│       └── scene_presets.dart             # 场景预设
├── assets/
│   ├── images/                            # 来自 lumira-app/src/static/
│   │   ├── scenes/                        # scene_cafe.jpg 等
│   │   ├── templates/                     # cafe_portrait.jpg 等
│   │   └── logo.png
│   ├── fonts/                             # Phosphor 图标字体（来自 uniapp 项目）
│   └── silhouettes/                       # 如有外部 SVG 资源
├── ohos/                                  # HarmonyOS 工程（已存在）
├── android/                               # Android 工程（已存在）
└── ios/                                   # iOS 工程（已存在）
```

### 1.2 技术栈选型（全部 Harmony 已适配）

| 类别 | 库 | 版本 | Harmony 状态 | 用途 |
|---|---|---|---|---|
| 状态管理 | `flutter_riverpod` | 2.5.x | 纯 Dart，无需适配 | 全局状态/依赖注入 |
| 路由 | `go_router` | 14.6.x | 纯 Dart | 命名路由 + 嵌套导航 |
| 相机 | `camerawesome` | 2.5.0 | 已适配 | 拍摄页取景器 |
| 权限 | `permission_handler` | 12.0.1 | 已适配 | 相机/相册权限 |
| 文件选择 | `file_picker` | 10.3.8 | 已适配 | .pptpl 导入导出 |
| 本地数据库 | `sqflite` | 2.4.2 | 已适配 | 自定义模板/场景/画廊数据 |
| 图像处理 | `gpu_image` + `image` | 1.0.0 + 4.2.x | 已适配 + 纯 Dart | 滤镜/LUT/锐化 |
| 保存相册 | `saver_gallery` | 3.0.6 | 已适配 | 拍摄成品保存 |
| 屏幕常亮 | `wakelock_plus` | 1.4.0 | 已适配 | 拍摄页防息屏 |
| 启动屏 | `flutter_native_splash` | 2.4.7 | 已适配 | splash 页面 |
| 分享 | `share_plus` | 12.0.1 | 已适配 | 成品分享 |
| 设备信息 | `device_info_plus` | 12.3.0 | 已适配 | 设备适配 |
| SVG 剪影 | `CustomPainter`（Flutter 内置） | — | 无需适配 | 剪影绘制（替代 flutter_svg） |
| 字体图标 | Phosphor Icons（字体文件） | — | 无需适配 | 图标（与 uniapp 一致） |

### 1.3 关键架构决策

1. **状态管理分层**：Riverpod 分为 `core/providers`（全局：主题、路由、数据库）和 `features/*/providers`（特性级：当前模板、当前场景）
2. **路由策略**：使用 `go_router` 声明式路由，路由名与 `pages.json` 路径完全对应（如 `/pages/capture/index` → `/capture`），参数通过 `queryParameters` 传递 `templateId` 等
3. **主题系统**：单一 `ThemeController`（Riverpod）持有当前 `themeKey`（暖米白/浓墨/胶片复古/日系清新/温馨粉/马卡龙/莫兰迪/玫瑰金）+ `uiStyleKey`（新拟态/扁平/玻璃/女性美学），通过 `InheritedWidget` 下发，所有组件响应式重建
4. **数据持久化**：sqflite 表结构对应 `custom_templates`（自定义模板）、`scenes`（场景）、`gallery_items`（画廊）、`user_progress`（成就/挑战进度）、`user_settings`（主题/风格偏好），与 uniapp 中 localStorage 数据 1:1 迁移
5. **Harmony 三平台构建**：iOS / Android / HarmonyOS 三端权限声明同步维护（`Info.plist` / `AndroidManifest.xml` / `module.json5`）

---

## 2. 主题系统迁移

### 2.1 主题矩阵

| 主题（Theme） | 画布色 | 品牌色 | 文本色 | 阴影基调 |
|---|---|---|---|---|
| warmWhite（暖米白） | `#FAF7F2` | `#C9A96E` | `#1A1A1A` | 暖灰凸起 |
| ink（浓墨） | `#1C1A17` | `#D4B57A` | `#F2EEE6` | 深黑凸起 |
| retro（胶片复古） | `#F5E6D3` | `#C4956A` | `#3D2817` | 棕调凸起 |
| fresh（日系清新） | `#F8FAF6` | `#8BAD72` | `#4A3F35` | 绿调凸起 |
| cozy（温馨粉） | `#FFF5F5` | `#E8A0A0` | `#4A3A3A` | 粉调凸起 |
| macaron（马卡龙） | `#FFF8F0` | `#A8D8C8` | `#5A4A4A` | 薄荷凸起 |
| morandi（莫兰迪） | `#E8E4E0` | `#8B9DAF` | `#4A4540` | 灰蓝凸起 |
| rosegold（玫瑰金） | `#FAF6F2` | `#C9A0A0` | `#3D2E2A` | 玫瑰凸起 |

### 2.2 UI 风格矩阵

| UI 风格（UIStyle） | 卡片表现 | 阴影策略 | 特殊处理 |
|---|---|---|---|
| neumorphic（新拟态） | 同色背景 + 双阴影凸起 | `shadow-convex` | 默认风格 |
| flat（扁平） | 边框 + 纯色背景 | 无阴影 | `border: 1rpx solid divider` |
| glass（玻璃拟态） | 半透明 + 模糊 | 柔和阴影 | 需背景渐变装饰 |
| female（女性美学） | 半透明 + 大圆角 + 暖光 + **多渐变** | 品牌色弥散阴影 | 呼吸光晕动画 |

### 2.3 架构设计

```dart
// core/theme/theme_tokens.dart
class ThemeTokens {
  final Color canvas;
  final Color canvasRGB;      // 用于 rgba() 透明背景
  final Color surface;
  final Color surfaceAlt;
  final Color canvasDeep;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textInverse;
  final Color divider;
  final Color brand;
  final Color brandDeep;
  final Color brandLight;
  final Color brandSubtle;
  final Color brandText;
  final Color danger;
  final Color dangerSubtle;
  final Color success;
  final Color successSubtle;
  // 阴影
  final List<BoxShadow> shadowConvex;
  final List<BoxShadow> shadowConvexSubtle;
  final List<BoxShadow> shadowConvexBrand;
  final List<BoxShadow> shadowConcave;
  final List<BoxShadow> shadowConcaveSubtle;
  final List<BoxShadow> shadowPressed;
  final List<BoxShadow> shadowFloat;
  // 风格变量
  final double cardRadius;
  final double surfaceAlpha;
  final Border? cardBorder;
}

// core/theme/app_theme.dart
class AppTheme {
  static ThemeData build(ThemeTokens tokens, UIStyle style) {
    // 根据 style 覆盖 cardRadius / surfaceAlpha / cardBorder
    // 生成完整 ThemeData（colorScheme / textTheme / appBarTheme / cardTheme / ...）
  }
}

// core/theme/theme_controller.dart
final themeKeyProvider = StateProvider<ThemeKey>((ref) => ThemeKey.warmWhite);
final uiStyleProvider = StateProvider<UIStyle>((ref) => UIStyle.neumorphic);

final themeTokensProvider = Provider<ThemeTokens>((ref) {
  final theme = ref.watch(themeKeyProvider);
  return ThemeTokens.of(theme);
});

final appThemeProvider = Provider<AppThemeData>((ref) {
  final tokens = ref.watch(themeTokensProvider);
  final style = ref.watch(uiStyleProvider);
  return AppThemeData(tokens: tokens, style: style);
});
```

### 2.4 4 种 UI 风格的差异化渲染

通过 `AppThemeData`（持有 tokens + style）在共享组件内做条件渲染：

```dart
// shared/widgets/cards/neu_card.dart
class NeuCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeData>();
    return Container(
      decoration: BoxDecoration(
        color: theme.tokens.canvas.withAlpha(theme.style.surfaceAlpha),
        borderRadius: BorderRadius.circular(theme.style.cardRadius),
        border: theme.style.cardBorder,
        boxShadow: theme.style.shadowStrategy(theme.tokens),
      ),
      // ...
    );
  }
}
```

### 2.5 玻璃拟态背景装饰

uniapp 中通过 `.lumira-container` 的 `background-image: radial-gradient(...)` 实现。Flutter 迁移为：

```dart
class GlassBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = context.watch<AppThemeData>();
    return Stack(
      children: [
        Container(color: theme.tokens.canvas),
        Positioned(
          top: -50, left: -50,
          child: Container(
            width: 300, height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [theme.tokens.brandSubtle, Colors.transparent],
              ),
            ),
          ),
        ),
        // 其他渐变装饰...
      ],
    );
  }
}
```

### 2.6 女性美学多渐变卡片实现

```dart
// shared/widgets/cards/neu_card.dart - female 风格分支
if (theme.style == UIStyle.female) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(48),
      // 多层渐变叠加
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          theme.tokens.canvas.withAlpha(191), // 75% 透明度
          theme.tokens.surface.withAlpha(140), // 55% 透明度
        ],
      ),
      // 叠加径向渐变作为高光
      boxShadow: [
        BoxShadow(
          color: theme.tokens.brand.withAlpha(38), // 15% 品牌色
          blurRadius: 32,
          offset: Offset(0, 8),
        ),
      ],
      border: Border.all(
        color: Colors.white.withAlpha(77), // 30% 白色边框
        width: 1,
      ),
    ),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: content,
    ),
  );
}
```

**多渐变卡片视觉层次**：
1. **底层**：线性渐变（画布色 75% → 表面色 55%），营造柔和过渡
2. **中层**：径向渐变高光（白色 30% 从左上角弥散），模拟光照
3. **顶层**：毛玻璃模糊（20px），增强层次感
4. **边框**：白色 30% 细边框，增加精致感
5. **阴影**：品牌色 15% 弥散阴影（32px 模糊），营造温暖光晕

### 2.7 女性美学呼吸光晕动画

uniapp 中通过 `@keyframes female-pulse` 实现。Flutter 迁移为 `AnimationController` + `BoxShadow` 动画：

```dart
class FemalePulseAnimation extends StatefulWidget {
  // 使用 AnimationController 循环改变 boxShadow 的 spreadRadius / color
  // 2s ease-in-out 循环
}
```

### 2.8 主题切换持久化

- 当前 `themeKey` 和 `uiStyleKey` 存入 sqflite 的 `user_settings` 表
- 启动时从 DB 读取，默认 `warmWhite + neumorphic`
- 切换时 Riverpod 状态立即更新，UI 全局响应式重建

---

## 3. 路由与页面结构

### 3.1 路由表（与 uniapp pages.json 1:1 对应）

使用 `go_router` 声明式路由，路由名与 uniapp 路径完全对应：

| uniapp 路径 | Flutter 路由名 | 页面组件 | 参数 |
|---|---|---|---|
| `pages/splash/index` | `/splash` | `SplashPage` | — |
| `pages/home/index` | `/home` | `HomePage` | — |
| `pages/templates/index` | `/templates` | `TemplatesPage` | — |
| `pages/challenge/index` | `/challenge` | `ChallengePage` | — |
| `pages/profile/index` | `/profile` | `ProfilePage` | — |
| `pages/capture/index` | `/capture` | `CapturePage` | `templateId?` |
| `pages/capture/preview` | `/capture/preview` | `CapturePreviewPage` | `photoPath` |
| `pages/capture/preview-template` | `/capture/preview-template` | `CapturePreviewTemplatePage` | `templateId` |
| `pages/capture/scene-guide` | `/capture/scene-guide` | `SceneGuidePage` | `scene?` |
| `pages/capture/scene-manage` | `/capture/scene-manage` | `SceneManagePage` | — |
| `pages/capture/scene-detail` | `/capture/scene-detail` | `SceneDetailPage` | `sceneId` |
| `pages/templates/detail` | `/templates/detail` | `TemplateDetailPage` | `templateId` |
| `pages/templates/unlock` | `/templates/unlock` | `TemplateUnlockPage` | `templateId` |
| `pages/templates/editor` | `/templates/editor` | `TemplateEditorPage` | `templateId?` |
| `pages/templates/drafts` | `/templates/drafts` | `TemplateDraftsPage` | — |
| `pages/templates/recommend` | `/templates/recommend` | `TemplateRecommendPage` | — |
| `pages/templates/all` | `/templates/all` | `TemplateAllPage` | — |
| `pages/challenge/detail` | `/challenge/detail` | `ChallengeDetailPage` | `challengeId` |
| `pages/inspiration/index` | `/inspiration` | `InspirationPage` | — |
| `pages/gallery/index` | `/gallery` | `GalleryPage` | — |
| `pages/gallery/detail` | `/gallery/detail` | `GalleryDetailPage` | `itemId` |
| `pages/gallery/diary` | `/gallery/diary` | `GalleryDiaryPage` | — |
| `pages/gallery/monthly-digest` | `/gallery/monthly-digest` | `GalleryMonthlyDigestPage` | `month?` |
| `pages/profile/settings` | `/profile/settings` | `ProfileSettingsPage` | — |
| `pages/profile/settings/theme` | `/profile/settings/theme` | `ProfileSettingsThemePage` | — |
| `pages/profile/growth` | `/profile/growth` | `ProfileGrowthPage` | — |
| `pages/profile/invite` | `/profile/invite` | `ProfileInvitePage` | — |
| `pages/profile/academy` | `/profile/academy` | `ProfileAcademyPage` | — |
| `pages/profile/academy-detail` | `/profile/academy-detail` | `ProfileAcademyDetailPage` | `articleId` |
| `pages/profile/collections` | `/profile/collections` | `ProfileCollectionsPage` | — |
| `pages/profile/collection-detail` | `/profile/collection-detail` | `ProfileCollectionDetailPage` | `collectionId` |
| `pages/profile/my-templates` | `/profile/my-templates` | `ProfileMyTemplatesPage` | — |
| `pages/scenes/index` | `/scenes` | `ScenesPage` | — |
| `pages/shootkit/editor` | `/shootkit/editor` | `ShootkitEditorPage` | `kitId?` |

### 3.2 路由配置代码

```dart
// app/router.dart
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => SplashPage()),
      GoRoute(path: '/home', builder: (_, __) => HomePage()),
      GoRoute(
        path: '/capture',
        builder: (_, state) => CapturePage(
          templateId: state.uri.queryParameters['templateId'],
        ),
      ),
      GoRoute(
        path: '/templates/detail',
        builder: (_, state) => TemplateDetailPage(
          templateId: state.uri.queryParameters['templateId']!,
        ),
      ),
      // ... 其他 30+ 路由
    ],
  );
});
```

### 3.3 页面结构约定

每个页面遵循统一结构：

```dart
// features/capture/pages/capture_page.dart
class CapturePage extends ConsumerWidget {
  final String? templateId;
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. 读取主题
    final theme = ref.watch(appThemeProvider);
    
    // 2. 读取状态（当前模板、相机状态等）
    final currentTemplate = ref.watch(currentTemplateProvider);
    
    // 3. 初始化逻辑（相机、模板加载等）
    ref.listen(captureStateProvider, (_, state) {
      // 响应状态变化
    });
    
    return Scaffold(
      backgroundColor: theme.tokens.canvas,
      body: Stack(
        children: [
          // 相机预览层
          CameraPreviewLayer(),
          // 构图覆盖层
          CompositionOverlayLayer(),
          // 剪影层
          PoseSilhouetteLayer(),
          // 参数面板
          ParamPanel(),
          // 拍摄按钮
          CaptureButton(),
        ],
      ),
    );
  }
}
```

### 3.4 页面间状态保持（优化 uniapp 薄弱点）

uniapp 中通过 URL query 传递 `templateId`，状态易丢失。Flutter 使用 **Riverpod Provider + 路由参数双轨**：

```dart
// shared/providers/template_provider.dart
final currentTemplateProvider = StateProvider<Template?>((ref) => null);

// 页面跳转时
context.go('/capture?templateId=$templateId');
// 同时更新 Provider
ref.read(currentTemplateProvider.notifier).state = template;

// 拍摄页读取
final template = ref.watch(currentTemplateProvider);
// 如果 Provider 为空，从路由参数恢复
if (template == null && templateId != null) {
  ref.read(currentTemplateProvider.notifier).state = 
    ref.read(templateRepositoryProvider).getById(templateId);
}
```

**优势**：
- 页面跳转时状态立即生效（Provider）
- 深链接/冷启动时从路由参数恢复（URL）
- 退出拍摄页时清理状态（`ref.read(currentTemplateProvider.notifier).state = null`）

---

## 4. 拍摄页与相机系统

### 4.1 拍摄页架构

```dart
// features/capture/pages/capture_page.dart
class CapturePage extends ConsumerStatefulWidget {
  final String? templateId;
  
  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(appThemeProvider);
    final isLandscape = ref.watch(orientationProvider);
    
    return Scaffold(
      backgroundColor: theme.tokens.canvas,
      body: Stack(
        children: [
          // 1. 相机预览层（全屏）
          CameraPreviewLayer(),
          
          // 2. 构图覆盖层（半透明）
          CompositionOverlayLayer(),
          
          // 3. 剪影层（可拖动/缩放）
          PoseSilhouetteLayer(),
          
          // 4. 顶部控制栏（横竖屏自适应）
          TopControlBar(),
          
          // 5. 底部参数面板（横竖屏自适应）
          ParamPanel(),
          
          // 6. 拍摄按钮
          CaptureButton(),
        ],
      ),
    );
  }
}
```

### 4.2 相机服务封装

```dart
// shared/services/camera_service.dart
class CameraService {
  CameraAwesomeBuilder? _builder;
  
  Future<void> initialize() async {
    // 请求权限
    final status = await PermissionHandler.camera.request();
    if (status != PermissionStatus.granted) {
      throw CameraPermissionDeniedException();
    }
  }
  
  CameraAwesomeBuilder getBuilder({
    required CameraAspectRatios aspectRatio,
    required FlashMode flashMode,
    required FocusMode focusMode,
  }) {
    return CameraAwesomeBuilder.custom(
      onImageForAnalysis: (img) => _processImage(img),
      imageAnalysisConfig: AnalysisConfig(
        androidOptions: AndroidAnalysisOptions.nv21(
          width: 256,
          height: 256,
        ),
        maxFramesPerSecond: 3,
      ),
      builder: (state, previewSize, previewRect) {
        return CameraPreview(state: state);
      },
      saveConfig: SaveConfig.photo(),
      aspectRatio: aspectRatio,
      flashMode: flashMode,
      sensorOrientation: SensorOrientation.portrait,
    );
  }
  
  Future<void> capture() async {
    // 触发拍摄
  }
  
  Future<void> release() async {
    // 释放资源
  }
}
```

### 4.3 取景器宽高比（修复 uniapp 硬编码 1:1 问题）

uniapp 中 `editor.vue` 的构图预览框硬编码 1:1，导致与模板 `aspectRatio` 不匹配。Flutter 统一使用模板的 `aspectRatio`：

```dart
// shared/widgets/capture/camera_preview_layer.dart
class CameraPreviewLayer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(currentTemplateProvider);
    final aspectRatio = template?.composition.aspectRatio ?? '1:1';
    
    // 解析 aspectRatio（如 "3:4", "16:9", "1:1"）
    final ratio = _parseAspectRatio(aspectRatio);
    
    return AspectRatio(
      aspectRatio: ratio,
      child: CameraPreview(),
    );
  }
  
  double _parseAspectRatio(String ratio) {
    final parts = ratio.split(':');
    if (parts.length != 2) return 1.0;
    final w = double.tryParse(parts[0]) ?? 1;
    final h = double.tryParse(parts[1]) ?? 1;
    return w / h;
  }
}
```

### 4.4 构图覆盖层（CompositionOverlay）

```dart
// shared/widgets/capture/composition_overlay_layer.dart
class CompositionOverlayLayer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final template = ref.watch(currentTemplateProvider);
    final overlayType = template?.composition.overlayType ?? 'none';
    final opacity = template?.composition.opacity ?? 0.3;
    
    return CustomPaint(
      painter: CompositionOverlayPainter(
        type: overlayType,
        opacity: opacity,
        color: Colors.white,
      ),
      child: SizedBox.expand(),
    );
  }
}

class CompositionOverlayPainter extends CustomPainter {
  final String type;
  final double opacity;
  final Color color;
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha((opacity * 255).toInt())
      ..strokeWidth = 2;
    
    switch (type) {
      case 'rule_of_thirds':
        _drawThirds(canvas, size, paint);
        break;
      case 'golden_ratio':
        _drawGoldenRatio(canvas, size, paint);
        break;
      case 'diagonal':
        _drawDiagonal(canvas, size, paint);
        break;
      case 'grid':
        _drawGrid(canvas, size, paint);
        break;
      case 'leading_lines':
        _drawLeadingLines(canvas, size, paint);
        break;
      case 'center':
        _drawCenter(canvas, size, paint);
        break;
    }
  }
  
  void _drawThirds(Canvas canvas, Size size, Paint paint) {
    // 绘制九宫格线
    final thirdW = size.width / 3;
    final thirdH = size.height / 3;
    
    canvas.drawLine(Offset(thirdW, 0), Offset(thirdW, size.height), paint);
    canvas.drawLine(Offset(thirdW * 2, 0), Offset(thirdW * 2, size.height), paint);
    canvas.drawLine(Offset(0, thirdH), Offset(size.width, thirdH), paint);
    canvas.drawLine(Offset(0, thirdH * 2), Offset(size.width, thirdH * 2), paint);
  }
  
  // ... 其他构图类型
}
```

### 4.5 剪影层（PoseSilhouette - CustomPainter）

```dart
// shared/widgets/silhouette/pose_silhouette.dart
class PoseSilhouetteLayer extends ConsumerStatefulWidget {
  @override
  ConsumerState<PoseSilhouetteLayer> createState() => _PoseSilhouetteLayerState();
}

class _PoseSilhouetteLayerState extends ConsumerState<PoseSilhouetteLayer> {
  Offset _position = Offset.zero;
  double _scale = 1.0;
  double _rotation = 0.0;
  
  @override
  Widget build(BuildContext context) {
    final template = ref.watch(currentTemplateProvider);
    final silhouette = template?.pose.silhouette;
    final showSilhouette = ref.watch(showSilhouetteProvider);
    
    if (!showSilhouette || silhouette == null) {
      return SizedBox.shrink();
    }
    
    return GestureDetector(
      onPanUpdate: (details) {
        // 原生拖动事件，无 clientX/clientY 丢失问题
        setState(() {
          _position += details.delta;
        });
      },
      onScaleUpdate: (details) {
        setState(() {
          _scale = details.scale;
          _rotation = details.rotation;
        });
      },
      child: Transform.translate(
        offset: _position,
        child: Transform.scale(
          scale: _scale,
          child: Transform.rotate(
            angle: _rotation,
            child: CustomPaint(
              size: Size(200, 300),
              painter: PoseSilhouettePainter(
                silhouette: silhouette,
                color: Colors.white.withAlpha(217), // 85% 透明度
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PoseSilhouettePainter extends CustomPainter {
  final SilhouetteResource silhouette;
  final Color color;
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    
    switch (silhouette.type) {
      case 'builtin':
        _drawBuiltinSilhouette(canvas, size, paint, silhouette.data);
        break;
      case 'svg':
        _drawInlineSvg(canvas, size, paint, silhouette.data);
        break;
      case 'image':
        _drawImageSilhouette(canvas, size, paint, silhouette.data);
        break;
    }
  }
  
  void _drawBuiltinSilhouette(Canvas canvas, Size size, Paint paint, String key) {
    // 从内置 SVG 路径数据绘制
    final path = BuiltinSilhouettes.getPath(key);
    if (path != null) {
      canvas.drawPath(path, paint);
    }
  }
  
  // ... 其他类型
}
```

### 4.6 横竖屏切换

```dart
// shared/providers/orientation_provider.dart
final orientationProvider = StateProvider<bool>((ref) => false); // false = 竖屏

// features/capture/pages/capture_page.dart
@override
void initState() {
  super.initState();
  // 监听屏幕方向变化
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  SystemChrome.onUserOrientationChanged.listen((orientation) {
    ref.read(orientationProvider.notifier).state = 
      orientation == DeviceOrientation.landscapeLeft || 
      orientation == DeviceOrientation.landscapeRight;
  });
}

@override
void dispose() {
  SystemChrome.setPreferredOrientations([]);
  super.dispose();
}
```

**横竖屏布局差异**：
- **竖屏**：顶部控制栏（72rpx）、底部参数面板（水平滚动）、拍摄按钮居中
- **横屏**：左侧控制栏（56rpx）、右侧参数面板（垂直滚动）、拍摄按钮右侧

### 4.7 模板/剪影显示隐藏切换

```dart
// shared/providers/capture_providers.dart
final showTemplateProvider = StateProvider<bool>((ref) => true);
final showSilhouetteProvider = StateProvider<bool>((ref) => true);

// features/capture/widgets/top_control_bar.dart
class TopControlBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showTemplate = ref.watch(showTemplateProvider);
    final showSilhouette = ref.watch(showSilhouetteProvider);
    
    return Row(
      children: [
        IconButton(
          icon: Icon(showTemplate ? Icons.visibility : Icons.visibility_off),
          onPressed: () {
            ref.read(showTemplateProvider.notifier).state = !showTemplate;
          },
        ),
        IconButton(
          icon: Icon(showSilhouette ? Icons.person : Icons.person_off),
          onPressed: () {
            ref.read(showSilhouetteProvider.notifier).state = !showSilhouette;
          },
        ),
      ],
    );
  }
}
```

### 4.8 拍摄流程

```dart
// features/capture/pages/capture_page.dart
Future<void> _onCapturePressed() async {
  // 1. 停止相机预览
  await ref.read(cameraServiceProvider).pause();
  
  // 2. 拍摄照片
  final photo = await ref.read(cameraServiceProvider).capture();
  
  // 3. 应用后处理（滤镜/锐化/暗角等）
  final processed = await ref.read(imageProcessorProvider).applyPostProcess(
    photo,
    ref.read(currentTemplateProvider)?.postProcess,
  );
  
  // 4. 跳转到预览页
  context.go('/capture/preview?photoPath=${processed.path}');
}
```

### 4.9 拍摄页退出清理

```dart
// features/capture/pages/capture_page.dart
@override
void dispose() {
  // 清理状态
  ref.read(currentTemplateProvider.notifier).state = null;
  ref.read(showTemplateProvider.notifier).state = true;
  ref.read(showSilhouetteProvider.notifier).state = true;
  
  // 释放相机资源
  ref.read(cameraServiceProvider).release();
  
  super.dispose();
}
```

---

## 5. 模板系统与数据持久化

### 5.1 数据模型（与 uniapp types/template.ts 对齐）

```dart
// shared/models/template.dart
enum SilhouetteType { builtin, image, svg }

class SilhouetteResource {
  final SilhouetteType type;
  final String data; // builtin: key; image: base64; svg: inline SVG string
  final String? filename;
  final int? sizeKB;
}

enum TemplateCategory {
  portrait, landscape, food, street, night, macro, stillLife
}

enum OverlayType {
  ruleOfThirds, goldenRatio, diagonal, grid, leadingLines, center, none
}

enum WhiteBalance {
  daylight, cloudy, shade, tungsten, fluorescent, custom
}

enum FlashMode { off, on, auto, torch }

enum FocusMode { auto, manual, continuous }

enum LensSuggestion { wide, main, telephoto, ultraWide }

enum LutPreset {
  none, cinematic, vintage, bw, warmFilm, coolFilm, pastel, fuji
}

class PhotoTemplate {
  final TemplateMeta meta;
  final TemplateComposition composition;
  final TemplatePose pose;
  final TemplateCamera camera;
  final TemplateSceneGuide sceneGuide;
  final TemplatePostProcess postProcess;
}

class TemplateMeta {
  final String id;
  final String name;
  final String author;
  final String version;
  final TemplateCategory category;
  final List<String> tags;
  final double price; // 0 = free
  final String cover; // asset path or base64
  final String description;
  final String referenceSource;
}

class TemplateComposition {
  final OverlayType overlayType;
  final String? gridType;
  final Rect subjectFrame; // x, y, w, h (normalized 0-1)
  final double opacity;
  final String aspectRatio; // "3:4", "16:9", "1:1"
  final String description;
}

class TemplatePose {
  final SilhouetteResource silhouette;
  final Offset position; // normalized 0-1
  final double scale;
  final double rotation;
  final String description;
}

class TemplateCamera {
  final double exposureCompensation;
  final String isoMode; // 'auto' | 'manual'
  final int iso;
  final String shutterSpeed;
  final WhiteBalance whiteBalance;
  final int whiteBalanceK;
  final FlashMode flashMode;
  final FocusMode focusMode;
  final String filterPreset;
  final LensSuggestion lensSuggestion;
}

class TemplateSceneGuide {
  final String lightDirection;
  final String shootingDistance;
  final String background;
  final List<String> props;
  final String bestTime;
  final List<String> tips;
}

class TemplatePostProcess {
  final String cropRatio;
  final ColorAdjustment color;
  final double smoothStrength;
  final double sharpen;
  final double vignette;
  final double grain;
  final LutPreset lut;
}

class ColorAdjustment {
  final double brightness;
  final double contrast;
  final double saturation;
  final double temperature;
  final double tint;
}
```

### 5.2 数据持久化（sqflite）

```dart
// core/db/database_provider.dart
final databaseProvider = Provider<Database>((ref) async {
  final db = await openDatabase(
    path: join(await getDatabasesPath(), 'lumira.db'),
    version: 1,
    onCreate: (db, version) async {
      // 自定义模板表
      await db.execute('''
        CREATE TABLE custom_templates (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          author TEXT,
          version TEXT,
          category TEXT,
          tags TEXT, -- JSON array
          price REAL DEFAULT 0,
          cover TEXT, -- base64 or asset path
          description TEXT,
          reference_source TEXT,
          composition TEXT, -- JSON
          pose TEXT, -- JSON
          camera TEXT, -- JSON
          scene_guide TEXT, -- JSON
          post_process TEXT, -- JSON
          created_at INTEGER,
          updated_at INTEGER
        )
      ''');
      
      // 场景表
      await db.execute('''
        CREATE TABLE scenes (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          image_path TEXT,
          light_direction TEXT,
          shooting_distance TEXT,
          background TEXT,
          props TEXT, -- JSON array
          best_time TEXT,
          tips TEXT, -- JSON array
          is_builtin INTEGER DEFAULT 0,
          created_at INTEGER
        )
      ''');
      
      // 画廊表
      await db.execute('''
        CREATE TABLE gallery_items (
          id TEXT PRIMARY KEY,
          photo_path TEXT NOT NULL,
          template_id TEXT,
          taken_at INTEGER,
          tags TEXT, -- JSON array
          location TEXT,
          notes TEXT
        )
      ''');
      
      // 用户进度表
      await db.execute('''
        CREATE TABLE user_progress (
          id TEXT PRIMARY KEY,
          challenge_id TEXT,
          progress INTEGER DEFAULT 0,
          completed INTEGER DEFAULT 0,
          last_updated INTEGER
        )
      ''');
      
      // 用户设置表
      await db.execute('''
        CREATE TABLE user_settings (
          key TEXT PRIMARY KEY,
          value TEXT
        )
      ''');
    },
  );
  return db;
});
```

### 5.3 模板数据访问对象

```dart
// core/db/dao/templates_dao.dart
class TemplatesDao {
  final Database db;
  
  TemplatesDao(this.db);
  
  Future<List<PhotoTemplate>> getAllCustom() async {
    final maps = await db.query('custom_templates');
    return maps.map(_fromMap).toList();
  }
  
  Future<PhotoTemplate?> getById(String id) async {
    final maps = await db.query(
      'custom_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return _fromMap(maps.first);
  }
  
  Future<void> insert(PhotoTemplate template) async {
    await db.insert(
      'custom_templates',
      _toMap(template),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  Future<void> update(PhotoTemplate template) async {
    await db.update(
      'custom_templates',
      _toMap(template),
      where: 'id = ?',
      whereArgs: [template.meta.id],
    );
  }
  
  Future<void> delete(String id) async {
    await db.delete(
      'custom_templates',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  PhotoTemplate _fromMap(Map<String, dynamic> map) {
    return PhotoTemplate(
      meta: TemplateMeta(
        id: map['id'],
        name: map['name'],
        author: map['author'],
        version: map['version'],
        category: TemplateCategory.values.byName(map['category']),
        tags: (jsonDecode(map['tags']) as List).cast<String>(),
        price: map['price'],
        cover: map['cover'],
        description: map['description'],
        referenceSource: map['reference_source'],
      ),
      composition: _parseComposition(map['composition']),
      pose: _parsePose(map['pose']),
      camera: _parseCamera(map['camera']),
      sceneGuide: _parseSceneGuide(map['scene_guide']),
      postProcess: _parsePostProcess(map['post_process']),
    );
  }
  
  Map<String, dynamic> _toMap(PhotoTemplate template) {
    return {
      'id': template.meta.id,
      'name': template.meta.name,
      'author': template.meta.author,
      'version': template.meta.version,
      'category': template.meta.category.name,
      'tags': jsonEncode(template.meta.tags),
      'price': template.meta.price,
      'cover': template.meta.cover,
      'description': template.meta.description,
      'reference_source': template.meta.referenceSource,
      'composition': jsonEncode(_compositionToMap(template.composition)),
      'pose': jsonEncode(_poseToMap(template.pose)),
      'camera': jsonEncode(_cameraToMap(template.camera)),
      'scene_guide': jsonEncode(_sceneGuideToMap(template.sceneGuide)),
      'post_process': jsonEncode(_postProcessToMap(template.postProcess)),
    };
  }
  
  // ... 解析/序列化辅助方法
}
```

### 5.4 内置模板数据迁移

```dart
// data/templates/template_registry.dart
class TemplateRegistry {
  static final List<PhotoTemplate> builtinTemplates = [
    CafePortraitTemplate.data,
    FilmVintageTemplate.data,
    FoodFlatLayTemplate.data,
    GoldenLandscapeTemplate.data,
    IndoorStillLifeTemplate.data,
    MacroFlowerTemplate.data,
    NeonPortraitTemplate.data,
    NightCityscapeTemplate.data,
    SoftPortraitTemplate.data,
    StreetBwTemplate.data,
    SunsetSilhouetteTemplate.data,
    UrbanArchitectureTemplate.data,
  ];
  
  static PhotoTemplate? getById(String id) {
    try {
      return builtinTemplates.firstWhere((t) => t.meta.id == id);
    } catch (_) {
      return null;
    }
  }
  
  static List<PhotoTemplate> getByCategory(TemplateCategory category) {
    return builtinTemplates.where((t) => t.meta.category == category).toList();
  }
  
  static List<PhotoTemplate> get freeTemplates => 
    builtinTemplates.where((t) => t.meta.price == 0).toList();
  
  static List<PhotoTemplate> get paidTemplates => 
    builtinTemplates.where((t) => t.meta.price > 0).toList();
}
```

### 5.5 .pptpl 导入导出

```dart
// shared/services/template_engine_service.dart
class TemplateEngineService {
  Future<String> exportTemplate(PhotoTemplate template) async {
    // 1. 序列化为 JSON
    final json = _serialize(template);
    
    // 2. 处理资源：
    //    - builtin 剪影：仅存 key
    //    - image 剪影：转为 base64 data URL
    //    - svg 剪影：存完整 SVG 字符串
    //    - cover：如果是 asset path，读取并转 base64
    
    // 3. 写入 .pptpl 文件
    final dir = await getApplicationDocumentsDirectory();
    final file = File(join(dir.path, '${template.meta.id}.pptpl'));
    await file.writeAsString(jsonEncode(json));
    
    return file.path;
  }
  
  Future<PhotoTemplate> importTemplate(String filePath) async {
    // 1. 读取 .pptpl 文件
    final file = File(filePath);
    final jsonStr = await file.readAsString();
    final json = jsonDecode(jsonStr);
    
    // 2. 反序列化
    final template = _deserialize(json);
    
    // 3. 校验内置剪影是否存在
    if (template.pose.silhouette.type == SilhouetteType.builtin) {
      if (!BuiltinSilhouettes.exists(template.pose.silhouette.data)) {
        // 降级为 none
        template.pose.silhouette = SilhouetteResource(
          type: SilhouetteType.builtin,
          data: 'none',
        );
      }
    }
    
    // 4. ID 冲突处理
    final existing = await _checkIdConflict(template.meta.id);
    if (existing) {
      template.meta.id = '${template.meta.id}_imported_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    return template;
  }
  
  Map<String, dynamic> _serialize(PhotoTemplate template) {
    // 完整序列化逻辑
  }
  
  PhotoTemplate _deserialize(Map<String, dynamic> json) {
    // 完整反序列化逻辑
  }
}
```

### 5.6 剪影系统

```dart
// data/silhouettes/builtin_silhouettes.dart
class BuiltinSilhouettes {
  static const Map<String, String> _silhouettePaths = {
    'standing-profile': '''
      M 50 10 C 45 10 42 13 42 18 C 42 23 45 26 50 26 C 55 26 58 23 58 18 C 58 13 55 10 50 10 Z
      M 50 30 L 45 50 L 40 80 L 45 80 L 50 60 L 55 80 L 60 80 L 55 50 Z
    ''',
    'sitting': '...',
    'walking': '...',
    // ... 其他内置剪影
  };
  
  static bool exists(String key) => _silhouettePaths.containsKey(key);
  
  static Path? getPath(String key) {
    final svgPath = _silhouettePaths[key];
    if (svgPath == null) return null;
    return _parseSvgPath(svgPath);
  }
  
  static Path _parseSvgPath(String svgPath) {
    // 解析 SVG path data 为 Flutter Path
    // 使用 flutter_svg 的 path_parsing 或自定义解析器
  }
}

// shared/models/silhouette_resource.dart
// 已在 5.1 定义

// features/templates/widgets/silhouette_editor.dart
class SilhouetteEditor extends StatefulWidget {
  // SVG 绘制编辑器
  // 支持：
  // - 内置库选择
  // - 图片导入（转 base64）
  // - SVG 绘制（自定义路径）
}
```

### 5.7 模板状态管理

```dart
// shared/providers/template_providers.dart
final templatesRepositoryProvider = Provider<TemplatesRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return TemplatesRepository(db);
});

final allTemplatesProvider = FutureProvider<List<PhotoTemplate>>((ref) async {
  final repo = ref.watch(templatesRepositoryProvider);
  final custom = await repo.getAllCustom();
  return [...TemplateRegistry.builtinTemplates, ...custom];
});

final currentTemplateProvider = StateProvider<PhotoTemplate?>((ref) => null);

final templateByCategoryProvider = Provider.family<List<PhotoTemplate>, TemplateCategory>((ref, category) {
  final all = ref.watch(allTemplatesProvider).valueOrNull ?? [];
  return all.where((t) => t.meta.category == category).toList();
});
```

### 5.8 数据迁移策略

uniapp 使用 localStorage，Flutter 使用 sqflite。首次启动时：

```dart
// app/app_startup.dart
Future<void> _migrateFromUniapp(Database db) async {
  // 检查是否需要迁移
  final settings = await db.query('user_settings', where: 'key = ?', whereArgs: ['migrated_from_uniapp']);
  if (settings.isNotEmpty) return;
  
  // 1. 读取 uniapp localStorage 数据（如果存在）
  //    uniapp localStorage 存储在 WebView 中，需要通过 JS 桥接读取
  //    或者用户手动导出 .pptpl 文件后导入
  
  // 2. 标记迁移完成
  await db.insert('user_settings', {
    'key': 'migrated_from_uniapp',
    'value': 'true',
  });
}
```

**实际策略**：
- 内置模板：直接在 Flutter 代码中定义（12 个模板数据文件）
- 自定义模板：用户通过 `.pptpl` 导入功能从 uniapp 导出后导入
- 场景/画廊：用户重新创建或手动迁移

---

## 6. 资源迁移与测试策略

### 6.1 静态资源迁移清单

| 资源类型 | uniapp 来源 | Flutter 目标 | 迁移方式 |
|---|---|---|---|
| 模板封面图（12 张） | `lumira-app/src/static/templates/*.jpg` | `assets/images/templates/` | 直接复制 |
| 场景图（4 张） | `lumira-app/src/static/scenes/*.jpg` | `assets/images/scenes/` | 直接复制 |
| Logo | `lumira-app/src/static/logo.png` | `assets/images/logo.png` | 直接复制 |
| Phosphor 图标字体 | `lumira-app/unpackage/.../assets/Phosphor-*.ttf` | `assets/fonts/` | 复制 + pubspec 注册 |
| 内置剪影 SVG | `lumira-app/src/data/silhouettes/index.ts` | `lib/data/silhouettes/` | 手动转写为 Dart Path 数据 |
| 品牌 SVG 资产 | `assets/logos/lumira/*.svg` | `assets/brand/` | 直接复制 |

### 6.2 pubspec.yaml 资源配置

```yaml
flutter:
  assets:
    - assets/images/
    - assets/images/templates/
    - assets/images/scenes/
    - assets/brand/
  fonts:
    - family: Phosphor
      fonts:
        - asset: assets/fonts/Phosphor-Bold.ttf
        - asset: assets/fonts/Phosphor-Fill.ttf
    - family: NotoSerifSC
      fonts:
        - asset: assets/fonts/NotoSerifSC-Regular.otf
        - asset: assets/fonts/NotoSerifSC-Bold.otf
          weight: 700
    - family: NotoSansSC
      fonts:
        - asset: assets/fonts/NotoSansSC-Regular.otf
        - asset: assets/fonts/NotoSansSC-Medium.otf
          weight: 500
```

### 6.3 图标字体组件

```dart
// shared/widgets/icons/lumira_icon.dart
class LumiraIcon extends StatelessWidget {
  final String codePoint;
  final double size;
  final Color? color;
  final bool filled;
  
  const LumiraIcon({
    required this.codePoint,
    this.size = 24,
    this.color,
    this.filled = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Icon(
      IconData(
        int.parse(codePoint, radix: 16),
        fontFamily: filled ? 'Phosphor-Fill' : 'Phosphor',
        fontPackage: null,
      ),
      size: size,
      color: color,
    );
  }
}

// 预定义常用图标常量
class LumiraIcons {
  static const camera = 'e14a';
  static const home = 'e274';
  static const grid = 'e26c';
  static const user = 'e470';
  static const heart = 'e2a4';
  static const star = 'e3d8';
  static const settings = 'e3b8';
  // ... 与 uniapp 使用的 Phosphor 图标一一对应
}
```

### 6.4 Harmony 权限声明同步

```json5
// ohos/entry/src/main/module.json5
{
  "module": {
    "requestPermissions": [
      {
        "name": "ohos.permission.CAMERA",
        "reason": "$string:camera_permission_reason",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
      },
      {
        "name": "ohos.permission.READ_IMAGEVIDEO",
        "reason": "$string:gallery_permission_reason",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
      },
      {
        "name": "ohos.permission.WRITE_IMAGEVIDEO",
        "reason": "$string:gallery_permission_reason",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
      },
      {
        "name": "ohos.permission.KEEP_BACKGROUND_RUNNING",
        "reason": "$string:background_running_reason",
        "usedScene": { "abilities": ["EntryAbility"], "when": "inuse" }
      }
    ]
  }
}
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

```xml
<!-- ios/Runner/Info.plist -->
<key>NSCameraUsageDescription</key>
<string>如画需要使用相机拍摄照片</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>如画需要访问相册保存照片</string>
```

### 6.5 测试策略

#### 6.5.1 单元测试（核心 Service / Provider）

| 测试目标 | 文件 | 覆盖内容 |
|---|---|---|
| `TemplateEngineService` | `test/services/template_engine_test.dart` | 序列化/反序列化、导入导出、ID 冲突处理、剪影降级 |
| `TemplatesRepository` | `test/db/templates_dao_test.dart` | CRUD、分类查询、价格过滤 |
| `ThemeController` | `test/theme/theme_controller_test.dart` | 9 主题 × 4 风格组合、Token 生成正确性 |
| `ImageProcessor` | `test/services/image_processor_test.dart` | 滤镜应用、LUT 映射、锐化/暗角/颗粒 |
| `SilhouetteResource` | `test/models/silhouette_test.dart` | 类型判断、builtin 校验、降级逻辑 |

#### 6.5.2 Widget 测试（关键组件）

| 测试目标 | 文件 | 覆盖内容 |
|---|---|---|
| `NeuCard` | `test/widgets/neu_card_test.dart` | 4 种 UI 风格渲染差异 |
| `LumiraNav` | `test/widgets/lumira_nav_test.dart` | 标题居中、返回按钮、毛玻璃滚动效果 |
| `FloatingTabBar` | `test/widgets/floating_tabbar_test.dart` | 5 个 Tab 切换、中心拍摄按钮 |
| `CompositionOverlay` | `test/widgets/composition_overlay_test.dart` | 7 种构图线绘制 |
| `PoseSilhouette` | `test/widgets/pose_silhouette_test.dart` | 拖动/缩放/旋转、3 种剪影类型 |
| `CapturePage` | `test/pages/capture_page_test.dart` | 横竖屏切换、模板/剪影显隐 |

#### 6.5.3 集成测试（关键流程）

| 测试场景 | 文件 | 覆盖内容 |
|---|---|---|
| 完整拍摄流程 | `integration_test/capture_flow_test.dart` | 选模板 → 拍摄 → 预览 → 保存 |
| 主题切换 | `integration_test/theme_switch_test.dart` | 9 主题 × 4 风格全局切换无异常 |
| 模板导入导出 | `integration_test/template_io_test.dart` | 导出 .pptpl → 删除 → 导入 → 验证 |
| 路由导航 | `integration_test/routing_test.dart` | 30+ 页面跳转、参数传递、返回清理 |

### 6.6 三平台构建验证流程

```
┌─────────────────────────────────────────────────────────┐
│                  三平台构建验证流程                        │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  1. flutter analyze          ← 静态分析（零 warning）     │
│  2. flutter test             ← 单元测试 + Widget 测试     │
│  3. flutter build apk        ← Android 构建验证           │
│  4. flutter build ios        ← iOS 构建验证               │
│  5. flutter build hap        ← Harmony 构建验证           │
│  6. flutter run -d harmony   ← Harmony 模拟器运行验证     │
│  7. flutter run -d android   ← Android 真机/模拟器验证    │
│  8. flutter run -d ios       ← iOS 真机/模拟器验证        │
│                                                           │
│  每个平台验证：                                            │
│  - [ ] 启动无崩溃                                          │
│  - [ ] 主题切换正常（9 × 4 = 36 组合）                     │
│  - [ ] 拍摄页相机预览正常                                  │
│  - [ ] 模板/剪影显隐切换正常                               │
│  - [ ] 路由跳转无异常                                      │
│  - [ ] 数据持久化正常                                      │
└─────────────────────────────────────────────────────────┘
```

### 6.7 视觉一致性验证方法

| 验证项 | 方法 | 通过标准 |
|---|---|---|
| 颜色一致性 | 截图对比（Flutter vs uniapp） | ΔE < 3（人眼不可分辨） |
| 布局一致性 | 像素级对比（关键页面） | 布局结构一致，允许微调 |
| 动画一致性 | 录屏对比 | 动画曲线/时长/效果一致 |
| 交互一致性 | 操作流对比 | 点击/拖动/缩放行为一致 |
| 字体一致性 | 字号/字重/行高对比 | 与 uniapp 视觉一致 |

### 6.8 实施顺序（基建 → 页面）

```
阶段 1：基建（预计 5 个子任务）
  1.1 pubspec.yaml 依赖配置 + 资源迁移
  1.2 主题系统（9 主题 + 4 风格 + InheritedWidget）
  1.3 路由系统（go_router + 30+ 路由声明）
  1.4 数据库（sqflite 初始化 + DAO）
  1.5 共享组件（LumiraNav / NeuCard / LumiraButton / FloatingTabBar）

阶段 2：页面迁移（按业务模块）
  2.1 Splash + Home + TabBar
  2.2 Templates 模块（index / detail / all / recommend / unlock / editor / drafts）
  2.3 Capture 模块（index / preview / preview-template / scene-guide / scene-manage / scene-detail）
  2.4 Challenge 模块（index / detail）
  2.5 Gallery 模块（index / detail / diary / monthly-digest）
  2.6 Inspiration 模块
  2.7 Profile 模块（index / settings / theme / growth / invite / academy / academy-detail / collections / collection-detail / my-templates）
  2.8 Scenes 模块
  2.9 Shootkit 模块

阶段 3：集成与测试
  3.1 模板导入导出（.pptpl）
  3.2 图像处理管线（滤镜/LUT/锐化）
  3.3 三平台构建验证
  3.4 视觉一致性对比
```

---

## 附录 A：Harmony 适配参考资源

| 资源 | 地址 | 用途 |
|---|---|---|
| Harmony 版 Flutter 引擎 | https://gitcode.com/CPF-Flutter/flutter_flutter | 华为 HarmonyOS 适配的 Flutter SDK 主仓 |
| Harmony 版 Flutter 引擎（分支） | https://gitcode.com/CPF-Flutter/flutter_flutter/tree/br_3.7.12-ohos-1.1.3 | 当前项目使用的 Harmony 适配分支 |
| 三方库适配清单 | https://gitcode.com/CPF-Flutter/docs/blob/main/ThirdpartyLibrarites.md | 已适配 Harmony 的三方库查询清单 |
| CPF-Flutter 文档总仓 | https://gitcode.com/CPF-Flutter/docs | Harmony 版 Flutter 适配文档总入口 |

## 附录 B：已确认的 Harmony 适配三方库

| 库名 | Harmony 适配版本 | 用途 |
|---|---|---|
| `camerawesome` | 2.5.0 | 相机功能 |
| `permission_handler` | 12.0.1 | 权限管理 |
| `file_picker` | 10.3.8 | 文件选择 |
| `sqflite` | 2.4.2 | 本地数据库 |
| `saver_gallery` | 3.0.6 | 保存相册 |
| `wakelock_plus` | 1.4.0 | 屏幕唤醒 |
| `flutter_native_splash` | 2.4.7 | 启动页 |
| `share_plus` | 12.0.1 | 分享功能 |
| `device_info_plus` | 12.3.0 | 设备信息 |
| `gpu_image` | 1.0.0 | 图像处理 |

---

> **文档状态**：设计完成，待用户审阅后进入实施计划阶段。
