# Lumira Flutter App 完善 - 设计文档

**日期**：2026-07-29
**项目**：Lumira 如画（Flutter 端，路径 `e:\Project\photo_post\lumira_app_flutter\`）
**目标**：完善 5 个功能/样式缺陷，统一接入现有 8 主题 × 4 UIStyle 设计系统

---

## 1. 改造点概览

| # | 改造点 | 核心改动 |
|---|---|---|
| 1 | 我的奖励/兑换码样式不符 | 重写 UI 层接入 ThemeTokens + NeuCard + LumiraNav + LumiraButton，数据层不动 |
| 2 | 首页 Banner 假数据 + 无跳转 | 新建 RecommendationService + Riverpod provider，5 条 banner，5 种推荐源混合 |
| 3 | 分享码弹窗未主题化 + 图标不清 | 删 AlertDialog，新建 `/profile/share-code` 页面，图标换为 `Icons.card_giftcard_outlined` |
| 4 | Tab 标题栏闪烁 + 布局错位 + SafeArea 不一致 | 修复 LumiraNav sigma 动画 + 统一 Scaffold.appBar + 修复 leading 占位 |
| 5 | 精选集全是 Mock | DB v8 迁移 + is_favorite 列 + collections/collection_photos 表 + 智能派生 + 手动管理 |

---

## 2. 第 1 块：我的奖励 / 兑换码页面样式统一

### 2.1 改动范围
- `lib/features/rewards/pages/rewards_page.dart`（重写 UI）
- `lib/features/redeem/pages/redeem_page.dart`（重写 UI）
- 数据层 `rewards_repository.dart` / `redeem_repository.dart` **不动**

### 2.2 设计要点

**统一接入 5 个共享组件**：
1. `LumiraNav(transparent: true, scrolled: ...)` 替换原生 `AppBar`
2. `Scaffold(extendBodyBehindAppBar: true, backgroundColor: tokens.canvas)` + `GlassBackground` 装饰
3. `NeuCard` 替换 `Card`，按 `appTheme.cardRadius` 自动适配圆角
4. `LumiraButton(variant: LumiraButtonVariant.brand)` 替换 `ElevatedButton`
5. `FadeUp(delay: Duration(milliseconds: i * 80))` 包裹每张卡实现交错入场

### 2.3 奖励页 (`rewards_page.dart`)

- 顶部"奖励总览"卡：累计已领 X 项 / 待领取 Y 项，`tokens.brandSubtle` 圆形背景 + `Icon`
- 每张奖励卡：左侧 tier 徽章（`tokens.brand` 圆形 + 文字），右侧标题 + reward items 列表 + 状态/领取按钮
- 空状态：`NeuCard` + 插图 + "暂无奖励" + 引导文案
- 加载态：`CircularProgressIndicator` 颜色为 `tokens.brand`

### 2.4 兑换码页 (`redeem_page.dart`)

- 顶部"输入兑换码"卡：`NeuCard` 包裹 `TextField`，`InputDecoration` 用 `tokens.canvas / tokens.divider / tokens.brand / tokens.textTertiary`
- 兑换按钮：`LumiraButton.brand` 全宽
- 下方"兑换说明"卡：列出规则（每个兑换码只能用一次 / 兑换后自动入账 / 等等）
- 兑换成功/失败：`SnackBar` 用 `tokens.surface` 背景 + `tokens.textPrimary` 文字

---

## 3. 第 2 块：首页 Banner 推荐算法

### 3.1 改动范围
- 新建 `lib/features/home/services/recommendation_service.dart`
- 新建 `lib/features/home/providers/banner_recommendation_provider.dart`
- 修改 `lib/features/home/widgets/home_banner.dart`（消费 provider）
- 修改 `lib/features/home/pages/home_page.dart`（移除 `HomeMockData.banners` 引用）
- 扩展 `lib/core/db/dao/gallery_dao.dart`（新增 `countByTemplate()` / `countByStyle()` / `getRecent(limit)`）

### 3.2 数据模型

`HomeBannerItem` 保持字段不变（id / title / subtitle / imageSeed / tag / route）。新增枚举：

```dart
enum BannerSource {
  recentCategory,    // 基于最近拍摄分类
  favoriteScene,     // 基于收藏场景/常用套件
  systemPick,        // 系统推荐模板
  newUserGuide,      // 新用户引导（totalPhotos < 3）
  exploration,       // 探索新鲜感（用户少拍的类型）
}
```

### 3.3 推荐算法（5 条 banner，固定槽位）

**槽位 1：新老用户分层**
- 读取 `user_progress.total_photos`
- 若 `< 3`：新用户引导 banner，route → `/capture/scene-guide?scene=preset_cafe`，tag "新手友好"
- 若 `>= 3`：跳过此槽位，由槽位 5 补位

**槽位 2：基于最近拍摄分类**
- `GalleryDao.countByCategory()` 取 top1 分类
- 从 `TemplatesDao.getBuiltin(category: topCategory, isRecommended: true)` 取第一个
- title: "继续拍 {分类标签}" / subtitle: "你最近常拍 {分类}，试试这套模板" / route → `/templates/detail?templateId=xxx`
- tag: "常拍分类"
- 冷启动 fallback：`TemplatesDao.getBuiltin(isRecommended: true)` 第一个

**槽位 3：基于收藏场景/常用套件**
- `ScenesDao.getFavorites()` 取第一个收藏场景
- 若无收藏：fallback 到 `CompositionKitsDao` 按 `usage_count DESC` 取第一个套件关联的场景
- title: "{场景名}灵感" / subtitle: "你收藏的场景，新的拍摄灵感" / route → `/capture/scene-guide?scene=xxx`
- tag: "收藏场景"
- 全空 fallback：系统推荐模板

**槽位 4：系统推荐模板**
- `TemplatesDao.getBuiltin(isRecommended: true)` 取未被槽位 2/3 用过的第一个
- title: "{模板名}" / subtitle: "编辑精选，{模板描述截断}" / route → `/templates/detail?templateId=xxx`
- tag: "编辑精选"

**槽位 5：探索新鲜感（用户少拍的类型）**
- `GalleryDao.countByCategory()` 取计数最少的非零分类（若全零则取 7 分类中第一个未在槽位 2 出现的）
- 从该分类 `TemplatesDao.getBuiltin(category: explorationCategory)` 取第一个
- title: "试试 {分类标签}" / subtitle: "换个风格，发现新视角" / route → `/templates/detail?templateId=xxx`
- tag: "探索新鲜"

### 3.4 推荐服务架构

```dart
class RecommendationService {
  final GalleryDao _galleryDao;
  final ScenesDao _scenesDao;
  final TemplatesDao _templatesDao;
  final CompositionKitsDao _kitsDao;
  final GrowthDao _growthDao;

  Future<List<HomeBannerItem>> buildBanners() async {
    final results = await Future.wait([
      _galleryDao.countByCategory(),
      _scenesDao.getFavorites(),
      _growthDao.getProgress(),
      _kitsDao.getAll(orderByUsage: true, limit: 1),
    ]);
    // 按槽位 1-5 顺序构建，每个槽位有 fallback 链
    // 去重：已用作 banner 的 templateId / sceneId 不再重复出现
    return [...];
  }
}
```

### 3.5 Riverpod Provider

```dart
final bannerRecommendationProvider = FutureProvider<List<HomeBannerItem>>((ref) async {
  final service = RecommendationService(
    galleryDao: await ref.watch(galleryDaoProvider.future),
    scenesDao: await ref.watch(scenesDaoProvider.future),
    templatesDao: await ref.watch(templatesDaoProvider.future),
    kitsDao: await ref.watch(compositionKitsDaoProvider.future),
    growthDao: await ref.watch(growthDaoProvider.future),
  );
  return service.buildBanners();
});
```

### 3.6 跳转规则
- 模板类 banner → `/templates/detail?templateId=xxx`
- 场景类 banner → `/capture/scene-guide?scene=xxx`（遵循项目规则）

### 3.7 home_banner.dart 改造
- 改为 `ConsumerWidget`，`ref.watch(bannerRecommendationProvider)` 取数据
- loading 态：占位 shimmer 卡（`tokens.surfaceAlt`）
- error 态：fallback 到 `HomeMockData.banners` 第 1 条
- data 态：真实推荐数据

### 3.8 缓存策略
- `FutureProvider` 自动缓存，tab 切换不重新计算
- 拍摄完成保存到 gallery 后调 `ref.invalidate(bannerRecommendationProvider)` 让下次进入首页刷新

---

## 4. 第 3 块：分享码入口改为独立页面

### 4.1 改动范围
- 新建 `lib/features/profile/pages/profile_share_code_page.dart`
- 修改 `lib/features/home/pages/home_page.dart`（删除 `_showScanDialog`，更换图标，跳转新页面）
- 修改 `lib/app/router.dart`（注册新路由）
- 修改 `lib/core/router/route_names.dart`（新增路由常量 `profileShareCode = '/profile/share-code'`）

### 4.2 图标更换
- 原 `Icons.qr_code_outlined` → 新 `Icons.card_giftcard_outlined`（礼品卡图标，明确暗示"输入码领奖励"）

### 4.3 页面结构

**顶部标题栏**：`LumiraNav(title: '分享码', transparent: true, scrolled: ..., showBackButton: true)`

**Section 1：输入区**（`NeuCard` 包裹）
- 标题："输入分享码 / 邀请码"
- `TextField`：placeholder `LUMIRA-{category}-{name}`，`InputDecoration` 用 tokens
- 输入框下方"导入"按钮：`LumiraButton.brand` 全宽
- 校验：调用 `template_import_sheet.dart` 中的解析逻辑（提取为可复用函数）

**Section 2：能获得的奖励说明**（`NeuCard` 包裹，列表）
- 标题："输入分享码能获得什么"
- 列表项（每项一行 Icon + 文字）：
  - 解锁对应分类的精选模板（限免 7 天）
  - 获得 50 积分（可兑换其他模板）
  - 解锁场景拍摄指导
  - 优先体验新功能

**Section 3：规则说明**（`NeuCard` 包裹）
- 标题："使用规则"
- 每个分享码只能使用一次
- 分享码有效期 30 天
- 同一分类分享码不能重复使用
- 奖励将在导入后自动入账

**Section 4：最近兑换记录**（可选，若用户有历史）
- 调用现有 `redeem_repository.dart` 的查询接口获取最近 5 条（若无对应方法则跳过此 Section）
- 每条记录显示：码、时间、获得奖励、状态
- 无记录时不显示此 Section

**Section 5：获取更多分享码**（`NeuCard` 包裹）
- 文案："关注官方账号 / 邀请好友 / 完成挑战任务可获得更多分享码"
- 按钮："邀请好友" → 跳 `/profile/invite`

### 4.4 主题化
- 全程 `ref.watch(themeTokensProvider)` + `ref.watch(appThemeProvider)`
- UIStyle 分支：glass 风格用 `GlassBackground` + 半透明卡，neumorphic 用 `NeuCard` 默认，female 用 `multiGradient`
- TextField/InputDecoration/SnackBar 全部按 `profile_invite_page.dart` 的 `_CodeCard` 模式实现

---

## 5. 第 4 块：Tab 标题栏修复

### 5.1 改动范围
- 修改 `lib/shared/widgets/nav/lumira_nav.dart`（核心修复）
- 修改 `lib/features/templates/pages/templates_page.dart`（统一 Scaffold.appBar）
- 修改 `lib/features/challenge/pages/challenge_page.dart`（统一 Scaffold.appBar）
- 修改 `lib/features/profile/pages/profile_page.dart`（启用 scrolled）
- 修改 `lib/features/home/pages/home_page.dart`（清理冗余 SafeArea）

### 5.2 闪烁根因

`lumira_nav.dart` 第 116-118 行 + 第 143-153 行：
```dart
final double blurSigma = isGlass
    ? (widget.scrolled ? 28.0 : 20.0)
    : (widget.scrolled ? 14.0 : 0.0);   // ← 非 glass：0 ↔ 14 瞬变（无动画）
BackdropFilter(filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma), // 瞬变
  child: AnimatedContainer(            // 颜色 400ms 动画
    duration: const Duration(milliseconds: 400),
    ...
  )
)
```

`BackdropFilter` 的 sigma 不可插值，从 0 跳到 14 是瞬间生效，与 400ms 颜色动画不同步 → 视觉撕裂感。

### 5.3 修复方案：动画过渡 sigma

将 `LumiraNav` 改为 `ConsumerStatefulWidget`，内部用 `AnimationController` 控制 sigma：

```dart
class LumiraNav extends ConsumerStatefulWidget { ... }

class _LumiraNavState extends ConsumerState<LumiraNav>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _sigmaAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _sigmaAnimation = Tween<double>(begin: 0.0, end: isGlass ? 28.0 : 14.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(LumiraNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrolled != oldWidget.scrolled) {
      if (widget.scrolled) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sigmaAnimation,
      builder: (context, child) => ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: _sigmaAnimation.value,
            sigmaY: _sigmaAnimation.value,
          ),
          child: child,
        ),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        decoration: BoxDecoration(color: _backgroundColor(), ...),
        child: SafeArea(
          bottom: false,
          child: SizedBox(height: 48, ...),
        ),
      ),
    );
  }
}
```

### 5.4 修复 leading 占位问题

`lumira_nav.dart` 第 110-113 行，当 `showBackButton: false` 且无 `leading` 时，不再用 `SizedBox(width: 40)` 占位，改为 `SizedBox.shrink()`：

```dart
final Widget leadingWidget = widget.leading ??
    (widget.showBackButton && Navigator.of(context).canPop()
        ? _NavBackButton()
        : const SizedBox.shrink());  // ← 改这里
```

效果：tab 页左侧从 68dp 死区降为 24dp（仅 horizontalPadding），与右侧对称。

### 5.5 统一所有 tab 用 Scaffold.appBar

**TemplatesPage**（第 86-103 行）和 **ChallengePage**（第 122-143 行）改造：
- 移除外层 `SafeArea > Column` 包裹 nav 的结构
- 改用 `Scaffold(appBar: LumiraNav(...), extendBodyBehindAppBar: true, body: ...)`
- body 内的 `ListView` 顶部不再需要额外 padding
- 滚动监听保持原样（`_scrollController` + `_scrolled` state）

**ProfilePage** 改造：
- 从 `ConsumerWidget` 改为 `ConsumerStatefulWidget`
- 添加 `ScrollController` + `_scrolled` 状态
- 传 `scrolled: _scrolled` 给 `LumiraNav`

**HomePage** 改造：
- 清理 body 内冗余的 `SafeArea`（第 163 行，因为 appBar 已处理顶部 inset）
- 保留 bottom SafeArea 逻辑

### 5.6 滚动阈值统一
- 所有 tab 页统一为 `_scrollThreshold = 12.0`（home=10/templates=8/challenge=10 → 统一 12）

---

## 6. 第 5 块：精选集功能（DB v8 迁移 + 智能派生 + 手动管理）

### 6.1 改动范围

**数据库迁移**：
- `lib/core/db/database_provider.dart`（版本 7 → 8，新增迁移逻辑）
- `lib/core/db/tables.dart`（新增列常量 + 新表常量）

**新增 DAO**：
- `lib/core/db/dao/gallery_dao.dart`（新增 `is_favorite` 列支持 + `toggleFavorite` / `getFavorites` / `getByCategory` / `getByTemplate`）
- 新建 `lib/core/db/dao/collections_dao.dart`（精选集 + 关联表 CRUD）

**Provider**：
- 新建 `lib/core/db/dao/collections_dao_provider.dart`
- 修改 `lib/features/profile/providers/` 下相关 provider

**UI 改造**：
- 重写 `lib/features/profile/pages/profile_collections_page.dart`（替换 Mock）
- 重写 `lib/features/profile/pages/profile_collection_detail_page.dart`（替换 Mock + 传 collectionId）
- 新建 `lib/features/profile/pages/profile_collection_edit_page.dart`（新建/编辑精选集）
- 新建 `lib/features/profile/widgets/collection_cover_grid.dart`（封面九宫格组件）
- 修改 `lib/features/gallery/pages/gallery_page.dart`（长按菜单增加"加入精选集"）
- 修改 `lib/features/gallery/pages/gallery_detail_page.dart`（添加收藏按钮）

**Service**：
- 新建 `lib/features/profile/services/collection_service.dart`（智能派生 + 手动管理统一入口）

**路由**：
- 修改 `lib/app/router.dart`
- 修改 `lib/core/router/route_names.dart`（新增 `profileCollectionEdit`）

### 6.2 数据库 v8 迁移

```sql
-- gallery_items 新增列
ALTER TABLE gallery_items ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_gallery_items_is_favorite ON gallery_items(is_favorite);

-- 精选集主表
CREATE TABLE collections (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  description TEXT,
  cover_photo_id TEXT,
  type TEXT NOT NULL,           -- 'manual' | 'auto_recent' | 'auto_monthly' | 'auto_scene' | 'auto_category' | 'auto_favorite'
  source_meta TEXT,             -- JSON：auto 类型的派生参数（如 {"sceneId": "xxx"} 或 {"category": "portrait"}）
  photo_count INTEGER NOT NULL DEFAULT 0,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);
CREATE INDEX idx_collections_type ON collections(type);
CREATE INDEX idx_collections_updated_at ON collections(updated_at);

-- 精选集-照片关联表（仅 manual 类型使用；auto 类型动态查询 gallery_items）
CREATE TABLE collection_photos (
  collection_id TEXT NOT NULL,
  photo_id TEXT NOT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  added_at INTEGER NOT NULL,
  PRIMARY KEY (collection_id, photo_id),
  FOREIGN KEY (collection_id) REFERENCES collections(id) ON DELETE CASCADE
);
CREATE INDEX idx_collection_photos_collection ON collection_photos(collection_id);
```

迁移用 `_addColumnIfNotExists` 幂等模式（遵循项目规则）。

### 6.3 数据模型

```dart
enum CollectionType {
  manual,         // 用户手动创建
  autoRecent,     // 最近精选（最新 9 张）
  autoMonthly,    // 月度精选（按月聚合）
  autoScene,      // 场景精选（收藏场景下的照片）
  autoCategory,   // 分类精选（top 分类照片）
  autoFavorite,   // 我的收藏（is_favorite=1 的照片）
}

class CollectionRecord {
  final String id;
  final String name;
  final String? description;
  final String? coverPhotoId;
  final CollectionType type;
  final Map<String, dynamic>? sourceMeta;
  final int photoCount;
  final int createdAt;
  final int updatedAt;
}

class CollectionPhotoRecord {
  final String collectionId;
  final String photoId;
  final int sortOrder;
  final int addedAt;
}
```

### 6.4 CollectionsDao

```dart
class CollectionsDao {
  Future<List<CollectionRecord>> getAll();
  Future<List<CollectionRecord>> getByType(CollectionType type);
  Future<CollectionRecord?> getById(String id);
  Future<String> insert(CollectionRecord record);
  Future<void> update(CollectionRecord record);
  Future<void> delete(String id);

  // 关联表（仅 manual 类型）
  Future<List<String>> getPhotoIds(String collectionId);
  Future<void> addPhoto(String collectionId, String photoId);
  Future<void> removePhoto(String collectionId, String photoId);
  Future<void> reorderPhotos(String collectionId, List<String> photoIds);
  Future<void> clearPhotos(String collectionId);

  // 派生查询（auto 类型用，不写关联表）
  Future<List<GalleryItemRecord>> getPhotosForAutoCollection(CollectionRecord collection, {int limit = 9});
}
```

### 6.5 智能派生精选集（auto 类型）

`CollectionService.syncAutoCollections()` 仅在用户进入精选集页面时调用一次（不在 App 启动时跑，避免拖慢启动）：

1. **autoRecent**：固定 1 个，name="最近精选"，cover = `gallery_items ORDER BY created_at DESC LIMIT 1`，photos = 最新 9 张
2. **autoMonthly**：每月 1 个（仅近 3 个月），name="{YYYY年M月}精选"，cover = 该月最新照片，photos = 该月最新 9 张
3. **autoScene**：每个收藏场景 1 个（`scenes.is_favorite=1`），name="{场景名}精选"，cover = 该场景最新照片，photos = `gallery_items WHERE scene_id=? ORDER BY created_at DESC LIMIT 9`
4. **autoCategory**：top 1 分类 1 个（`GalleryDao.countByCategory()` 取第一），name="{分类标签}精选"，photos = `gallery_items JOIN scenes ON ... WHERE related_category=? LIMIT 9`
5. **autoFavorite**：固定 1 个，name="我的收藏"，photos = `gallery_items WHERE is_favorite=1 ORDER BY created_at DESC LIMIT 9`

派生时**不写 `collection_photos` 表**，详情页通过 `getPhotosForAutoCollection` 动态查询。

`syncAutoCollections` 流程：
- 删除所有 auto 类型的旧记录
- 重新计算并插入新的 auto 记录
- 仅在数据变化时触发（如本月新增照片 >= 1 才更新 monthly）

### 6.6 手动精选集（manual 类型）

**列表页 (`profile_collections_page.dart`)**：
- 顶部统计：累计 X 个精选集 / Y 张照片
- 列表：auto 类型在上（带"自动"标签），manual 类型在下
- 每张卡：封面（cover_photo_id 缩略图或九宫格预览）+ 名称 + 照片数 + 更新时间 + 类型标签
- 点击 → `/profile/collection-detail?collectionId=xxx`
- "+新建"按钮 → `/profile/collection-edit`（无 collectionId 即新建模式）

**编辑页 (`profile_collection_edit_page.dart`)**：
- 顶部 `TextField`：精选集名称
- 描述 `TextField`（可空）
- "选择封面" → 弹出相册选择器（用 gallery_page 的多选模式）
- "添加照片" → 跳转 `/gallery?mode=select&collectionId=xxx` 复用相册多选
- 已添加照片列表（可拖动排序 + 删除）
- 保存按钮：调用 `CollectionsDao.insert/update` + `addPhoto/removePhoto/clearPhotos/reorderPhotos`

**详情页 (`profile_collection_detail_page.dart`)**：
- 接收 `collectionId` 参数
- 顶部：封面 + 名称 + 描述 + 照片数 + 创建时间
- 统计区：照片数 / 创建日 / 平均评分（auto 类型不显示评分）
- 九宫格预览（前 9 张）+ "查看全部"按钮
- 操作按钮：
  - auto 类型：仅"导出九宫格拼图"
  - manual 类型：显示"编辑"+ "导出九宫格拼图"+ "删除精选集"
- 导出九宫格：调用现有 `poster_generator.dart` 的拼图能力

### 6.7 相册页集成

**`gallery_page.dart` 长按菜单**：
- 现有：删除 / 导出
- 新增："加入精选集" → 弹出底部 Sheet 显示所有 manual 类型精选集 + "新建精选集"按钮
- 多选模式下底部操作栏也增加"加入精选集"按钮

**`gallery_detail_page.dart` 收藏按钮**：
- 顶部右上角增加 `IconButton`：`Icons.favorite_border` / `Icons.favorite`（根据 `is_favorite` 切换）
- 点击调用 `GalleryDao.toggleFavorite(id)`
- 收藏后 `ref.invalidate(collectionsAutoFavoriteProvider)` 刷新"我的收藏"

### 6.8 路由

```dart
// route_names.dart
profileCollectionEdit = '/profile/collection-edit';

// router.dart
GoRoute(
  path: RouteNames.profileCollectionEdit,
  builder: (context, state) => ProfileCollectionEditPage(
    collectionId: state.uri.queryParameters[RouteNames.paramCollectionId],
  ),
),
```

### 6.9 测试

- `test/core/db/dao/collections_dao_test.dart`：CRUD + 关联表 + 派生查询
- `test/core/db/database_provider_test.dart`：v8 迁移幂等性
- `test/features/profile/collection_service_test.dart`：syncAutoCollections 5 种类型
- `test/features/profile/profile_collections_page_test.dart`：更新现有测试为真实 DAO

---

## 7. 实施策略

### 7.1 子任务并行度
5 个改造点相对独立，但第 4 块（LumiraNav）改动 shared 组件，其他块依赖它。顺序：

1. **第 4 块先做**（LumiraNav 修复）— 其他块的页面都依赖 LumiraNav
2. **第 1、3 块并行**（都是页面 UI 重写，不互相依赖）
3. **第 2 块**（独立 service + provider，无 UI 依赖）
4. **第 5 块最后做**（涉及 DB 迁移 + 多个页面 + DAO，工作量最大）

### 7.2 验证
- 每个子任务完成后跑 `flutter analyze`
- 全部完成后跑 `flutter test`
- 关键路径手测：8 主题 × 4 UIStyle 切换验证

### 7.3 风险

| 风险 | 缓解 |
|---|---|
| LumiraNav 改 AnimationController 后性能问题 | sigma 上限保持 14，且只在 scrolled 状态切换时动画 |
| DB v8 迁移失败 | 用 `_addColumnIfNotExists` 幂等模式；测试覆盖 |
| 推荐算法冷启动无数据 | 每个槽位都有 fallback 到系统推荐模板 |
| 精选集 syncAutoCollections 性能 | 仅在进入精选集页面时同步，不在 App 启动时跑 |
| Banner 拍摄后未刷新 | 在拍摄完成保存 gallery 后调 `ref.invalidate(bannerRecommendationProvider)` |

---

## 8. 不在本次范围

- 后端 API 对接（rewards/redeem/collections 都是本地优先，无远程同步）
- 精选集分享功能（导出 .cptpl 文件给他人）
- Banner A/B 测试
- 推荐算法个性化权重学习（当前用规则，非 ML）
- 精选集评分系统（仅显示统计，不实现打分 UI）
