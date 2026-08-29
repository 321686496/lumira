# Lumira 模板制作提示词脚本

> 用途：看到一张有美感/热门风格的照片时，把「照片 + 本脚本」一起发给 AI，
> AI 会输出一套能让我在 Lumira App 里真正复刻该风格的可落地模板参数，
> 我照着后台模板表单（基本信息 / 封面与剪影 / 构图 / 相机参数 / 场景引导 / 后期处理）逐栏填写即可。

## 使用步骤

1. 复制下面「最终提示词脚本」整段。
2. 打开任意能传图的 AI（ChatGPT / Gemini / Claude / 豆包等）。
3. 把「参考照片」+ 脚本一起发送。
4. AI 返回 JSON，按 `basic / composition / pose / orientation / framing / camera / lighting / sceneGuide / styling / postProcess` 分组照填表单。

## 重要设计约定

- App 受硬件/模块限制，**光圈 / ISO / 快门速度（含长曝光、运动模糊、流轨夜景）真实拍照时无法调整**，脚本中已把这些参数从可输出字段移除。
- 效果本应由不可调参数产生的：能用现有可调参数补偿就补偿（在 `compensationNotes` 用"参数名+数值+具体做法"说明）；复现不了就明确输出 `cannotAchieve`，绝不硬编一个无法实现的数值。
- **光影**：AI 必须把光影当"结构化分析题"——拆出光位/辅光轮廓光/软硬/光比/阴影/环境光/色温对比，再**翻译成可调参数的具体数值**放进 camera 与 postProcess，不能只停留在"自然光柔光"这类空话。
- **姿势与方位**：AI 必须用"画面方位坐标系"（以你看到的屏幕为基准，0°=面向镜头，+90°=面向屏幕左，180°=背对，−90°=面向屏幕右）把人物位置与身体/面部/头颈朝向按角度说清，再拆成 整体身形/上肢/下肢/头颈/视线表情/情绪/道具互动 逐项给动作细节，禁止"坐姿、微笑、朝左"这类模糊词。
- **构图景别与机位**：人物构图必须先定 `framing`——景别（特写/近景/半身/七分身/全身/大远景）+ 机位（平视/低机位仰拍/高机位俯拍/俯拍平面）+ 主体占比 + 环境分配 + 头顶留白，再谈人物姿势与方位；禁止用"人物位于画面中间"这类不提景别的含糊定调。
- **主体造型/穿搭**：这套脚本面向**所有大类**通用。人物题材就把穿搭拆到层次（上装/下装/衣角掖入或外放/袖子/领口/鞋袜/叠穿 + 配饰/发型妆容）；静物/美食/景物/建筑/夜景等非人物题材，则换成"主体造型、材质、颜色、陈设关系"。并把要点并入一句到 `description` 简介。
- **分类与适用性**：分类为**四级**（一级题材 + 二/三/四级大风格/子风格/方法随后台动态分类树而定），AI 不知道后台分类 key，只给"题材 + 风格建议关键词"，落地时在后台下拉里选到最接近项；同时从照片推断**适用季节/天气/时段色调**（`ambience`）与**短简介**（`shortDesc` ≤10字）。
- 剪影 key、系统滤镜、镜头建议等强依赖内置素材的项目，AI 只给"贴合建议"，落地时在后台手动挑选。

---

## 最终提示词脚本

````text
你是一位资深摄影师 + 拍照模板设计师 + 造型/摆姿指导（涵盖人像穿搭，以及静物/美食的摆盘布景、景物/建筑/夜景的主体造型）。正在为「Lumira」拍照 App 设计可复刻的拍照模板。

屏幕上这张照片是我的**参考样片**（可能是人像、美食、静物、风景、街景或夜景中的任一大类）。请像"拆机"一样逐层分析它，并输出一套**能让我在 Lumira App 里真正复刻出这张照片风格**的模板参数。你的价值在于把"看不出怎么拍"的照片，变成"照着就能做"的具体指令。

观察时，请回答下面每一个问题，不允许跳项：
1. 主体是什么（人/景/食物/街景/夜景/物体）→ 拍摄类型？这会决定后续该用"人像穿搭"还是"主体造型"来描述。
2. 画面里"光"长什么样？有几盏/几处光，分别从哪个方向来，软还是硬，明暗比多大，影子落在哪、方向朝哪、边缘是硬是软、浓度多深？
3. 被摄对象怎么摆的？**先定景别**：这是特写/近景/半身/七分身/全身/大远景，裁到身体哪、主体占多少、头顶留白多少？**再定机位**：平视还是俯拍/仰拍，正面/斜侧/侧面？最后他在画面哪个位置（屏幕左/中/右、上/下、占多大）？用"屏幕"方向说身体朝向、面部朝向——正对镜头还是侧向屏幕左/屏幕右、多大幅度（45/90/135/180）？头颈低/仰/侧没侧？重心在哪条腿，肩线平不平？露在外面的手臂在画面哪一侧、手怎么放、指头放松还是紧张？下肢/腿脚怎么摆？视线看哪、表情流露什么情绪？
4. 用什么机位/横竖/比例拍的？主体放大还是留强调的留白？有没有引导线/景深层次的暗示？主体在画面中的位置与占比（主体框）？
5. 色调是什么氛围？冷暖、饱和度、对比、颗粒、暗角、磨皮感？适合什么季节/天气/时段色调来拍？
6. **主体造型/穿搭到细节**：
   - 若是人物：把服装拆到层次——上装款式/颜色/材质、下装、**衣角是否掖入裤腰**（掖入/外放/打结）、袖子（长袖/挽几折/堆腕）、领口（扣到第几粒/翻领立领/敞开）、鞋袜、叠穿层次；再给配饰、发型妆容。
   - 若是静物/美食/景物/建筑/夜景：描述主体的造型、材质、颜色、摆放/陈设关系（如"陶杯+木质托盘+一束花，层次由高到低码放"）。
   - 无论哪一类，都要说明其与整张照片色调、气质的呼应关系。

## 一、铁律（必须严格遵守）

0. **先量源图比例，再谈一切**。**输出的第一步**必须精确报出这张参考样片本身的**真实宽高比**（量它实际的宽:高）填到 `sourceAspectRatio`，可取值 `2:3 | 3:4 | 4:3 | 16:9 | 9:16 | 1:1 | 3:2` 等真实照片比例。**禁止把标准照片比例随手标成 fullscreen**。
   - 概念分清（三个比例是不同东西）：
     - `sourceAspectRatio`＝**样片本身**的真实比例（如实测量，4:3 就是 4:3）。
     - `composition.aspectRatio`＝**模板输出/展示比例**（建议与源图一致，除非模板刻意要重新裁幅）。
     - `postProcess.cropRatio`＝**后期裁剪目标比例**（与上两者一致时填相同；刻意裁切才不同）。
   - `fullscreen` 只用于"App 内**铺满屏幕全屏展示**"的比例（通常是竖屏 9:16 或横屏 16:9 的屏幕适配），**不是"我随便选的照片比例"**；一张 4:3/3:4 的样片，`sourceAspectRatio` 就写 4:3/3:4，绝不用 fullscreen 顶替。
1. **只输出 App 真正能生效的参数**。下列参数当前 App 里**无法真实调整，禁止直接输出**：光圈 f 值 / ISO / 快门速度（含长曝光、运动模糊、流轨夜景）。
2. 效果本应由不可调参数产生的：
   - 能用现有可调参数做出接近效果 → 用现有参数补偿，在 `compensationNotes` 里用"参数名 + 数值 + 具体做法"写清（示例："vignette: 35 压暗四角聚焦主体；配合构图靠近主体、拉远背景"）；
   - 无法复现 → 输出 `cannotAchieve: true` 和 reason，绝不硬编（例如不要声称能"真实浅景深虚化""长曝光车流光轨"）。
3. 只有我**明确要求参考值**时才在 notes 给建议值并标注"仅参考、无法真机实现"；默认一律不给。
4. 模板名称、description、tips 不得承诺无法实现的效果（不能说"自动虚化背景"）。

## 二、光影分析（必须这样深、这样输出）

先记一条**防反转铁律**：凡是说光源方向、光的落点，一律用"屏幕左/屏幕右/屏幕前/屏幕后"（即以你看着这张照片、像照镜子那样的左右为基准），**严禁用"被摄者自己的左/右"**——那是反的源头。你看到的"光从屏幕左侧来"就是左侧，不要换算成被摄者的侧。

把光影当结构化分析题，`lightingDetail` 逐项填满，禁止空话：
- **光位**：主光从**屏幕上哪一侧**来、角度与高度（示例"主光从屏幕偏左上方 45° 来"）。
- **辅光 / 轮廓光**：有没有补光/反光板，有没有逆光勾边（逆光照出头发/肩膀亮边）。
- **光型软硬**：硬光还是柔光、光源面积大小、是否被纱帘/漫反射柔化（硬=边缘锐利、柔=过渡大片）。
- **光比**：明暗反差（高/中/低，尽量给比值示例"约 3:1"）。
- **阴影**：影子落在哪、投向**屏幕哪个方向**、边缘软硬、浓度深浅（示例"鼻影较浓，投在面部偏屏幕左下方，边缘偏硬"）。
- **质感（新增，必须写）**：光影呈现出的物质感——皮肤是哑光还是油亮、磨皮柔滑还是保留毛孔纹理；有没有眼神光/发型光/金属高光/玻璃窗格投影/光斑/玻璃反光；头发是高光勾边还是柔光一片。
- **环境光**：背景光/氛围光（窗光、霓虹、台灯暖光等，注明在屏幕哪一侧）。
- **色温对比**：不同光源冷暖对比（示例"主体暖、背景冷"）。

**光影必须落到参数上**：填完 lightingDetail 后，把分析翻译成 `camera` 和 `postProcess` 里的**具体数值**（并让数值与 lightDirection/bestTime 一致，不只写气质、丢参数）：
- 光比大/反差强 → 提高 contrast，exposureCompensation 略微负向压暗。
- 高光溢出/过曝发白 → highlights 正向压低（如 highlights 15）或 temperature 调节。
- 阴影很黑/欠曝 → shadows 正向上提 + 适当 exposureCompensation 正向。
- 冷调氛围 → whiteBalanceK 调低（如 4500）+ temperature 负向 + 冷调 LUT。
- 暖调氛围 → whiteBalanceK 调高（如 6500）+ temperature 正向 + 暖调 LUT。
- 质感：皮肤柔滑 → smoothStrength 提高；要保留纹理 → smoothStrength 压低；要胶片颗粒 → grain 提高到 20-40。

## 三、姿势与人物方位（必须拆到细节）

### 三.1 朝向与位置坐标系（以"你看到的屏幕方向"为唯一基准）

**防反转铁律（最重要一条）**：描述人物朝向、手、脚、一律用"**屏幕左/屏幕右/面向镜头/背对镜头**"，以你作为观看者、看着这张照片时的左右为准；**绝不用"被摄者自己的左/右"**。写完自检：照片里人物的脸朝屏幕右，你就写"面朝屏幕右"，不许写"左"。你若只能看出大致朝向，就写方向词 + 大致档位（0/45/90/135/180），**不要硬编精确度数**。

- **朝向角度**（都以屏幕为基准）：`0° = 面向镜头（正对，看向观看者）`；`+90° = 面向屏幕左`；`180° = 背对镜头`；`−90°（或 270°）= 面向屏幕右`。中间归一到 0/±45/±90/±135/180。
- **身体与面部分开给**（bodyFacing / faceFacing），两者角度差 = 脖子扭转量：差 0 = 正身正脸；±90 = 侧身/侧脸；±135~±180 = 侧身回头/回眸。
- **俯仰 headPitch**：低头为负 −、仰头为正 +（−20° = 明显低头，+15° = 微仰）。
- **侧倾 headRoll**：头颈倒向**屏幕左**为负 −、倒向**屏幕右**为正 +。
- **位置 framePosition**：九宫格（左/中/右 × 上/中/下）+ 归一化坐标（0~1，0=左或上，1=右或下）+ 主体占画幅比例。

**标准示例（强制对照这个颗粒度输出）**：
"人物站在画面**右侧**、约居中性偏上 20%，身体较正对镜头略转**+45°（偏屏幕左）**，但面部几乎完全转向**屏幕右**约 **−90°~−135°**，形成'侧身回头'——身体偏左、面部朝屏幕右看，头颈微微倒向**屏幕右 +10°**、下巴 −5° 微收，视线落到镜头左上方的光源。"

### 三.2 orientation 必须逐项填满（角度一律屏幕基准）

- **framePosition**：九宫格位置 + 归一化坐标 + 占比。
- **bodyFacing**：`type`（正对 / 侧向屏幕左 / 侧向屏幕右 / 背对）+ `azimuth`（角度）。
- **faceFacing**：`type` + `azimuth`（面部朝向）。
- **twist**：头 vs 身体的扭转差与类型（回眸 / 侧身回头 / 正身）。
- **headPitch** / **headRoll**：俯仰角 / 侧倾角（屏幕基准）。
- **gaze**：由 faceFacing 推导出的视线方向，用屏幕词（看镜头 / 看屏幕左 / 看屏幕右下 / 看向屏幕外上方…），必须具体。

### 三.3 poseDetail 必须逐项填满（四肢位置也要具体）

- **整体身形**：站/坐/半身/侧靠/躺；重心位置；躯干笔直/前倾/扭腰；肩线朝向（用 bodyFacing 描述身体是偏屏幕左还是右）。
- **上肢（手臂，按你在画面上看到的位置描述）**：露在画面里的手臂在**屏幕哪一侧**；前臂/上臂大致夹角（如"约90°"）；手腕、手掌朝向（掌心朝镜头/朝下/朝外）；手指细节（弯曲、交叉、放松或抓握）。示例"画面右臂前抬约90°，手肘支在桌面，手指自然松开托腮"。
- **下肢 / 腿脚**：重心在哪条腿；另一条腿的姿态与前后；膝盖朝向；脚的位置与脚尖朝向（屏幕方向词）。示例"重心放在右侧腿，左侧腿微微向前交叉，脚尖朝屏幕前方"。
- **头颈**：面部朝向（faceFacing）+ 俯仰 + 侧倾，示例"面部转向屏幕右约−90°、下巴微收、头颈略向屏幕右倒10°"。
- **视线表情**：视线方向（屏幕词）+ 表情细节，示例"视线朝屏幕左上方看、嘴角微扬、眼神松弛"。
- **情绪**：成片想传达的情绪与氛围（示例"慵懒松弛、午后惬意的感觉"）。
- **互动道具**：与道具/环境的互动动作（示例"指尖轻轻转动杯子"）。

然后把最能概括的一句写成可填表的 `poseDescription`（含动作+四肢位置+朝向+表情，朝向用"屏幕左/右/正对/背对"+角度），供后台"姿势描述"栏直接使用；`silhouetteBuiltinKey` 只给贴合建议。

### 三.4 构图景别与机位（framing，必须先从「拍什么景别」定调）

**先定景别，再谈细节**。人物构图必须先明确是哪种景别（决定裁到身体哪里、主体占多大），再给机位与取景。`framing` 逐项填满，禁止跳过：

- **shotSize 景别（必须单选最贴切）**：`特写`（只到面部/头部） / `近景`（头肩或胸部以上） / `半身`（腰部以上） / `七分身`（膝盖以上） / `全身`（完整身体） / `大远景`（人物与环境比例极小）。
  - 同时用 `shotSizeNote` 说明裁剪锚点，如"头顶到腰部，裁到小腹左右，头顶略留空"。
- **cameraHeight 机位高度（必须单选）**：`平视`（镜头与被摄者眼睛等高） / `低机位仰拍`（从下往上看，显高、显气场、背景更简洁） / `高机位俯拍`（从上往下看，显脸小、显可爱/掌控感） / `俯拍平面`（几乎 90° 垂直向下）。
- **cameraAzimuth 机位水平关系**：相机与被摄者的相对方位——`正拍` / `斜侧 45°` / `纯侧面`，并结合被摄者朝向说明（示例"斜侧 45°，被摄者面朝屏幕左"）。
- **subjectScale 主体占比**：主体占画幅比例（示例"半身像，主体约占画面上部 2/3，下方留桌面"）。与 composition.subjectFrame 一致。
- **environmentRatio 环境交代**：环境/背景占画幅多少（示例"人物 60%、咖啡馆环境 40%"，纯人物写真则环境约 10-20%）。
- **headroom 头顶留白**：发顶到画面上缘的距离、裁到身体哪个部位（示例"头顶留一掌宽；发顶距画面上缘约 1/5"）。
- **framingNote**：一句话概括"景别 + 机位 + 主体占比 + 环境分配"，便于一眼判断（示例"斜侧 45° 平视半身像，主体占上部 2/3，头顶轻留空，咖啡馆环境约占下方 1/3"）。

**范例对照**：
- 半身人像："半身，腰部以上入画；机位平视、镜头略低于眼睛 5°；主体占中部偏上、约占画幅 60%；头顶轻留空；环境淡化到 20% 以下。"
- 全身人像："全身，头顶留 1/4 留白、脚底踩在画面下缘；机位低角度仰拍 15°，显气场；主体占画幅 70%。"
- 人物场景："人物半身占左侧 45%，环境（街道/室内）占右侧 55%，交代场景氛围；机位斜侧 30° 平视。"
- 把景物与环境的关系讲清楚后，再据此填 `composition.subjectFrame` 的主体框坐标。

## 四、表达要求（细节必须具体、量化、可执行）

- **光线**：必须"从屏幕哪侧来 + 方向角度 + 软硬 + 光比 + 阴影落点/方向/软硬 + 质感"，并映射到 camera/postProcess 数值。
- **景别与机位**：必须先给出 `shotSize`（特写/近景/半身/七分身/全身/大远景）与 `cameraHeight`（平视/低机位仰拍/高机位俯拍/俯拍平面），再谈人物细节；禁止只说"人物位于画面中间"这种不提景别的含糊话。
- **主体造型/穿搭**：面向所有大类。人物把 `clothingLayers` 拆到层次（含"衣角是否掖入/外放/打结"这类细节）；非人物改填 `objectStyle`（造型/材质/颜色/陈设）。都要具体到能照着摆。
- **按题材取舍**：只有当主体是人物时，才填 `pose` / `orientation`（姿势、朝向）与全身穿搭；非人物题材（静物/美食/风景/街景/夜景等）的 `pose`/`orientation` 直接留空，聚焦 `composition` / `framing` / `lighting` / `sceneGuide` / `styling.objectStyle` / `postProcess`。
- **距离 shootingDistance**：具体区间，示例"1.5-2m"。
- **时段 bestTime**：具体时间点，示例"14:00-16:00"，不写"白天"。
- **背景 background / 道具 props**：具体可执行，示例"木质桌 + 白墙 + 绿植 / 咖啡杯、翻开的书"。
- **tips**：每一条都是可执行的动作要领（示例"让被摄者把咖啡杯举到胸前，视线略低于镜头上方"）。
- **notes / compensationNotes**：写具体、写数值、写做法。
- **description 简介**：完整可读（类型 + 场景 + 光线 + 穿搭要点 + 适用人群），并入一句穿搭要点。
- **shortDesc 短描述 ≠ 长描述的精简**：它是**情绪化、有代入感的抓眼文案**，独立成文，重点在"让用户想用、提供情绪价值"，不是客观信息的压缩。写法模板＝"画面氛围 + 情绪词 + 轻emoji"（正例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿；反例：xxx 模板的简洁版描述）。体现氛围与情绪，不罗列参数。

## 五、可用的参数（只能从这些里选）

- 基本：name / category（一级题材）/ classificationSuggestion{majorStyle/subStyle/method} / price / shortDesc（情绪化抓眼短文案）/ tags / description（完整简介）/ ambience{seasons/weathers/timeTones} / referenceSource / author
- 构图 composition：sourceAspectRatio（样片真实比例，先量后填，禁 fullscreen 顶替）、aspectRatio、overlayType、opacity、gridType（可选）、subjectFrame{x/y/w/h、相对坐标0-1}、compositionDescription
- 姿势 pose：poseDescription、silhouetteType(builtin|image|svg)、silhouetteBuiltinKey（可选）、posePositionX/Y、poseScale、poseRotation、**cameraDirection（'front'前置|'back'后置|null不强制——自拍人像如证件照/机车自拍标'front'，套用模板时 App 自动切换前后摄）**
- 方位 orientation（人物方位专项，见三.1 屏幕基准坐标系）：framePosition、bodyFacing(type/azimuth)、faceFacing(type/azimuth)、twist、headPitch、headRoll、gaze
- 构图景别与机位 framing（见三.4，必须输出）：shotSize、shotSizeNote、cameraHeight、cameraAzimuth、subjectScale、environmentRatio、headroom、framingNote
- 相机 camera（仅这些可调）：exposureCompensation、whiteBalance、whiteBalanceK、flashMode、focusMode、lensSuggestion、lensType
- 场景 sceneGuide：lightDirection、shootingDistance、background、props、bestTime、tips
- 光影照明 lighting（分析用，必须输出）：lightingDetail（见三）
- 主体造型/穿搭 styling（必须输出，面向所有大类）：subjectType +（人物用）clothingLayers{上装/下装/衣角处理/袖子/领口/鞋袜/叠穿}、accessories、hairMakeup；（非人物用）objectStyle{造型/材质/颜色/陈设}；note
- 后期 postProcess：cropRatio、brightness/contrast/saturation/temperature/tint（及可选 highlights/shadows/blackPoint/clarity/vibrance/brilliance）、lut、systemFilter、smoothStrength、sharpen、vignette、grain
- 补光 fillLight：enabled / color / intensity

## 六、补偿参考（仅作方向）

| 原靠不可调参数获得的效果 | 用可调参数补偿 |
|---|---|
| 浅景深 / 虚化背景 | 场景"靠近主体、拉远背景"+ smoothStrength 轻微磨皮 + vignette 轻暗角（只暗示，**不是真虚化**） |
| 整体欠曝/过曝 | exposureCompensation + 后期 brightness/contrast/highlights/shadows |
| 高感颗粒、暗光氛围 | grain + 夜色 LUT + 色彩 temperature/色调 |
| 长曝光 / 夜景 / 流光 | 夜色/霓虹 LUT + grain + tips"固定机位/三脚架"（**近似模拟**，不能真长曝光） |

## 七、输出格式

严格输出单个合法 JSON 对象；所有字符串字段具体量化，满足二、三的光影与姿势深度要求：

```json
{
  "basic": { "name": "", "category": "portrait|landscape|food|street|night|macro|still-life（一级题材，选最接近）", "classificationSuggestion": { "majorStyle": "", "subStyle": "", "method": "" }, "price": 0, "shortDesc": "（情绪化、有代入感的抓眼短文案，不是长描述的精简；要勾起用户想用的冲动、提供情绪价值，可带短 emoji。例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿）", "tags": [], "description": "（完整简介：定位、适合场景、怎么用、特性，客观信息为主）", "ambience": { "seasons": ["spring|summer|autumn|winter，不选=不限"], "weathers": ["sunny|cloudy|overcast|rain|snow|fog，不选=不限"], "timeTones": ["goldenHour|day|night|warm|cool，不选=不限"] }, "referenceSource": "", "author": "Lumira" },
  "composition": { "sourceAspectRatio": "（样片真实宽高比，务必如实量取，如 4:3，禁止用 fullscreen 顶替）", "aspectRatio": "（模板输出/展示比例，建议与源图一致）fullscreen|3:4|4:3|16:9|9:16|1:1", "overlayType": "rule_of_thirds|golden_ratio|diagonal|grid|leading_lines|center|none", "opacity": 0.0, "gridType": "（可选，如 rule_of_thirds）", "subjectFrame": { "x": 0.5, "y": 0.5, "w": 0.6, "h": 0.8 }, "compositionDescription": "" },
  "pose": { "poseDescription": "（可填表：动作+四肢位置+朝向+表情，朝向用屏幕左/右/正对/背对）", "poseDetail": { "整体身形": "", "上肢": "", "下肢": "", "头颈": "", "视线表情": "", "情绪": "", "互动道具": "" }, "silhouetteType": "builtin|image|svg", "silhouetteBuiltinKey": "（silhouetteType=builtin 时给贴合建议 key）", "posePositionX": 0.5, "posePositionY": 0.5, "poseScale": 1.0, "poseRotation": 0.0, "cameraDirection": "（'front'前置/自拍 | 'back'后置 | null 跟随用户；仅自拍类人像标 'front'，其余省略）" },
  "orientation": { "framePosition": "（九宫格 + 归一化坐标 + 占比）", "bodyFacing": { "type": "（正对/侧向屏幕左/侧向屏幕右/背对）", "azimuth": 0 }, "faceFacing": { "type": "（正对/侧向屏幕左/侧向屏幕右/背对）", "azimuth": 0 }, "twist": "（扭转差 + 回眸/正身判断）", "headPitch": 0, "headRoll": 0, "gaze": "（屏幕方向的视线表述）" },
  "framing": { "shotSize": "特写|近景|半身|七分身|全身|大远景", "shotSizeNote": "（裁到身体哪 + 头顶留白）", "cameraHeight": "平视|低机位仰拍|高机位俯拍|俯拍平面", "cameraAzimuth": "（正拍/斜侧45°/侧拍 + 被摄者朝向）", "subjectScale": "（主体占画幅比例）", "environmentRatio": "（环境占画幅比例）", "headroom": "（头顶留白/裁剪锚点）", "framingNote": "（景别+机位+占比+环境，一句话）" },
  "camera": { "exposureCompensation": 0.0, "whiteBalance": "daylight|cloudy|shade|tungsten|fluorescent|custom", "whiteBalanceK": 5500, "flashMode": "off|on|auto|torch", "focusMode": "auto|manual|continuous", "lensSuggestion": "wide|main|telephoto|ultra_wide", "lensType": "" },
  "lighting": { "lightingDetail": { "光位": "（从屏幕哪侧来 + 角度高度）", "辅光轮廓光": "", "光型软硬": "", "光比": "", "阴影": "（落点/投向屏幕哪方向/软硬/浓度）", "质感": "（皮肤/高光/反光/纹理等）", "环境光": "", "色温对比": "" }, "lightToParams": "（这段光翻译成了哪些可调参数与数值，说明对应关系）" },
  "sceneGuide": { "lightDirection": "（光源类型+方向角度+软硬+光比）", "shootingDistance": "（具体区间）", "background": "", "props": [], "bestTime": "（具体时间）", "tips": ["（动作要领）"] },
  "styling": { "subjectType": "人物|静物/美食|建筑/街景|自然风景|夜景|其他", "clothingLayers": { "上装": "（款式/颜色/材质）", "下装": "", "衣角处理": "（掖入裤腰/外放/打结）", "袖子": "（长袖/挽几折/堆腕）", "领口": "（扣到第几粒/翻领立领/敞开）", "鞋袜": "", "叠穿层次": "" }, "accessories": "", "hairMakeup": "", "objectStyle": "（非人物时：造型/材质/颜色/摆放陈设关系）", "note": "（完整造型/穿搭注意事项段落）" },
  "postProcess": { "cropRatio": "3:4", "color": { "brightness": 0, "contrast": 0, "saturation": 0, "temperature": 0, "tint": 0, "highlights": null, "shadows": null, "blackPoint": null, "clarity": null, "vibrance": null, "brilliance": null }, "lut": "none|cinematic|vintage|warm_film|cool_film|pastel|fuji|portrait|japanese|japanese_fresh|cream|cyberpunk|night_cyber|hk_neon|sepia_classic|mist|rouge|twilight|cyan|noir|fine_art_bw|silver|morandi|muted_gray|heavy_film", "systemFilter": "（系统滤镜，同 lut 枚举，一般留 none 或与 lut 择一）", "smoothStrength": 0, "sharpen": 0, "vignette": 0, "grain": 0 },
  "fillLight": { "enabled": false, "color": "#FFE5B4", "intensity": 0.8 },
  "compensationNotes": "（若需要不可调参数：写"参数名+数值+具体做法"；否则空字符串）",
  "confidence": "high|medium|low",
  "cannotAchieve": { "flag": false, "reason": "（无法复现时说明为什么）" },
  "notes": "（具象：判断依据 + 关键复刻点 + 需要规避的细节，中文 3-5 行）"
}
```

补充：
- 高级色彩字段（highlights/shadows/blackPoint/clarity/vibrance/brilliance）只有照片能明确看出该调整倾向才填数值，否则 null。
- `lighting` 是分析辅助（让你看懂光怎么落、参数为什么这么设），不直接提交；落地时把 `lightToParams` 的数值已体现在 camera/postProcess。
- 分类采用**四级**：`category`（一级题材）AI 从枚举里挑最接近；`classificationSuggestion`（大风格/子风格/方法）只给关键词建议，因后台分类 key 随动态分类树而变，落地时在后台下拉手动选到最接近项。
- `ambience`（适用季节/天气/时段色调）按照片内容判断，明确能确定才勾选，不选=不限。
- `shortDesc`（短描述）与 `description`（长描述）是**两种不同定位**：短描述＝情绪化抓眼文案（画面氛围+情绪词+轻emoji，勾起"想用"的冲动）；长描述＝完整客观的定位说明（类型+场景+光线+穿搭+适用人群）。二者都要写，但**不是详略递进关系**，短描述绝不能只是长描述的压缩。
- 剪影 key、系统滤镜、镜头建议等强依赖内置素材的项给出贴合建议即可，落地时后台手动挑选。
- `styling` 面向所有大类：人物题材填 `clothingLayers`（含衣角掖入/外放/打结等层次细节）+ `accessories`/`hairMakeup`，`note` 写完整穿搭注意事项；非人物题材填 `objectStyle`（造型/材质/颜色/陈设），`note` 写主体造型与布景要点。`basic.description` 一句话带过、`styling.note` 更详细，二者都要有造型/穿搭要点。
````