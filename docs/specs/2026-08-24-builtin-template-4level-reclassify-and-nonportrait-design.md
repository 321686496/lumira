# 内置模板四级分类整理 + 补充非人像内置模板（设计）

- 日期：2026-08-24
- 状态：待实现
- 影响范围：`lumira_app_flutter`（Flutter 端仅），不涉及 `lumira-server`，无需双仓 push

## 背景

模板分类已升级为四级（`type`(L1) → `majorStyle`(L2 大风格) → `subStyle`(L3 子风格) → `method`(L4 方法)）。但当前内置模板存在两处问题：

1. **分类字段未按四级填写**：内置模板只填了 `{type, style, method}`，人像模板把「子风格」塞进了 `style`，没有大风格 `majorStyle`。
2. **管线丢失字段**：内置模板种子落库走 `TemplateMapper.toRecord`，只写 `type/style/method`，丢弃 `majorStyle/subStyle`（远程模板走的 `metaToRecord` 已正确落两者，见 `template_mapper.dart` L35-39 vs L75-83）。导致按大风格/子风格钻取过滤（`matchesSubtree`）对内置模板永远匹配不到。

## 目标

1. 补齐 `majorStyle/subStyle` 落库/读回管线，让内置模板按大风格/子风格钻取真正生效。
2. 按四级规则重新整理现有 29 款内置模板分类。
3. 补充非人像大类内置模板（每类 +2~3 款，共约 12 款），让人像之外的大类不再只有单款或稀疏。

## Part A：重整现有 29 款内置模板分类

### A1. 数据管线改造

- `PhotoTemplate` 的 `TemplateClassification` 模型（`photo_template.dart` L176）增加 `majorStyle` 字段（默认 `''`），并纳入 `copyWith` / `==` / `hashCode`。
- `TemplateMapper.toRecord`（内置种子落库）在 classification 中补写：
  - `'majorStyle': tpl.meta.classification.majorStyle`
  - `'subStyle': tpl.meta.classification.subStyle`
- 读回方向（`TemplateRecord` 的 classification 读取，`template_mapper.dart` L151-157 与 L330-347）已含 `majorStyle`→`style` 兜底、`subStyle`/`method` 直接读取的逻辑，无需大改；确保 `majorStyle` 读入模型字段（与 `style` 兜底并存）。

### A2. 人像模板 → 大风格/子风格/方法

| 大风格 | 子风格 | method | 模板 |
|---|---|---|---|
| fresh_healing 清新治愈 | japanese | normal | soft_portrait、cafe_portrait |
| fresh_healing | japanese_fresh | seven_body | japanese_fresh_portrait |
| fresh_healing | cream_healing | half_body | cream_healing_portrait |
| fresh_healing | fresh_green | full_body | fresh_green_portrait |
| fresh_healing | sweet_girl | half_body | sweet_girl_portrait |
| fresh_healing | morandi_minimal | half_body | morandi_minimal_portrait |
| emotional_film 情绪胶片 | emotional | wide | sunset_silhouette |
| emotional_film | film | normal | film_vintage |
| emotional_film | ccd_retro | half_body | ccd_retro_portrait |
| urban_trend 都市潮流 | neon_city | half_body | **neon_portrait**（由 film 挪入）、neon_city_portrait |
| urban_trend | y2k | half_body | y2k_portrait |
| urban_trend | dark_indoor | half_body | dark_indoor_portrait |
| retro_nostalgia 复古怀旧 | hk_noir | half_body | hk_noir_portrait |
| retro_nostalgia | french_lazy | half_body | french_lazy_portrait |
| retro_nostalgia | chinese_classical | full_body | chinese_classical_portrait |
| dreamy_night 梦幻夜色 | blue_night | seven_body | blue_night_portrait |
| dreamy_night | purple_dusk | half_body | purple_dusk_portrait |
| dreamy_night | anime_dream | full_body | anime_dream_portrait |
| scene_portrait 场景人像 | foodie_portrait | half_body | foodie_portrait |
| scene_portrait | elegant_lady | seven_body | elegant_lady_portrait |

> 注：人像模板统一 `majorStyle`=上表大风格、`subStyle`=子风格、`method`=方法；`style` 字段留空（读回时走 `majorStyle` 兜底）。

### A3. 非人像模板（不改类型，`majorStyle` 置空，`subStyle`=原 style，`method` 修正为有效 key）

| 模板 | type | subStyle(原 style) | method |
|---|---|---|---|
| golden_landscape | landscape | fresh | wide |
| urban_architecture | landscape | epic | wide |
| food_flat_lay | food | overhead | flat（原 `flat-lay` 无效，修正） |
| indoor_still_life | still-life | minimal | single |
| macro_flower | macro | nature | macro |
| night_cityscape | night | neon | wide |
| street_bw | street | casual | normal（原 `candid` 无效，修正） |

## Part B：新增非人像内置模板（每类 +2~3 款，共 12 款）

每款为完整 `PhotoTemplate`，字段对齐现有模板（composition/pose/camera/sceneGuide/postProcess/tags/cover/silhouette）。

| 类别 | 新增模板 | subStyle | method | 备注 |
|---|---|---|---|---|
| 风光 landscape | mountain_dawn（山岳晨光） | epic | wide | |
| 风光 landscape | seaside_dusk（海边黄昏） | fresh | wide | |
| 美食 food | dessert_closeup（甜点特写） | closeup | macro | |
| 美食 food | cafe_table（餐桌氛围） | overhead | flat | |
| 街拍 street | rainy_neon_street（雨夜街头） | casual | normal | |
| 街拍 street | architectural_lines（几何建筑线构） | geometric | wide | |
| 夜景 night | city_lights_trail（城市光轨） | neon | wide | |
| 夜景 night | starry_desert（璀璨星空） | starry | -（无 method） | |
| 微距 macro | dew_moss（露珠苔藓） | nature | macro | |
| 微距 macro | jewelry_closeup（首饰特写） | object | - | |
| 静物 still-life | ceramic_vessel（素陶瓷器） | minimal | single | |
| 静物 still-life | magazine_flat（杂志静物平面） | flat | - | |

- 封面：用图片生成产出到 `assets/images/templates/<id>.png`。
- 剪影：复用现有 12 款内置 SVG（如 food-overhead / cityscape-tripod / landscape-wide / macro-flower / still-life-table / walking-street 等），不新增 SVG。
- 注册：新增 dart 文件加入 `templates/index.dart`，并在 `template_registry.dart` 的 `TemplatesRegistry` 中登记。

## 验收

1. `flutter analyze` 无新增告警。
2. 内置模板（降级/新装内核）按大风格、子风格钻取过滤时能匹配到（含 neon_portrait 归入都市潮流）。
3. 新增 12 款模板在「模板浏览页」可见、可点开预览、可进入拍摄。