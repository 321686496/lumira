# 首页真实数据集成设计

日期：2026-08-05
范围：Flutter 首页（lumira_app_flutter）+ 后端（lumira-server）

## 目标

首页 8 个 section 全部接入真实数据：
1. HeroCard（今日灵感）：日期+天气+智能文案
2. StreakCard（打卡统计）：已接入，不变
3. TipCard（拍照小贴士）：基于用户最近 30 天拍摄偏好的推荐算法
4. SceneRecoCard（场景推荐）：3+1 混合算法（3 同类常去 + 1 系统推荐）
5. RecentShotCard（最近拍摄）：显示用户真实照片（filePath > dataUrl > originalPath）
6. StatsCard（统计）：已接入，不变
7. HomeBanner：已接入，不变
8. QuickActions：纯导航，无数据

## 架构（方案 B：拆分多服务）

```
lib/features/home/
├── services/
│   ├── recommendation_service.dart          [现有] Banner
│   ├── inspiration_service.dart             [新增] 今日灵感
│   ├── tip_recommendation_service.dart      [新增] 小贴士推荐
│   └── scene_recommendation_service.dart    [新增] 场景推荐（3+1）
├── data/
│   ├── home_providers.dart                  [改造] 新增 3 provider，改造 recentShots/sceneRecos
│   ├── home_mock_data.dart                  [精简] RecentShot 加图片源字段
│   ├── inspiration_models.dart              [新增] HeroInspiration / WeatherInfo
│   └── tip_knowledge_base.dart              [新增] 小贴士知识库
└── widgets/
    ├── hero_card.dart                       [改造]
    ├── tip_card.dart                        [改造]
    └── recent_shot_card.dart                [改造]

lumira-server/packages/backend/src/modules/weather/   [新增] 天气代理
```

## 关键决策

| 维度 | 决策 |
|---|---|
| 天气数据源 | open-meteo，后端代理（含缓存） |
| 智能文案 | 本地规则模板（时段 × 主导category × 天气） |
| 小贴士偏好维度 | category + 自拍/他拍细分 |
| 自拍/他拍判定 | 模板无 subject 字段，用 `template.tags` 含「自拍」关键词判定；无模板时按 category=portrait 默认他拍 |
| 场景推荐算法 | 3+1 混合：3 同类常去 + 1 系统推荐 |
| 真实照片源 | filePath > dataUrl > originalPath 优先级 |
| 离线回退 | ApiCacheDao 缓存天气响应；其他纯本地 |

## Provider 一览

| Provider | 类型 | 数据源 |
|---|---|---|
| homeStreakProvider | FutureProvider | ChallengeRepository（不变） |
| homeStatsProvider | FutureProvider | GalleryDao + GrowthDao（不变） |
| homeRecentShotsProvider | FutureProvider | GalleryDao（改造返回图片源） |
| homeSceneRecosProvider | FutureProvider | SceneRecommendationService（改造） |
| homeInspirationProvider | FutureProvider | InspirationService（新增） |
| homeTipsProvider | FutureProvider | TipRecommendationService（新增） |
| bannerRecommendationProvider | FutureProvider | RecommendationService（不变） |

## 小贴士推荐算法

```
1. 取最近 50 张照片（GalleryDao.getRecent）
2. 过滤最近 30 天
3. 统计 template.category 分布 → topCategory
4. 若 topCategory == 'portrait'：
   - 检查 template.tags 是否含「自拍」→ 自拍偏好
   - 否则默认他拍
5. 从 TipKnowledgeBase 取 (topCategory, selfie/other) 对应贴士列表
6. 随机打乱取前 N 条
7. fallback：无数据时用通用贴士
```

## 场景推荐 3+1 算法

```
1. 统计每场景的照片数（GalleryDao.countByScene）
2. 排序得到常去场景列表
3. 槽位 1：最常去场景
4. 槽位 2：次常去场景的同类（同 scene.category）不同的场景
5. 槽位 3：第三常去场景的同类不同的场景
   - 若不足，从同类未拍过场景补
6. 槽位 4：系统推荐（用户从未拍过的场景，优先不同 category）
7. 不足 4 条时，从预设场景补齐
```

## 今日灵感智能文案规则

时段 × 主导 category × 天气状态 → 文案模板

```
时段：晨（5-10）/ 午（10-14）/ 暮（14-18）/ 夜（18-5）
category：portrait/landscape/food/street/night/macro/still-life/无数据
天气：晴/多云/阴/雨/雪

例：
- 午 + portrait + 晴 → "午后侧光柔和，适合人像"
- 暮 + landscape + 晴 → "黄金时刻光线暖黄，风光最佳时段"
- 晨 + food + 多云 → "晨光均匀，美食色彩还原准确"
- 无数据 + 任意 + 任意 → "捕捉每一束光，让日常成为习惯"
```

## 离线与降级

- 天气 API 失败：ApiCacheDao 缓存 → 静态兜底（移除天气文本，仅显示日期+黄金时刻）
- 小贴士无数据：通用贴士 fallback
- 场景推荐无数据：HomeMockData.scenes fallback
- 最近拍摄无数据：空状态引导拍摄
