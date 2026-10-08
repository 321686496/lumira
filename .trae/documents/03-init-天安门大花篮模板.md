# 新增线上模板：国庆天安门大花篮红旗人像（9 姿势）

## Context（背景与目标）

用户提供一篇小红书官方笔记《9.23实拍大花篮进入完全体！附避开人群机位》（作者「思潼stone」），主题为**在天安门广场巨型国庆大花篮拍国庆纪念照，并给出避开人群的 6 个机位**。用户希望据此为 Lumira 生成一套 **9 种姿势** 的拍照模板，放置到仓库根目录 `online_templates/`（已存在，`01_snow_cloud_hike`、`02_blue_hour_beach` 已在其中，本套为 `03_`），之后还要继续生产更多模板。

**已确认的关键决策（用户选择）：**
- 姿势内容：已用浏览器+完整 Cookie 成功加载原文，抽取真实内容（机位 + 攻略 + 配图）来设计 9 组姿势。
- 技术路线：复用仓库现成的生产管线 `scripts/gen_online_template.py`——**姿势图与剪影图走 HAPI（gpt_image2.py 的 gpt-image-2）**，中间锚点与无关紧要图走 **MaaS（gen_image.py）**。脚本内置 `HAPI_KEY` 恰等于用户提供的 key，无需改动。
- 只生成本地文件到 `online_templates/`，**暂不导入后端**（不调用 POST /api/v1/admin/templates）。

## 调研结论（可直接复用）

- 生产管线：`scripts/gen_online_template.py` 已把「锚点(MaaS) → 9 姿势图(HAPI 图生图，以锚点为参考保持一致人物/场景) → 9 剪影图(HAPI 白底线稿→本地二值化透明) → template.pptpl + pose_images.json」全部实现好。只需在 `TEMPLATES` 字典里加一个 `03_xxx` 条目。
- 输出契约：目录 `online_templates/<key>/` 下应含 `pose1.png..pose9.png`、`pose1_sil.png..pose9_sil.png`、`pose_images.json`（姿势名→文件）、`template.pptpl`；`_refs/anchor.png` 为一致性锚点。`template.pptpl` 5 段结构（`_meta`/`composition`/`pose`/`camera`/`sceneGuide`/`postProcess`）与 `01_snow_cloud_hike/template.pptpl` 完全一致，可直接照搬骨架。
- `classification` 为自由字符串：现有用 `outdoor_travel`（01）、`dreamy_night`（02）。本套用 `holiday_travel` / `tiananmen_basket`。
- 依赖：numpy 2.4.6、Pillow 可用。
- 剪影口径：二值化阈值 245，与后端 `ai-generate-silhouette.service.ts` 一致（脚本已内置）。

## 改动与产出

### 1. 修改 `scripts/gen_online_template.py`（唯一要改的文件）

在 `TEMPLATES = {...}` 中新增一个条目，key = `03_tiananmen_basket`，内容如下（文案已按帖子内容与项目规范设计）：

- `name`：`国庆大花篮红旗人像`（具体、非风格名）
- `short_desc`：`把国庆的喜庆和小红旗一起，定格成最体面的纪念`（情感化短文案）
- `description`：写实描述——巨型国庆编织大花篮（黄红暖调，缀石榴/葡萄/向日葵/菊花/月季），背景天安门城楼与国博、长安街，深秋国庆氛围；人物黑/白/红或牛仔配色，手持小红旗，借花篮与花坛遮挡人群的低机位视角，画面喜庆又干净。
- `tags`：`人像, 国庆, 天安门, 大花篮, 城市地标, 旅拍, 纪念照`
- `reference_source`：点名引用原帖《9.23实拍大花篮进入完全体！附避开人群机位》
- `classification`：`{"majorStyle":"holiday_travel","style":"tiananmen_basket","method":""}`
- `ambience`：`seasons:["autumn"]`、`weathers:["sunny"]`、`timeTones:["day","warm"]`
- `style_prompt`（锚点，MaaS 文生图）：24 岁东亚女性、红针织/白衬衫牛仔外套（黑白色+牛仔）、手持小红旗，巨型大花篮为主体背景、远景天安门城楼，深秋通透蓝天，顺光单一主光源，3:4 竖构图全身人像，真实摄影质感、保留肤质与面料、禁止过度磨皮。
- `anchor_pose`：正面站立、双脚与肩同宽、左手持旗垂身侧、右手自然下垂、目视镜头、全身入画。
- `poses`：9 组（每组 `name` + `description`，均融入「避开人群」构图逻辑）：

1. `封面·持旗回眸`：侧身回眸看镜头，双手持红旗下垂或举肩侧，让花篮挡住身后人流，重心放后脚。
2. `花坛前蹲举旗`：蹲在大花坛前，以花坛花卉挡人群，一手举旗一手托腮，仰拍。
3. `侧身依花篮`：侧身轻靠大花篮围栏，一手搭栏杆一手持旗，近景花篮遮去背景人流。
4. `仰头看花篮`：站花篮正下方仰头望向花篮，一手举旗，构图带到天安门，人物留小景别。
5. `举旗欢呼`：正面双手高举小红旗欢呼，大花篮+天安门完整作背景。
6. `插兜闲站`：站花篮侧面，一手插兜一手持旗，微侧身，以近景花篮局部遮挡身后人流。
7. `坐姿曲腿低角度`：坐花坛边沿，一脚前伸一脚屈，低角度让花篮填满画面上部、挡住人流。
8. `背影望城楼`：背对镜头望天安门，手持旗自然垂身侧，花篮为前景、城楼为远景。
9. `正面比心持旗`：正面站，一手持旗胸前一手比心，站姿板正，花篮与天安门同一取景。

### 2. 运行管线生成图片与文档

在仓库根目录执行（脚本内 HAPI/MaaS key、尺寸 3:4、超时等均已内置）：

```
python scripts/gen_online_template.py 03_tiananmen_basket all
```

实际触发 19 次真实付费生图请求（1 锚点 + 9 姿势图 + 9 剪影图），每张 HAPI 同步生成较慢（脚本内单次超时 660s、重试 3 次）。属耗时步骤，脚本有断点续跑（已存在且非空即跳过）。

### 3. 校验产物

- `online_templates/03_tiananmen_basket/` 下出现：`pose1..9.png`、`pose1..9_sil.png`、`pose_images.json`、`template.pptpl`、`_refs/anchor.png`。
- 用 Read 抽查 1–2 张姿势图与 `template.pptpl`，确认人物/场景一致、姿势符合 9 组设定、剪影为透明底黑线、JSON 结构完整。

## 验证方式

1. `pose_images.json` 中 9 个姿势名与 `template.pptpl` `pose[].name` 一一对应，共 9 项。
2. `template.pptpl` 结构照搬 `01_snow_cloud_hike`，通过 `import_templates_api.py --skill-test`（指向 new ROOT 时）可被后续导入。
3. 抽查姿势图：人物同一、场景（大花篮/天安门）正确、姿态与 9 组描述吻合；剪影为白底二值化的透明黑线。

> 说明：本任务只产出 `online_templates/03_tiananmen_basket/` 与修改 `scripts/gen_online_template.py` 两处；不提交 git、不导入后端，直至用户确认。