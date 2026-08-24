# 内置模板批量重构：风格叶节点 → 4 款具体模板（可执行映射）

> 配套 `docs/specs/2026-08-24-builtin-template-batch-4variants-design.md`。
> 本文件是子代理创建模板文件时唯一参照的“变体清单”：给出每个风格叶节点下 4 款具体模板的
> **id / 展示名 / 方法(method) / 复用封面 / 复用剪影**。展示名须为具体作品名，不得等于风格名。

## 通用规则（创建模板文件必须遵守）

1. 文件放 `lib/features/capture/data/templates/`，命名 `<id>.dart`。
2. 导出 const 命名 = `<id> 转驼峰小写 + Template`，如 `japanese_soft` → `japaneseSoftTemplate`。
3. `PhotoTemplate.meta` 字段：
   - `name`：下表中文展示名（具体作品名）。
   - `category`: 题材；`classification.type` 同 category。
   - `classification`：人像填 `majorStyle + subStyle + method`；非人像填 `style + method`（type=题材）。三级/二级参照下表“风格路径”。
   - `cover`：下表封面复用路径（同风格 4 款共用同一封面，体现风格一致）。
   - `pose.silhouette`：复用 `assets/images/silhouettes/<style>.png`（同风格共用）。若该风格无剪影文件则用 `SilhouetteResource(type:'builtin', data:'standing-profile')`。
   - `price`：继承原风格现有款资产定价（下表给出基准，新变体与同风格一致或免费）。
4. 4 款之间差异：`method` 不同（见下表），并通过 `composition.subjectFrame / overlayType`、`pose.description`、`sceneGuide.background`、`postProcess`（微调、裁剪比）区分，不得 4 款完全相同。
5. 已有模板（41 款）在各自节点内：**保留 id 与文件名**，仅把 `name` 改为下表具体名（若当前名即风格名则必改），并补足分类 method 字段。节点内差多少就新建多少变体文件。
6. `aspectRatio` 人像默认 '3:4'；风光/夜景可 '16:9'；美食/微距/静物可 '1:1'。

## 人像 portrait（路径：type=portrait → majorStyle → subStyle → method）

### 大风格 fresh_healing 清新治愈

#### 节点 japanese 日系（现有 soft_portrait, cafe_portrait，+2）
| id | 展示名 | method | 复用封面 | 备注 |
|---|---|---|---|---|
| soft_portrait | 窗边柔光人像 | normal | templates/soft_portrait.jpg | 保留id改名 |
| cafe_portrait | 咖啡馆窗边人像 | normal | templates/cafe_portrait.jpg | 保留id改名 |
| japanese_golden_hour | 日系黄昏逆光人像 | side | templates/soft_portrait.jpg | 新增 |
| japanese_tulip | 日系花田少女他拍 | selfie | templates/soft_portrait.jpg | 新增 |

#### 节点 japanese_fresh 日系清新（现有 japanese_fresh_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| japanese_fresh_portrait | 日系清新回眸人像 | seven_body | templates/japanese_fresh_portrait.png |
| japanese_fresh_beach | 海边日系清新自拍 | selfie | templates/japanese_fresh_portrait.png |
| japanese_fresh_meadow | 草地远景日系少女 | wide | templates/japanese_fresh_portrait.png |
| japanese_fresh_side | 日系清新侧拍人像 | side | templates/japanese_fresh_portrait.png |

#### 节点 cream_healing 奶油治愈（现有 cream_healing_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| cream_healing_portrait | 奶油暖调半身人像 | half_body | templates/cream_healing_portrait.png |
| cream_healing_window | 奶油窗光他拍人像 | normal | templates/cream_healing_portrait.png |
| cream_healing_overhead | 奶油柔光俯拍人像 | overhead | templates/cream_healing_portrait.png |
| cream_healing_side | 奶油逆光侧拍人像 | side | templates/cream_healing_portrait.png |

#### 节点 fresh_green 清新绿意（现有 fresh_green_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| fresh_green_portrait | 清新绿意全身人像 | full_body | templates/fresh_green_portrait.png |
| fresh_green_park | 公园绿意远景人像 | wide | templates/fresh_green_portrait.png |
| fresh_green_overhead | 绿野俯拍人像 | overhead | templates/fresh_green_portrait.png |
| fresh_green_courtyard | 庭院绿意他拍人像 | normal | templates/fresh_green_portrait.png |

#### 节点 sweet_girl 甜美少女（现有 sweet_girl_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| sweet_girl_portrait | 甜美少女半身人像 | half_body | templates/sweet_girl_portrait.png |
| sweet_girl_selfie | 甜美元气自拍 | selfie | templates/sweet_girl_portrait.png |
| sweet_girl_dress | 甜美裙装全身人像 | full_body | templates/sweet_girl_portrait.png |
| sweet_girl_side | 甜美回眸侧拍人像 | side | templates/sweet_girl_portrait.png |

#### 节点 morandi_minimal 莫兰迪极简（现有 morandi_minimal_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| morandi_minimal_portrait | 莫兰迪极简半身人像 | half_body | templates/morandi_minimal_portrait.png |
| morandi_minimal_he | 莫兰迪静物他拍人像 | normal | templates/morandi_minimal_portrait.png |
| morandi_minimal_side | 莫兰迪侧拍人像 | side | templates/morandi_minimal_portrait.png |
| morandi_minimal_overhead | 莫兰迪低饱和俯拍 | overhead | templates/morandi_minimal_portrait.png |

#### 节点 anime_tender 动漫温柔青（由 anime_dream_portrait 归位，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| anime_dream_portrait | 晴空田园少女人像 | full_body | templates/anime_dream_portrait.png |
| anime_tender_girl_side | 晴空田园少女人像·侧拍 | side | templates/anime_dream_portrait.png |
| anime_tender_girl_overhead | 晴空田园少女人像·俯拍 | overhead | templates/anime_dream_portrait.png |
| anime_tender_girl_two | 晴空田园少女人像·二 | normal | templates/anime_dream_portrait.png |

### 大风格 emotional_film 情绪胶片

#### 节点 emotional 情绪（现有 sunset_silhouette，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| sunset_silhouette | 夕阳剪影远景人像 | wide | templates/sunset_silhouette.jpg |
| emotional_selfie | 情绪氛围自拍 | selfie | templates/sunset_silhouette.jpg |
| emotional_half | 情绪特写半身人像 | half_body | templates/sunset_silhouette.jpg |
| emotional_corridor | 室外情绪他拍人像 | normal | templates/sunset_silhouette.jpg |

#### 节点 film 胶片（现有 film_vintage，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| film_vintage | 胶片复古他拍人像 | normal | templates/film_vintage.jpg |
| film_selfie | 胶片质感自拍 | selfie | templates/film_vintage.jpg |
| film_side | 胶片旧时光侧拍 | side | templates/film_vintage.jpg |
| film_wide | 胶片街角远景人像 | wide | templates/film_vintage.jpg |

#### 节点 ccd_retro CCD复古（现有 ccd_retro_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| ccd_retro_portrait | CCD复古半身人像 | half_body | templates/ccd_retro_portrait.png |
| ccd_retro_selfie | CCD闪光自拍人像 | selfie | templates/ccd_retro_portrait.png |
| ccd_retro_he | CCD旧味他拍人像 | normal | templates/ccd_retro_portrait.png |
| ccd_retro_side | CCD小脸侧拍人像 | side | templates/ccd_retro_portrait.png |

### 大风格 urban_trend 都市潮流

#### 节点 neon_city 霓虹都市（现有 neon_portrait, neon_city_portrait，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| neon_portrait | 霓虹街角他拍人像 | normal | templates/neon_portrait.jpg |
| neon_city_portrait | 霓虹都市半身人像 | half_body | templates/neon_city_portrait.png |
| neon_city_selfie | 霓虹夜景自拍 | selfie | templates/neon_city_portrait.png |
| neon_city_wide | 霓虹长街远景人像 | wide | templates/neon_city_portrait.png |

#### 节点 y2k Y2K千禧（现有 y2k_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| y2k_portrait | Y2K千禧半身人像 | half_body | templates/y2k_portrait.png |
| y2k_selfie | 千禧辣妹自拍 | selfie | templates/y2k_portrait.png |
| y2k_he | 千禧街头他拍人像 | normal | templates/y2k_portrait.png |
| y2k_side | 千禧侧拍人像 | side | templates/y2k_portrait.png |

#### 节点 dark_indoor 暗调室内（现有 dark_indoor_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| dark_indoor_portrait | 暗调室内半身人像 | half_body | templates/dark_indoor_portrait.png |
| dark_indoor_he | 暗房轮廓他拍人像 | normal | templates/dark_indoor_portrait.png |
| dark_indoor_side | 暗调侧光人像 | side | templates/dark_indoor_portrait.png |
| dark_indoor_low | 暗调仰拍人像 | low_angle | templates/dark_indoor_portrait.png |

#### 节点 western 欧美（空节点，+4 新建）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| western_street | 欧美街拍他拍人像 | normal | templates/neon_portrait.jpg |
| western_wide | 欧美都市远景人像 | wide | templates/neon_portrait.jpg |
| western_side | 欧美时尚侧拍人像 | side | templates/neon_portrait.jpg |
| western_half | 欧美大片半身人像 | half_body | templates/neon_portrait.jpg |

### 大风格 retro_nostalgia 复古怀旧

#### 节点 hk_noir 港风Noir（现有 hk_noir_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| hk_noir_portrait | 港风Noir半身人像 | half_body | templates/hk_noir_portrait.png |
| hk_noir_he | 港味街角他拍人像 | normal | templates/hk_noir_portrait.png |
| hk_noir_wide | 港风旧街远景人像 | wide | templates/hk_noir_portrait.png |
| hk_noir_side | 港风侧拍人像 | side | templates/hk_noir_portrait.png |

#### 节点 french_lazy 法式慵懒（现有 french_lazy_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| french_lazy_portrait | 法式慵懒半身人像 | half_body | templates/french_lazy_portrait.png |
| french_lazy_he | 法式街头他拍人像 | normal | templates/french_lazy_portrait.png |
| french_lazy_side | 法式侧拍人像 | side | templates/french_lazy_portrait.png |
| french_lazy_overhead | 法式慵懒俯拍 | overhead | templates/french_lazy_portrait.png |

#### 节点 chinese_classical 中式古典（现有 chinese_classical_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| chinese_classical_portrait | 中式古典全身人像 | full_body | templates/chinese_classical_portrait.png |
| chinese_classical_wide | 中式庭院远景人像 | wide | templates/chinese_classical_portrait.png |
| chinese_classical_he | 中式雅韵他拍人像 | normal | templates/chinese_classical_portrait.png |
| chinese_classical_side | 中式侧拍人像 | side | templates/chinese_classical_portrait.png |

### 大风格 dreamy_night 梦幻夜色

#### 节点 blue_night 蓝色之夜（现有 blue_night_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| blue_night_portrait | 蓝色之夜七分身人像 | seven_body | templates/blue_night_portrait.png |
| blue_night_wide | 蓝色夜景远景人像 | wide | templates/blue_night_portrait.png |
| blue_night_he | 蓝色夜光他拍人像 | normal | templates/blue_night_portrait.png |
| blue_night_side | 蓝色侧拍人像 | side | templates/blue_night_portrait.png |

#### 节点 purple_dusk 紫色黄昏（现有 purple_dusk_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| purple_dusk_portrait | 紫色黄昏半身人像 | half_body | templates/purple_dusk_portrait.png |
| purple_dusk_he | 紫色暮色他拍人像 | normal | templates/purple_dusk_portrait.png |
| purple_dusk_wide | 紫色黄昏远景人像 | wide | templates/purple_dusk_portrait.png |
| purple_dusk_side | 紫色侧拍人像 | side | templates/purple_dusk_portrait.png |

### 大风格 scene_portrait 场景人像

#### 节点 foodie_portrait 美食人像（现有 foodie_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| foodie_portrait | 美食人像半身 | half_body | templates/foodie_portrait.png |
| foodie_he | 餐桌互动他拍人像 | normal | templates/foodie_portrait.png |
| foodie_overhead | 美食俯拍人像 | overhead | templates/foodie_portrait.png |
| foodie_side | 用餐侧拍人像 | side | templates/foodie_portrait.png |

#### 节点 elegant_lady 优雅女士（现有 elegant_lady_portrait，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| elegant_lady_portrait | 优雅女士七分身人像 | seven_body | templates/elegant_lady_portrait.png |
| elegant_lady_he | 优雅都市他拍人像 | normal | templates/elegant_lady_portrait.png |
| elegant_lady_side | 优雅侧拍人像 | side | templates/elegant_lady_portrait.png |
| elegant_lady_wide | 优雅远眺人像 | wide | templates/elegant_lady_portrait.png |

## 非人像（路径：type=题材 → style → method）

### landscape 风光
#### 节点 fresh 清新（现有 golden_landscape, seaside_dusk，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| golden_landscape | 金色麦田风光 | wide | templates/golden_landscape.jpg |
| seaside_dusk | 海边黄昏风光 | flat | templates/seaside_dusk.jpg |
| fresh_lake | 湖畔清新平拍 | flat | templates/seaside_dusk.jpg |
| fresh_flower_field | 花田清新远景 | wide | templates/seaside_dusk.jpg |

#### 节点 epic 大气（现有 urban_architecture, mountain_dawn，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| urban_architecture | 城市建筑天际线 | wide | templates/urban_architecture.jpg |
| mountain_dawn | 群山破晓 | wide | templates/mountain_dawn.jpg |
| epic_valley | 峡谷晨雾俯拍 | overhead | templates/mountain_dawn.jpg |
| epic_sea | 海天一色远景 | wide | templates/mountain_dawn.jpg |

### food 美食
#### 节点 overhead 俯拍（现有 food_flat_lay, cafe_table，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| food_flat_lay | 木质桌面俯拍料理 | flat | templates/food_flat_lay.jpg |
| cafe_table | 咖啡馆午后桌面 | flat | templates/cafe_table.jpg |
| overhead_brunch | 早午餐俯拍 | overhead | templates/food_flat_lay.jpg |
| overhead_dessert_table | 甜品桌俯拍 | flat | templates/food_flat_lay.jpg |

#### 节点 closeup 特写（现有 dessert_closeup，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| dessert_closeup | 甜品奶泡特写 | detail | templates/dessert_closeup.jpg |
| closeup_soup | 汤面热气特写 | macro | templates/dessert_closeup.jpg |
| closeup_sushi | 寿司鱼生特写 | detail | templates/dessert_closeup.jpg |
| closeup_pizza | 披萨拉丝特写 | macro | templates/dessert_closeup.jpg |

### street 街拍
#### 节点 casual 随性（现有 street_bw, rainy_neon_street，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| street_bw | 随性街头黑白 | normal | templates/street_bw.jpg |
| rainy_neon_street | 雨夜霓虹街拍 | wide | templates/rainy_neon_street.jpg |
| casual_crosswalk | 斑马线随拍 | wide | templates/street_bw.jpg |
| casual_market | 市集日常抓拍 | normal | templates/street_bw.jpg |

#### 节点 geometric 几何（现有 architectural_lines，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| architectural_lines | 建筑线条几何 | wide | templates/architectural_lines.jpg |
| geometric_shadow | 光影几何过道 | overhead | templates/architectural_lines.jpg |
| geometric_stairs | 旋转楼梯几何 | wide | templates/architectural_lines.jpg |
| geometric_facade | 立面几何结构 | wide | templates/architectural_lines.jpg |

### night 夜景
#### 节点 neon 霓虹（现有 night_cityscape, city_lights_trail，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| night_cityscape | 城市霓虹夜景 | wide | templates/night_cityscape.jpg |
| city_lights_trail | 车流光轨夜景 | wide | templates/city_lights_trail.jpg |
| neon_storefront | 霓虹招牌夜景 | normal | templates/night_cityscape.jpg |
| neon_river | 河岸霓虹倒影 | wide | templates/night_cityscape.jpg |

#### 节点 starry 星空（现有 starry_desert，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| starry_desert | 沙漠银河星空 | wide | templates/starry_desert.jpg |
| starry_milkyway | 银河拱门夜景 | wide | templates/starry_desert.jpg |
| starry_meteor | 流星划过夜空 | wide | templates/starry_desert.jpg |
| starry_campsite | 露营星空帐篷 | wide | templates/starry_desert.jpg |

### macro 微距
#### 节点 nature 自然（现有 macro_flower, dew_moss，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| macro_flower | 微距花卉花蕊 | macro | templates/macro_flower.jpg |
| dew_moss | 苔藓晨露微距 | macro | templates/dew_moss.jpg |
| nature_butterfly | 蝴蝶翅膀微距 | macro | templates/macro_flower.jpg |
| nature_bees | 蜜蜂采蜜微距 | macro | templates/macro_flower.jpg |

#### 节点 object 物品（现有 jewelry_closeup，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| jewelry_closeup | 珠宝首饰微距 | detail | templates/jewelry_closeup.jpg |
| object_watch | 手表表盘微距 | macro | templates/jewelry_closeup.jpg |
| object_leaf | 枯叶纹理微距 | detail | templates/jewelry_closeup.jpg |
| object_coin | 老硬币细节 | macro | templates/jewelry_closeup.jpg |

### still-life 静物
#### 节点 minimal 极简（现有 indoor_still_life, ceramic_vessel，+2）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| indoor_still_life | 室内极简静物 | single | templates/indoor_still_life.jpg |
| ceramic_vessel | 陶器器皿静物 | single | templates/ceramic_vessel.jpg |
| minimal_book | 单本书籍静物 | single | templates/indoor_still_life.jpg |
| minimal_fruit | 极简果盘静物 | single | templates/indoor_still_life.jpg |

#### 节点 flat 扁平（现有 magazine_flat，+3）
| id | 展示名 | method | 复用封面 |
|---|---|---|---|
| magazine_flat | 杂志版面扁平静物 | flat | templates/magazine_flat.jpg |
| flat_sonboc | 扁平桌面摆件 | flat | templates/magazine_flat.jpg |
| flat_tshirt | 扁平衣物陈列 | flat | templates/magazine_flat.jpg |
| flat_cosmetics | 化妆品扁平展架 | flat | templates/magazine_flat.jpg |

> 每次创建完成后更新此表状态列；`问题、冲突`直接在本文件下追加说明。