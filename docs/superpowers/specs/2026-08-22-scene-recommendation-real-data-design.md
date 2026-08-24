# 场景推荐真实数据化优化设计

日期：2026-08-22
模块：Flutter `lumira_app_flutter`（仅客户端，不涉及后端）
状态：已确认

## 背景与问题

目前首页「场景推荐」、以及从首页跳转到的场景管理页 / 场景详情页，存在多处使用 mock 数据或依赖占位图的情况：

1. **首页场景推荐**：数据链路本已接 `SceneRecommendationService`（本地 `scenes` 表自定义场景 + 内置预设 + `gallery_items` 照片数），但当服务返回空/异常时，[home_providers.dart](file:///e:/Project/photo_post/lumira_app_flutter/lib/features/home/data/home_providers.dart) 会静默回退到写死的 `HomeMockData.scenes`；且卡片封面一律用 picsum 占位，未使用场景真实封面。
2. **首页「收藏 / 管理」入口**：「收藏」跳 `captureSceneManage?tab=fav`，「管理」跳 `captureSceneManage`（无 tab 时默认也是 fav），两者实际落到同一个「我的收藏」tab，语义重复。
3. **场景详情页**：主字段由 `CaptureSceneMockData.getSceneById` 提供（mock），仅收藏标记来自真实 `SceneRecord`；成就/周榜为 mock；未展示「该场景下拍摄的照片」（照片其实已通过 `gallery_items.scene_id` 关联，`GalleryDao.getByScene` 可直接查询）。

## 目标

1. 首页场景推荐展示真实场景数据与真实封面（自定义封面 / 预设示例图），缺省统一占位图，不再以写死 mock 兜底。
2. 首页「收藏」「管理」入口语义分离，分别落在管理页「我的收藏」与「自定义场景」tab。
3. 场景详情页以真实数据为主，去掉 mock 主数据源；展示该场景下拍摄的真实照片，可点开全屏查看。
4. 场景详情「我的成就」只展示真实照片数与等级，删除 mock 周榜。

## 设计内容

### 1. 首页场景推荐真实数据 + 真实封面

**数据模型扩展**
- `home_mock_data.dart` 的 `SceneReco` 新增字段 `coverUrl`（`String`，默认空串）。`imageSeed` 语义降级为「无真实封面的回退线索」，`SceneRecoCard` 不再依赖 picsum。
- `SceneRecommendationService` 内部 `_SceneInfo` 新增 `coverUrl`：
  - 自定义场景：取 `SceneRecord.coverUrl`；
  - 预设/系统场景：取 `ScenePreset.exampleImages` 首图（若有）。
- `_toReco()` 将 `coverUrl` 写入 `SceneReco`。

**卡片封面渲染**
- `SceneRecoCard._buildCoverImage()`：
  1. `coverUrl` 以 `data:image/` 开头 → `Image.memory`；
  2. `coverUrl` 为 http/本地路径 → `CachedNetworkImage`；
  3. 均无 → **统一主题化占位图**（`tokens.surfaceAlt` 底 + 图标），移除 picsum。

**Provider 兜底调整**
- `homeSceneRecosProvider`：不再回退 `HomeMockData.scenes`；服务返回空/N 条时展示空态（内置预设恒存在，正常不触发）。若返回条数 < 网格需要的数量，展示实际数量即可，不强凑 4 个。

### 2. 首页「收藏 / 管理」入口

- `home_page.dart` 场景推荐标题链接：
  -「收藏」→ `captureSceneManage?tab=fav`（不变）；
  -「管理」→ `captureSceneManage?tab=custom`（新增）。
- `capture_scene_manage_page.dart` 的 `_parseTab` 已支持 `custom`，无需改动跳转目标逻辑；仅需首页传入 `tab=custom`。

### 3. 场景详情页真实数据 + 该场景照片

**数据加载真实化（`capture_scene_detail_page.dart`）**
- 用 `scenesDao.getById` 拿到真实 `SceneRecord` 后：
  - `creator == 'user'` → `sceneRecordToCustom(record)`；
  - 其它 → `sceneRecordToPreset(record)`。
- 仅当 DB 无该场景时，回退 `ScenePresetsData.getScenePreset(id)`（真实预设）。
- 移除以 `CaptureSceneMockData.getSceneById` 作为主数据源；`CaptureSceneMockData` 仅保留 icon 字符串映射、标签名称解析等常量工具。

**新增「此场景拍摄」区块**
- 数据：`galleryDao.getByScene(sceneId)`。
- 位置：成就区上方（滤镜/贴士之前）。
- 交互：横向缩略图（真实照片源，复用现有图片渲染），点击用 `FullscreenImageGallery` 全屏查看；无照片时显示引导拍摄空态（可跳「用此场景拍照」）。

**成就区真实化（`_AchievementSection`）**
- 照片数 = `galleryDao.getByScene(id).length`（真实），据此构造 `SceneAchievement`（沿用现有等级阈值逻辑：0/1-2/3-9/10+）。
- 删除 mock `weeklyRanking` 周榜；`SceneAchievementCard` 不传 `rank`（组件已支持 rank 为空则不渲染榜单）。

### 数据流汇总

```
首页场景推荐
  homeSceneRecosProvider
    → SceneRecommendationService
        → ScenesDao.getAll() + ScenePresetsData.allScenePresets
        → GalleryDao.countByScene(id)
    → 真实 SceneReco(含 coverUrl) → SceneRecoCard(真实封面/统一占位)

场景详情
  CaptureSceneDetailPage
    → ScenesDao.getById(id) → sceneRecordToCustom/Preset（真实）
    → GalleryDao.getByScene(id) → 「此场景拍摄」+ 成就照片数
    → FullscreenImageGallery（全屏查看）
```

## 影响面与边界

- 仅改 Flutter 端；不改后端。
- 卡片/详情图片在无真实封面/无照片时统一展示占位，避免白屏。
- 保留原有「用此场景拍照」「加入组合」「收藏」等交互与跳转。

## 验收要点

1. 首页场景推荐卡片显示真实场景名/照片数，封面为真实封面（自定义或预设首图）。
2. 有真实数据的场景，不再回退到 4 个写死 mock 场景。
3. 首页「收藏」落在收藏 tab、「管理」落在自定义场景 tab。
4. 场景详情各字段来自真实 `SceneRecord`/真实预设；新增「此场景拍摄」展示该场景照片并可全屏查看；无照片有空态。
5. 成就区显示真实照片数与等级，无 mock 周榜。