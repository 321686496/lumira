# Lumira 模板制作提示词脚本（v3 — 多姿势 · 多效果图）

> 用途：看到一张或一组有美感/热门风格的照片时，把「照片/组照 + 本脚本」一起发给 AI，
> AI 会输出一套**适配 Lumira App 多姿势 / 多效果图**的可落地模板参数，
> 我照着后台表单（基本信息 / 封面与效果图 / 构图 / 姿势组 / 相机 / 场景引导 / 后期处理）逐栏填写即可。
>
> **v3 相比 v1 的关键变化（仅数据结构层面）**：
> - **多图片输入**：可一次上传多张图，第一张为**封面效果图**，其余为**附加效果图**。
> - **多姿势 `poses`**：每张图对应一个姿势元素——人像给**人物姿势**数据；非人像（食物摆拍 / 风景 / 美学构图等）则姿势退化为「**构图描述**」，并据此给出**构图剪影**建议。
> - **分类仍为四级**（题材 → 大风格 → 子风格 → 方法），与后台分类树能力一致。
> - 业务字段（`price / referenceSource / author / tagIds / sortOrder / isActive`）仍由你自行定义，**不放入输出**。

## 使用步骤

1. 复制下面「最终提示词脚本」整段。
2. 打开任意能传图的 AI（ChatGPT / Gemini / Claude / 豆包等），并上传**一张或多张**参考照片。
3. 把「照片 + 脚本」一起发送。多张图时请按期望的展示顺序排列（**第一张视为封面**）。
4. AI 返回 JSON，按 `name/category/classification → images → poses → composition → camera → sceneGuide → postProcess` 分组照填后台表单；其中 `orientation / framing / lighting / styling` 区块为**分析参考**（用于你理解与校对，其结论已折进对应字段，不直接写入后台）。

## 重要设计约定

- App 受硬件/模块限制，**光圈 / ISO / 快门速度（含长曝光、运动模糊、流轨夜景）真机无法调整**。后台结构仍保留 `isoMode / iso / shutterSpeed` 键（结构对齐），填 `auto / null / null`，仅供记录展示，**不依赖它们做效果补偿**。
- **白平衡已真机实现**（不是参考值）：`camera.whiteBalance`（档位下拉：`daylight / cloudy / shade / tungsten / fluorescent / custom`）+ `camera.whiteBalanceK`（K 值）**可直接精确给出**。AI 应依据原图色温/色偏，给出对应的白平衡档位与 K 值来"还原或刻意保留"色感，**不要再依赖后期 `temperature` 去补偿白平衡**（temperature 只用于细微冷暖微差）。
- 效果本应由不可调参数产生的：能用现有可调参数补偿就补偿（把"参数名 + 数值 + 具体做法"写进 `sceneGuide.tips`）；复现不了就明确写进 `sceneGuide.tips` 说明"真机无法复现，改用 XX 近似"，绝不硬编无法实现的数值。
- **多姿势与多效果图**：`poses` 数组的每个元素**对应一张 `images` 图**（用 `imageIndex` 关联）。头图 = 封面 = `poses[0]`。
  - **人物题材**：每个 `pose` 填**人物姿势数据**（动作 + 四肢位置 + 朝向 + 表情，见三），`silhouette` 给**人物剪影**建议。
  - **非人物题材（食物 / 风景 / 静物 / 街景 / 夜景 / 建筑等）**：该图往往考的就是**构图**。此时 `pose.type = "composition"`，由 `compositionFrame` 精确描述构图骨架（主体位置 / 框架 / 留白 / 引导线 / 对称线 / 切割比例），`silhouette` 给**构图剪影**建议——后台会根据该构图剪影在取景时叠加引导，让用户照着摆出/框出同样的构图。
- **光影**：AI 必须把光影当"结构化分析题"（见二）——拆出光位/辅光轮廓光/软硬/光比/阴影/质感/环境光/色温对比，再**翻译成可调参数的具体数值**放进 `camera` 与 `postProcess`，不能只停在"自然光柔光"这类空话。
- **补光灯（打正面光）**：很多样片是**逆光 / 背景比主体亮 / 主体面部偏暗**才显得有氛围，这种通常靠补光照亮主体正面。AI 必须判断该图**是否依赖补光**：
  - 判断依据：主体被置于强背光 / 大亮背景下仍保留清晰细节、面部或主体正面比背景亮、有明显"补亮感"但光源又在后方。
  - 输出：a) 实拍指引写进 `sceneGuide.tips`——"建议开启补光灯从**屏幕正面**向主体补光，距离约 X m、强度调到 Y"；b) 后期用 `postProcess.fillLight` 模拟打正面光（`enabled:true` + 暖白色 + 强度），作为"没带补光灯时的近似替代"。
  - 若样片本身是**自然顺光 / 不需要补光**，`fillLight.enabled` 置 `false`，不必强加。
- **姿势与方位**：AI 必须用"画面方位坐标系"（以你看到的屏幕为基准，0°=面向镜头，+90°=面向屏幕左，180°=背对，−90°=面向屏幕右）把人物位置与身体/面部/头颈朝向按角度说清（见三）。
- **构图景别与机位**：拍摄前必须先定 `framing`——景别（特写/近景/半身/七分身/全身/大远景）+ 机位（平视/低机位仰拍/高机位俯拍/俯拍平面）+ 主体占比 + 环境分配 + 头顶留白（见三.4）；非人物题材同样要先定景别与机位。
- **主体造型/穿搭**：这套脚本面向**所有大类**通用。人物题材把穿搭拆到层次（上装/下装/衣角掖入或外放/袖子/领口/鞋袜/叠穿 + 配饰/发型妆容）；非人物题材，换成"主体造型、材质、颜色、陈设关系"，并把要点并入一句到顶层 `description`。
- **分类**：后台分类为**四级**（`classification.type` ＝一级题材，与 `category` 同值；`majorStyle / subStyle / method` 为二/三/四级，随后台动态分类树而定）。AI 不知道后台分类 key，`majorStyle / subStyle / method` 只给"风格建议关键词"，落地时在后台下拉里选到最接近项；同时从照片推断**适用季节/天气/时段色调**（`ambience`）与**短简介**（`shortDesc`）。
- **滤镜（重点）**：后台滤镜是**25 个确定的颜色矩阵**（不是抽象名字）。选 `lut` 必须对照「六、滤镜效果参数字典」，按原图"色性/质感"对号入座，并用该表"协同项"去微调 `color`，使成片质感逼近原图；避免 lut 与 color 反向打架。`lut` 与 `systemFilter` 同库、只填其一。
- 剪影 key、系统滤镜、镜头建议等强依赖内置素材的项目，AI 只给"贴合建议"，落地时在后台手动挑选。

---

## 最终提示词脚本

````text
你是一位资深摄影师 + 拍照模板设计师 + 造型/摆姿指导（涵盖人像穿搭，以及静物/美食的摆盘布景、景物/建筑/夜景的主体造型）。正在为「Lumira」拍照 App 设计可复刻的拍照模板。

屏幕上我提供了一张或多张**参考样片**（可含人像、美食、静物、风景、街景、夜景中的任一大类）。请像"拆机"一样逐层分析，并输出一套**适配 Lumira 多姿势 / 多效果图**的模板参数。你的价值在于把"看不出怎么拍"的照片，变成"照着就能填"的具体 JSON。

**多张图时**：第一张是我的**封面效果图（主模板效果）**，其余是**附加效果图**。每张图都要单独产出一个 `poses` 元素（用 `imageIndex` 对应），并在 `images` 里登记每张图。

观察时，请回答下面每一个问题，不允许跳项：
1. 主体是什么（人/景/食物/街景/夜景/物体）→ 拍摄类型？这决定该图用"人物姿势"还是"构图"来描述。
2. 画面里"光"长什么样？有几盏/几处光，分别从哪个方向来，软还是硬，明暗比多大，影子落在哪、方向朝哪、边缘是硬是软、浓度多深？呈现什么物质质感（磨皮/颗粒/高光/光斑/反光）？**判断是否靠补光**：主体是否背对强光源/置于大亮背景中仍清晰发亮，如果有——明确这是"逆光+正面补光"（需要建议补光灯打正面光），还是纯自然顺光（无需补光）。
3. **若主体是人物**：**先定景别**：特写/近景/半身/七分身/全身/大远景，裁到身体哪、主体占多少、头顶留白多少？**再定机位**：平视还是俯拍/仰拍，正面/斜侧/侧面？最后他在画面哪个位置（屏幕左/中/右、上/下、占多大）？用"屏幕"方向说身体朝向、面部朝向——正对镜头还是侧向屏幕左/屏幕右、多大幅度（45/90/135/180）？头颈低/仰/侧没侧？重心在哪条腿，肩线平不平？露在外面的手臂在画面哪一侧、手怎么放、指头放松还是紧张？下肢/腿脚怎么摆？视线看哪、表情流露什么情绪？
   **若主体不是人物（食物/风景/静物等）**：跳过姿势细节，改而抽出"**构图语言**"——主体/趣味点放画面哪个位置、用几分线/对称/框架/引导线组织、留白多少、前后景层次感？
4. 用什么机位/横竖/比例拍的？**量一量样片真实宽高比**（如 4:3、3:4、16:9、9:16、1:1、2:3），作为 `composition.aspectRatio`。主体放大还是留白？有没有引导线/景深层次暗示？主体在画面中的位置与占比（主体框）？
5. 色调是什么氛围？冷暖、饱和度、对比、颗粒、暗角、磨皮感？适合什么季节/天气/时段色调来拍？
6. **主体造型/穿搭到细节**：

## 一、铁律（必须严格遵守）

0. **先量源图比例，再谈一切**。不能把样片的真实宽高比搞错：4:3 就是 4:3、3:4 就是 3:4。**`fullscreen` 只用于"App 内铺满屏幕全屏展示"的比例（通常是竖屏 9:16 或横屏 16:9）**，绝非"随手选的照片比例"。`composition.aspectRatio` ＝ 模板输出/展示比例（建议与源图一致）；`postProcess.cropRatio` ＝ 后期裁剪目标（默认与 aspectRatio 一致，刻意裁剪才不同）。
1. **只输出后台真实存在的字段**，字段名必须与下方「输出格式」完全一致，不多不少。`orientation / framing / lighting / styling` 是**分析参考区块**（让你看懂依据、也用于字段互推），其结论已折进 `pose.description / composition.description / sceneGuide.* / 顶层 description`，不要把它们当成额外提交字段。
2. **只输出 App 真正能生效的参数**。光圈 f 值无此字段；`camera.iso / shutterSpeed` 填 `null`（真机不可调、仅供记录展示），`camera.isoMode` 填 `"auto"`，**不要依赖 ISO / 快门做效果补偿**。**例外：白平衡已实现**——`camera.whiteBalance / whiteBalanceK` 要据原图色温**给精确档位与 K 值**（见二·白平衡）。
3. 效果本应由不可调参数产生的（大光圈浅景深、长曝光流轨等）：
   - 能用现有可调参数接近 → 用 EV/明暗/饱和/颗粒/暗角/拉远背景等补偿，把做法写进 `sceneGuide.tips`（示例："vignette:35 压暗四角聚焦主体；配合构图靠近主体、拉远背景"）；
   - 无法复现 → 明确写进 `sceneGuide.tips` 说明"该效果真机无法实现，改用 XX 近似"，绝不硬编。
4. 模板名称、`description`、`tips` 不得承诺无法实现的效果（不能说"自动虚化背景"）。

## 二、光影分析（必须这样深、这样输出）

先记一条**防反转铁律**：凡是说光源方向、光的落点，一律用"屏幕左/屏幕右/屏幕前/屏幕后"（即以你看着这张照片、像照镜子那样的左右为基准），**严禁用"被摄者自己的左/右"**——那是反的源头。你看到的"光从屏幕左侧来"就是左侧。

把光影当结构化分析题，逐项填满，禁止空话：
- **光位**：主光从**屏幕上哪一侧**来、角度与高度（示例"主光从屏幕偏左上方 45° 来"）。
- **辅光 / 轮廓光**：有没有补光/反光板，有没有逆光勾边（逆光照出头发/肩膀亮边）。
- **光型软硬**：硬光还是柔光、光源面积大小、是否被纱帘/漫反射柔化（硬=边缘锐利、柔=过渡大片）。
- **光比**：明暗反差（高/中/低，尽量给比值示例"约 3:1"）。
- **阴影**：影子落在哪、投向**屏幕哪个方向**、边缘软硬、浓度深浅（示例"鼻影较浓，投在面部偏屏幕左下方，边缘偏硬"）。
- **质感（必须写）**：光影呈现出的物质感——皮肤哑光还是油亮、磨皮柔滑还是保留毛孔纹理；有没有眼神光/发型光/金属高光/玻璃窗格投影/光斑/玻璃反光；头发是高光勾边还是柔光一片。
- **环境光**：背景光/氛围光（窗光、霓虹、台灯暖光等，注明在屏幕哪一侧）。
- **色温对比**：不同光源冷暖对比（示例"主体暖、背景冷"）。

**光影必须落到参数上**：填完后把分析翻译成 `camera` 和 `postProcess` 里的**具体数值**（并让数值与 `sceneGuide.lightDirection` / `bestTime` 一致，不只写气质、丢参数）：
- 光比大/反差强 → 提高 contrast，exposureCompensation 略微负向压暗。
- 高光溢出/过曝发白 → highlights 正向压低（如 highlights 15）或 temperature 调节。
- 阴影很黑/欠曝 → shadows 正向上提 + 适当 exposureCompensation 正向。
- 冷调氛围 → whiteBalanceK 调低（如 4500）+ temperature 负向 + 冷调 LUT。
- 暖调氛围 → whiteBalanceK 调高（如 6500）+ temperature 正向 + 暖调 LUT。
- 质感：皮肤柔滑 → smoothStrength 提高；要保留纹理 → smoothStrength 压低；要胶片颗粒 → grain 提高到 20-40。

**白平衡（已真机实现，必须据原图色温精确给出 `whiteBalance` 档位 + `whiteBalanceK`）**：

先看样片整体色调倾向再定档位；`whiteBalance` 负责"整体色偏的还原/保留"，`whiteBalanceK` 微调到贴合，`temperature` 只做轻微冷暖微差、**不要拿它替代白平衡**：

| 样片观感 | `whiteBalance` 档位 | `whiteBalanceK`（典型） |
|---|---|---|
| 高色温冷调（蓝天、阴影、偏蓝青） | `shade`（阴影） | 7000–7500 |
| 阴天/多云、偏灰冷的自然光 | `cloudy`（阴天） | 6000–6500 |
| 正午/明亮自然光、色感正常 | `daylight`（日光） | 5500 |
| 偏暖、白炽灯/钨丝灯室内 | `tungsten`（白炽灯） | 3200–3500 |
| 荧光灯/日光灯室内、略带绿 | `fluorescent`（荧光灯） | 4000–4200 |
| 想刻意保留/精确微调色感 | `custom`（自定义） | 2000–10000（默 5500，步长 50） |

> 提醒（真机约束，务必遵守）：
> - `whiteBalance` 档位仅 6 个：`daylight / cloudy / shade / tungsten / fluorescent / custom`（无 `auto`）。
> - `whiteBalanceK` 真机范围 **2000–10000、默认 5500、滑块步长 50**；选 `custom` 档时**必须同时给出具体 K 值**，其它档位也可带 K 作微调。
> - K 值是"色温"：数值**越低越偏冷（蓝）**、**越高越偏暖（黄）**；想"清冷"给低 K、想"暖黄"给高 K，与"太阳色温高=暖"的直觉相反，别搞反。

**必须单独判断"是否靠补光打正面光"**（在 `lightingDetail.补光/辅光` 与最终 `fillLight` 都要体现）：
- 若主体处于**强背光 / 大亮背景 / 逆光剪影边缘**却仍被正面照得清晰发亮 → 判定为"**逆光 + 正面补光**"。此时：`sceneGuide.tips` 写"建议开启补光灯，从**屏幕正面**向主体补光"（给出距离与挡位建议，示例"40cm-1m，柔光、亮度约 2000lm"）；同时 `postProcess.fillLight` 开启（`enabled:true` + 暖白或贴合眼色的补光色 + 合适强度），表示"实拍没带补光灯时用它模拟打正面光"。
- 若主体为**自然顺光 / 顶光 / 侧光**且无需照亮暗面 → `fillLight.enabled:false`，不要为了凑字段而强行开补光。
- 补光属于"对图片效果的正面补充"，不是让 AI 硬加；只有照片确实透出"主体被专门照亮点亮"的信息时才启用。

## 三、姿势 / 构图与方位（必须拆到细节）

### 三.1 朝向与位置坐标系（以"你看到的屏幕方向"为唯一基准）

**防反转铁律（最重要一条）**：描述人物朝向、手、脚，一律用"**屏幕左/屏幕右/面向镜头/背对镜头**"，以你作为观看者、看着这张照片时的左右为准；**绝不用"被摄者自己的左/右"**。写完自检：照片里人物的脸朝屏幕右，你就写"面朝屏幕右"，不许写"左"。你若只能看出大致朝向，就写方向词 + 大致档位（0/45/90/135/180），**不要硬编精确度数**。

- **朝向角度**（都以屏幕为基准）：`0° = 面向镜头`；`+90° = 面向屏幕左`；`180° = 背对镜头`；`−90°（或 270°）= 面向屏幕右`。中间归一到 0/±45/±90/±135/180。
- **身体与面部分开给**（bodyFacing / faceFacing），两者角度差 = 脖子扭转量：差 0 = 正身正脸；±90 = 侧身/侧脸；±135~±180 = 侧身回头/回眸。
- **俯仰 headPitch**：低头为负 −、仰头为正 +（−20° = 明显低头，+15° = 微仰）。
- **侧倾 headRoll**：头颈倒向**屏幕左**为负 −、倒向**屏幕右**为正 +。
- **位置 framePosition**：九宫格（左/中/右 × 上/中/下）+ 归一化坐标（0~1，0=左或上，1=右或下）+ 主体占画幅比例。

**标准示例（人物，强制对照这个颗粒度输出）**：
"人物站在画面**右侧**、约居中性偏上 20%，身体较正对镜头略转**+45°（偏屏幕左）**，但面部几乎完全转向**屏幕右**约 **−90°~−135°**，形成'侧身回头'——身体偏左、面部朝屏幕右看，头颈微微倒向**屏幕右 +10°**、下巴 −5° 微收，视线落到镜头左上方的光源。"

**构图示例（非人物，强制对照这个颗粒度输出）**：
"咖啡杯与甜点置于画面上方**1/3 分割线**右侧交叉点附近，桌面斜线从左下贯穿到右上形成引导线，前景刀叉微虚、后景白墙留白占上部 1/3，俯拍 45° 俯视构图，主体约占画幅 55%。"

### 三.2 orientation 必须逐项填满（人物题材；非人物题材可精简主体朝向）

- **framePosition**：九宫格位置 + 归一化坐标 + 占比。
- **bodyFacing**：`type`（正对 / 侧向屏幕左 / 侧向屏幕右 / 背对）+ `azimuth`（角度）。
- **faceFacing**：`type` + `azimuth`（面部朝向）。
- **twist**：头 vs 身体的扭转差与类型（回眸 / 侧身回头 / 正身）。
- **headPitch** / **headRoll**：俯仰角 / 侧倾角（屏幕基准）。
- **gaze**：由 faceFacing 推导出的视线方向，用屏幕词（看镜头 / 看屏幕左 / 看屏幕右下 / 看向屏幕外上方…），必须具体。

### 三.3 poseDetail（人物题材逐项填满 / 非人物渲染成"构图要点"）

- **整体身形**：站/坐/半身/侧靠/躺；重心位置；躯干笔直/前倾/扭腰；肩线朝向（用 bodyFacing 描述身体是偏屏幕左还是右）。
- **上肢（手臂，按画面所看到的位置描述）**：露在画面里的手臂在**屏幕哪一侧**；前臂/上臂大致夹角（如"约90°"）；手腕、手掌朝向（掌心朝镜头/朝下/朝外）；手指细节（弯曲、交叉、放松或抓握）。示例"画面右臂前抬约90°，手肘支在桌面，手指自然松开托腮"。
- **下肢 / 腿脚**：重心在哪条腿；另一条腿的姿态与前后；膝盖朝向；脚的位置与脚尖朝向（屏幕方向词）。示例"重心放在右侧腿，左侧腿微微向前交叉，脚尖朝屏幕前方"。
- **头颈**：面部朝向（faceFacing）+ 俯仰 + 侧倾，示例"面部转向屏幕右约−90°、下巴微收、头颈略向屏幕右倒10°"。
- **视线表情**：视线方向（屏幕词）+ 表情细节，示例"视线朝屏幕左上方看、嘴角微扬、眼神松弛"。
- **情绪**：成片想传达的情绪与氛围（示例"慵懒松弛、午后惬意的感觉"）。
- **互动道具**：与道具/环境的互动动作（示例"指尖轻轻转动杯子"）。

把最能概括的一句写成 `pose.description`（含动作+四肢位置+朝向+表情），供后台"姿势描述"栏直接使用。

### 三.4 构图景别与机位（framing，必须先从「拍什么景别」定调，人像与非人像都要）

**先定景别，再谈细节**。`framing` 逐项填满，禁止跳过：

- **shotSize 景别（必须单选最贴切）**：`特写` / `近景` / `半身` / `七分身` / `全身` / `大远景`。同时用 `shotSizeNote` 说明裁剪锚点。
- **cameraHeight 机位高度（必须单选）**：`平视` / `低机位仰拍` / `高机位俯拍` / `俯拍平面`。
- **cameraAzimuth 机位水平关系**：`正拍` / `斜侧 45°` / `纯侧面`，并结合被摄主体朝向说明。
- **subjectScale 主体占比**：主体占画幅比例（示例"半身像，主体约占画面上部 2/3，下方留桌面"）。
- **environmentRatio 环境交代**：环境/背景占画幅多少（示例"主体 60%、咖啡馆环境 40%"）。
- **headroom 头顶留白**：发顶到画面上缘的距离、裁到身体哪个部位（示例"头顶留一掌宽；发顶距画面上缘约 1/5"）。
- **framingNote**：一句话概括"景别+机位+主体占比+环境分配"。

**范例对照**：
- 半身人像："半身，腰部以上入画；机位平视、镜头略低于眼睛 5°；主体占中部偏上、约占画幅 60%；头顶轻留空；环境淡化到 20% 以下。"
- 全身人像："全身，头顶留 1/4 留白、脚底踩在画面下缘；机位低角度仰拍 15°，显气场；主体占画幅 70%。"
- 桌面美食："俯拍 45° 俯视，主体置上 1/3 分割线右交点，桌面斜引导线贯穿画面，主体占画幅 55%。"
- 把主体/环境的关系讲清楚后，再据此填 `composition.subjectFrame` 的主体框坐标。

## 四、表达要求（细节必须具体、量化、可执行）

- **光线**：必须"从屏幕哪侧来 + 方向角度 + 软硬 + 光比 + 阴影落点/方向/软硬 + 质感"，并映射到 camera/postProcess 数值。
- **景别与机位**：必须先给出 `shotSize` 与 `cameraHeight`，再谈细节；禁止只说"主体位于画面中间"这种不提景别的含糊话。
- **多姿势**：`poses` 数组每项都要有 `imageIndex`（对应某张图）、`type`（people|composition）、`description` 与 `silhouette` 建议。人物题材给人物姿势；非人物题材给构图描述 + 构图剪影建议。
- **主体造型/穿搭**：面向所有大类。人物把穿搭拆到层次（含"衣角是否掖入/外放/打结"这类细节）；非人物改成"主体造型/材质/颜色/陈设"。都要具体到能照着摆。
- **距离 shootingDistance**：具体区间，示例"1.5-2m"。
- **时段 bestTime**：具体时间点，示例"14:00-16:00"，不写"白天"。
- **背景 background / 道具 props**：具体可执行，示例"木质桌 + 白墙 + 绿植 / 咖啡杯、翻开的书"。
- **tips**：每一条都是可执行的动作要领，并负责承载"补偿做法 / 无法复现"说明。
- **顶层 description 简介**：完整可读（类型 + 场景 + 光线 + 穿搭/造型要点 + 适用人群），并入一句穿搭/造型要点。
- **shortDesc 短描述 ≠ 长描述的精简**：它是**情绪化、有代入感的抓眼文案**，独立成文，重点在"让用户想用、提供情绪价值"，不是客观信息的压缩。写法模板＝"画面氛围 + 情绪词 + 轻 emoji"（正例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿；反例：xxx 模板的简洁版描述）。

## 五、可用的参数（只能从这些里选；字段名即后台表单字段）

- 基础：name / category（一级题材）/ classification{type(=category), majorStyle, subStyle, method} / shortDesc / description / ambience{seasons/weathers/timeTones} / tags
  - （`price / referenceSource / author / tagIds / sortOrder / isActive` 由我自行定义，**不要输出**）
- 效果图 images：数组，每项 `{ imageIndex, role(封面|效果图), caption }`
- 多姿势 poses：数组，每项 `{ imageIndex, name?, type(people|composition), description, compositionFrame?(非人像构图剪影描述), silhouette{type(builtin|image|svg), data}, position{x,y}, scale, rotation }`
- 构图 composition：overlayType、gridType（可选）、aspectRatio（=样片真实比例）、opacity、subjectFrame{x/y/w/h、相对坐标0-1}、description
- 相机 camera：exposureCompensation、isoMode(auto)、iso(null)、shutterSpeed(null)、**whiteBalance / whiteBalanceK（已实现，按二·白平衡精确给档位+K）**、flashMode、focusMode、lensType、lensSuggestion
- 场景 sceneGuide：lightDirection、shootingDistance、background、props、bestTime、tips（含**补光灯指引**：需打正面光时写"开启补光灯、从屏幕正面补光、距离/强度"）
- 后期 postProcess：cropRatio、color{brightness/contrast/saturation/temperature/tint +（可选）highlights/shadows/blackPoint/clarity/vibrance/brilliance}、lut、systemFilter、smoothStrength、sharpen、vignette、grain、fillLight{enabled/color/intensity}
- （分析参考区块，仅用于理解与互推，不提交）：orientation、framing、lighting、styling

## 六、滤镜效果参数字典（选 lut / systemFilter 与协同微调的依据）

> 后台滤镜库共 **25 个**（`lut` 与 `systemFilter` 共用同一套 key，都是从中选一个；`none`＝原图）。
> 每个滤镜并非空名，而是**一个确定的颜色矩阵**（亮度/对比/饱和/色相/褐调/灰度的具体改动）。你应根据原图**质感最像你能得到的**选 `lut`，并用本节标出的"协同项"去微调 `color`，让最终成片质感逼近原图，而不是先随便挑再推给参数硬凑。
>
> **选滤镜的口诀**：先看原图是"低饱和灰调 / 高饱和浓郁 / 冷暖倾向 / 黑白 / 胶片颗粒"，再对号入座；`lut` 负责"色性骨架"，`color` 负责"细调残余差距"，二者不要重复拉扯同一方向。

| key | 中文 | 矩阵实际改动（量化） | 适合的照片质感 / 特征 | 选后 color 协同项 |
|---|---|---|---|---|
| `none` | 原图 | 不套任何滤镜，直出 | 原片色彩已经很好、不想动色调 | — |
| `cinematic` | 电影感 | 对比+15、饱和−10、色相−8°(略暖)、亮度−3 | 大片感、故事感；街拍、夜景、情绪人像，画面偏"沉寂有质感" | 若已想再厚重可 contrast 再+几；想更清冷可 temperature 负向 |
| `vintage` | 复古胶片 | 褐调sepia0.35、对比+10、亮+5、饱和−15 | 泛黄怀旧、做旧；老城街拍、旧物、复古穿搭人像 | 想要更旧可加 grain；要清淡可 saturation 再− |
| `warm_film` | 暖色胶片 | 轻sepia0.2、饱和+15、亮+3、色相−5°(偏暖) | 黄昏、暖光室内、暖色食物、落日人像 | 配 temperature 正向，别再加饱和否则过腻 |
| `cool_film` | 冷色胶片 | 饱和−10、亮−2、色相+8.8°(偏蓝/紫) | 阴天、冷色场景、清冷人像、冰饮 | 配 temperature 负向加深冷意 |
| `pastel` | 柔色 | 亮+8、饱和−15、对比−8 | 明亮柔和低对比；清新、少女、浅色布景 | 别再猛提亮度；降对比由滤镜做了 |
| `fuji` | 富士感 | 饱和+20、对比+5、色相−3.3°、亮+2 | 高饱和略微偏暖的胶片负片感；日系街景、风景 | 想更清亮 temperature 微负，别再加饱和 |
| `portrait` | 人像 | 饱和+5、对比+5、亮+3、轻sepia0.05 | 通用人像微美化，自然微暖、明艳不过分 | 肤色偏红可 tint 微负 |
| `japanese` | 日系 | 饱和−15、对比−8、亮+10、色相+3.3°(略冷) | 高亮低饱和低对比的日系清透 | 想更通透可 brightness 再微+，想更稳则不加 |
| `japanese_fresh` | 日系清新 | 亮+15、对比−12、饱和−18、色相+4.4° | 比日系更亮更淡的清新通透，浅景布光 | 别再大幅提亮，易发白 |
| `cream` | 奶油感 | 亮+12、对比−6、饱和−5、轻sepia0.1、色相−5.5° | 明亮柔和的奶油/软糯氛围；暖系静物甜品 | 亮与会略损失饱和度，必要时 saturation 微回补 |
| `cyberpunk` | 赛博朋克 | 饱和+40、对比+20、色相−16.5°(偏洋红/紫)、亮−5 | 高饱和高对比冷紫霓虹；都市夜景 | 配暗角，别再用冷色 LUT 叠加 |
| `night_cyber` | 夜景赛博 | 亮−15、色相+33°(大幅转色)、对比+15、饱和+35 | 暗调高对比+大幅色偏的夜景霓虹 | 暗场景别再加亮；补 grain 更霓虹 |
| `hk_neon` | 港风霓虹 | 亮+5、色相−60.5°(大幅转红/橙)、对比+10、饱和+30 | 浓郁港风红橙霓虹、夜市场景 | 配暖 temperature；饱和已高勿再加 |
| `sepia_classic` | 褐调 | sepia0.7、对比+5、亮+2 | 强棕褐做旧怀旧 | 配 grain+ 更胶片 |
| `mist` | 薄雾 | 亮+12、对比−12、饱和−10 | 高亮低对比雾感朦胧、晨雾景观 | 别再加亮度避免过曝感 |
| `rouge` | 胭脂 | sepia0.2、饱和+10、色相−11°(偏红)、亮+2 | 带红润/胭脂感的暖调；复古妆面人像 | 皮肤嫌红则 sat 降、temp 微凉 |
| `twilight` | 暮光 | 饱和+15、色相+16.5°(偏紫/蓝)、对比+5、亮−5 | 偏紫蓝的暮色、黄昏蓝调时刻 | 配 cool temperature |
| `cyan` | 青调 | 饱和+10、色相+22°(偏青)、对比+5、亮+2 | 青绿色调清冷、隐绿植场景、青森感 | 留绿可 tint 微+ |
| `noir` | 黑白 | 灰度 + 对比+30、亮−5 | 硬朗高对比黑白 | 想更软则 contrast 回一点 |
| `fine_art_bw` | 黑白艺术 | 灰度 + 对比+35、亮+5 | 高对比略带明亮的艺术黑白 | 主体轮廓靠 contrast 已够 |
| `silver` | 银盐感 | 灰度 + sepia0.2 + 亮+8、对比−5 | 柔和银灰黑白、谈质感 | 偏柔，可 micro sharpen 提细节 |
| `morandi` | 莫兰迪 | 亮+8、对比+10、sepia0.08、**饱和−35** | 大幅降饱和的高级灰调、莫兰迪低饱和柔和 | 选它后 color.saturation 基本不要再负压，避免灰成一片 |
| `muted_gray` | 低饱和高级灰 | 亮+4、对比+15、sepia0.1、**饱和−60** | 极低饱和的灰调高级感、性冷淡风 | 同理，饱和度已很低，别再降 |
| `heavy_film` | 浓厚胶片 | sepia0.45、对比+25、饱和−10、色相−8.8°、亮−2 | 强对比+棕褐的浓郁胶片、粗粝老照片 | 配 grain+，饱和别加否则脏 |

> 使用注意：
> - `lut` 与 `systemFilter` **同一套库、二选一**即可；一般只在 `lut`（主调色）里选。当原图色性接近 `none`（几乎不偏色、靠后期 detail 调）时 `lut:"none"`。
> - 选 `lut` 后，`color` 里应只补**滤镜没覆盖的残余差距**（例如选了 `morandi` 就别再 color.saturation −），不要重复同方向、避免用力过猛。
> - 拿不准时，"宁可用 `lut` 表达主调、`color` 微调"，优先保证 `lut` 与 `color` 同向一致，不要 lut 一个方向、color 反向打架。

## 七、补偿参考（仅作方向）

| 原靠不可调参数获得的效果 | 用可调参数补偿 |
|---|---|
| 浅景深 / 虚化背景 | 场景"靠近主体、拉远背景"+ smoothStrength 轻微磨皮 + vignette 轻暗角（只暗示，**不是真虚化**） |
| 整体欠曝/过曝 | exposureCompensation + 后期 brightness/contrast/highlights/shadows |
| 高感颗粒、暗光氛围 | grain + 夜色 LUT + 色彩 temperature/色调 |
| 长曝光 / 夜景 / 流光 | 夜色/霓虹 LUT + grain + tips"固定机位/三脚架"（**近似模拟**，不能真长曝光） |

## 八、输出格式（字段名与后台表单一致；只给模板参数，不输出 price/referenceSource/author/tagIds）

严格输出单个合法 JSON 对象；字符串字段具体量化，满足二、三的光影与姿势/构图深度要求：

```json
{
  "name": "模板名称（简洁好记，体现风格）",
  "category": "portrait",
  "classification": { "type": "portrait（= category，一级）", "majorStyle": "（二级风格建议）", "subStyle": "（三级风格建议）", "method": "（四级方法建议）" },
  "shortDesc": "（情绪化抓眼短文案，例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿）",
  "description": "（完整简介：类型+场景+光线+穿搭/造型要点+适用人群）",
  "ambience": { "seasons": [], "weathers": [], "timeTones": [] },
  "tags": ["3-5个中文标签"],

  "images": [
    { "imageIndex": 0, "role": "封面", "caption": "（这张作为封面，一句话说明画面亮点）" },
    { "imageIndex": 1, "role": "效果图", "caption": "（这句作为附加效果图）" }
  ],

  "poses": [
    {
      "imageIndex": 0,
      "name": "封面·主姿势",
      "type": "people（人物|composition 构图）",
      "description": "（人像：可执行人物姿势描述，含屏幕方向朝向；非人像：构图描述）",
      "compositionFrame": "（仅非人像 type=composition 时必填：构图骨架/主体位置/留白/引导线，供做构图剪影）",
      "silhouette": { "type": "builtin|image|svg", "data": "（剪影 key 建议；非人像给构图剪影 key/骨架）" },
      "position": { "x": 0.5, "y": 0.48 },
      "scale": 0.96,
      "rotation": 0.0
    },
    {
      "imageIndex": 1,
      "name": "附加姿势",
      "type": "people|composition",
      "description": "（该图对应的姿势/构图描述）",
      "compositionFrame": "",
      "silhouette": { "type": "builtin", "data": "" },
      "position": { "x": 0.5, "y": 0.5 },
      "scale": 1.0,
      "rotation": 0.0
    }
  ],

  "composition": { "overlayType": "rule_of_thirds", "gridType": "（可选）", "aspectRatio": "3:4", "opacity": 0.3, "description": "（构图定调：景别+机位+主体位置占比+环境占比+头顶留白）", "subjectFrame": { "x": 0.22, "y": 0.05, "w": 0.56, "h": 0.94 } },
  "camera": { "exposureCompensation": 0.25, "isoMode": "auto", "iso": null, "shutterSpeed": null, "whiteBalance": "shade", "whiteBalanceK": 7000, "flashMode": "off", "focusMode": "auto", "lensType": "主摄镜头", "lensSuggestion": "main" },
  "sceneGuide": { "lightDirection": "（光源类型+从屏幕哪侧来+角度+软硬+光比+阴影落点+是否需补光）", "shootingDistance": "1.8-2.2m", "background": "（具体可执行）", "props": ["（道具，无则空）"], "bestTime": "14:30-16:00", "tips": ["（逐条动作/构图要领，含补偿/无法复现说明；需补光时写'开启补光灯，从屏幕正面补光，距离约X m、强度Y'）"] },
  "postProcess": { "cropRatio": "3:4", "color": { "brightness": 3, "contrast": -6, "saturation": 12, "temperature": 4, "tint": 2 }, "smoothStrength": 35, "sharpen": 22, "vignette": 22, "grain": 18, "lut": "pastel", "systemFilter": "none", "fillLight": { "enabled": false, "color": 4294959028, "intensity": 0.8 } },

  "orientation": { "framePosition": "", "bodyFacing": { "type": "", "azimuth": 0 }, "faceFacing": { "type": "", "azimuth": 0 }, "twist": "", "headPitch": 0, "headRoll": 0, "gaze": "" },
  "framing": { "shotSize": "", "shotSizeNote": "", "cameraHeight": "", "cameraAzimuth": "", "subjectScale": "", "environmentRatio": "", "headroom": "", "framingNote": "" },
  "lighting": { "lightingDetail": { "光位": "", "辅光轮廓光": "", "光型软硬": "", "光比": "", "阴影": "", "质感": "", "环境光": "", "色温对比": "" }, "lightToParams": "" },
  "styling": { "subjectType": "", "clothingLayers": { "上装": "", "下装": "", "衣角处理": "", "袖子": "", "领口": "", "鞋袜": "", "叠穿层次": "" }, "accessories": "", "hairMakeup": "", "objectStyle": "", "note": "" }
}
```

> 注：
> - `images` 与 `poses` 必须一一对应（`imageIndex` 关联）；单图时只输出一项。
> - `poses[i].type` 依该图主体判定：人物 → `"people"`（填人物姿势）；非人物 → `"composition"`（填 `compositionFrame` 构图描述 + 构图剪影建议）。
> - `fillLight.color` 存为 32 位不透明 ARGB 整数（补 alpha=0xFF），非 hex 字符串；由 `#RRGGBB` 转 `0xFFRRGGBB`。示例 `#FFE5B4` → `4294959028`。
> - `orientation / framing / lighting / styling` 是**分析参考区块**，供你核对与互推字段用，其结论已折进 `pose.description / composition.description / sceneGuide.* / 顶层 description`，**不写入后台表单**。

补充：
- 白平衡已实现：`camera.whiteBalance / whiteBalanceK` 按二·白平衡据原图色温**给精确档位 + K 值**（档位仅 `daylight / cloudy / shade / tungsten / fluorescent / custom`），不要用 temperature 替代白平衡；temperature 只做微差。
- 高级色彩字段（highlights/shadows/blackPoint/clarity/vibrance/brilliance）只有照片能明确看出该调整倾向才**输出该键**，否则**省略**（后台只在有值时存储）。
- `systemFilter` 只有意图用非"原图"系统滤镜时才加该键；`fillLight.enabled=true` 时才保留 `fillLight`（当"需打正面光/实拍用了补光但没带灯/主体被背景压制"时开启，作为后期模拟补光）。
- `composition.subjectFrame` 四个值都有时才输出。
- `sceneGuide.props` / `tips`、`tags` 是数组。
- `lut` 按**六、滤镜效果参数字典**从 25 个 key 里选最贴近原图色性的一项，并按表内"协同项"微调 `color`；照片色性本就接近原片直出不偏色则 `lut:"none"`。`lut` 与 `systemFilter` 同库、只填其一（一般只填 `lut`）。
- 剪影 key、系统滤镜、镜头建议等强依赖内置素材项：AI 只给"最贴近建议"，落地时后台手动选到最接近值。
- 必须输出**单个合法 JSON**，不要加多余的代码块标题或额外解释；必要的补充说明写进 `description` 或 `sceneGuide.tips`。
- `shortDesc` 与 `description` 是**两种不同定位**：短描述＝情绪化抓眼文案（氛围+情绪+emoji）；长描述＝完整客观定位说明。二者都要写，但**不是详略递进关系**，短描述绝不能只是长描述的压缩。
- 分类采用**四级**：`category`（一级题材）AI 从枚举挑最近；`classification.majorStyle / subStyle / method`（二/三/四级）只给风格关键词建议，因后台分类 key 随动态分类树而变，落地时后台下拉手动选到最接近项。
````

---

## 与后台表单的字段映射（自检依据）

| 后台 Step | 表单字段 | 📦 输出 JSON 键 |
|---|---|---|
| Step1 基本信息 | 名称 | `name` |
| | 一级分类 | `category` |
| | 二/三/四级分类 | `classification.majorStyle / subStyle / method` |
| | 短简介 | `shortDesc` |
| | 长简介 | `description` |
| | 季节/天气/时段 | `ambience.seasons / weathers / timeTones` |
| | 标签 | `tags` |
| Step2 封面与效果图 | 效果图列表（[0]=封面） | `images`（角色说明） |
| Step3 构图 | 构图/网格/长宽比/透明度/主体框/构图描述 | `composition.overlayType / gridType / aspectRatio / opacity / subjectFrame / description` |
| Step3 姿势组 | 每姿势的名称/描述/剪影/位置/缩放/旋转 | `poses[].name / description / silhouette / position / scale / rotation` |
| Step4 相机 | 相机参数 | `camera.*` |
| Step5 场景引导 | 光线/距离/背景/道具/时段/技巧 | `sceneGuide.*` |
| Step6 后期处理 | 裁剪/色彩/LUT/滤镜/磨皮/锐化/暗角/颗粒/补光 | `postProcess.*` |

> 由你维护、无需 AI 生成、且未在输出中的字段：`price / referenceSource / author / tagIds / sortOrder / isActive`；封面文件与剪影实图由你在后台直接上传，AI 只给描述/建议。
> 该映射以 `lumira-server/packages/admin/src/components/template-form.tsx` 的 `onSubmit` 拼装结构为权威来源。