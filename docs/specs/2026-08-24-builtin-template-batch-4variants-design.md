# 内置模板「风格=分类 + 每风格4款具体模板」批量重构（设计）

- 日期：2026-08-24
- 状态：待评审
- 影响范围：`lumira_app_flutter`（Flutter 端仅），不涉及 `lumira-server`，无需双仓 push
- 前置：先回顾 `docs/specs/2026-08-24-builtin-template-4level-reclassify-and-nonportrait-design.md`（当前 41 款模板的四级分类归属）

## 背景与问题

当前内置模板存在两处结构性错误：

1. **模板命名 = 风格命名**：41 款内置模板里，多数模板名就是其风格名（如 `anime_dream_portrait` 名「动漫温柔青」、`fresh_green_portrait` 名「清新绿意」等）。按「风格=分类、模板=分类下多款具体作品」的产品语义，这不对。
2. **动漫温柔青归类错误**：`anime_dream_portrait`（动漫温柔青）被归到「梦幻夜色(dreamy_night)/动漫梦境」，但它是清新治愈类风格，应归入「清新治愈(fresh_healing)」系。

## 目标

1. 确立「**风格=分类(L2/L3)，模板=风格下多款具体作品**」的数据模型。
2. 把 `anime_dream`（动漫温柔青）归位到 `fresh_healing → anime_tender`，作为三级子风格「动漫温柔青」。
3. 全内置模板**改名**为具体作品名（不再用风格名）。
4. 每个风格叶节点下补齐 **4 款**具体模板，同风格内用 `method(构图/方法) + 构图 + 姿态/场景词 + 后期微调` 区分，封面与剪影延续该风格基调。
5. 同步：分类种子、`template_registry`、`templates/index.dart`、内置数量断言与测试、`flutter analyze` 全绿。

## 定义：四级分类语义

- L1 `type`（题材）：portrait / landscape / food / street / night / macro / still-life
- L2 `majorStyle`（仅人像，大风格）或 `style`（非人像，二级风格）
- L3 `subStyle`（仅人像，子风格）→ 对非人像为 `method` 的上一级
- L4 `method`（人像下的方法/构图）：normal/selfie/overhead/wide/half_body/full_body/seven_body 等

模板的完整分类路径 = `category(type)` + `majorStyle(L2)` + `subStyle(L3)` + `method(L4)`（非人像另含 `style`）。

## 分级策略：一个风格叶节点 → 4 款模板

- **风格叶节点**：人像取其 `subStyle`（L3），非人像取其 `style`（L2）。
- 每节点 4 款模板：命名 `[风格意象+主体]` 为基准名，另 3 款加构图/形态后缀（如 base、·侧拍、·俯拍、·二）。
- 四款通过 `method` 不同 + `composition`/`pose`/`sceneGuide`/`postProcess` 微调区分，`cover`/`silhouette` 复用该风格现成资源或延续基调。
- 已含 2 款（如日系 soft_portrait+cafe_portrait）再补 2；已含 1 款补 3；空节点（欧美 western）按风格语义新建 4。

## 全量目标清单（41 现有 + 新增 ≈ 131 款）

> 下表「现值」为该风格叶节点已有模板数，其余需新增。若风格已有多款，可在现有款数与新增款之间平衡命名。

### 人像 portrait（L2:majorStyle → L3:subStyle，L4:method）

| 大风格 | 子风格(现有模板) | 现有 | 补到 4 款 |
|---|---|---|---|
| fresh_healing 清新治愈 | japanese(soft_portrait, cafe_portrait) | 2 | +2 |
| fresh_healing | japanese_fresh(japanese_fresh_portrait) | 1 | +3 |
| fresh_healing | cream_healing(cream_healing_portrait) | 1 | +3 |
| fresh_healing | fresh_green(fresh_green_portrait) | 1 | +3 |
| fresh_healing | sweet_girl(sweet_girl_portrait) | 1 | +3 |
| fresh_healing | morandi_minimal(morandi_minimal_portrait) | 1 | +3 |
| fresh_healing | **anime_tender(动漫温柔青)**(anime_dream_portrait 改名归位) | 1 | +3 |
| emotional_film 情绪胶片 | emotional(sunset_silhouette) | 1 | +3 |
| emotional_film | film(film_vintage) | 1 | +3 |
| emotional_film | ccd_retro(ccd_retro_portrait) | 1 | +3 |
| urban_trend 都市潮流 | neon_city(neon_portrait, neon_city_portrait) | 2 | +2 |
| urban_trend | y2k(y2k_portrait) | 1 | +3 |
| urban_trend | dark_indoor(dark_indoor_portrait) | 1 | +3 |
| urban_trend | western(——) | 0 | +4 |
| retro_nostalgia 复古怀旧 | hk_noir(hk_noir_portrait) | 1 | +3 |
| retro_nostalgia | french_lazy(french_lazy_portrait) | 1 | +3 |
| retro_nostalgia | chinese_classical(chinese_classical_portrait) | 1 | +3 |
| dreamy_night 梦幻夜色 | blue_night(blue_night_portrait) | 1 | +3 |
| dreamy_night | purple_dusk(purple_dusk_portrait) | 1 | +3 |
| scene_portrait 场景人像 | foodie_portrait(foodie_portrait) | 1 | +3 |
| scene_portrait | elegant_lady(elegant_lady_portrait) | 1 | +3 |

### 非人像（L2:style → L4:method）

| 题材 | 风格(现有模板) | 现有 | 补到 4 款 |
|---|---|---|---|
| landscape 风光 | fresh(golden_landscape, seaside_dusk) | 2 | +2 |
| landscape | epic(urban_architecture, mountain_dawn) | 2 | +2 |
| food 美食 | overhead(food_flat_lay, cafe_table) | 2 | +2 |
| food | closeup(dessert_closeup) | 1 | +3 |
| street 街拍 | casual(street_bw, rainy_neon_street) | 2 | +2 |
| street | geometric(architectural_lines) | 1 | +3 |
| night 夜景 | neon(night_cityscape, city_lights_trail) | 2 | +2 |
| night | starry(starry_desert) | 1 | +3 |
| macro 微距 | nature(macro_flower, dew_moss) | 2 | +2 |
| macro | object(jewelry_closeup) | 1 | +3 |
| still-life 静物 | minimal(indoor_still_life, ceramic_vessel) | 2 | +2 |
| still-life | flat(magazine_flat) | 1 | +3 |

**合计**：人像 21 叶节点 × 4 = 84；非人像 12 叶节点 × 4 = 48；共 ~132 款（其中 41 款为现有改名+归位，其余为新增变体）。

## 对齐项（每次提交）

1. **模板文件**：`lib/features/capture/data/templates/<style>_<variant>.dart`，含完整 `PhotoTemplate`（meta/composition/pose/camera/sceneGuide/postProcess），`classification` 按目标风格路径填 `majorStyle/subStyle/method`。
2. **注册**：`lib/features/capture/data/templates/index.dart` + `lib/features/capture/data/template_registry.dart` 登记新 id。
3. **分类种子**：`lib/core/db/seeders/builtin_data_seeder.dart`
   - 子风格表：新增 `['fresh_healing', 'anime_tender', '动漫温柔青', sortOrder]`。
   - 方法表：为 `anime_tender` 增加所需 method（normal/selfie/overhead/full_body 等）。
4. **资产**：封面进 `assets/images/templates/<id>.png`，剪影进 `assets/images/silhouettes/<id>.png`（复用风格剪影可共用）。
5. **管线**：`TemplateMapper.toRecord/toPhotoTemplate` 已支持 majorStyle/subStyle 持久化（保留，不强改）。
6. **测试**：更新 `template_registry_test.dart` 等内置数量/命名断言。
7. **静态校验**：`flutter analyze` 无新增报错。

## 执行分批

按大分类分批：人像（清新治愈系 → 情绪胶片/复古/都市/梦幻/场景）→ 风光/美食 → 街拍/夜景 → 微距/静物。每批完成即 `flutter analyze` + 数量断言校验后再进入下一批。

## 验收

1. `flutter analyze` 全绿。
2. 所有风格叶节点均有 4 款具体命名模板；模板名不再等于风格名。
3. 动漫温柔青在「清新治愈」分类下可见，含 4 款（晴空田园少女人像 / ·侧拍 / ·俯拍 / ·二）。
4. 模板浏览/钻取过滤按风格与 method 正确命中；非人像模板不再混入人像大类。
5. 内置模板总数 ≈132 款，可在模板库概览/浏览页可见可拍。