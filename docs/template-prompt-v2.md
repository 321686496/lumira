# Lumira 模板制作提示词脚本（v2 — 数据结构对齐后台）

> 用途：看到一张有美感/热门风格的照片时，把「照片 + 本脚本」一起发给 AI，
> AI 会输出一套**数据结构精确对应当后台模板表单**的可落地模板参数，
> 我照着后台表单（基本信息 / 封面与剪影 / 构图 / 相机参数 / 场景引导 / 后期处理）逐栏填写即可。
>
> **v2 与 v1 的唯一区别是「数据结构」**：字段名对齐后台提交结构（见 `template-form.tsx` 的 `onSubmit`），
> 且**只给出 AI 需要生成的模板相关参数**——`price / referenceSource / author / tagIds` 这类由你自己定义/维护的业务字段，**不再放入输出**。
> 其余的分析深度与规则（光影、方位坐标系、景别机位、姿势细节、穿搭、短描述定位等）**全部保留 v1**。

## 使用步骤

1. 复制下面「最终提示词脚本」整段。
2. 打开任意能传图的 AI（ChatGPT / Gemini / Claude / 豆包等）。
3. 把「参考照片」+ 脚本一起发送。
4. AI 返回 JSON，按 `name/category/classification → composition → pose → camera → sceneGuide → postProcess` 分组照填后台表单；其中 `orientation / framing / lighting / styling / poseDetail` 区块为**分析参考**（用于你理解与校对，其结论已折进对应字段，不直接写入后台）。

## 重要设计约定

- App 受硬件/模块限制，**光圈 / ISO / 快门速度（含长曝光、运动模糊、流轨夜景）真实拍照时无法调整**。配套后台数据结构中仍保留 `isoMode / iso / shutterSpeed` 键（为了结构对齐），但填 `auto / null / null`，仅供记录展示，**不依赖它们做效果补偿**。
- 效果本应由不可调参数产生的：能用现有可调参数补偿就补偿（把"参数名+数值+具体做法"写进 `sceneGuide.tips`）；复现不了就明确写进 `sceneGuide.tips` 说明"真机无法复现，改用 XX 近似"，绝不硬编一个无法实现的数值。
- **光影**：AI 必须把光影当"结构化分析题"（见二）——拆出光位/辅光轮廓光/软硬/光比/阴影/质感/环境光/色温对比，再**翻译成可调参数的具体数值**放进 `camera` 与 `postProcess`，不能只停在"自然光柔光"这类空话。
- **姿势与方位**：AI 必须用"画面方位坐标系"（以你看到的屏幕为基准，0°=面向镜头，+90°=面向屏幕左，180°=背对，−90°=面向屏幕右）把人物位置与身体/面部/头颈朝向按角度说清，再拆成 整体身形/上肢/下肢/头颈/视线表情/情绪/道具互动 逐项给动作细节（见三）。
- **构图景别与机位**：人物构图必须先定 `framing`——景别（特写/近景/半身/七分身/全身/大远景）+ 机位（平视/低机位仰拍/高机位俯拍/俯拍平面）+ 主体占比 + 环境分配 + 头顶留白，再谈人物姿势与方位（见三.4）。
- **主体造型/穿搭**：这套脚本面向**所有大类**通用。人物题材把穿搭拆到层次（上装/下装/衣角掖入或外放/袖子/领口/鞋袜/叠穿 + 配饰/发型妆容）；静物/美食/景物/建筑/夜景等非人物题材，换成"主体造型、材质、颜色、陈设关系"，并把要点并入一句到顶层 `description`。
- **分类**：后台分类为**四级**（`classification.type` ＝一级题材，与 `category` 同值；`majorStyle/subStyle/method` 为二/三/四级，随后台动态分类树而定）。AI 不知道后台分类 key，`majorStyle/subStyle/method` 只给"风格建议关键词"，落地时在后台下拉里选到最接近项；同时从照片推断**适用季节/天气/时段色调**（`ambience`）与**短简介**（`shortDesc`）。
- 剪影 key、系统滤镜、镜头建议等强依赖内置素材的项目，AI 只给"贴合建议"，落地时在后台手动挑选。

---

## 最终提示词脚本

````text
你是一位资深摄影师 + 拍照模板设计师 + 造型/摆姿指导（涵盖人像穿搭，以及静物/美食的摆盘布景、景物/建筑/夜景的主体造型）。正在为「Lumira」拍照 App 设计可复刻的拍照模板。

屏幕上这张照片是我的**参考样片**（可能是人像、美食、静物、风景、街景或夜景中的任一大类）。请像"拆机"一样逐层分析它，并输出一套**能让我在后台模板表单里真正落地**的模板参数。你的价值在于把"看不出怎么拍"的照片，变成"照着就能填"的具体 JSON。

观察时，请回答下面每一个问题，不允许跳项：
1. 主体是什么（人/景/食物/街景/夜景/物体）→ 拍摄类型？这会决定后续该用"人像穿搭"还是"主体造型"来描述。
2. 画面里"光"长什么样？有几盏/几处光，分别从哪个方向来，软还是硬，明暗比多大，影子落在哪、方向朝哪、边缘是硬是软、浓度多深？呈现什么物质质感（磨皮/颗粒/高光/光斑/反光）？
3. 被摄对象怎么摆的？**先定景别**：这是特写/近景/半身/七分身/全身/大远景，裁到身体哪、主体占多少、头顶留白多少？**再定机位**：平视还是俯拍/仰拍，正面/斜侧/侧面？最后他在画面哪个位置（屏幕左/中/右、上/下、占多大）？用"屏幕"方向说身体朝向、面部朝向——正对镜头还是侧向屏幕左/屏幕右、多大幅度（45/90/135/180）？头颈低/仰/侧没侧？重心在哪条腿，肩线平不平？露在外面的手臂在画面哪一侧、手怎么放、指头放松还是紧张？下肢/腿脚怎么摆？视线看哪、表情流露什么情绪？
4. 用什么机位/横竖/比例拍的？**量一量样片真实宽高比**（如 4:3、3:4、16:9、9:16、1:1、2:3），把它作为 `composition.aspectRatio`。主体放大还是留强调的留白？有没有引导线/景深层次的暗示？主体在画面中的位置与占比（主体框）？
5. 色调是什么氛围？冷暖、饱和度、对比、颗粒、暗角、磨皮感？适合什么季节/天气/时段色调来拍？
6. **主体造型/穿搭到细节**：
   - 若是人物：把服装拆到层次——上装款式/颜色/材质、下装、**衣角是否掖入裤腰**（掖入/外放/打结）、袖子（长袖/挽几折/堆腕）、领口（扣到第几粒/翻领立领/敞开）、鞋袜、叠穿层次；再给配饰、发型妆容。
   - 若是静物/美食/景物/建筑/夜景：描述主体的造型、材质、颜色、摆放/陈设关系（如"陶杯+木质托盘+一束花，层次由高到低码放"）。
   - 无论哪一类，都要说明其与整张照片色调、气质的呼应关系。

## 一、铁律（必须严格遵守）

0. **先量源图比例，再谈一切**。不能把样片的真实宽高比搞错：4:3 就是 4:3、3:4 就是 3:4。**`fullscreen` 只用于"App 内铺满屏幕全屏展示"的比例（通常是竖屏 9:16 或横屏 16:9）**，绝非"随手选的照片比例"。`composition.aspectRatio` ＝ 模板输出/展示比例（建议与源图一致）；`postProcess.cropRatio` ＝ 后期裁剪目标（默认与 aspectRatio 一致，刻意裁剪才不同）。
1. **只输出后台真实存在的字段**，字段名必须与下方「输出格式」完全一致，不多不少。`orientation / framing / lighting / styling / poseDetail` 是**分析参考区块**（让你看懂依据、也用于字段互推），其结论已折进 `pose.description / composition.description / sceneGuide.* / 顶层 description`，不要把它们当成额外提交字段。
2. **只输出 App 真正能生效的参数**。光圈 f 值无此字段；`camera.iso / shutterSpeed` 填 `null`（真机不可调、仅供记录展示），`camera.isoMode` 填 `"auto"`，**不要依赖 ISO / 快门做效果补偿**。
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

## 三、姿势与人物方位（必须拆到细节）

### 三.1 朝向与位置坐标系（以"你看到的屏幕方向"为唯一基准）

**防反转铁律（最重要一条）**：描述人物朝向、手、脚，一律用"**屏幕左/屏幕右/面向镜头/背对镜头**"，以你作为观看者、看着这张照片时的左右为准；**绝不用"被摄者自己的左/右"**。写完自检：照片里人物的脸朝屏幕右，你就写"面朝屏幕右"，不许写"左"。你若只能看出大致朝向，就写方向词 + 大致档位（0/45/90/135/180），**不要硬编精确度数**。

- **朝向角度**（都以屏幕为基准）：`0° = 面向镜头（正对，看向观看者）`；`+90° = 面向屏幕左`；`180° = 背对镜头`；`−90°（或 270°）= 面向屏幕右`。中间归一到 0/±45/±90/±135/180。
- **身体与面部分开给**（bodyFacing / faceFacing），两者角度差 = 脖子扭转量：差 0 = 正身正脸；±90 = 侧身/侧脸；±135~±180 = 侧身回头/回眸。
- **俯仰 headPitch**：低头为负 −、仰头为正 +（−20° = 明显低头，+15° = 微仰）。
- **侧倾 headRoll**：头颈倒向**屏幕左**为负 −、倒向**屏幕右**为正 +。
- **位置 framePosition**：九宫格（左/中/右 × 上/中/下）+ 归一化坐标（0~1，0=左或上，1=右或下）+ 主体占画幅比例。

**标准示例（强制对照这个颗粒度）**：
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

然后把最能概括的一句写成 `pose.description`（含动作+四肢位置+朝向+表情，朝向用"屏幕左/右/正对/背对"+角度），供后台"姿势描述"栏直接使用；`pose.silhouette.data` 只给贴合建议 key。

### 三.4 构图景别与机位（framing，必须先从「拍什么景别」定调）

**先定景别，再谈细节**。人物构图必须先明确是哪种景别（决定裁到身体哪里、主体占多大），再给机位与取景。`framing` 逐项填满，禁止跳过：

- **shotSize 景别（必须单选最贴切）**：`特写`（只到面部/头部） / `近景`（头肩或胸部以上） / `半身`（腰部以上） / `七分身`（膝盖以上） / `全身`（完整身体） / `大远景`（人物与环境比例极小）。同时用 `shotSizeNote` 说明裁剪锚点。
- **cameraHeight 机位高度（必须单选）**：`平视` / `低机位仰拍` / `高机位俯拍` / `俯拍平面`。
- **cameraAzimuth 机位水平关系**：`正拍` / `斜侧 45°` / `纯侧面`，并结合被摄者朝向说明。
- **subjectScale 主体占比**：主体占画幅比例（示例"半身像，主体约占画面上部 2/3，下方留桌面"）。
- **environmentRatio 环境交代**：环境/背景占画幅多少（示例"人物 60%、咖啡馆环境 40%"）。
- **headroom 头顶留白**：发顶到画面上缘的距离、裁到身体哪个部位（示例"头顶留一掌宽；发顶距画面上缘约 1/5"）。
- **framingNote**：一句话概括"景别+机位+主体占比+环境分配"。

**范例对照**：
- 半身人像："半身，腰部以上入画；机位平视、镜头略低于眼睛 5°；主体占中部偏上、约占画幅 60%；头顶轻留空；环境淡化到 20% 以下。"
- 全身人像："全身，头顶留 1/4 留白、脚底踩在画面下缘；机位低角度仰拍 15°，显气场；主体占画幅 70%。"
- 人物场景："人物半身占左侧 45%，环境（街道/室内）占右侧 55%，交代场景氛围；机位斜侧 30° 平视。"
- 把景物与环境的关系讲清楚后，再据此填 `composition.subjectFrame` 的主体框坐标。

## 四、表达要求（细节必须具体、量化、可执行）

- **光线**：必须"从屏幕哪侧来 + 方向角度 + 软硬 + 光比 + 阴影落点/方向/软硬 + 质感"，并映射到 camera/postProcess 数值。
- **景别与机位**：必须先给出 `shotSize` 与 `cameraHeight`，再谈人物细节；禁止只说"人物位于画面中间"这种不提景别的含糊话。
- **主体造型/穿搭**：面向所有大类。人物把穿搭拆到层次（含"衣角是否掖入/外放/打结"这类细节）；非人物改成"主体造型/材质/颜色/陈设"。都要具体到能照着摆。
- **按题材取舍**：只有当主体是人物时，才需要 `pose` / `orientation`（姿势、朝向）与全身穿搭；非人物题材（静物/美食/风景/街景/夜景等）的姿势/朝向简述主体摆放即可，聚焦 `composition` / `sceneGuide` / `postProcess` / 顶层 `description` 的主体造型。
- **距离 shootingDistance**：具体区间，示例"1.5-2m"。
- **时段 bestTime**：具体时间点，示例"14:00-16:00"，不写"白天"。
- **背景 background / 道具 props**：具体可执行，示例"木质桌 + 白墙 + 绿植 / 咖啡杯、翻开的书"。
- **tips**：每一条都是可执行的动作要领（示例"让被摄者把咖啡杯举到胸前，视线略低于镜头上方"），并负责承载"补偿做法 / 无法复现"的说明。
- **顶层 description 简介**：完整可读（类型 + 场景 + 光线 + 穿搭/造型要点 + 适用人群），并入一句穿搭/造型要点。
- **shortDesc 短描述 ≠ 长描述的精简**：它是**情绪化、有代入感的抓眼文案**，独立成文，重点在"让用户想用、提供情绪价值"，不是客观信息的压缩。写法模板＝"画面氛围 + 情绪词 + 轻 emoji"（正例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿；反例：xxx 模板的简洁版描述）。

## 五、可用的参数（只能从这些里选；字段名即后台表单字段）

- 基础：name / category（一级题材）/ classification{type(=category), majorStyle, subStyle, method} / shortDesc / description / ambience{seasons/weathers/timeTones} / tags
  - （`price / referenceSource / author / tagIds / sortOrder / isActive` 由我自行定义，**不要输出**）
- 构图 composition：overlayType、gridType（可选）、aspectRatio（=样片真实比例）、opacity、subjectFrame{x/y/w/h、相对坐标0-1}、description
- 姿势 pose：description、position{x/y}、scale、rotation、silhouette{type(builtin|image|svg), data}
- 相机 camera：exposureCompensation、isoMode(auto)、iso(null)、shutterSpeed(null)、whiteBalance、whiteBalanceK、flashMode、focusMode、lensType、lensSuggestion
- 场景 sceneGuide：lightDirection、shootingDistance、background、props、bestTime、tips
- 后期 postProcess：cropRatio、color{brightness/contrast/saturation/temperature/tint +（可选）highlights/shadows/blackPoint/clarity/vibrance/brilliance}、lut、systemFilter、smoothStrength、sharpen、vignette、grain、fillLight{enabled/color/intensity}
- （分析参考区块，仅用于理解与互推，不提交）：poseDetail、orientation、framing、lighting、styling

## 六、补偿参考（仅作方向）

| 原靠不可调参数获得的效果 | 用可调参数补偿 |
|---|---|
| 浅景深 / 虚化背景 | 场景"靠近主体、拉远背景"+ smoothStrength 轻微磨皮 + vignette 轻暗角（只暗示，**不是真虚化**） |
| 整体欠曝/过曝 | exposureCompensation + 后期 brightness/contrast/highlights/shadows |
| 高感颗粒、暗光氛围 | grain + 夜色 LUT + 色彩 temperature/色调 |
| 长曝光 / 夜景 / 流光 | 夜色/霓虹 LUT + grain + tips"固定机位/三脚架"（**近似模拟**，不能真长曝光） |

## 七、输出格式（字段名与后台表单一致；只给模板参数，不输出 price/referenceSource/author/tagIds）

严格输出单个合法 JSON 对象；字符串字段具体量化，满足二、三的光影与姿势深度要求：

```json
{
  "name": "模板名称（简洁好记，体现风格）",
  "category": "portrait",
  "classification": { "type": "portrait（= category，一级）", "majorStyle": "（二级风格建议）", "subStyle": "（三级风格建议）", "method": "（四级方法建议）" },
  "shortDesc": "（情绪化抓眼短文案，例：林间落日柔光漫染，裙裾轻扬，静谧治愈，满是松弛森系氛围感🌿）",
  "description": "（完整简介：类型+场景+光线+穿搭/造型要点+适用人群）",
  "ambience": { "seasons": [], "weathers": [], "timeTones": [] },
  "tags": ["3-5个中文标签"],
  "composition": { "overlayType": "rule_of_thirds", "gridType": "（可选）", "aspectRatio": "3:4", "opacity": 0.3, "description": "（构图定调：景别+机位+主体位置占比+环境占比+头顶留白）", "subjectFrame": { "x": 0.22, "y": 0.05, "w": 0.56, "h": 0.94 } },
  "pose": { "description": "（可执行姿势描述，含屏慕方向朝向）", "position": { "x": 0.5, "y": 0.48 }, "scale": 0.96, "rotation": 0.0, "silhouette": { "type": "builtin", "data": "（剪影 key）" } },
  "camera": { "exposureCompensation": 0.25, "isoMode": "auto", "iso": null, "shutterSpeed": null, "whiteBalance": "daylight", "whiteBalanceK": 5400, "flashMode": "off", "focusMode": "auto", "lensType": "主摄镜头", "lensSuggestion": "main" },
  "sceneGuide": { "lightDirection": "（光源类型+从屏幕哪侧来+角度+软硬+光比+阴影落点）", "shootingDistance": "1.8-2.2m", "background": "（具体可执行）", "props": ["（道具，无则空）"], "bestTime": "14:30-16:00", "tips": ["（逐条动作要领，含补偿/无法复现说明）"] },
  "postProcess": { "cropRatio": "3:4", "color": { "brightness": 3, "contrast": -6, "saturation": 12, "temperature": 4, "tint": 2 }, "smoothStrength": 35, "sharpen": 22, "vignette": 22, "grain": 18, "lut": "pastel", "systemFilter": "none", "fillLight": { "enabled": false, "color": "#FFE5B4", "intensity": 0.8 } },

  "poseDetail": { "整体身形": "", "上肢": "", "下肢": "", "头颈": "", "视线表情": "", "情绪": "", "互动道具": "" },
  "orientation": { "framePosition": "", "bodyFacing": { "type": "", "azimuth": 0 }, "faceFacing": { "type": "", "azimuth": 0 }, "twist": "", "headPitch": 0, "headRoll": 0, "gaze": "" },
  "framing": { "shotSize": "", "shotSizeNote": "", "cameraHeight": "", "cameraAzimuth": "", "subjectScale": "", "environmentRatio": "", "headroom": "", "framingNote": "" },
  "lighting": { "lightingDetail": { "光位": "", "辅光轮廓光": "", "光型软硬": "", "光比": "", "阴影": "", "质感": "", "环境光": "", "色温对比": "" }, "lightToParams": "" },
  "styling": { "subjectType": "", "clothingLayers": { "上装": "", "下装": "", "衣角处理": "", "袖子": "", "领口": "", "鞋袜": "", "叠穿层次": "" }, "accessories": "", "hairMakeup": "", "objectStyle": "", "note": "" }
}
```

> 注：`poseDetail / orientation / framing / lighting / styling` 是**分析参考区块**，供你核对与互推字段用，其结论已折进 `pose.description / composition.description / sceneGuide.* / 顶层 description`，**不写入后台表单**。若想让输出完全精简为"只提交"结构，可删掉这几个区块仅留上方"参数区长块"。

补充：
- 高级色彩字段（highlights/shadows/blackPoint/clarity/vibrance/brilliance）只有照片能明确看出该调整倾向才**输出该键**，否则**省略**（后台只在有值时存储）。
- `systemFilter` 只有意图用非"原图"系统滤镜时才加该键；`fillLight.enabled=true` 时才保留 `fillLight`（`color` 填 `#RRGGBB`）。
- `composition.subjectFrame` 四个值都有时才输出。
- `sceneGuide.props` / `tips`、`tags` 是数组。
- `lut` 选最贴近整张照片一项；照片偏"原片直出"就 `lut:"none"`。
- 排除 `classification.type`（= category）、剪影 key、系统滤镜、镜头建议等强依赖后台动态分类与内置素材的项：AI 只给"最贴近建议"，落地时后台手动选到最接近值。
- 必须输出**单个合法 JSON**，不要加多余的代码块标题或额外解释；必要的补充说明写进 `description` 或 `sceneGuide.tips`。
- `shortDesc` 与 `description` 是**两种不同定位**：短描述＝情绪化抓眼文案（氛围+情绪+emoji）；长描述＝完整客观定位说明。二者都要写，但**不是详略递进关系**，短描述绝不能只是长描述的压缩。
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
| Step2 封面与剪影 | 剪影类型/key | `pose.silhouette.type / data`（封面后台传图） |
| Step3 构图 | 构图/网格/长宽比/透明度/主体框/构图描述 | `composition.overlayType / gridType / aspectRatio / opacity / subjectFrame / description` |
| Step4 姿势 | 姿势描述 / 位置 / 缩放 / 旋转 | `pose.description / position / scale / rotation` |
| Step4 相机 | 相机参数 | `camera.*` |
| Step5 场景引导 | 光线/距离/背景/道具/时段/技巧 | `sceneGuide.*` |
| Step6 后期处理 | 裁剪/色彩/LUT/滤镜/磨皮/锐化/暗角/颗粒/补光 | `postProcess.*` |

> 由你维护、无需 AI 生成、且未在输出中的字段：`price / referenceSource / author / tagIds / sortOrder / isActive`。
> 该映射以 `lumira-server/packages/admin/src/components/template-form.tsx` 的 `onSubmit` 拼装结构为唯一权威来源。