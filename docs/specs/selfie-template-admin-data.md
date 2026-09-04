# 自拍类模板 · 后台表单填充数据

> 用途：在后台管理（`lumira-server/packages/admin`）「照片模板」创建/编辑向导中，按本表逐字段填写即可成模板。
> 本批共 **23 个自拍模板**，全部为\*\*前置（自拍）\*\*相机方向，覆盖 4 大风格族 + 2026 潮流 + 韩系松弛。

***

## 一、填写说明（必读）

后台表单是 6 步向导。本文档每个模板按步骤组织，标注字段值；凡未标注的字段按「默认值」即可。字段名与 `template-form.tsx` 完整一致：

| 步骤          | 表单字段                                                                                                                                                                                                                         |
| ----------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Step1 基本信息  | `name`、`category`、`classificationMajorStyle`、`classificationSubStyle`、`classificationMethod`、`price`、`description`、`shortDesc`、`ambienceSeasons/Weathers/TimeTones`、`author`、`tags`、`referenceSource`、`sortOrder`、`isActive` |
| Step2 封面与剪影 | 上传 `封面/效果图`（首张即封面），每个姿势填 `name/description/cameraDirection/silhouetteType/positionX/positionY/scale/rotation`                                                                                                                |
| Step3 构图    | `overlayType`、`gridType`、`subjectFrameX/Y/W/H`、`aspectRatio`、`opacity`、`compositionDescription`                                                                                                                              |
| Step4 相机参数  | `exposureCompensation`、`isoMode`、`iso`、`shutterSpeed`、`whiteBalance`、`whiteBalanceK`、`flashMode`、`focusMode`、`lensType`、`lensSuggestion`                                                                                     |
| Step5 场景引导  | `lightDirection`、`shootingDistance`、`background`、`props`、`bestTime`、`tips`                                                                                                                                                   |
| Step6 后期处理  | `cropRatio`、`lut`、`systemFilter`、色彩区、`smoothStrength/sharpen/vignette/grain`、`fillLightEnabled/Color/Intensity`                                                                                                              |

> `tags`、`props`、`tips` 在表单里是**逗号/换行分隔**的字符串，提交后自动转数组——在文档里我用顿号分隔，粘贴时改为英文逗号即可。

***

## 二、字段枚举字典（下拉取值）

### Step3 构图

- `overlayType`：`rule_of_thirds`（三分法）/ `golden_ratio`（黄金分割）/ `diagonal`（对角线）/ `grid`（网格）/ `leading_lines`（引导线）/ `center`（居中）/ `none`

- `aspectRatio`：`fullscreen` / `3:4` / `4:3` / `16:9` / `1:1` / `9:16`

- `gridType`/`subjectFrame`：可选，不启用留空

### Step4 相机

- `isoMode`：`auto` / `manual`

- `whiteBalance`：`daylight` / `cloudy` / `shade` / `tungsten` / `fluorescent` / `custom`

- `flashMode`：`off` / `on` / `auto` / `torch`

- `focusMode`：`auto` / `manual` / `continuous`

- `lensType`：供参考；`lensSuggestion`：`wide` / `main` / `telephoto` / `ultra_wide`

### Step2 姿势

- `silhouetteType`：`builtin`（内置）/ `image`（上传图）/ `svg`

- `cameraDirection`：`front`（前置·自拍）/ `back`（后置）/ 留空=跟随用户

- `positionX/Y`：0~~1（相对坐标）；`scale`：0.3~~4.0；`rotation`：−45\~45°

### Step3 ambience

- `seasons`：`spring` / `summer` / `autumn` / `winter`

- `weathers`：`sunny` / `cloudy` / `overcast` / `rain` / `snow` / `fog`

- `timeTones`：`goldenHour` / `day` / `night` / `warm` / `cool`

### Step6 LUT 滤镜

`none`(原图) / `cinematic`(电影感) / `vintage`(复古胶片) / `warm_film`(暖色胶片) / `cool_film`(冷色胶片) / `pastel`(柔色) / `fuji`(富士感) / `portrait` / `japanese` / `japanese_fresh` / `cream`(奶油) / `cyberpunk` / `night_cyber` / `hk_neon`(港霓虹) / `sepia_classic`(棕古) / `mist`(薄雾) / `rouge`(胭脂) / `twilight`(暮色) / `cyan`(青调) / `noir` / `fine_art_bw`(黑白艺术) / `silver`(银灰) / `morandi`(莫兰迪) / `muted_gray`(灰调) / `heavy_film`(重胶片)

### Step6 补光 fillLight

- `fillLightColor`：十六进制色（`#RRGGBB`），提交后存为不透明 ARGB

- `fillLightIntensity`：0\~1

***

## 三、各模板通用默认值（未标注即用此项）

| 字段                                           | 默认值                                                                   |
| -------------------------------------------- | --------------------------------------------------------------------- |
| `author`                                     | Lumira                                                                |
| `sortOrder` / `isActive`                     | 默认依次递增 / 勾选启用                                                         |
| `silhouetteType`                             | `image`（上传剪影图）                                                        |
| `posePositionX/Y`                            | 各姿势单独给出                                                               |
| `composition.overlayType`                    | `center`（自拍主体居中）                                                      |
| `camera.isoMode` / `focusMode` / `flashMode` | `auto` / `auto` / `off`                                               |
| `camera.exposureCompensation`                | 各模板给出                                                                 |
| `postProcess.color` 高级项                      | 未标明的 `highlights/shadows/blackPoint/clarity/vibrance/brilliance` 留空不填 |
| `systemFilter`                               | `none`（不启用）                                                           |
| `fillLightEnabled`                           | `false`（仅夜间/背光模板置 `true`）                                             |

***

## 四、模板数据

> 分类说明：`category`/`classificationMajorStyle`/`classificationSubStyle`/`classificationMethod` 都必须是后台「分类管理」里已存在的项。若下列风格键未创建，请先在分类管理中新增，再回填对应 key。`method`（四级）可留空。

### ◆ 模板 1 · 晴空奶油窗边少女自拍

**Step1 基本信息**

- `name`：晴空奶油窗边少女自拍

- `category`：portrait

- `classificationMajorStyle`：sweet\_healing（元气治愈）｜`classificationSubStyle`：去填 `cream_window_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置摄像头正面自拍，整体柔亮低饱和奶油色调。脸部均匀受光、肤色清透水润带轻微光泽，背景为白色纱帘透进的晴日侧光，光比 2:1，带一点过曝氛围感。人物面带甜笑或俏皮歪头，唇色上提，肤色呈暖调奶油粉。机位与眼平齐或略高 5°，手机举屏右同时挡一点脸更显自然。后期保留皮肤细腻质感，不做过度磨皮。

- `shortDesc`：阳光懒懒趴在窗边，奶油肌甜到发亮☀️（17 字）

- `ambienceSeasons`：spring, summer, autumn｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 甜美, 奶油肌, 窗边, 元气

- `referenceSource`：小红书「奶油肌」「窗边自拍」热门模板；甜系元气自拍教程

**Step2 封面与剪影**（上传封面部即第一张效果图；每个姿势上传对应剪影图）

- 姿势1 `name`：封面·捧脸呲牙笑｜`description`：双手捧住脸颊两侧，手肘内收，头微向屏右倾+5°，眼睛弯成月牙笑，视线看镜头。｜`front`｜`0.5,0.55,2.4,0`

- 姿势2 `name`：对镜比心回眸｜`description`：手机举在屏右比心挡半脸，另一手屏左胸前比心，身体侧转15°回头甜笑。｜`front`｜`0.5,0.55,2.6,0`

- 姿势3 `name`：托下巴眨眼｜`description`：单肘撑台面色缘，单手托下巴，另一手自然垂放，一只眼俏皮眨眼，头微低+3°。｜`front`｜`0.5,0.5,2.5,0`

**Step3 构图**

- `overlayType`：center｜`gridType`：留空

- `subjectFrame`：x0.22 y0.12 w0.56 h0.78

- `aspectRatio`：1:1｜`opacity`：0.30

- `compositionDescription`：1:1 方幅，主体居中占画幅 60% 左右，头顶留白约 1/10，机位平视略高 5°；第三张半身近景可适当放大主体。

**Step4 相机参数**

- `exposureCompensation`：+0.5｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：daylight｜`whiteBalanceK`：5500｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：侧光（90°），来自屏幕左前方门窗方向，柔光透过纱帘，皮肤高光柔和，光比约 2:1。

- `shootingDistance`：0.4-0.7m（前置近景特写/半身）

- `background`：白色纱帘/木色窗台/浅米色墙面/布艺沙发靠背

- `props`：白色抱枕, 马克杯, 小花束, 兔子发箍, 圆框眼镜

- `bestTime`：晴天 15:00-17:00 或室内自然光时段

- `tips`：前置直拍开「自然光」优先级最高；逆光时用屏幕补光提亮脸部；笑要笑到眼睛、脸颊带一点点婴儿肥；后期只做轻磨皮保留毛孔纹理

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：cream｜`systemFilter`：none

- `color`：brightness+4 / contrast-3 / saturation+5 / temperature+3 / tint 0（高级项留空）

- `smoothStrength`：20｜`sharpen`：10｜`vignette`：8｜`grain`：0

- `fillLightEnabled`：true｜`fillLightColor`：#FFE8C8｜`fillLightIntensity`：0.5

***

### ◆ 模板 2 · 多巴胺彩色甜心对镜自拍

**Step1 基本信息**

- `name`：多巴胺彩色甜心对镜自拍

- `category`：portrait｜`classificationMajorStyle`：sweet\_healing｜`classificationSubStyle`：去填 `dopamine_mirror_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置对镜自拍，高饱和明快色调。背景为彩色毛绒/糖果色墙面或贴满卡通贴纸的镜子。脸部腮红明显、甜蜜大笑，肤色明快健康。彩色小物（糖果色头巾、彩色项链、玩偶）作前景或肩部点缀。机位平视，手机举屏侧挡半脸更自然，镜像感强。整体如糖果色广告海报，情绪是「快乐到飞起」。

- `shortDesc`：满屏彩色泡泡甜到冒泡🧸 元气全开（13 字）

- `ambienceSeasons`：spring, summer｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 甜心, 彩色, 对镜, 高饱和

- `referenceSource`：小红书「多巴胺穿搭」「对镜自拍」热门模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·对镜比耶｜`description`：右手举手机屏右、左手屏左比耶贴脸，露出彩色腕表，俏皮吐舌，头向屏左倾。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：抱玩偶抿嘴笑｜`description`：双手把彩色玩偶贴脸，抿嘴眯眼笑，身体前倾靠近镜头。｜`front`｜`0.5,0.5,2.3,0`

- 姿势3 `name`：叉腰眨眼｜`description`：一手叉腰一手举手机，头发彩色发夹点缀，对镜 wink + 露齿笑。｜`front`｜`0.47,0.52,2.5,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，主体大而靠前，机位平视，背景彩色高饱和铺满，人物约占画面 65%。

**Step4 相机参数**

- `exposureCompensation`：+0.3｜`isoMode`：auto｜`iso`：160｜`shutterSpeed`：1/250

- `whiteBalance`：daylight｜`whiteBalanceK`：5200｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：顺光/环顶光，正面均匀，不开闪光灯，靠环境高饱和。

- `shootingDistance`：0.3-0.6m

- `background`：糖果色墙/贴纸镜面/彩色纱帘/玩偶墙

- `props`：彩色头巾, 蝴蝶结发夹, 糖果色项链, 圆框彩虹眼镜, 毛绒玩偶

- `bestTime`：室内任意明亮时段

- `tips`：正面均匀光即可，优先在明亮房间；腮红和唇色要饱和才出「多巴胺」感；用屏幕补光弱档；后期 saturation 可 +5\~8

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：fuji｜`systemFilter`：none

- `color`：brightness+4 / contrast+5 / saturation+8 / temperature+2 / tint 0

- `smoothStrength`：18｜`sharpen`：12｜`vignette`：5｜`grain`：8

- `fillLightEnabled`：false

***

### ◆ 模板 3 · 夜色胶片逆光阴郁自拍

**Step1 基本信息**

- `name`：夜色胶片逆光阴郁自拍

- `category`：portrait｜`classificationMajorStyle`：emo\_film｜`classificationSubStyle`：去填 `film_noir_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，低饱和青灰冷调胶片质感，强逆光从屏幕后方/侧面打亮发丝与肩线轮廓，脸部略暗带侧光补亮清晰五官。光比 4:1，画面四周自然暗角。氛围慵懒安静，表情冷淡微抬眼、嘴唇轻抿，不看镜头或半垂眸。胶片颗粒中等明显，阴影偏青、高光偏暖一点。适合夜窗、路灯、烛光等弱光环境。

- `shortDesc`：光从背后漏进来，把轮廓描成朦胧的梦🌙（16 字）

- `ambienceSeasons`：all（spring, summer, autumn, winter）｜`ambienceWeathers`：cloudy, overcast, rain, fog｜`ambienceTimeTones`：night, cool, goldenHour

- `tags`：人像, 自拍, 胶片, 逆光, 冷调, 情绪

- `referenceSource`：小红书「胶片氛围感」「逆光情绪照」热门模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·侧脸垂眸｜`description`：手机举屏右，头微低-3° 半垂眼，视线偏向镜头一侧不看镜，肩膀放松。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：回眸雾气抬眸｜`description`：背对光源，头回眸约-135°，双眼略湿润抬眸看向镜头，发丝被逆光打亮。｜`front`｜`0.45,0.5,2.4,0`

- 姿势3 `name`：抱膝窗边无表情｜`description`：蹲坐窗台抱膝，下巴搭膝上，眼神放空看镜头外，冷感。｜`front`｜`0.4,0.5,2.2,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.18 y0.1 w0.64 h0.82（留上方暗部）

- `compositionDescription`：3:4 竖幅，主体居中偏下，上部留暗部空间营造空旷感，逆光轮廓为视觉重心。

**Step4 相机参数**

- `exposureCompensation`：-0.5｜`isoMode`：auto｜`iso`：400｜`shutterSpeed`：1/60

- `whiteBalance`：shade｜`whiteBalanceK`：6500（冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：逆光/侧逆光（135°-180°），轮廓光打亮发丝，脸部用弱屏幕补光。

- `shootingDistance`：0.4-0.8m

- `background`：深色窗帘/夜晚路灯斑驳的窗/逆光的楼道/烛光房间

- `props`：透明玻璃杯, 蜡烛, 深色素T, 耳机线, 半开的书

- `bestTime`：夜晚 19:00 后或黄昏逆光时段

- `tips`：逆光时脸部开一档屏幕补光避免死黑；找发丝/耳廓能有光边的光源；后期 grain 25 颗粒 + 冷调降温 + 加暗角营造胶片情绪

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：heavy\_film｜`systemFilter`：none

- `color`：brightness-3 / contrast+8 / saturation-10 / temperature-6 / tint+3（阴影偏青可 clarity+5 / highlights-15 / shadows+8）

- `smoothStrength`：10｜`sharpen`：15｜`vignette`：30｜`grain`：25

- `fillLightEnabled`：true｜`fillLightColor`：#CFE4FF｜`fillLightIntensity`：0.4

***

### ◆ 模板 4 · 雾蓝清晨窗边素冷自拍

**Step1 基本信息**

- `name`：雾蓝清晨窗边素冷自拍

- `category`：portrait｜`classificationMajorStyle`：emo\_film｜`classificationSubStyle`：去填 `mist_blue_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，整体偏雾蓝灰冷调，窗外阴天/清晨弱光漫射进来，脸部受光均匀偏柔、肤色冷白通透。背景为起雾/磨砂的玻璃窗，有虚化色块感。神情淡然内敛，唇色偏裸，眼神柔和带一丝疏离。低饱和、中等颗粒，桌面物件虚化增加纵深感。

- `shortDesc`：清晨的第一缕雾蓝，把心事揉软了🌫️（14 字）

- `ambienceSeasons`：spring, autumn, winter｜`ambienceWeathers`：overcast, fog, rainy｜`ambienceTimeTones`：cool, day

- `tags`：人像, 自拍, 清冷, 雾蓝, 窗边, 静谧

- `referenceSource`：小红书「清冷感」「雾蓝氛围」自拍模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·托腮望窗外｜`description`：一手托腮扶窗沿，视线望向窗外不聚焦镜头，侧脸线条清晰。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：低头掖发梢｜`description`：单手把耳侧发别到耳后，头微低-3°，垂眸看手机屏幕。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：双肘搭窗静看｜`description`：双肘撑窗台、双手交叠托下巴，眼神平静看镜头，冷感。｜`front`｜`0.5,0.5,2.3,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.30

- `subjectFrame`：x0.18 y0.12 w0.64 h0.8

- `compositionDescription`：3:4 竖幅，主体居中，窗外起雾玻璃占上部做留白，弱化地平线。

**Step4 相机参数**

- `exposureCompensation`：+0.2｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/125

- `whiteBalance`：cloudy｜`whiteBalanceK`：6000（偏冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：漫射柔光，顺窗外（0°），均匀无硬影。

- `shootingDistance`：0.4-0.7m

- `background`：起雾玻璃窗/灰白窗帘/浅灰素墙

- `props`：白瓷杯, 雾蓝针织开衫, 泛黄的书, 晨间薄雾窗外景

- `bestTime`：清晨 6:00-8:00 或阴天白天

- `tips`：玻璃起雾时用哈气后擦拭留出取景空隙；优先纯自然漫射光避免直射硬光；神情以「安静」为主，不用挤笑

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：mist｜`systemFilter`：none

- `color`：brightness0 / contrast+4 / saturation-8 / temperature-5 / tint+3（可 shadows+6 提冷灰）

- `smoothStrength`：12｜`sharpen`：10｜`vignette`：20｜`grain`：20

- `fillLightEnabled`：false

***

### ◆ 模板 5 · 涂鸦墙直闪酷拽辣妹自拍

**Step1 基本信息**

- `name`：涂鸦墙直闪酷拽辣妹自拍

- `category`：portrait｜`classificationMajorStyle`：urban\_trend｜`classificationSubStyle`：去填 `graffiti_baddie_selfie` 或留空｜`classificationMethod`：留空

- `price`：40

- `description`：前置屏幕强补光模拟机顶直闪，硬光从正前打亮主体、压暗涂鸦墙背景，人物轮廓清晰、皮肤哑光带高光点。表情拽酷：微挑单眉、抿嘴或轻微歪口，眼神向上看镜头有俯视感。金属饰品（墨镜、项链、铆钉）出现锐利反光。低饱和冷灰调 + 细颗粒，都市街头感。穿搭核心：黑超短背心+铆钉链条裤+多层银项链+窄框黑墨镜。

- `shortDesc`：直闪一怼，拽味当场拉满🖤（11 字）

- `ambienceSeasons`：spring, summer, autumn｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：night, cool

- `tags`：人像, 自拍, 辣妹, 直闪, 涂鸦, 酷感

- `referenceSource`：小红书「Y2K直闪」「酷girl自拍」「辣妹模板」；千禧回潮摄影

**Step2 封面与剪影**

- 姿势1 `name`：封面·墨镜单手挡脸｜`description`：右手举手机屏右挡半脸，左手比 V 贴颧骨，头微抬+5°，透过墨镜看镜头。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：叉腰下压嘴角｜`description`：双手叉腰肩微斜，下压嘴角歪头+3° 挑眉，拽感。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：抓衣领回眸｜`description`：单手抓胸前衣领往后扯，头回眸-135° 单挑眉看镜头。｜`front`｜`0.45,0.5,2.3,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.22 y0.1 w0.56 h0.8

- `compositionDescription`：1:1 方幅，主体居中约占 60%，头顶留白约 1/8，机位平视略低 5° 显气场，背景涂鸦墙满铺。

**Step4 相机参数**

- `exposureCompensation`：+0.2｜`isoMode`：auto｜`iso`：320｜`shutterSpeed`：1/125

- `whiteBalance`：daylight｜`whiteBalanceK`：5200｜`flashMode`：torch（屏幕补光强亮）｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：正面直闪硬光（0°，用屏幕补光顶墙挡光形成硬质），光比约 4:1，阴影浓黑边缘锐利。

- `shootingDistance`：0.3-0.6m（近距才有硬光感）

- `background`：粉黑涂鸦墙/银灰卷帘门/水泥墙/贴满贴纸的镜面

- `props`：黑超墨镜, 多层银项链, 铆钉手环, 工装上衣, 银色发夹

- `bestTime`：夜晚或室内暗光（需压背景）；夜间 19:00-23:00

- `tips`：屏幕补光开满且拉近手机，靠光衰减压暗背景；哑光底妆避免油光破硬光；金属饰品要多才有直闪锐利反光点

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：cinematic｜`systemFilter`：none

- `color`：brightness+2 / contrast+12 / saturation-10 / temperature-4 / tint 0（可 clarity+10 / highlights-10）

- `smoothStrength`：15｜`sharpen`：30｜`vignette`：25｜`grain`：22

- `fillLightEnabled`：true｜`fillLightColor`：#FFFFFF｜`fillLightIntensity`：0.9

***

### ◆ 模板 6 · 暗夜霓虹紫调酷girl自拍

**Step1 基本信息**

- `name`：暗夜霓虹紫调酷girl自拍

- `category`：portrait｜`classificationMajorStyle`：urban\_trend｜`classificationSubStyle`：去填 `neon_baddie_selfie` 或留空｜`classificationMethod`：留空

- `price`：40

- `description`：前置自拍，夜晚街头霓虹（紫/蓝/粉）为背景光，脸部用中性屏幕补光提亮五官。背景灯牌虚化成彩色光斑，人物边缘有霓虹色描边。表情冷冽：单眉微挑、嘴角冷静，眼神犀利看镜头。高对比、背景压暗、肤色偏冷。运动街头/夜跑氛围，酷感十足。

- `shortDesc`：霓虹灯牌染紫黑夜，冷酷到骨子里💜（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：cloudy, overcast, rain｜`ambienceTimeTones`：night, cool

- `tags`：人像, 自拍, 酷girl, 霓虹, 夜景, 高对比

- `referenceSource`：小红书「霓虹自拍」「夜跑酷girl」「夜晚街头照」热门模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·拉帽檐压脸｜`description`：拉低连帽卫衣帽檐半遮眼，单挑眉，视线从帽檐下看镜头。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：手比心挑衅｜`description`：一手举手机屏右，另一手比耶抵下巴，歪嘴笑一丝。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：侧身回眸墨镜｜`description`：身体侧转，墨镜回望镜头，霓虹光在镜片上反光成线。｜`front`｜`0.45,0.5,2.3,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：1:1｜`opacity`：0.35

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，主体居中偏下，背后霓虹灯牌虚化为彩色光斑铺满，视觉重心在人物轮廓与镜片反光。

**Step4 相机参数**

- `exposureCompensation`：-0.3｜`isoMode`：auto｜`iso`：800｜`shutterSpeed`：1/80

- `whiteBalance`：shade｜`whiteBalanceK`：7000（冷紫）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：背景霓虹光 + 正面屏幕补光主光（0°），人物边缘有彩色轮廓。

- `shootingDistance`：0.3-0.6m

- `background`：霓虹灯牌/夜跑街头/灯箱/紫色暗巷

- `props`：墨镜, 连帽卫衣, 耳机, 金属链条包, 荧光色小物

- `bestTime`：夜晚 19:00 后（霓虹亮起）

- `tips`：找有彩色灯箱背景，脸部用屏幕补光提亮避免和环境光糊在一起；服饰选深色反衬霓虹边缘光

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：hk\_neon｜`systemFilter`：none

- `color`：brightness0 / contrast+10 / saturation+2 / temperature-6 / tint+5（可 highlights-8 / shadows+5）

- `smoothStrength`：12｜`sharpen`：25｜`vignette`：25｜`grain`：20

- `fillLightEnabled`：true｜`fillLightColor`：#E6E6FA（冷紫）｜`fillLightIntensity`：0.5

***

### ◆ 模板 7 · 晨光裸肌奶白床沿自拍

**Step1 基本信息**

- `name`：晨光裸肌奶白床沿自拍

- `category`：portrait｜`classificationMajorStyle`：home\_healing｜`classificationSubStyle`：去填 `bare_glow_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，柔和的清晨窗光从侧面/上方洒进来，肤色裸透水润（伪素颜妆或素颜），色调偏暖白、低对比、清透。背景为柔和棉被、浅色素床单/枕头，画面温馨慵懒。表情惬意微眯眼、带浅浅睡意笑，肩颈放松，头发微乱更有生活感。轻颗粒，无浓墨重彩，治愈系。

- `shortDesc`：晨光叫醒裸肌，奶香小面包出炉🌞（13 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm, goldenHour

- `tags`：人像, 自拍, 裸肌, 晨光, 软糯, 居家

- `referenceSource`：小红书「素颜自拍」「清晨氛围感」「床沿照」热门模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·侧卧枕手眯眼笑｜`description`：侧躺在枕头上，手垫脸下，双眼微眯，晨光洒脸上。｜`front`｜`0.5,0.55,2.4,0`

- 姿势2 `name`：半坐揉眼伸懒腰｜`description`：半坐床头，一手揉眼作刚醒状，头发微乱，浅浅笑。｜`front`｜`0.5,0.5,2.3,0`

- 姿势3 `name`：抱被角嘟嘴｜`description`：把被角拉到鼻尖，只露眼睛，弯眼甜笑，软糯。｜`front`｜`0.5,0.52,2.5,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.22 y0.12 w0.56 h0.78（侧卧/半坐）

- `compositionDescription`：1:1 方幅，主体居中占 60%，上方留棉被与晨光的留白，光从床侧打亮面部，柔和无硬影。

**Step4 相机参数**

- `exposureCompensation`：+0.5｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：daylight｜`whiteBalanceK`：5500｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：侧光（45°-90°），来自床侧窗户，柔光穿透，光比约 2:1。

- `shootingDistance`：0.3-0.5m

- `background`：浅色棉被/白色枕头/米色床头/床尾素色床单

- `props`：白色棉被, 枕头, 马克杯热饮, 猫咪(可选), 绒拖鞋

- `bestTime`：清晨 7:00-9:00 侧窗光最柔和

- `tips`：优先靠窗不背光；素颜靠后期轻磨皮即可，保留毛孔更真实；被角挡脸制造「只露眼睛」的甜感

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：cream｜`systemFilter`：none

- `color`：brightness+5 / contrast-4 / saturation-2 / temperature+4 / tint 0

- `smoothStrength`：22｜`sharpen`：8｜`vignette`：10｜`grain`：10

- `fillLightEnabled`：true｜`fillLightColor`：#FFF5E6｜`fillLightIntensity`：0.3

***

### ◆ 模板 8 · 奶茶慵懒居家奶猫自拍

**Step1 基本信息**

- `name`：奶茶慵懒居家奶猫自拍

- `category`：portrait｜`classificationMajorStyle`：home\_healing｜`classificationSubStyle`：去填 `milk_tea_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，整体奶茶色/奶咖暖调，柔和室内光均匀漫射，肤色温润带淡粉。背景为米白/奶咖色调的家居（沙发、抱枕、针织毯），慵懒惬意。表情软萌：微微嘟嘴、眯眼笑或安静看镜头，头微微倾斜，小动作（抱杯、摸猫、拢发）都是治愈感。低对比、轻磨皮、温暖治愈。

- `shortDesc`：一杯奶茶一只猫，午后专用来躺平🧋（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 居家, 奶猫, 慵懒, 治愈

- `referenceSource`：小红书「居家自拍」「奶咖氛围」「下班宅家」热门模板

**Step2 封面与剪影**

- 姿势1 `name`：封面·双手捧奶茶杯｜`description`：双手捧奶茶靠近胸前，抿吸管翘嘴角，眼弯成月牙，头向屏左倾。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：抱猫侧头蹭脸｜`description`：怀里抱猫，脸蹭猫毛，半垂眼享受表情（猫可后续合成）。｜`front`｜`0.5,0.5,2.4,0`

- 姿势3 `name`：双膝坐下趴沙发边｜`description`：盘腿坐沙发、双手叠搭靠背上，下巴搁手背，望向镜头软笑。｜`front`｜`0.5,0.52,2.3,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，主体居中占 65%，背景奶咖色居家虚化，暖调铺满，氛围治愈。

**Step4 相机参数**

- `exposureCompensation`：+0.4｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/160

- `whiteBalance`：daylight｜`whiteBalanceK`：5200（暖）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：室内散射暖光（0°-60° 混合），无硬影。

- `shootingDistance`：0.3-0.6m

- `background`：米白沙发/奶咖针织毯/暖木茶几/大抱枕

- `props`：奶茶, 猫咪, 针织开衫, 抱枕, 毛绒毯, 木托盘

- `bestTime`：午后 14:00-17:00 室内自然光

- `tips`：暖调的白织灯或窗光均可；表情走「乖、软、萌」路线，避免挤笑；猫是加分项，没有可用玩偶替代

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：japanese\_fresh｜`systemFilter`：none

- `color`：brightness+4 / contrast-2 / saturation+2 / temperature+6 / tint 0

- `smoothStrength`：20｜`sharpen`：8｜`vignette`：8｜`grain`：12

- `fillLightEnabled`：true｜`fillLightColor`：#FFE8C8｜`fillLightIntensity`：0.4

***

## 4B · 2026 潮流系列（模板 9-16）

> 依据当前抖音/小红书热门趋势整理：清冷感 / 粉彩瓷釉 / 水光肌·晨露 / 港风胶片 / 新中式 / 黑布林甜酷 / 红丝绒千金 / 云上舞白。

### ◆ 模板 9 · 灰调清冷伪素颜特写自拍

**Step1 基本信息**

- `name`：灰调清冷伪素颜特写自拍

- `category`：portrait｜`classificationMajorStyle`：misty\_cool｜`classificationSubStyle`：去填 `cool_minimal_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置特写自拍，整体低饱和冷调、克制做减法，妆感哑光微雾面、保留原生气孔。眼影只用浅灰/浅咖消肿，眼线只画眼尾小段略微上扬，唇妆锁定裸灰/灰粉/浅茶，下唇稍深做渐变。面部神情淡然、眼神不讨好，微侧脸朝镜头，嘴角平直。光线柔冷、无硬影，肤色冷白通透，氛围是「刚刚好」的清冷高级感。

- `shortDesc`：淡而有层次，冷而不疏离🥶（11 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：overcast, cloudy, fog｜`ambienceTimeTones`：cool, day

- `tags`：人像, 自拍, 清冷感, 伪素颜, 低饱和, 克制

- `referenceSource`：2026 清冷感妆容风潮；小红书「清冷感自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·四分之三侧脸微垂眼｜`description`：头转约 40°，鼻梁侧面线条清晰，视线略微下垂不聚焦镜头。｜`front`｜`0.5,0.58,2.7,0`

- 姿势2 `name`：眉眼近景·单手拢发｜`description`：放大到眉眼特写，单手把侧发别到耳后，露英气眉骨，眼神冷定。｜`front`｜`0.5,0.6,2.9,0`

- 姿势3 `name`：伸颈回望·无表情｜`description`：稍微前倾肩颈，回望镜头，全脸无表情走冷感。｜`front`｜`0.5,0.52,2.5,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：1:1｜`opacity`：0.35

- `subjectFrame`：x0.18 y0.12 w0.64 h0.78

- `compositionDescription`：1:1 方幅，眼部对焦特写占上三分之一，下方留灰白留白，压迫感与呼吸感并存。

**Step4 相机参数**

- `exposureCompensation`：+0.2｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：cloudy｜`whiteBalanceK`：6200（冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔冷漫射光（0°-45°），窗边天然冷自然光最佳。

- `shootingDistance`：0.25-0.45m（特写/近景）

- `background`：浅灰素墙/冷白纱帘/灰粉床单/水泥质感墙

- `props`：冷调裸色口红, 浅灰针织, 银质细链, 素色发夹

- `bestTime`：阴天白天或清晨冷光段

- `tips`：妆感宁淡勿浓，粉底薄涂别厚盖；眼妆只消肿不堆色；微雾面底 + 后期轻度磨皮保留毛孔，做「克制」不做「精致假面」

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：muted\_gray｜`systemFilter`：none

- `color`：brightness0 / contrast+4 / saturation-12 / temperature-6 / tint 0（可 highlights-8）

- `smoothStrength`：15｜`sharpen`：12｜`vignette`：15｜`grain`：15

- `fillLightEnabled`：false

***

### ◆ 模板 10 · 粉彩瓷釉少女自拍

**Step1 基本信息**

- `name`：粉彩瓷釉少女自拍

- `category`：portrait｜`classificationMajorStyle`：sweet\_healing｜`classificationSubStyle`：去填 `porcelain_pastel_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，配方=50% 中性色底 + 40% 粉彩色 + 10% 高光。底妆清透奶油肌，腮红用杏白/灰裸粉统一全脸，眼妆低饱和粉彩晕染，唇部偏裸粉。神情软糯甜带一点俏皮，眼神清澈，氛围柔和治愈。画面边缘像「空气感雾化」，色彩边界模糊、有水流动的朦胧透气感。

- `shortDesc`：粉与青在水里晕开，把春色揉进脸🌸（13 字）

- `ambienceSeasons`：spring, summer｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 粉彩风, 瓷釉, 柔和, 氛围

- `referenceSource`：抖音×WGSN 2026 粉彩风趋势；小红书「粉彩瓷釉妆」

**Step2 封面与剪影**

- 姿势1 `name`：封面·双手托腮甜笑｜`description`：双手微托腮，眼弯成月牙，头微倾+3°，望向镜头。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：遮一半脸·眨眼｜`description`：单手举起遮半张小脸，另一只眼俏皮 wink，露一点唇色。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：捏脸颊·嘟嘴｜`description`：双手从下往上托着脸颊轻轻一捏，鼓一点腮帮，微嘟嘴。｜`front`｜`0.5,0.5,2.4,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，主体居中占 60%，画面边缘强力「揉化」出空气感，色彩边界模糊。

**Step4 相机参数**

- `exposureCompensation`：+0.4｜`isoMode`：auto｜`iso`：160｜`shutterSpeed`：1/250

- `whiteBalance`：daylight｜`whiteBalanceK`：5400｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔亮漫射光（90° 侧光 + 顺光混合），无硬影、带气孔。

- `shootingDistance`：0.3-0.6m

- `background`：粉彩渐变墙/薄纱帘/磨砂玻璃/淡粉床单

- `props`：粉彩针织, 小雏菊, 奶白马克杯, 缎面发带

- `bestTime`：晴天上午 9:00-11:00 室内柔光

- `tips`：全脸主色不超过两种粉色系；高光只在鼻梁/苹果肌点缀别铺满；后期把边缘使劲「揉」出空气感、降低锐度

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：pastel｜`systemFilter`：none

- `color`：brightness+4 / contrast-3 / saturation+4 / temperature+2 / tint 0

- `smoothStrength`：24｜`sharpen`：5｜`vignette`：5｜`grain`：8

- `fillLightEnabled`：false

***

### ◆ 模板 11 · 晨露水光肌透亮自拍

**Step1 基本信息**

- `name`：晨露水光肌透亮自拍

- `category`：portrait｜`classificationMajorStyle`：sweet\_healing｜`classificationSubStyle`：去填 `dewdrop_glass_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，极致清透「玻璃肌」原生水光，保留原生纹理与健康光泽。眼妆低饱和、几乎无感，唇部薄涂润泽裸粉，整体轻薄透气。神情明澈自信、带一点元气笑意，肤色水润泛光。光线柔亮，画面干净通透，主打「健康好气色」而非磨皮假面。

- `shortDesc`：晨露滚在叶上，皮肤能掐出水💧（11 字）

- `ambienceSeasons`：spring, summer｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 水光肌, 晨露, 透亮, 原生

- `referenceSource`：2026 晨露精灵妆容趋势；小红书「玻璃肌」「水光肌自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·侧打光露笑｜`description`：自然看向镜头，侧光把苹果肌/鼻梁打出柔亮高光，露齿浅笑。｜`front`｜`0.5,0.58,2.7,0`

- 姿势2 `name`：揉脸·闭眼享受｜`description`：双手轻轻揉一下脸颊，闭眼微仰头，慵懒享受感。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：眨单眼·歪头｜`description`：歪头 +2°，单手比耶放颧骨旁，单眼 wink 元气笑。｜`front`｜`0.47,0.54,2.6,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.12 w0.6 h0.78

- `compositionDescription`：1:1 方幅，主体居中占 65%，光线打亮面部高光区，背景浅米/绿留白，干净通透。

**Step4 相机参数**

- `exposureCompensation`：+0.5｜`isoMode`：auto｜`iso`：160｜`shutterSpeed`：1/250

- `whiteBalance`：daylight｜`whiteBalanceK`：5400｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔亮侧顺光（45°），正面均匀，突出皮肤光泽。

- `shootingDistance`：0.3-0.5m

- `background`：浅米/浅绿素墙/磨砂窗/植物叶影

- `props`：绿叶小盆栽, 玻尿酸精华瓶, 白T, 水杯

- `bestTime`：晴天 8:00-10:00 或明亮房间

- `tips`：妆养合一、只薄粉留纹理；光线要打在苹果肌斜上方显出光泽；后期修图别过度磨皮，保住「能掐出水」的质感

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：portrait｜`systemFilter`：none

- `color`：brightness+5 / contrast-4 / saturation-2 / temperature+2 / tint 0（可 highlights+6）

- `smoothStrength`：20｜`sharpen`：8｜`vignette`：5｜`grain`：6

- `fillLightEnabled`：true｜`fillLightColor`：#FFF5E6｜`fillLightIntensity`：0.3

***

### ◆ 模板 12 · 90年代港风胶片氛围自拍

**Step1 基本信息**

- `name`：90年代港风胶片氛围自拍

- `category`：portrait｜`classificationMajorStyle`：retro\_film｜`classificationSubStyle`：去填 `hk_film_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，90年代港片氛围：偏黄绿/暖洋红复古色调、粗颗粒、轻微漏光与边角柔光。慢门电影感，人物侧光分明、五官立体，低调的复古妆容（红唇或雾面），眉眼有故事感。神情带一点疏离与复古韵味，像旧片镜头里定格的女主角。

- `shortDesc`：胶片一按，退回90年代香港雨夜🎞️（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：rain, overcast, cloudy｜`ambienceTimeTones`：night, goldenHour, warm

- `tags`：人像, 自拍, 港风, 复古, 胶片, 漏光

- `referenceSource`：港风胶片复古风（搜索量 +320%）；小红书「港风自拍」「ccd 复古人像」

**Step2 封面与剪影**

- 姿势1 `name`：封面·侧脸藏半脸｜`description`：侧转约 60°，半张脸隐入阴影，露鼻梁与下颌轮廓，眼神望向暗处。｜`front`｜`0.48,0.55,2.6,0`

- 姿势2 `name`：手扶墙面·回眸｜`description`：背靠花砖墙/老式卷帘门，转身回眸看镜头，复古港风。｜`front`｜`0.45,0.5,2.4,0`

- 姿势3 `name`：撩发·半垂眸｜`description`：单手撩起侧发，头微低-3° 半垂眸，唇色微启。｜`front`｜`0.5,0.5,2.5,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.18 y0.12 w0.64 h0.8

- `compositionDescription`：3:4 竖幅，主体居中偏左，侧脸留影调层次，上部留旧墙/卷帘门线条作背景，复古构图。

**Step4 相机参数**

- `exposureCompensation`：-0.3｜`isoMode`：auto｜`iso`：400｜`shutterSpeed`：1/100

- `whiteBalance`：tungsten｜`whiteBalanceK`：2800（暖洋红）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：侧光（90°）带顶光，硬中带柔，边缘漏光；可用霓虹侧光点缀。

- `shootingDistance`：0.3-0.6m

- `background`：老式花砖墙/旧式卷帘门/霓虹橱窗/深色木门

- `props`：复古墨镜, 红唇, 丝巾, 老式耳环, 汽水瓶

- `bestTime`：黄昏/夜晚，人造复古光为准

- `tips`：偏黄绿调滤镜味；后期加漏光或光斑；颗粒 + 边缘暗角要够，别处理得太干净现代

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：vintage｜`systemFilter`：none

- `color`：brightness-2 / contrast+6 / saturation-6 / temperature+4 / tint+8（可 highlights-10）

- `smoothStrength`：12｜`sharpen`：15｜`vignette`：30｜`grain`：30

- `fillLightEnabled`：true｜`fillLightColor`：#FFE8C8｜`fillLightIntensity`：0.4

***

### ◆ 模板 13 · 新中式清冷国风意境自拍

**Step1 基本信息**

- `name`：新中式清冷国风意境自拍

- `category`：portrait｜`classificationMajorStyle`：chinese\_style｜`classificationSubStyle`：去填 `new_chinese_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，新中式氛围：以潘通 2026 年度色「云上舞白」与浅墨灰为基调，低饱和、大留白、画意留白构图。妆面清透淡雅、柳叶细眉、点绛或哑光裸唇，神情从容娴静。背景带中式元素（圆月窗、竹影、山水屏风、书法墙），人物占画面一侧，像一幅雅致的水墨小品。

- `shortDesc`：裙裾微动，眉眼似水，留白即意境🪷（13 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, cool

- `tags`：人像, 自拍, 新中式, 国风, 意境, 留白

- `referenceSource`：2025-2026 新中式国风趋势；小红书「新中式自拍」「国风氛围」

**Step2 封面与剪影**

- 姿势1 `name`：封面·持簪侧目｜`description`：单手抚发簪/伸手理鬓，头微侧回眸，眼神沉静。｜`front`｜`0.46,0.52,2.4,0`

- 姿势2 `name`：半遮面·团扇｜`description`：手持团扇/折扇半遮脸，只露眉眼，垂眸静望。｜`front`｜`0.5,0.5,2.3,0`

- 姿势3 `name`：倚窗·望竹｜`description`：侧倚圆月窗，目光望向窗外竹影，人物居画面一侧留白。｜`front`｜`0.42,0.5,2.2,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.2 y0.12 w0.6 h0.78

- `compositionDescription`：3:4 竖幅，人物居一侧，对面大面积留白，中式窗/屏风线条作背景，一幅水墨小品的构图。

**Step4 相机参数**

- `exposureCompensation`：+0.3｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/160

- `whiteBalance`：cloudy｜`whiteBalanceK`：5800｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔光侧光（90°）+ 适量留白，像自然窗光透过窗棂。

- `shootingDistance`：0.4-0.7m

- `background`：圆月窗/竹影屏风/水墨书法墙/山水纱帘

- `props`：团扇, 折扇, 发簪, 玉坠, 中式蒲扇

- `bestTime`：白天自然光或室内素雅布景

- `tips`：画面做减法、多留白；用侧光雕出鼻梁下颌光影；神情「静、稳、雅」，别笑太开

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：morandi｜`systemFilter`：none

- `color`：brightness+2 / contrast+4 / saturation-8 / temperature-2 / tint 0

- `smoothStrength`：14｜`sharpen`：10｜`vignette`：12｜`grain`：20

- `fillLightEnabled`：false

***

### ◆ 模板 14 · 黑布林紫调甜酷自拍

**Step1 基本信息**

- `name`：黑布林紫调甜酷自拍

- `category`：portrait｜`classificationMajorStyle`：urban\_trend｜`classificationSubStyle`：去填 `dark_plum_sweet_cool_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，新复古甜酷：哑光深紫/灰黑眼影晕染眼窝，弱化烟熏的攻击性，再加细闪片点睛；唇色包裹味深紫或浆果红，锁骨/肩部带细闪。神情带一丝拽的甜、微微勾嘴角。背景偏暗、有一点旧 disco/复古背景虚化，情绪张力丰富。

- `shortDesc`：把复古disco灯球点亮在眼底🍇（12 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：cloudy, overcast, night｜`ambienceTimeTones`：night, cool

- `tags`：人像, 自拍, 黑布林, 甜酷, 复古, 闪片

- `referenceSource`：2026 黑布林甜心复古妆容趋势；小红书「甜酷自拍」「复古 disco」

**Step2 封面与剪影**

- 姿势1 `name`：封面·挑眉勾唇｜`description`：单眉微挑，嘴角轻勾一侧，自信甜酷感，正对镜头。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：手指比心·眼角闪片特写｜`description`：放大眼部特写，手指比耶斜贴眼角，闪片反光。｜`front`｜`0.5,0.6,2.8,0`

- 姿势3 `name`：背靠镜·回眸｜`description`：背靠复古背景回眸，肩露锁骨细闪，眼神带刺。｜`front`｜`0.45,0.5,2.3,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.35

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，主体居中偏下，暗紫背景虚化成 disco 光斑，眼部闪片为视觉焦点。

**Step4 相机参数**

- `exposureCompensation`：-0.2｜`isoMode`：auto｜`iso`：400｜`shutterSpeed`：1/100

- `whiteBalance`：shade｜`whiteBalanceK`：6500（冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔和顶光 + 正面屏幕补光，突出闪片折射。

- `shootingDistance`：0.3-0.5m

- `background`：暗紫波纹背景/复古disco灯球虚化/深色丝绒

- `props`：细闪眼妆, 浆果色唇釉, 丝绒上衣, 金属耳饰

- `bestTime`：夜晚或暗房补光

- `tips`：眼妆打底铺色→叠闪片只在眼尾/卧蚕别铺满；顶光让闪片会反光更有「灯球」味

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：twilight｜`systemFilter`：none

- `color`：brightness-2 / contrast+8 / saturation+2 / temperature-4 / tint+5

- `smoothStrength`：12｜`sharpen`：18｜`vignette`：25｜`grain`：22

- `fillLightEnabled`：true｜`fillLightColor`：#E6E6FA｜`fillLightIntensity`：0.4

***

### ◆ 模板 15 · 红丝绒千金高定自拍

**Step1 基本信息**

- `name`：红丝绒千金高定自拍

- `category`：portrait｜`classificationMajorStyle`：editorial\_glam｜`classificationSubStyle`：去填 `red_velvet_heiress_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，大女主高定质感：钧净无瑕底妆打底，眼、唇、颊点缀酒红与金属光泽，重点在拉开利落的一抹红唇——先薄涂打底、沿唇线描出利落轮廓、唇中叠加深色得饱满丝绒。妆面简洁、一个亮点拉升气场，神情自信从容、微抬下颌，眼神笃定，像刚从高定秀场走出来。

- `shortDesc`：姐不在江湖，江湖有姐的传奇👑（13 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：night, warm

- `tags`：人像, 自拍, 千金, 红唇, 高定, 高级感

- `referenceSource`：2026 红丝绒千金妆容趋势；小红书「千金感自拍」「高定妆」

**Step2 封面与剪影**

- 姿势1 `name`：封面·微抬下颌冷看｜`description`：下巴微抬 +5°，眼神自上而下一瞥，红唇轻启。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：手腕搭肩·侧瞥｜`description`：一手自然搭另一肩，侧头 30° 瞥向镜头，千金气场。｜`front`｜`0.48,0.5,2.4,0`

- 姿势3 `name`：指腹轻抚唇·回眸｜`description`：伸食指点下唇中，眉眼上扬看向镜头。｜`front`｜`0.5,0.52,2.5,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：3:4｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：3:4 竖幅，主体居中占 60%，简洁高级背景衬红唇为唯一视觉亮点。

**Step4 相机参数**

- `exposureCompensation`：+0.2｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：daylight｜`whiteBalanceK`：5300｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔亮正面 + 轮廓侧光，突出红唇与金属光泽，背景简洁。

- `shootingDistance`：0.35-0.6m

- `background`：丝绒幕布/极简高级灰/大面积留白/深褐木饰

- `props`：酒红/正红唇釉, 金属耳坠, 丝绒连衣裙, 珍珠项链, 高跟细带

- `bestTime`：室内布光或黄昏暖光

- `tips`：全妆一个重点（红唇），其它部位克制；唇线要利落清晰别晕染廉价；姿态挺直、眼神笃定才撑得起「千金感」

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：rouge｜`systemFilter`：none

- `color`：brightness+2 / contrast+7 / saturation+6 / temperature+3 / tint 0

- `smoothStrength`：14｜`sharpen`：18｜`vignette`：12｜`grain`：10

- `fillLightEnabled`：true｜`fillLightColor`：#FFE8C8｜`fillLightIntensity`：0.5

***

### ◆ 模板 16 · 云上舞白留白清透自拍

**Step1 基本信息**

- `name`：云上舞白留白清透自拍

- `category`：portrait｜`classificationMajorStyle`：misty\_cool｜`classificationSubStyle`：去填 `cloud_dancer_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，以大面积暖白与低饱和灰为主、极致留白的高级感。妆容以潘通 2026 年度色「云上舞白」为灵魂：雾感底妆、留白式构图，人物只占一小角，四周留出通透留白。神情安宁松弛，眼神清澈，像一张会呼吸的高级胶片；细碎银闪只在眼角点缀一点点。整体是「淡极生艳」的空灵感。

- `shortDesc`：不是纯白是暖白，让美从呼吸里透出☁️（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, warm, cool

- `tags`：人像, 自拍, 云上舞白, 留白, 高级感, 素净

- `referenceSource`：潘通 2026 年度色「云上舞白」；小红书「留白高级感」「空灵感自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·小角落侧身回看｜`description`：人物置于画面一侧做回眸，四周大面积留白，极简构图。｜`front`｜`0.4,0.5,2.2,0`

- 姿势2 `name`：低眉·静看远处｜`description`：半垂眼望向镜头之外，神情安宁，留白感强。｜`front`｜`0.45,0.52,2.4,0`

- 姿势3 `name`：单手触脸·放空｜`description`：单手垂放触脸，眼神放空，整个人像挂在留白里的剪影。｜`front`｜`0.5,0.5,2.3,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.2 y0.14 w0.5 h0.7（人物偏小偏一侧，重留白）

- `compositionDescription`：3:4 竖幅，人物仅占画面一部，四周大面积通透留白，极简留白式构图。

**Step4 相机参数**

- `exposureCompensation`：+0.5｜`isoMode`：auto｜`iso`：160｜`shutterSpeed`：1/250

- `whiteBalance`：daylight｜`whiteBalanceK`：5600｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：纯净漫射光（无硬影、无强烈高光），环境通透明亮。

- `shootingDistance`：0.35-0.6m（多留画面空间）

- `background`：暖白/灰白空墙/半透纱帘/极简素底

- `props`：白衬衫, 奶白针织, 极简金属细链, 云朵摆件

- `bestTime`：晴天自然光（不过曝）

- `tips`：构图做减法和留白、人物别占满画面；妆容低饱和干净、留出呼吸感；眼神要「空」而不要「木」

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：silver｜`systemFilter`：none

- `color`：brightness+5 / contrast-2 / saturation-10 / temperature+2 / tint 0

- `smoothStrength`：16｜`sharpen`：6｜`vignette`：0｜`grain`：12

- `fillLightEnabled`：false

***

## 4C · 韩系松弛系列（模板 17-23）

> 韩系「松弛感」核心：低饱和大地色、轻薄原生底妆、宽松慵懒穿搭、生活化动作、眼神松弛不抢戏。

### ◆ 模板 17 · 燕麦奶咖松弛通勤自拍

**Step1 基本信息**

- `name`：燕麦奶咖松弛通勤自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `oat_milky_commute_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系松弛通勤感：低饱和燕麦奶咖色调、轻薄奶油底妆，肤色温润收敛。穿搭为宽松西装外套/奶咖针织+直筒裤，头发微慵懒随性。神情松弛不聚焦镜头，带一点日常的「今天随便出门」感，动作生活、画面不摆拍。光线柔亮，整体质感是「随手定格的通勤日常」。

- `shortDesc`：一杯燕麦拿铁的浓度，刚好装下今天🧋（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 韩系, 松弛感, 奶咖, 通勤

- `referenceSource`：小红书「韩系松弛感」「通勤自拍」「燕麦拿铁氛围」

**Step2 封面与剪影**

- 姿势1 `name`：封面·低头看咖啡｜`description`：低头看向手中的燕麦拿铁，发丝垂落半遮脸，眼神专注不盯镜头。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：随手拨发·侧脸｜`description`：单手随意撩一下侧发，头微侧 30°，视线略偏向镜头外。｜`front`｜`0.48,0.52,2.5,0`

- 姿势3 `name`：抱着袋子·半蹲｜`description`：单肩背包/抱纸袋顺手整理，半蹲身体前倾，松弛自然。｜`front`｜`0.5,0.5,2.3,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：3:4｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：3:4 竖幅，主体居中占 60%，背景奶咖色虚化，生活化不刻意构图。

**Step4 相机参数**

- `exposureCompensation`：+0.3｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/160

- `whiteBalance`：daylight｜`whiteBalanceK`：5400（暖）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔和窗侧光（0°-60°），通勤咖啡店/办公室光源，无硬影。

- `shootingDistance`：0.35-0.6m

- `background`：暖木咖啡台/奶咖色墙面/布艺沙发/窗外街景虚化

- `props`：燕麦咖啡, 帆布包, 宽松针织, 皮质单肩包

- `bestTime`：上午 9:00-11:00 咖啡店自然光

- `tips`：妆感轻薄不厚重，裸棕大地色眼影；穿搭选宽松剪裁才有松弛感；动作往「生活流」走，别直挺挺摆拍

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：japanese\_fresh｜`systemFilter`：none

- `color`：brightness+3 / contrast-2 / saturation-4 / temperature+4 / tint 0

- `smoothStrength`：16｜`sharpen`：8｜`vignette`：8｜`grain`：10

- `fillLightEnabled`：true｜`fillLightColor`：#FFE8C8｜`fillLightIntensity`：0.3

***

### ◆ 模板 18 · 奶白色珍珠韩系慵懒自拍

**Step1 基本信息**

- `name`：奶白色珍珠韩系慵懒自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `pearl_ivory_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系珍珠奶白调：极低饱和的奶油白/base 白为主色，妆容轻薄润泽、几乎无感，唇部奶杏色。穿搭纯白/米色系（oversize 白衬衫、针织、珍珠耳饰），头发慵懒盘起。神情放松、带一点不经意的笑意，动作自然松弛，画面干净柔和、像柔和奶油质感的杂志照。

- `shortDesc`：像刚剥开的海盐奶油壳，白而温润🦪（12 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 韩系, 珍珠奶白, 慵懒, 高级感

- `referenceSource`：小红书「韩系慵懒」「奶白穿搭」「象牙白自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·托腮放空｜`description`：单手托腮，眼神放空看向窗外，肩膀放松。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：捏衣领·侧头｜`description`：双手揪一下衣领往上拉，头侧 +2°，轻微抿嘴。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：端咖啡·垂眸｜`description`：单手端奶白咖啡杯贴近鼻尖闻香，垂眸享受。｜`front`｜`0.5,0.5,2.4,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.12 w0.6 h0.78

- `compositionDescription`：1:1 方幅，主体居中占 65%，奶白环境留白，柔和奶油质感，不抢眼耐看。

**Step4 相机参数**

- `exposureCompensation`：+0.5｜`isoMode`：auto｜`iso`：160｜`shutterSpeed`：1/250

- `whiteBalance`：daylight｜`whiteBalanceK`：5600｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：纯净柔光（90° 侧光），奶白环境补足亮光，无阴影感。

- `shootingDistance`：0.3-0.5m

- `background`：奶白素墙/白纱帘/极简浅色家居/米色布艺

- `props`：珍珠耳饰, oversize白衬衫, 奶白马克杯, 针织开衫

- `bestTime`：晴天室内柔光

- `tips`：全脸颜色做减法，白+奶+一点杏就够了；材质用针织/纱织添「软」感；眼神要「放空」而非「发呆」，姿态别紧绷

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：cream｜`systemFilter`：none

- `color`：brightness+5 / contrast-3 / saturation-6 / temperature+2 / tint 0

- `smoothStrength`：18｜`sharpen`：6｜`vignette`：6｜`grain`：8

- `fillLightEnabled`：false

***

### ◆ 模板 19 · 韩系清冷白开水松弛自拍

**Step1 基本信息**

- `name`：韩系清冷白开水松弛自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `boring_chic_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系「清净感」：妆容极度清淡（白开水妆）、几乎没有明显色彩，肤色透亮干净；神情平和清冷、微带疏离，不刻意讨好镜头。穿搭简单素净、剪裁流畅。整体像一杯温度刚好的白开水，干净、舒服、不抢眼却耐看。

- `shortDesc`：妆淡得像白开水，却淡出高级感💧（13 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：overcast, cloudy, sunny｜`ambienceTimeTones`：cool, day

- `tags`：人像, 自拍, 韩系, 清冷, 白开水妆, 松弛

- `referenceSource`：小红书/抖音「白开水妆」「清净感妆」「韩系清冷」

**Step2 封面与剪影**

- 姿势1 `name`：封面·平视无表情｜`description`：正面平视镜头，全脸清冷无情绪，呼吸感构图。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：单手插兜·侧瞥｜`description`：一手插衣兜，头侧 30° 瞥向镜头，松弛清冷。｜`front`｜`0.48,0.5,2.4,0`

- 姿势3 `name`：低头掖发·不看镜｜`description`：低头拨弄发梢，视线落在胸口，氛围安静。｜`front`｜`0.5,0.52,2.5,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.12 w0.6 h0.78

- `compositionDescription`：1:1 方幅，主体居中，灰白留白，妆容清淡，画面干净耐看。

**Step4 相机参数**

- `exposureCompensation`：+0.3｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：cloudy｜`whiteBalanceK`：6000（冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔冷漫射光（0°-45°），清透不艳。

- `shootingDistance`：0.35-0.6m

- `background`：米灰素墙/冷白窗光/极简空环境

- `props`：基础白T, 素色针织, 简单银饰

- `bestTime`：阴天自然光

- `tips`：妆感「像没画」；神情清冷却别「木」；留白构图

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：muted\_gray｜`systemFilter`：none

- `color`：brightness+3 / contrast+3 / saturation-10 / temperature-2 / tint 0

- `smoothStrength`：14｜`sharpen`：8｜`vignette`：10｜`grain`：14

- `fillLightEnabled`：false

***

### ◆ 模板 20 · 韩系柔光氛围窗边自拍

**Step1 基本信息**

- `name`：韩系柔光氛围窗边自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `window_aura_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系柔和氛围感：窗边柔光为灵魂，逆光/侧光晕染轮廓、带轻微光晕，画面柔和通透。妆容轻薄润泽、暖调大地色，发丝被光线镀上一层柔边。神情松弛微带笑意，动作自然（倚窗、捧杯），氛围慵懒治愈。中等颗粒，高光过曝一点更有氛围。

- `shortDesc`：把午后阳光穿在身上，一帧就治愈🌤️（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, goldenHour｜`ambienceTimeTones`：day, goldenHour, warm

- `tags`：人像, 自拍, 韩系, 氛围感, 窗边, 柔和

- `referenceSource`：小红书「韩系氛围感」「窗边逆光」「柔光自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·倚窗侧望｜`description`：侧身倚窗，头向窗外微侧，逆光把发丝打亮，氛围感。｜`front`｜`0.48,0.55,2.6,0`

- 姿势2 `name`：捧杯抿嘴·浅笑｜`description`：双手捧一杯热饮贴近下巴，逆光下轻轻抿一口，眼睛弯起。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：半掩窗帘·回眸｜`description`：一只手拉起纱帘一角，回头看向镜头，光线从帘缝漏出。｜`front`｜`0.45,0.5,2.4,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.18 y0.12 w0.64 h0.8

- `compositionDescription`：3:4 竖幅，主体居中，窗光与纱帘占背景，逆光轮廓为氛围重心。

**Step4 相机参数**

- `exposureCompensation`：+0.4｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/160

- `whiteBalance`：cloudy｜`whiteBalanceK`：5800（暖）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：逆光/侧逆光（90°-180°），轮廓柔光，脸部用补光提亮。

- `shootingDistance`：0.4-0.7m

- `background`：透光纱帘/暖木窗台/窗外绿植虚化

- `props`：热拿铁, 针织开衫, 白纱帘, 绿植

- `bestTime`：晴天 15:00-17:00 逆光窗边

- `tips`：逆光别让脸全黑，用屏幕补光兜脸；找发丝/耳廓勾光边的角度

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：mist｜`systemFilter`：none

- `color`：brightness+4 / contrast-2 / saturation-3 / temperature+5 / tint 0（可 highlights+5）

- `smoothStrength`：16｜`sharpen`：8｜`vignette`：12｜`grain`：15

- `fillLightEnabled`：true｜`fillLightColor`：#FFF0D6｜`fillLightIntensity`：0.4

***

### ◆ 模板 21 · 韩系男友视角随性自拍

**Step1 基本信息**

- `name`：韩系男友视角随性自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `bf_view_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系「男友视角」（BF view）：模拟恋人/好友随性抓拍，构图略带随意、有生活感瑕疵（发丝、轻微过曝）。妆容日常清淡、润泽唇色，穿搭家居随性（oversize T 恤/卫衣）。神情自然带笑、偶尔不看镜头，互动感强，松弛得不像在拍照。

- `shortDesc`：不是摆给镜头，是「他随手拍下的你」📱（14 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 韩系, 男友视角, 随性, 日常

- `referenceSource`：小红书/抖音「男友视角」「随身抓拍」「韩式日常」

**Step2 封面与剪影**

- 姿势1 `name`：封面·伸手挡镜头·露笑｜`description`：伸手作势挡镜头 / 比耶，露齿大笑，画面有「你抢我拍的」互动感。｜`front`｜`0.5,0.55,2.7,0`

- 姿势2 `name`：嘟嘴迎镜头｜`description`：微微探头迎向镜头，眨眼或嘟嘴，俏皮松弛。｜`front`｜`0.5,0.52,2.6,0`

- 姿势3 `name`：半遮脸·回眸笑｜`description`：双手举起半遮脸，从指缝露出眉眼，笑意放松。｜`front`｜`0.5,0.5,2.5,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.1 w0.6 h0.8

- `compositionDescription`：1:1 方幅，近镜互动感，构图略带随意、保留生活感。

**Step4 相机参数**

- `exposureCompensation`：+0.4｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：daylight｜`whiteBalanceK`：5500｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：日常柔光，不讲究、近真实生活光。

- `shootingDistance`：0.25-0.5m（近镜互动感）

- `background`：居家客厅/餐桌/窗边床沿，日常场景

- `props`：oversizeT恤, 抱枕, 零食, 手机

- `bestTime`：白天室内自然光

- `tips`：画面别太完美，留生活感；多互动表情（迎镜头、挡脸、大笑）才有「随手抓拍」的甜

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：portrait｜`systemFilter`：none

- `color`：brightness+4 / contrast+2 / saturation+2 / temperature+2 / tint 0

- `smoothStrength`：18｜`sharpen`：10｜`vignette`：6｜`grain`：8

- `fillLightEnabled`：false

***

### ◆ 模板 22 · 韩系高级冷淡松弛杂志自拍

**Step1 基本信息**

- `name`：韩系高级冷淡松弛杂志自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `editorial_indifferent_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系高级冷淡感（大片杂志风）：低饱和冷调、克制留白，肤色收敛干净，妆容极简（裸灰/灰粉仅一点气色）。神情冷淡、眼神疏离有故事感，姿态松弛不讨好。构图像杂志大片：人物居一侧、留灰，光线硬中带柔，质感冷峻高级。

- `shortDesc`：一张脸的镜头感，胜过千军万马📸（13 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：overcast, cloudy, fog｜`ambienceTimeTones`：cool, night

- `tags`：人像, 自拍, 韩系, 高级, 冷淡, 杂志感

- `referenceSource`：小红书「韩系冷感」「杂志大片感」「clear 高级感自拍」

**Step2 封面与剪影**

- 姿势1 `name`：封面·垂眸侧脸｜`description`：头侧 45°、半垂眸，下颌线清晰，冷淡。｜`front`｜`0.48,0.55,2.6,0`

- 姿势2 `name`：倚墙·单腿微屈｜`description`：斜倚墙面/柜沿，双腿自然交叉或微屈，目光放远不看镜。｜`front`｜`0.42,0.5,2.3,0`

- 姿势3 `name`：单手撩发·抬眼｜`description`：单手扬起发梢，抬眼直视镜头，眼神犀利疏离。｜`front`｜`0.5,0.52,2.5,0`

**Step3 构图**

- `overlayType`：rule\_of\_thirds｜`aspectRatio`：3:4｜`opacity`：0.35

- `subjectFrame`：x0.18 y0.12 w0.64 h0.78

- `compositionDescription`：3:4 竖幅，人物居一侧留灰白，像杂志编辑页，冷峻高级构图。

**Step4 相机参数**

- `exposureCompensation`：+0.1｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/200

- `whiteBalance`：cloudy｜`whiteBalanceK`：6300（冷）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：冷调自然光 + 侧影（90°），水墨灰冷环境。

- `shootingDistance`：0.35-0.6m

- `background`：高级灰/深灰素墙, 大面积留白

- `props`：极简西装, 冷调首饰, 素色丝巾

- `bestTime`：阴天或室内冷光

- `tips`：妆感「妈生好皮+一点冷调气色」；神情走「疏离」不要「冷脸凶」；构图多留白像杂志编辑页

**Step6 后期处理**

- `cropRatio`：3:4｜`lut`：silver｜`systemFilter`：none

- `color`：brightness+1 / contrast+6 / saturation-12 / temperature-4 / tint 0（可 clarity+8）

- `smoothStrength`：14｜`sharpen`：16｜`vignette`：15｜`grain`：16

- `fillLightEnabled`：false

***

### ◆ 模板 23 · 韩系周末奶香居家自拍

**Step1 基本信息**

- `name`：韩系周末奶香居家自拍

- `category`：portrait｜`classificationMajorStyle`：korean\_relax｜`classificationSubStyle`：去填 `weekend_home_selfie` 或留空｜`classificationMethod`：留空

- `price`：0

- `description`：前置自拍，韩系居家慵懒感：暖白低饱和、柔和光，妆感素净通透。穿搭为宽松卫衣/针织+棉质，头发慵懒自然披散或低马尾。动作松弛生活（盖毯、捧杯、窝沙发），神情惬意放松带睡意般温柔，氛围治愈像韩剧居家片段，轻颗粒、软糯。

- `shortDesc`：周末的光是懒洋洋的奶白色，连头发都不想绑🏡（15 字）

- `ambienceSeasons`：all｜`ambienceWeathers`：sunny, cloudy, overcast｜`ambienceTimeTones`：day, warm

- `tags`：人像, 自拍, 韩系, 慵懒, 居家, 周末, 治愈

- `referenceSource`：小红书「韩剧居家感」「周末慵懒自拍」「 cozy 居家照」

**Step2 封面与剪影**

- 姿势1 `name`：封面·窝毯侧头｜`description`：裹着针织毯侧头，半靠沙发，眼神温和带笑意。｜`front`｜`0.5,0.55,2.6,0`

- 姿势2 `name`：捧饮·眯眼享受｜`description`：双手捧热饮贴脸，轻轻眯眼，享受午后。｜`front`｜`0.5,0.52,2.5,0`

- 姿势3 `name`：抱抱枕·趴沙发｜`description`：下巴搁抱枕上，眼睛弯成月牙望镜头，软糯。｜`front`｜`0.5,0.5,2.4,0`

**Step3 构图**

- `overlayType`：center｜`aspectRatio`：1:1｜`opacity`：0.30

- `subjectFrame`：x0.2 y0.12 w0.6 h0.78

- `compositionDescription`：1:1 方幅，主体居中占 60%，米白家具与奶咖毯作背景，暖调治愈。

**Step4 相机参数**

- `exposureCompensation`：+0.4｜`isoMode`：auto｜`iso`：200｜`shutterSpeed`：1/160

- `whiteBalance`：daylight｜`whiteBalanceK`：5300（暖）｜`flashMode`：off｜`focusMode`：auto

- `lensType`：main｜`lensSuggestion`：main

**Step5 场景引导**

- `lightDirection`：柔暖窗光（60°-90°），透进纱帘的自然光。

- `shootingDistance`：0.3-0.6m

- `background`：米白沙发, 奶咖毯, 暖木茶几, 大抱枕

- `props`：针织毯, 热饮, 抱枕, 棉质开衫

- `bestTime`：午后 14:00-17:00 室内

- `tips`：整套走「软」「暖」「松」，妆素净、动作不板正；光线能柔就柔，靠窗不背光

**Step6 后期处理**

- `cropRatio`：1:1｜`lut`：japanese\_fresh｜`systemFilter`：none

- `color`：brightness+4 / contrast-3 / saturation-2 / temperature+6 / tint 0

- `smoothStrength`：20｜`sharpen`：6｜`vignette`：6｜`grain`：10

- `fillLightEnabled`：true｜`fillLightColor`：#FFF0D6｜`fillLightIntensity`：0.3

***

## 五、补充说明

- **封面与多效果图**：Step2 里上传的第一张图片自动作为封面（`cover`），其余按 `images` 多效果图入库，App 端展示多图；每张效果图尽量与上述姿势一一对应。

- **剪影图**：这些是新模板，`silhouetteType` 都用 `image`（后续可换内置），需为每个姿势准备一张剪影 PNG；若暂时没有，可先用内置剪影占位，之后在「编辑模板」里替换。

- **分类预置**：文档用到的 `majorStyle`（sweet\_healing / emo\_film / urban\_trend / home\_healing / misty\_cool / retro\_film / chinese\_style / editorial\_glam / korean\_relax）多数是新的，请先在「分类管理」创建后再回填 key。

- **定价**：除模板 5、6（直闪/霓虹，40 金币）外，其余建议免费（0）；可按运营调整。

- **所有模板均为** **`front`** **前置自拍**，套用时 App 自动切换前置摄像头。

