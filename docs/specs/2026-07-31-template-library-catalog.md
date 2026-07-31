# 如画 Lumira · 拍照模板库总目录

> 整理日期：2026-07-31
> 用途：作为产品内置模板库的扩充蓝本，覆盖 7 大分类，每分类 5–10 套模板
> 字段约定：对齐 [lumira-app/src/types/template.ts](../../lumira-app/src/types/template.ts) 中的 `PhotoTemplate` 结构（meta / composition / pose / camera / sceneGuide / postProcess）

---

## 目录概览

| 分类（Target） | 中文名 | 子分类 | 模板数 |
| --- | --- | --- | --- |
| portrait | 人像 | 氛围感 / 清新 / 港风 / 情绪 / 国风 / 街拍人像 | 30 |
| landscape | 风光 | — | 8 |
| food | 美食 | — | 8 |
| street | 街拍 | — | 8 |
| night | 夜景 | — | 8 |
| macro | 微距 | — | 8 |
| still-life | 静物 | — | 8 |
| **合计** |  |  | **78** |

> 价格策略：每个分类前 5 套为免费（price: 0），其后为付费（price: 6–18 Lumira 币）。封面统一走 `https://picsum.photos/seed/{id}/400/600`。

---

## 一、人像 Portrait

> 人像分类按国内热门拍摄类型拆分为 6 个子分类（对应 `classification.style` 字段），每子分类 5 套，共 30 套。

### 1.1 氛围感 atmosphere

主打"光线讲故事"，以暖橙、雾蓝、霓虹色温为主，强调低饱和与情绪浓度。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_atmosphere_sunset_backlight | 落日逆光剪影 | 0 | 日落 / 剪影 / 暖橙 | 35mm·f2.0·1/200s·ISO100·WB shade·EV+0.7·LUT warm_film |
| portrait_atmosphere_rainy_neon | 雨夜霓虹人像 | 0 | 雨夜 / 霓虹冷暖对撞 | 50mm·f1.8·1/60s·ISO800·WB tungsten·EV-0.3·LUT cyberpunk |
| portrait_atmosphere_fog_window | 车窗雾气朦胧 | 0 | 雾窗 / 侧脸 / 低饱和 | 35mm·f2.8·1/100s·ISO400·WB cloudy·EV+0.3·LUT mist |
| portrait_atmosphere_candle_warm | 烛光暖意肖像 | 6 | 烛光 / 暗调 / 油画感 | 50mm·f1.4·1/40s·ISO1600·WB custom 3200K·EV-0.3·LUT rouge |
| portrait_atmosphere_seaside_dusk | 海边黄昏氛围 | 6 | 海风 / 逆光 / 蓝橙对撞 | 85mm·f1.8·1/250s·ISO100·WB daylight·EV+0.5·LUT twilight |

**通用场景指南**
- 光线方向：日落逆光 180°、雨夜霓虹侧逆光 135°、车窗外散光、烛光顶前 30°、海边逆光 180°
- 拍摄距离：1.5–3m，氛围感优先半身或剪影
- 道具：透明雨伞、咖啡杯、复古打火机、丝巾、便携补光
- 最佳时间：日落前后 30min / 雨夜 20:00 后 / 烛光任意时段
- 贴士：保留高光细节，肤色可偏暖偏粉；逆光时按面部测光 +EV 0.3~0.7

### 1.2 清新 fresh

主打"日系通透"，高明度、低对比、青绿+米白配色。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_fresh_campus_morning | 校园晨光清新 | 0 | 校园 / 侧光 / 青绿 | 35mm·f2.0·1/250s·ISO100·WB daylight·EV+0.5·LUT fuji |
| portrait_fresh_cherry_blossom | 樱花树下人像 | 0 | 春日 / 散景 / 粉白 | 50mm·f1.8·1/320s·ISO100·WB daylight·EV+0.3·LUT pastel |
| portrait_fresh_summer_beach | 夏日海边清新 | 0 | 海风 / 顺光 / 蓝白 | 35mm·f2.8·1/500s·ISO100·WB daylight·EV+0.7·LUT cyan |
| portrait_fresh_field_grass | 田野草地人像 | 0 | 田园 / 逆光 / 暖绿 | 50mm·f1.8·1/400s·ISO100·WB daylight·EV+0.5·LUT fuji |
| portrait_fresh_window_morning | 晨光窗边清新 | 6 | 居家 / 窗光 / 米白 | 50mm·f1.8·1/160s·ISO200·WB cloudy·EV+0.3·LUT pastel |

**通用场景指南**
- 光线方向：晨光顺光 0°–45°、窗光侧光 90°、樱花树散光
- 拍摄距离：1.2–2m，半身或七分身
- 道具：草帽、白衬衫、书本、白色帆布袋、透明水杯
- 最佳时间：07:00–09:00 / 15:00–17:00
- 贴士：白色服装优先，肤色稍提亮，背景留白多；避免正午硬光

### 1.3 港风 hongkong

主打"90 年代王家卫式港风"，高饱和红绿、霓虹色块、颗粒感重。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_hk_retro_street | 复古街角港风 | 0 | 街角 / 侧光 / 颗粒 | 35mm·f2.8·1/125s·ISO400·WB tungsten·EV-0.3·LUT vintage |
| portrait_hk_neon_sign | 霓虹招牌人像 | 0 | 霓虹 / 冷暖对撞 | 50mm·f1.8·1/60s·ISO800·WB tungsten·EV-0.3·LUT cyberpunk |
| portrait_hk_taxi_backseat | 的士后座港风 | 6 | 车内 / 顶光 / 红皮座椅 | 35mm·f2.0·1/60s·ISO800·WB tungsten·EV-0.3·LUT rouge |
| portrait_hk_cha_chaan_teng | 茶餐厅人像 | 6 | 室内 / 暖光 / 复古 | 35mm·f2.8·1/80s·ISO400·WB tungsten·EV+0.3·LUT vintage |
| portrait_hk_rainy_overpass | 夜雨天桥港风 | 6 | 雨夜 / 路灯 / 反光 | 50mm·f1.8·1/60s·ISO1600·WB tungsten·EV-0.7·LUT cinematic |

**通用场景指南**
- 光线方向：霓虹招牌侧逆光 135°、街灯顶光、车内顶光
- 拍摄距离：1.5–2.5m
- 道具：复古墨镜、皮夹克、胶片相机、红色唇彩、繁体招牌
- 最佳时间：18:30 后入夜 / 雨夜
- 贴士：肤色偏黄红，颗粒 +30，画面加暗角；可拍胶卷感粗颗粒

### 1.4 情绪 emotion

主打"孤独叙事"，冷调、低饱和、空旷构图。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_emotion_rooftop_alone | 天台孤独人像 | 0 | 天台 / 逆光 / 剪影 | 35mm·f4.0·1/250s·ISO100·WB daylight·EV-0.7·LUT cinematic |
| portrait_emotion_bw_solitude | 黑白情绪肖像 | 0 | 室内 / 侧光 / 黑白 | 50mm·f2.0·1/100s·ISO400·WB daylight·EV-0.3·LUT bw |
| portrait_emotion_rain_window | 雨窗背后情绪 | 0 | 雨窗 / 散光 / 冷调 | 50mm·f2.0·1/125s·ISO400·WB fluorescent·EV-0.3·LUT cool_film |
| portrait_emotion_empty_train | 空荡车厢情绪 | 6 | 地铁 / 顶光 / 对称 | 24mm·f4.0·1/60s·ISO800·WB fluorescent·EV-0.3·LUT cyan |
| portrait_emotion_late_night_store | 深夜便利店人像 | 6 | 便利店 / 冷光 / 孤独 | 35mm·f2.0·1/60s·ISO1600·WB fluorescent·EV+0.3·LUT cyan |

**通用场景指南**
- 光线方向：天台逆光、室内单侧窗光、地铁顶光对称、便利店冷光
- 拍摄距离：2–4m，多带环境
- 道具：耳机、白衬衫、纸杯、透明伞、手机
- 最佳时间：傍晚 17:00–19:00 / 深夜 22:00 后
- 贴士：人物在画面占比 <1/3，留白多；冷调色温 -10~-20

### 1.5 国风 chinese

主打"东方古典美学"，青绿山水、黛色朱砂、宣纸米白。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_chinese_hanfu_garden | 汉服园林古风 | 0 | 园林 / 散光 / 青绿 | 85mm·f2.0·1/200s·ISO100·WB daylight·EV+0.3·LUT japanese |
| portrait_chinese_bamboo_forest | 竹林禅意人像 | 0 | 竹林 / 侧光 / 墨绿 | 50mm·f2.0·1/160s·ISO200·WB daylight·EV-0.3·LUT fuji |
| portrait_chinese_oil_paper_umbrella | 油纸伞雨巷人像 | 6 | 雨巷 / 散光 / 黛色 | 50mm·f2.0·1/100s·ISO400·WB cloudy·EV-0.3·LUT mist |
| portrait_chinese_tea_ceremony | 禅意茶席人像 | 6 | 茶席 / 侧光 / 米白 | 50mm·f2.8·1/80s·ISO400·WB shade·EV+0.3·LUT pastel |
| portrait_chinese_moon_courtyard | 月夜庭院国风 | 6 | 月夜 / 冷光 / 蓝调 | 35mm·f2.8·1/60s·ISO800·WB tungsten·EV-0.3·LUT twilight |

**通用场景指南**
- 光线方向：园林漫射光、竹林侧光 90°、雨巷顶散光、茶席侧前 45°
- 拍摄距离：1.5–3m
- 道具：油纸伞、团扇、茶器、古籍、香炉、汉服/旗袍
- 最佳时间：清晨 / 雨后 / 黄昏后
- 贴士：肤色偏白皙，对比度 -5，画面留白多；避免艳俗饱和

### 1.6 街拍人像 street-portrait

主打"城市日常感"，自然抓拍、生活化场景。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| portrait_street_walking_avenue | 城市步行街人像 | 0 | 街拍 / 走动 / 顺光 | 35mm·f2.8·1/320s·ISO100·WB daylight·EV+0.3·LUT standard |
| portrait_street_subway_commute | 地铁通勤人像 | 0 | 地铁 / 顶光 / 抓拍 | 35mm·f2.0·1/80s·ISO400·WB fluorescent·EV-0.3·LUT cool_film |
| portrait_street_cafe_window | 咖啡馆窗边街拍 | 0 | 窗光 / 侧脸 / 暖调 | 50mm·f1.8·1/160s·ISO200·WB cloudy·EV+0.3·LUT warm_film |
| portrait_street_art_district | 艺术街区人像 | 6 | 涂墙 / 侧光 / 鲜艳 | 35mm·f4.0·1/250s·ISO100·WB daylight·EV+0.3·LUT vivid |
| portrait_street_mall_window | 商场橱窗人像 | 6 | 橱窗 / 反射 / 都市 | 50mm·f2.0·1/100s·ISO400·WB tungsten·EV+0.3·LUT cinematic |

**通用场景指南**
- 光线方向：街拍顺光 0°–45°、地铁顶光、窗光侧光 90°、橱窗反射光
- 拍摄距离：1.5–3m，多带环境
- 道具：耳机、咖啡杯、购物袋、墨镜、手机
- 最佳时间：10:00–11:00 / 15:00–17:00
- 贴士：模特走动中抓拍，快门 ≥1/250s；橱窗拍摄注意反光

---

## 二、风光 Landscape

主打"自然与城市的宏大叙事"。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| landscape_sunrise_cloud_sea | 日出云海山巅 | 0 | 高山 / 顺光 / 暖金 | 24mm·f8.0·1/125s·ISO100·WB daylight·EV-0.3·LUT warm_film |
| landscape_snow_mountain | 雪山远景 | 0 | 雪山 / 顺光 / 冷暖对撞 | 70mm·f11·1/250s·ISO100·WB daylight·EV+0.7·LUT cool_film |
| landscape_seaside_rocks | 海浪礁石长曝 | 0 | 海岸 / 长曝 / 雾化 | 16mm·f11·30s·ISO100·WB cloudy·ND1000·LUT cyan |
| landscape_forest_path | 森林小径 | 0 | 林间 / 散光 / 墨绿 | 35mm·f5.6·1/60s·ISO200·WB shade·EV-0.3·LUT fuji |
| landscape_city_skyline | 城市天际线 | 6 | 城市 / 蓝调 / 广角 | 24mm·f8.0·1/30s·ISO200·WB tungsten·EV-0.3·LUT cinematic |
| landscape_rice_terrace_mist | 梯田晨雾 | 6 | 田园 / 雾气 / 米绿 | 35mm·f8.0·1/60s·ISO100·WB daylight·EV+0.3·LUT mist |
| landscape_desert_starry_night | 沙漠星空银河 | 12 | 夜空 / 银河 / 长曝 | 14mm·f2.8·25s·ISO3200·WB tungsten·EV0·LUT twilight |
| landscape_autumn_maple_forest | 秋色枫林 | 12 | 秋林 / 顺光 / 暖橙 | 50mm·f4.0·1/200s·ISO100·WB daylight·EV+0.3·LUT warm_film |

**通用场景指南**
- 光线方向：日出顺光、雪山侧光 90°、海岸逆光、林间散光
- 拍摄距离：远景为主，焦段 14–70mm
- 道具：三脚架、ND/CPL 滤镜、快门线
- 最佳时间：日出 05:00–06:30 / 蓝调时刻 17:30–18:30 / 银河 22:00–02:00
- 贴士：风光优先小光圈 f8–f11；长曝必上三脚架；HDR 拍摄大光比

---

## 三、美食 Food

主打"食物的故事感与食欲感"。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| food_cafe_breakfast | 咖啡馆早餐平铺 | 0 | 平铺 / 顶光 / 暖白 | 35mm·f5.6·1/125s·ISO400·WB daylight·EV+0.3·LUT warm_film |
| food_japanese_washoku | 日式和食定食 | 0 | 侧俯 / 侧光 / 木色 | 50mm·f4.0·1/100s·ISO400·WB daylight·EV+0.3·LUT fuji |
| food_afternoon_tea_sweets | 下午茶甜点特写 | 0 | 特写 / 逆光 / 暖粉 | 50mm·f2.8·1/160s·ISO200·WB daylight·EV+0.5·LUT pastel |
| food_street_snacks | 街头小吃烟火 | 0 | 街头 / 顺光 / 颗粒 | 35mm·f4.0·1/200s·ISO400·WB tungsten·EV+0.3·LUT vintage |
| food_homestyle_dinner | 家常料理俯拍 | 6 | 俯拍 / 顶光 / 暖色 | 35mm·f5.6·1/100s·ISO400·WB cloudy·EV+0.3·LUT warm_film |
| food_michelin_plating | 米其林精致摆盘 | 6 | 特写 / 侧光 / 暗调 | 50mm·f2.8·1/125s·ISO400·WB daylight·EV-0.3·LUT cinematic |
| food_hotpot_late_night | 火锅夜宵热气 | 6 | 俯拍 / 暖光 / 烟雾 | 35mm·f4.0·1/80s·ISO800·WB tungsten·EV+0.3·LUT rouge |
| food_baking_process | 烘焙过程手作 | 12 | 过程 / 侧光 / 暖白 | 50mm·f2.8·1/125s·ISO400·WB daylight·EV+0.3·LUT warm_film |

**通用场景指南**
- 光线方向：平铺顶光 90°、侧俯侧光 45°、特写逆光 180°
- 拍摄距离：0.3–1m
- 道具：木质砧板、亚麻餐布、银餐具、新鲜食材、手冲壶
- 最佳时间：自然光 10:00–11:00 / 14:00–16:00
- 贴士：俯拍桌面简洁，特写虚化背景；热食趁热拍热气

---

## 四、街拍 Street

主打"城市切片与决定性瞬间"，无人像主体，强调环境叙事。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| street_urban_avenue | 都市街头切片 | 0 | 街角 / 顺光 / 鲜艳 | 35mm·f5.6·1/250s·ISO100·WB daylight·EV+0.3·LUT vivid |
| street_subway_corridor | 地铁通道通勤 | 0 | 通道 / 顶光 / 对称 | 24mm·f4.0·1/60s·ISO400·WB fluorescent·EV-0.3·LUT cool_film |
| street_market_bustle | 市场烟火气 | 0 | 市场 / 顺光 / 暖色 | 35mm·f4.0·1/200s·ISO400·WB cloudy·EV+0.3·LUT warm_film |
| street_rainy_night | 雨夜街景反光 | 0 | 雨夜 / 路灯 / 反光 | 35mm·f2.8·1/60s·ISO800·WB tungsten·EV-0.3·LUT cinematic |
| street_night_market_lights | 夜市灯火 | 6 | 夜市 / 暖光 / 颗粒 | 35mm·f2.8·1/60s·ISO1600·WB tungsten·EV+0.3·LUT vintage |
| street_architecture_geometry | 建筑几何线条 | 6 | 建筑 / 顺光 / 极简 | 24mm·f8.0·1/250s·ISO100·WB daylight·EV-0.3·LUT standard |
| street_old_town_alley | 老城弄堂 | 6 | 弄堂 / 散光 / 复古 | 35mm·f4.0·1/100s·ISO200·WB cloudy·EV-0.3·LUT vintage |
| street_corner_cafe | 街角咖啡馆 | 12 | 街角 / 侧光 / 暖调 | 50mm·f2.8·1/160s·ISO200·WB daylight·EV+0.3·LUT warm_film |

**通用场景指南**
- 光线方向：街头顺光、通道顶光、夜市暖光、建筑侧光 90°
- 拍摄距离：2–10m，多带环境
- 道具：无（环境本身即主体）
- 最佳时间：07:00–09:00 / 16:00–18:00 / 夜市 19:00 后
- 贴士：扫街快门 ≥1/250s 抓拍瞬间；几何构图启用网格辅助线

---

## 五、夜景 Night

主打"暗夜中的光"，长曝光、星轨、车轨、霓虹。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| night_city_skyline_lights | 城市夜景天际线 | 0 | 蓝调 / 长曝 / 广角 | 24mm·f8.0·8s·ISO100·WB tungsten·EV-0.3·LUT cinematic |
| night_starry_milky_way | 星空银河拱桥 | 0 | 银河 / 长曝 / 冷调 | 14mm·f2.8·25s·ISO3200·WB tungsten·EV0·LUT twilight |
| night_car_light_trails | 车灯光轨长曝 | 0 | 车轨 / 长曝 / 红黄 | 24mm·f11·15s·ISO100·WB tungsten·EV-0.3·LUT cinematic |
| night_neon_street | 霓虹街景冷暖 | 0 | 霓虹 / 冷暖 / 颗粒 | 35mm·f2.8·1/60s·ISO800·WB tungsten·EV-0.3·LUT cyberpunk |
| night_riverside_moonlight | 江畔月夜 | 6 | 月光 / 长曝 / 冷蓝 | 35mm·f4.0·10s·ISO200·WB tungsten·EV-0.7·LUT twilight |
| night_architecture_light | 夜景建筑灯光 | 6 | 建筑 / 长曝 / 几何 | 24mm·f8.0·5s·ISO100·WB tungsten·EV-0.3·LUT cinematic |
| night_fireworks_bloom | 烟花绽放长曝 | 6 | 烟花 / 长曝 / 暖色 | 35mm·f11·4s·ISO100·WB daylight·EV-0.3·LUT warm_film |
| night_water_reflection | 夜景水景倒影 | 12 | 倒影 / 长曝 / 镜面 | 24mm·f8.0·10s·ISO100·WB tungsten·EV-0.3·LUT cyan |

**通用场景指南**
- 光线方向：城市灯光多向、月光顶光、烟花爆点
- 拍摄距离：远景为主，焦段 14–35mm
- 道具：三脚架（必备）、快门线、手电筒补光
- 最佳时间：蓝调时刻 18:00–18:40 / 深夜 22:00 后
- 贴士：长曝必上三脚架；夜景启用 nightMode + nightExposureTime；蓝调时刻拍城市最佳

---

## 六、微距 Macro

主打"细微之处的奇观"。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| macro_flower_petal | 花朵花瓣细节 | 0 | 花瓣 / 侧光 / 柔和 | 100mm·f4.0·1/200s·ISO200·WB daylight·EV+0.3·LUT pastel |
| macro_insect_wing | 昆虫翅膀纹理 | 0 | 翅膀 / 逆光 / 通透 | 100mm·f5.6·1/250s·ISO400·WB daylight·EV+0.5·LUT fuji |
| macro_water_droplet | 水滴露珠折射 | 0 | 露珠 / 逆光 / 折射 | 100mm·f8.0·1/200s·ISO200·WB daylight·EV+0.3·LUT cyan |
| macro_leaf_veins | 植物叶脉细节 | 0 | 叶脉 / 侧光 / 墨绿 | 100mm·f5.6·1/160s·ISO200·WB daylight·EV-0.3·LUT fuji |
| macro_jewelry_detail | 珠宝首饰特写 | 6 | 首饰 / 顶光 / 闪亮 | 100mm·f8.0·1/125s·ISO200·WB daylight·EV+0.3·LUT vivid |
| macro_snow_crystal | 雪花结晶 | 6 | 雪花 / 顶光 / 冷调 | 100mm·f11·1/160s·ISO400·WB daylight·EV+0.7·LUT cool_film |
| macro_butterfly_scale | 蝴蝶鳞片微观 | 12 | 鳞片 / 侧光 / 鲜艳 | 100mm·f8.0·1/200s·ISO400·WB daylight·EV+0.3·LUT vivid |
| macro_spider_web_dew | 清晨蛛网露珠 | 12 | 蛛网 / 逆光 / 通透 | 100mm·f5.6·1/200s·ISO200·WB daylight·EV+0.5·LUT cyan |

**通用场景指南**
- 光线方向：花瓣侧光 90°、翅膀逆光 180°、露珠逆光 180°、首饰顶光
- 拍摄距离：0.1–0.3m，最近对焦距离
- 道具：微距镜头（100mm）、环形灯、反光板、三脚架
- 最佳时间：清晨 06:00–08:00（露珠）/ 全天室内
- 贴士：微距景深极浅，光圈 f5.6–f11；启用 manual 对焦更精准

---

## 七、静物 Still-life

主打"器物的呼吸感与生活美学"。

| ID | 名称 | 价格 | 风格定位 | 关键参数摘要 |
| --- | --- | --- | --- | --- |
| still_life_minimal_desk | 极简桌面 | 0 | 极简 / 侧光 / 米白 | 50mm·f4.0·1/125s·ISO200·WB daylight·EV+0.3·LUT pastel |
| still_life_literary_desk | 文艺书桌 | 0 | 书桌 / 侧光 / 暖调 | 50mm·f2.8·1/100s·ISO400·WB cloudy·EV+0.3·LUT warm_film |
| still_life_vintage_objects | 复古物件陈列 | 0 | 复古 / 侧光 / 颗粒 | 50mm·f4.0·1/100s·ISO400·WB tungsten·EV-0.3·LUT vintage |
| still_life_flower_arrangement | 花艺布置 | 0 | 花艺 / 侧光 / 鲜艳 | 50mm·f2.8·1/160s·ISO200·WB daylight·EV+0.3·LUT vivid |
| still_life_perfume_display | 香水陈列 | 6 | 香水 / 逆光 / 通透 | 50mm·f2.8·1/160s·ISO200·WB daylight·EV+0.5·LUT pastel |
| still_life_coffee_gear | 咖啡器具 | 6 | 器具 / 侧光 / 暖调 | 50mm·f4.0·1/125s·ISO400·WB daylight·EV+0.3·LUT warm_film |
| still_life_handicraft | 手作工艺 | 12 | 手作 / 侧光 / 暖白 | 50mm·f4.0·1/125s·ISO400·WB daylight·EV+0.3·LUT fuji |
| still_life_seasonal_decor | 季节装饰 | 12 | 季节 / 顶光 / 暖色 | 50mm·f4.0·1/100s·ISO400·WB cloudy·EV+0.3·LUT warm_film |

**通用场景指南**
- 光线方向：侧光 45°–90°、逆光 180°（香水/花艺）、顶光 90°（季节装饰）
- 拍摄距离：0.3–1m
- 道具：亚麻布、木质托盘、干花、书籍、陶瓷器皿
- 最佳时间：窗光 10:00–11:00 / 14:00–16:00
- 贴士：背景虚化突出主体，留白多；色彩控制在 3 色以内

---

## 附录 A：模板字段填写规范

每套模板需对齐 [PhotoTemplate](../../lumira-app/src/types/template.ts) 接口，落地为独立 TS 文件（如 `portrait_atmosphere_sunset_backlight.ts`）并注册到 [templates/index.ts](../../lumira-app/src/data/templates/index.ts)。

| 字段块 | 必填项 | 备注 |
| --- | --- | --- |
| meta | id / name / author / version / category / classification / tags / price / cover / description | id 全小写下划线；cover 走 picsum.photos/seed/{id} |
| composition | overlayType / subjectFrame / opacity / aspectRatio / description | aspectRatio 推荐 '3:4'（人像/美食）或 '16:9'（风光/夜景） |
| pose | silhouette / position / scale / rotation / description | 静物/风光可填占位 silhouette |
| camera | exposureCompensation / iso / shutterSpeed / whiteBalance / flashMode / focusMode | 长曝模板需补 nightMode + nightExposureTime |
| sceneGuide | lightDirection / shootingDistance / background / props / bestTime / tips | 道具 ≤4 项；tips 3–4 条 |
| postProcess | cropRatio / color / smoothStrength / sharpen / vignette / grain / lut | LUT 选择参照 LutPreset 枚举 |

## 附录 B：分类与子分类映射（classification.style）

| 分类 | 子分类 style 值 | 备注 |
| --- | --- | --- |
| portrait | atmosphere / fresh / hongkong / emotion / chinese / street-portrait | 新增 6 个子分类 |
| landscape | epic / nature / city / astro | 风光按场景分 |
| food | overhead / closeup / process / street | 美食按拍法分 |
| street | casual / geometry / night / retro | 街拍按风格分 |
| night | cityscape / astro / trail / neon | 夜景按主题分 |
| macro | nature / detail / object | 微距按对象分 |
| still-life | minimal / vintage / floral / product | 静物按风格分 |

---

## 待办

- [ ] 用户预览本文档并确认分类与模板列表
- [ ] 按确认后的列表批量生成 78 个 TS 模板文件
- [ ] 更新 `templates/index.ts` 注册新模板
- [ ] 设计每个模板的 silhouette 资源 key
- [ ] 验证 picsum.photos seed 命名不冲突
